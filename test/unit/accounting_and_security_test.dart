import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:dm_lace_surat/core/database/database_helper.dart';
import 'package:dm_lace_surat/core/database/sample_data_seeder.dart';
import 'package:dm_lace_surat/core/utils/currency_formatter.dart';
import 'package:dm_lace_surat/core/security/pin_service.dart';
import 'package:dm_lace_surat/models/party.dart';
import 'package:dm_lace_surat/models/document.dart';
import 'package:dm_lace_surat/models/document_item.dart';
import 'package:dm_lace_surat/models/transaction.dart';
import 'package:dm_lace_surat/models/inventory_item.dart';
import 'package:dm_lace_surat/repositories/party_repository.dart';
import 'package:dm_lace_surat/repositories/document_repository.dart';
import 'package:dm_lace_surat/repositories/transaction_repository.dart';
import 'package:dm_lace_surat/repositories/inventory_repository.dart';
import 'package:dm_lace_surat/services/backup_service.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    DatabaseHelper.resetForTesting(null, inMemoryDatabasePath);
  });

  late DatabaseHelper dbHelper;
  late PartyRepository partyRepo;
  late DocumentRepository docRepo;
  late TransactionRepository txRepo;
  late InventoryRepository invRepo;
  late BackupService backupService;

  setUp(() async {
    dbHelper = DatabaseHelper.instance;
    await dbHelper.wipeDatabase();
    partyRepo = PartyRepository(dbHelper: dbHelper);
    docRepo = DocumentRepository(dbHelper: dbHelper, partyRepo: partyRepo);
    txRepo = TransactionRepository(dbHelper: dbHelper, partyRepo: partyRepo);
    invRepo = InventoryRepository(dbHelper: dbHelper);
    backupService = BackupService(dbHelper: dbHelper);
  });

  test('Supplier balance accurately tracks purchases and payments', () async {
    // 1. Create Supplier with opening payable ₹ 15,000
    final supplierId = await partyRepo.insertParty(Party(
      name: 'Radhe Zari Mills',
      type: 'supplier',
      phone: '9825112233',
      openingBalancePaise: CurrencyFormatter.rupeesToPaise(15000.0),
      balanceType: 'payable',
    ));

    var party = await partyRepo.getPartyById(supplierId);
    expect(party?.currentBalanceRupees, -15000.0);
    expect(party?.balanceType, 'payable');

    // 2. Issue a Purchase Bill of ₹ 25,000
    final purchaseBillId = await docRepo.createDocument(
      BusinessDocument(
        docNumber: 'PB-2026-TEST-01',
        docType: 'purchase_bill',
        partyId: supplierId,
        docDate: '2026-10-25',
        items: [
          DocumentItem(
            itemName: 'Gold Zari Spools',
            quantity: 50,
            unit: 'roll',
            ratePaise: CurrencyFormatter.rupeesToPaise(500.0), // 50 * 500 = 25,000
          ),
        ],
      ),
    );

    party = await partyRepo.getPartyById(supplierId);
    // -15,000 opening - 25,000 purchase = -40,000 payable
    expect(party?.currentBalanceRupees, -40000.0);

    // 3. Make partial payment of ₹ 20,000 to supplier via Bank Transfer
    await txRepo.insertTransaction(
      BusinessTransaction(
        transactionDate: '2026-10-25',
        partyId: supplierId,
        transactionType: 'supplier_payment',
        amountPaise: CurrencyFormatter.rupeesToPaise(20000.0),
        paymentMethod: 'bank_transfer',
      ),
      allocatedDocId: purchaseBillId,
    );

    // -40,000 + 20,000 = -20,000 payable remaining
    party = await partyRepo.getPartyById(supplierId);
    expect(party?.currentBalanceRupees, -20000.0);

    final bill = await docRepo.getDocumentById(purchaseBillId);
    expect(bill?.paidAmountRupees, 20000.0);
    expect(bill?.remainingBalanceRupees, 5000.0);
    expect(bill?.paymentStatus, 'partial');
  });

  test('Inventory tracking manages stock movements and low-stock indicators', () async {
    // 1. Add inventory item with opening stock 100 meters
    final itemId = await invRepo.insertItem(InventoryItem(
      designCode: 'ZL-SILVER-01',
      itemName: 'Silver Sequence Lace',
      unit: 'meter',
      openingQuantity: 100.0,
      currentStock: 100.0,
      purchaseRatePaise: CurrencyFormatter.rupeesToPaise(40.0),
      sellingRatePaise: CurrencyFormatter.rupeesToPaise(80.0),
      lowStockWarningQty: 25.0,
    ));

    var item = await invRepo.getItemById(itemId);
    expect(item?.currentStock, 100.0);
    expect(item?.isLowStock, false);

    // 2. Adjust stock to 20 meters (below warning threshold 25)
    await invRepo.adjustStock(
      itemId: itemId,
      adjustedQty: 20.0,
      reason: 'Physical stock reconciliation after dispatch',
    );

    item = await invRepo.getItemById(itemId);
    expect(item?.currentStock, 20.0);
    // 20.0 <= lowStockWarningQty (25.0), so isLowStock should be true!
    expect(item?.isLowStock, true);
  });

  test('PinService provides salted SHA-256 hash, verification, and inactivity lock', () {
    // Test hashing
    final hash1 = PinService.hashPin('1234');
    final hash2 = PinService.hashPin('1234');
    final hashDifferent = PinService.hashPin('4321');

    expect(hash1, hash2);
    expect(hash1, isNot(hashDifferent));
    expect(hash1.length, 64); // SHA-256 hex string

    // Test initialization and verification
    PinService.initialize(hash1, timeoutMinutes: 5);
    expect(PinService.isPinEnabled, true);
    expect(PinService.isLocked, true);

    // Wrong PIN
    expect(PinService.verifyPin('9999'), false);
    expect(PinService.isLocked, true);

    // Correct PIN unlocks
    expect(PinService.verifyPin('1234'), true);
    expect(PinService.isLocked, false);

    // Lock explicitly
    PinService.setLocked(true);
    expect(PinService.isLocked, true);
  });

  test('BackupService creates tamper-proof JSON backup and restores database cleanly', () async {
    // Seed sample data
    await SampleDataSeeder.seedSampleData();

    final partiesBefore = await partyRepo.getAllParties();
    expect(partiesBefore.length, greaterThanOrEqualTo(4));

    // Create backup JSON with SHA-256 checksum
    final backupJson = await backupService.createBackupJson();
    expect(backupJson.contains('checksum'), true);
    expect(backupJson.contains('DM Lace Surat'), true);

    // Validate backup integrity
    final validated = backupService.validateBackup(backupJson);
    expect(validated, isNotNull);

    // Test tamper detection: tamper with the JSON string
    final tamperedJson = backupJson.replaceFirst('Surat', 'Mumbai');
    final tamperedResult = backupService.validateBackup(tamperedJson);
    expect(tamperedResult, isNull); // Must reject tampered backup!

    // Wipe database completely
    await dbHelper.wipeDatabase();
    final partiesAfterWipe = await partyRepo.getAllParties();
    expect(partiesAfterWipe.isEmpty, true);

    // Restore backup
    final restoreSuccess = await backupService.restoreBackup(backupJson);
    expect(restoreSuccess, true);

    // Verify all parties and data are restored
    final partiesRestored = await partyRepo.getAllParties();
    expect(partiesRestored.length, partiesBefore.length);
  });
}
