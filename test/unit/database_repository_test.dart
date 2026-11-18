import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:dm_lace_surat/core/database/database_helper.dart';
import 'package:dm_lace_surat/core/database/sample_data_seeder.dart';
import 'package:dm_lace_surat/core/utils/currency_formatter.dart';
import 'package:dm_lace_surat/models/party.dart';
import 'package:dm_lace_surat/models/document.dart';
import 'package:dm_lace_surat/models/document_item.dart';
import 'package:dm_lace_surat/models/transaction.dart';
import 'package:dm_lace_surat/repositories/party_repository.dart';
import 'package:dm_lace_surat/repositories/document_repository.dart';
import 'package:dm_lace_surat/repositories/transaction_repository.dart';
import 'package:dm_lace_surat/repositories/inventory_repository.dart';
import 'package:dm_lace_surat/repositories/dashboard_repository.dart';

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
  late DashboardRepository dashboardRepo;

  setUp(() async {
    dbHelper = DatabaseHelper.instance;
    await dbHelper.wipeDatabase();
    partyRepo = PartyRepository(dbHelper: dbHelper);
    docRepo = DocumentRepository(dbHelper: dbHelper, partyRepo: partyRepo);
    txRepo = TransactionRepository(dbHelper: dbHelper, partyRepo: partyRepo);
    invRepo = InventoryRepository(dbHelper: dbHelper);
    dashboardRepo = DashboardRepository(dbHelper: dbHelper, txRepo: txRepo);
  });

  test('Party balance accurately tracks opening balance, sales bills, and payments', () async {
    // 1. Create Customer with opening balance ₹ 10,000 receivable
    final customerId = await partyRepo.insertParty(Party(
      name: 'Surat Saree Palace',
      type: 'customer',
      phone: '9898001122',
      openingBalancePaise: CurrencyFormatter.rupeesToPaise(10000.0),
      balanceType: 'receivable',
    ));

    var party = await partyRepo.getPartyById(customerId);
    expect(party?.currentBalanceRupees, 10000.0);

    // 2. Issue a Kaccha Bill for ₹ 15,000 with advance payment ₹ 5,000
    // Net addition to balance should be + ₹ 15,000 billed - ₹ 5,000 received = + ₹ 10,000
    // Total balance becomes ₹ 20,000
    final billId = await docRepo.createDocument(
      BusinessDocument(
        docNumber: 'KB-2026-TEST-01',
        docType: 'kaccha_bill',
        partyId: customerId,
        docDate: '2026-10-25',
        items: [
          DocumentItem(
            itemName: 'Zari Lace 3-Inch',
            quantity: 150,
            unit: 'meter',
            ratePaise: CurrencyFormatter.rupeesToPaise(100.0), // 150 * 100 = 15,000
          ),
        ],
      ),
      advancePaymentPaise: CurrencyFormatter.rupeesToPaise(5000.0),
    );

    party = await partyRepo.getPartyById(customerId);
    expect(party?.currentBalanceRupees, 20000.0);

    final bill = await docRepo.getDocumentById(billId);
    expect(bill?.grandTotalRupees, 15000.0);
    expect(bill?.paidAmountRupees, 5000.0);
    expect(bill?.remainingBalanceRupees, 10000.0);
    expect(bill?.paymentStatus, 'partial');

    // 3. Receive remaining payment of ₹ 10,000 against this bill
    await txRepo.insertTransaction(
      BusinessTransaction(
        transactionDate: '2026-10-25',
        partyId: customerId,
        transactionType: 'customer_receipt',
        amountPaise: CurrencyFormatter.rupeesToPaise(10000.0),
        paymentMethod: 'upi',
      ),
      allocatedDocId: billId,
    );

    party = await partyRepo.getPartyById(customerId);
    expect(party?.currentBalanceRupees, 10000.0); // Only opening balance remains

    final updatedBill = await docRepo.getDocumentById(billId);
    expect(updatedBill?.paidAmountRupees, 15000.0);
    expect(updatedBill?.remainingBalanceRupees, 0.0);
    expect(updatedBill?.paymentStatus, 'paid');
  });

  test('Delivery challan does not create sales revenue or increase party balance until converted', () async {
    final customerId = await partyRepo.insertParty(Party(
      name: 'Shree Krishna Boutiques',
      type: 'customer',
      openingBalancePaise: 0,
      balanceType: 'receivable',
    ));

    // Create Delivery Challan for ₹ 8,000 worth of lace
    final challanId = await docRepo.createDocument(
      BusinessDocument(
        docNumber: 'DC-2026-TEST-01',
        docType: 'challan',
        partyId: customerId,
        docDate: '2026-10-25',
        items: [
          DocumentItem(
            itemName: 'Embroidered Border',
            quantity: 40,
            unit: 'piece',
            ratePaise: CurrencyFormatter.rupeesToPaise(200.0),
          ),
        ],
      ),
    );

    // Party balance must still be 0! Challans do NOT create accounting revenue
    var party = await partyRepo.getPartyById(customerId);
    expect(party?.currentBalanceRupees, 0.0);

    // Now convert the Challan into a Kaccha Bill
    final convertedBillId = await docRepo.convertChallanToInvoice(
      challanId: challanId,
      targetDocType: 'kaccha_bill',
    );

    expect(convertedBillId, isNotNull);

    // Now party balance must reflect the billed ₹ 8,000
    party = await partyRepo.getPartyById(customerId);
    expect(party?.currentBalanceRupees, 8000.0);

    final convertedBill = await docRepo.getDocumentById(convertedBillId);
    expect(convertedBill?.isConvertedFromChallan, true);
    expect(convertedBill?.originalChallanId, challanId);
  });

  test('Cash and Bank transfers preserve total liquid funds without creating fake income/expense', () async {
    // Initial capital of ₹ 1,00,000 into Bank
    await txRepo.insertTransaction(BusinessTransaction(
      transactionDate: '2026-10-25',
      transactionType: 'owner_capital',
      amountPaise: CurrencyFormatter.rupeesToPaise(100000.0),
      paymentMethod: 'bank_transfer',
    ));

    var balances = await txRepo.getLiquidBalances();
    expect(balances['cash'], 0.0);
    expect(balances['bank'], 100000.0);
    expect(balances['total'], 100000.0);

    // Transfer ₹ 30,000 from Bank to Cash drawer
    await txRepo.insertTransaction(BusinessTransaction(
      transactionDate: '2026-10-25',
      transactionType: 'bank_to_cash',
      amountPaise: CurrencyFormatter.rupeesToPaise(30000.0),
      paymentMethod: 'cash',
    ));

    balances = await txRepo.getLiquidBalances();
    expect(balances['cash'], 30000.0);
    expect(balances['bank'], 70000.0);
    expect(balances['total'], 100000.0); // Total remains strictly unchanged!
  });

  test('SampleDataSeeder populates rich realistic Surat lace dataset across periods and clears cleanly', () async {
    // 1. Seed sample data
    await SampleDataSeeder.seedSampleData();

    final parties = await partyRepo.getAllParties();
    expect(parties.length, greaterThanOrEqualTo(5));

    final items = await invRepo.getItems();
    expect(items.length, greaterThanOrEqualTo(5));

    final docs = await docRepo.getDocuments();
    expect(docs.length, greaterThanOrEqualTo(5));

    // 2. Test Period filtering for Today, Week, Month, All Time
    final todaySummary = await dashboardRepo.getDashboardSummary(period: 'today');
    final weekSummary = await dashboardRepo.getDashboardSummary(period: 'week');
    final monthSummary = await dashboardRepo.getDashboardSummary(period: 'month');
    final allSummary = await dashboardRepo.getDashboardSummary(period: 'all');

    // Today must have positive activity
    expect(todaySummary.todaySales, greaterThan(0));
    expect(todaySummary.todayReceipts, greaterThan(0));

    // Week sales must be >= today's sales
    expect(weekSummary.todaySales, greaterThanOrEqualTo(todaySummary.todaySales));

    // Month sales must be >= week's sales
    expect(monthSummary.todaySales, greaterThanOrEqualTo(weekSummary.todaySales));

    // All time sales must be >= month's sales
    expect(allSummary.todaySales, greaterThanOrEqualTo(monthSummary.todaySales));

    // Receivables must grow across periods
    expect(allSummary.totalReceivables, greaterThanOrEqualTo(monthSummary.totalReceivables));
    expect(monthSummary.totalReceivables, greaterThanOrEqualTo(weekSummary.totalReceivables));
    expect(weekSummary.totalReceivables, greaterThanOrEqualTo(todaySummary.totalReceivables));

    // Payables must grow across periods
    expect(allSummary.totalPayables, greaterThanOrEqualTo(monthSummary.totalPayables));
    expect(monthSummary.totalPayables, greaterThanOrEqualTo(weekSummary.totalPayables));
    expect(weekSummary.totalPayables, greaterThanOrEqualTo(todaySummary.totalPayables));

    // 3. Test clearAllData wipes everything back to a clean slate
    await SampleDataSeeder.clearAllData();

    final clearedParties = await partyRepo.getAllParties();
    expect(clearedParties.isEmpty, true);

    final clearedDocs = await docRepo.getDocuments();
    expect(clearedDocs.isEmpty, true);

    final clearedItems = await invRepo.getItems();
    expect(clearedItems.isEmpty, true);
  });
}
