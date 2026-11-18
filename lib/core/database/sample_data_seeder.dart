import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart' show ConflictAlgorithm;
import '../utils/currency_formatter.dart';
import '../../models/party.dart';
import '../../models/document.dart';
import '../../models/document_item.dart';
import '../../models/transaction.dart';
import '../../models/inventory_item.dart';
import '../../models/worker.dart';
import '../../models/machine_katai_entry.dart';
import '../../models/worker_payment.dart';
import '../../repositories/party_repository.dart';
import '../../repositories/document_repository.dart';
import '../../repositories/transaction_repository.dart';
import '../../repositories/inventory_repository.dart';
import '../../repositories/worker_repository.dart';
import 'database_helper.dart';
import 'database_tables.dart';

class SampleDataSeeder {
  /// Safely wipes all data tables back to an empty, clean ledger state.
  static Future<void> clearAllData() async {
    final dbHelper = DatabaseHelper.instance;
    await dbHelper.wipeDatabase();
  }

  /// Seeds realistic Surat lace merchant business data distributed across:
  /// Today, This Week, This Month, and Historical Months.
  static Future<void> seedSampleData() async {
    final dbHelper = DatabaseHelper.instance;
    await dbHelper.wipeDatabase();

    final partyRepo = PartyRepository(dbHelper: dbHelper);
    final docRepo = DocumentRepository(dbHelper: dbHelper, partyRepo: partyRepo);
    final txRepo = TransactionRepository(dbHelper: dbHelper, partyRepo: partyRepo);
    final invRepo = InventoryRepository(dbHelper: dbHelper);

    final now = DateTime.now();
    String formatDate(DateTime dt) => DateFormat('yyyy-MM-dd').format(dt);

    final todayStr = formatDate(now);
    final twoDaysAgoStr = formatDate(now.subtract(const Duration(days: 2)));
    final fourDaysAgoStr = formatDate(now.subtract(const Duration(days: 4)));
    final fifteenDaysAgoStr = formatDate(now.subtract(const Duration(days: 15)));
    final twentyDaysAgoStr = formatDate(now.subtract(const Duration(days: 20)));
    final thirtyFiveDaysAgoStr = formatDate(now.subtract(const Duration(days: 35)));
    final sixtyFiveDaysAgoStr = formatDate(now.subtract(const Duration(days: 65)));
    final ninetyFiveDaysAgoStr = formatDate(now.subtract(const Duration(days: 95)));
    final oneTwentyDaysAgoStr = formatDate(now.subtract(const Duration(days: 120)));

    final dueInTenDays = formatDate(now.add(const Duration(days: 10)));
    final overdueDueDate = formatDate(now.subtract(const Duration(days: 3)));

    // 1. Seed Real Surat Lace Inventory Items (Matching DM Lace Factory Production)
    final inv1 = await invRepo.insertItem(InventoryItem(
      designCode: 'DM-ZARI-101',
      itemName: 'Royal Zari Gota Jali Border (2-Inch)',
      unit: 'meter',
      category: 'Zari Border',
      width: '2.0 Inch (45mm)',
      colors: 'Antique Gold, Bright Gold',
      imagePath: 'assets/images/catalog/dm_zari_jali.jpg',
      description: 'Fine geometric diamond jali openwork with solid zari borders for bridal sarees and lehengas.',
      openingQuantity: 1500,
      purchaseRatePaise: CurrencyFormatter.rupeesToPaise(38.0),
      sellingRatePaise: CurrencyFormatter.rupeesToPaise(65.0),
      lowStockWarningQty: 200,
    ));

    final inv2 = await invRepo.insertItem(InventoryItem(
      designCode: 'DM-LOOP-201',
      itemName: 'Lachka Loop Kangura Braided Trim',
      unit: 'meter',
      category: 'Loop Kangura',
      width: '1.0 Inch (25mm)',
      colors: 'Gold, Antique Gold, Silver',
      imagePath: 'assets/images/catalog/dm_lachka_loop_gold.jpg',
      description: 'Classic Surat crochet loom loop lachka lace with teardrop swirl edge.',
      openingQuantity: 900,
      purchaseRatePaise: CurrencyFormatter.rupeesToPaise(18.0),
      sellingRatePaise: CurrencyFormatter.rupeesToPaise(35.0),
      lowStockWarningQty: 100,
    ));

    final inv3 = await invRepo.insertItem(InventoryItem(
      designCode: 'DM-MOTI-301',
      itemName: 'Zari Pearl Moti Drop Saree Border',
      unit: 'meter',
      category: 'Pearl & Beads',
      width: '1.5 Inch (38mm)',
      colors: 'Gold with White Pearls',
      imagePath: 'assets/images/catalog/dm_pearl_moti.jpg',
      description: 'Royal metallic gold border embellished with hanging white round pearl beads along the scalloped edge.',
      openingQuantity: 500,
      purchaseRatePaise: CurrencyFormatter.rupeesToPaise(48.0),
      sellingRatePaise: CurrencyFormatter.rupeesToPaise(85.0),
      lowStockWarningQty: 50,
    ));

    final inv4 = await invRepo.insertItem(InventoryItem(
      designCode: 'DM-KUNDAN-401',
      itemName: 'Kundan Stone Ruby & Emerald Gold Border',
      unit: 'meter',
      category: 'Kundan & Stone',
      width: '1.25 Inch (32mm)',
      colors: 'Gold with Ruby Red & Emerald Green Stones',
      imagePath: 'assets/images/catalog/dm_kundan_stone.jpg',
      description: 'Heavy designer gold border studded with alternating red & green cut stones set in gold bezels.',
      openingQuantity: 350,
      purchaseRatePaise: CurrencyFormatter.rupeesToPaise(68.0),
      sellingRatePaise: CurrencyFormatter.rupeesToPaise(120.0),
      lowStockWarningQty: 40,
    ));

    final inv5 = await invRepo.insertItem(InventoryItem(
      designCode: 'DM-SEQ-501',
      itemName: 'White Thread & Rainbow Sequin Lattice Trim',
      unit: 'meter',
      category: 'Sequence Work',
      width: '0.75 Inch (18mm)',
      colors: 'Gold & White with Holographic Sequins',
      imagePath: 'assets/images/catalog/dm_sequin_lattice.jpg',
      description: 'Delicate cross-hatch white thread lattice embroidery with iridescent reflective sequins and metallic gold cording.',
      openingQuantity: 300,
      purchaseRatePaise: CurrencyFormatter.rupeesToPaise(26.0),
      sellingRatePaise: CurrencyFormatter.rupeesToPaise(48.0),
      lowStockWarningQty: 30,
    ));

    final inv6 = await invRepo.insertItem(InventoryItem(
      designCode: 'DM-LOOP-202',
      itemName: 'Multicolor Festive Loop Kangura Border',
      unit: 'meter',
      category: 'Loop Kangura',
      width: '1.2 Inch (30mm)',
      colors: 'Rainbow Multicolor, Pastel, Dual-tone',
      imagePath: 'assets/images/catalog/dm_lachka_loop_shades.jpg',
      description: 'Vibrant multi-shade twisted loop lace with metallic gold border for festive wear.',
      openingQuantity: 250,
      purchaseRatePaise: CurrencyFormatter.rupeesToPaise(22.0),
      sellingRatePaise: CurrencyFormatter.rupeesToPaise(42.0),
      lowStockWarningQty: 35,
    ));

    await invRepo.insertItem(InventoryItem(
      designCode: 'DM-DANA-601',
      itemName: 'Glass Cut-Dana Zigzag Chevron Border',
      unit: 'meter',
      category: 'Cut-Dana Work',
      width: '1.0 Inch (25mm)',
      colors: 'Gold with Clear Crystal Bugle Beads',
      imagePath: 'assets/images/catalog/dm_cutdana_zigzag.jpg',
      description: 'Handloom look metallic braid with clear iridescent glass cut-dana bugle beads in chevron pattern.',
      openingQuantity: 400,
      purchaseRatePaise: CurrencyFormatter.rupeesToPaise(40.0),
      sellingRatePaise: CurrencyFormatter.rupeesToPaise(72.0),
      lowStockWarningQty: 40,
    ));

    await invRepo.insertItem(InventoryItem(
      designCode: 'DM-RESHAM-701',
      itemName: 'Bottle Green & Gold Resham Saree Border',
      unit: 'meter',
      category: 'Resham & Zari',
      width: '1.0 Inch (25mm)',
      colors: 'Bottle Green, Golden Yellow, Peach',
      imagePath: 'assets/images/catalog/dm_green_resham.jpg',
      description: 'Fine dual-tone dark green tape with zigzag yellow-peach resham thread and gold metallic cords.',
      openingQuantity: 300,
      purchaseRatePaise: CurrencyFormatter.rupeesToPaise(20.0),
      sellingRatePaise: CurrencyFormatter.rupeesToPaise(38.0),
      lowStockWarningQty: 30,
    ));

    await invRepo.insertItem(InventoryItem(
      designCode: 'DM-CHEV-801',
      itemName: 'Multicolor Triangle Samosa Chevron Gota',
      unit: 'meter',
      category: 'Gota Patti',
      width: '1.0 Inch (25mm)',
      colors: 'Multicolor Resham & Gold',
      imagePath: 'assets/images/catalog/dm_triangle_chevron.jpg',
      description: 'Sharp triangular prism kangura edge with multi-color braided silk threads and gold zari.',
      openingQuantity: 200,
      purchaseRatePaise: CurrencyFormatter.rupeesToPaise(28.0),
      sellingRatePaise: CurrencyFormatter.rupeesToPaise(52.0),
      lowStockWarningQty: 25,
    ));

    await invRepo.insertItem(InventoryItem(
      designCode: 'DM-WAVE-901',
      itemName: 'Scalloped Cutwork Zari & Sequin Wave Border',
      unit: 'meter',
      category: 'Sequence Work',
      width: '1.2 Inch (30mm)',
      colors: 'Gold with Holographic Sequins',
      imagePath: 'assets/images/catalog/dm_scallop_wave.jpg',
      description: 'Scalloped wave edge with fine micro sequins and twisted golden metallic cord weave in roll spool packaging.',
      openingQuantity: 450,
      purchaseRatePaise: CurrencyFormatter.rupeesToPaise(32.0),
      sellingRatePaise: CurrencyFormatter.rupeesToPaise(58.0),
      lowStockWarningQty: 40,
    ));

    // 2. Seed Parties (Wholesalers, Retailers, Manufacturers & Suppliers)
    final cust1 = await partyRepo.insertParty(Party(
      name: 'Radha Krishna Sarees',
      type: 'customer',
      phone: '9825123456',
      address: 'Shop 204, Millennium Textile Market, Ring Road, Surat',
      openingBalancePaise: CurrencyFormatter.rupeesToPaise(12000.0),
      balanceType: 'receivable',
      notes: 'Regular retail showroom client, 15-day credit cycle',
    ));

    final cust2 = await partyRepo.insertParty(Party(
      name: 'Ambaji Designer Boutique',
      type: 'retailer',
      phone: '9898234567',
      address: 'G-12, City Light Road, Surat',
      openingBalancePaise: CurrencyFormatter.rupeesToPaise(6500.0),
      balanceType: 'receivable',
      notes: 'Boutique bridal orders, immediate UPI payment',
    ));

    final cust3 = await partyRepo.insertParty(Party(
      name: 'Shree Balaji Textile Agency',
      type: 'wholesaler',
      phone: '9879012345',
      address: 'Lower Ground 45, Avadh Textile Market, Surat',
      openingBalancePaise: CurrencyFormatter.rupeesToPaise(18500.0),
      balanceType: 'receivable',
      notes: 'Wholesale outstation delivery partner',
    ));

    final cust4 = await partyRepo.insertParty(Party(
      name: 'Surat Saree Sansar',
      type: 'manufacturer',
      phone: '9427098765',
      address: 'Universal Textile Market, Ring Road, Surat',
      openingBalancePaise: CurrencyFormatter.rupeesToPaise(9000.0),
      balanceType: 'receivable',
      notes: 'Designer fancy sarees manufacturer',
    ));

    final supp1 = await partyRepo.insertParty(Party(
      name: 'Jay Ambe Yarns & Zari Mills',
      type: 'material',
      phone: '9712345678',
      address: 'Plot 45, Road 8, GIDC Sachin, Surat',
      openingBalancePaise: CurrencyFormatter.rupeesToPaise(48000.0),
      balanceType: 'payable',
      notes: 'Zari and raw metallic thread yarn supplier',
    ));

    final supp2 = await partyRepo.insertParty(Party(
      name: 'Mahavir Dyeing & Finishing Works',
      type: 'supplier',
      phone: '9426112233',
      address: 'Pandesara Industrial Estate, Surat',
      openingBalancePaise: CurrencyFormatter.rupeesToPaise(32000.0),
      balanceType: 'payable',
      notes: 'Lace dyeing, bleaching and calendering processing unit',
    ));

    final supp3 = await partyRepo.insertParty(Party(
      name: 'Kuber Embroidery Threads',
      type: 'material',
      phone: '9824156789',
      address: 'Katargam GIDC, Surat',
      openingBalancePaise: CurrencyFormatter.rupeesToPaise(28000.0),
      balanceType: 'payable',
      notes: 'Metallic sequins and multihead embroidery thread supplier',
    ));

    final chunLace = await partyRepo.insertParty(Party(
      name: 'चुन लेस (Chun Lace)',
      type: 'customer',
      phone: '9825012345',
      address: 'सूरत टेक्सटाइल मार्केट, रिंग रोड, सूरत',
      openingBalancePaise: 0,
      balanceType: 'receivable',
      notes: 'रेगुलर लेस व्यापारी • चालान डिलीवरी पार्टी',
    ));

    final santAshish = await partyRepo.insertParty(Party(
      name: 'संत आशिष (Sant Ashish)',
      type: 'supplier',
      phone: '9879123456',
      address: 'गोडादरा रोड, सूरत',
      openingBalancePaise: 0,
      balanceType: 'payable',
      notes: 'लेस सप्लायर • कच्चा माल आवक',
    ));

    final kalpataruMall = await partyRepo.insertParty(Party(
      name: 'Shree Kalpataru Mall',
      type: 'supplier',
      phone: '7383744080',
      address: 'Shop 8-9, Roopsagar Row House, Devadh Road, Godadara',
      openingBalancePaise: 0,
      balanceType: 'payable',
      notes: 'मॉल / रिटेल इनवॉइस',
    ));

    // Seed Real Physical Slips from User Photos
    // 1. Slip 191 to Chun Lace
    await docRepo.createDocument(
      BusinessDocument(
        docNumber: 'CH-191',
        docType: 'challan',
        tradeType: 'sale',
        partyId: chunLace,
        partyName: 'चुन लेस (Chun Lace)',
        docDate: '2026-09-07',
        subtotalPaise: CurrencyFormatter.rupeesToPaise(66560.0),
        grandTotalPaise: CurrencyFormatter.rupeesToPaise(66560.0),
        paidAmountPaise: 0,
        imagePath: 'assets/images/slips/slip_191_chun_lace.jpg',
        notes: 'D.N. 56 18 mt (32 × 26 = 832 mt @ ₹80) • Recd by Vijay',
        items: [
          DocumentItem(
            itemName: 'D.N. 56 18 mt (32 × 26 = 832 mt)',
            quantity: 832.0,
            unit: 'meter',
            ratePaise: CurrencyFormatter.rupeesToPaise(80.0),
            taxableAmountPaise: CurrencyFormatter.rupeesToPaise(66560.0),
            lineTotalPaise: CurrencyFormatter.rupeesToPaise(66560.0),
          ),
        ],
      ),
    );

    // 2. Slip 222 to Chun Lace
    await docRepo.createDocument(
      BusinessDocument(
        docNumber: 'CH-222',
        docType: 'challan',
        tradeType: 'sale',
        partyId: chunLace,
        partyName: 'चुन लेस (Chun Lace)',
        docDate: '2026-09-30',
        subtotalPaise: CurrencyFormatter.rupeesToPaise(19760.0),
        grandTotalPaise: CurrencyFormatter.rupeesToPaise(19760.0),
        paidAmountPaise: 0,
        imagePath: 'assets/images/slips/slip_222_chun_lace.jpg',
        notes: 'D.N. 56 18 mt (260 mt @ ₹76) • Recd by Vijay',
        items: [
          DocumentItem(
            itemName: 'D.N. 56 18 mt (260 mt)',
            quantity: 260.0,
            unit: 'meter',
            ratePaise: CurrencyFormatter.rupeesToPaise(76.0),
            taxableAmountPaise: CurrencyFormatter.rupeesToPaise(19760.0),
            lineTotalPaise: CurrencyFormatter.rupeesToPaise(19760.0),
          ),
        ],
      ),
    );

    // 3. Slip 1068 from Sant Ashish (Inward Challan)
    await docRepo.createDocument(
      BusinessDocument(
        docNumber: 'CH-1068',
        docType: 'purchase_bill',
        tradeType: 'purchase',
        partyId: santAshish,
        partyName: 'संत आशिष (Sant Ashish)',
        docDate: '2026-10-20',
        subtotalPaise: CurrencyFormatter.rupeesToPaise(11368.0),
        grandTotalPaise: CurrencyFormatter.rupeesToPaise(11368.0),
        paidAmountPaise: 0,
        imagePath: 'assets/images/slips/slip_1068_sant_ashish.jpg',
        notes: 'Pal... 32.480 × ₹350 (आवक चालान)',
        items: [
          DocumentItem(
            itemName: 'Pal... 32.480 × 350',
            quantity: 32.48,
            unit: 'meter',
            ratePaise: CurrencyFormatter.rupeesToPaise(350.0),
            taxableAmountPaise: CurrencyFormatter.rupeesToPaise(11368.0),
            lineTotalPaise: CurrencyFormatter.rupeesToPaise(11368.0),
          ),
        ],
      ),
    );

    // 4. Retail Invoice 10097 from Shree Kalpataru Mall (Inward Bill)
    await docRepo.createDocument(
      BusinessDocument(
        docNumber: 'INV-10097',
        docType: 'purchase_bill',
        tradeType: 'purchase',
        partyId: kalpataruMall,
        partyName: 'Shree Kalpataru Mall',
        docDate: '2026-07-22',
        subtotalPaise: CurrencyFormatter.rupeesToPaise(36700.0),
        grandTotalPaise: CurrencyFormatter.rupeesToPaise(36700.0),
        paidAmountPaise: CurrencyFormatter.rupeesToPaise(36700.0),
        imagePath: 'assets/images/slips/bill_kalpataru_mall.jpg',
        notes: 'Samsung Washing Machine + Stand + Soundbar (Full Paid)',
        items: [
          DocumentItem(
            itemName: 'Samsung Fully Automatic Washing Machine',
            quantity: 1.0,
            unit: 'pck',
            ratePaise: CurrencyFormatter.rupeesToPaise(32000.0),
            taxableAmountPaise: CurrencyFormatter.rupeesToPaise(32000.0),
            lineTotalPaise: CurrencyFormatter.rupeesToPaise(32000.0),
          ),
          DocumentItem(
            itemName: 'Stand Washing Machine Metal',
            quantity: 1.0,
            unit: 'pck',
            ratePaise: CurrencyFormatter.rupeesToPaise(2400.0),
            taxableAmountPaise: CurrencyFormatter.rupeesToPaise(2400.0),
            lineTotalPaise: CurrencyFormatter.rupeesToPaise(2400.0),
          ),
          DocumentItem(
            itemName: 'Soundbar Special',
            quantity: 1.0,
            unit: 'pck',
            ratePaise: CurrencyFormatter.rupeesToPaise(2300.0),
            taxableAmountPaise: CurrencyFormatter.rupeesToPaise(2300.0),
            lineTotalPaise: CurrencyFormatter.rupeesToPaise(2300.0),
          ),
        ],
      ),
    );

    // 3. Seed Capital Infusion & Cash Counter Setup
    await txRepo.insertTransaction(BusinessTransaction(
      transactionDate: sixtyFiveDaysAgoStr,
      transactionType: 'owner_capital',
      amountPaise: CurrencyFormatter.rupeesToPaise(150000.0),
      paymentMethod: 'bank_transfer',
      referenceNumber: 'NEFT-CAPITAL-01',
      notes: 'Initial business capital invested in Bank of Baroda account',
    ));

    await txRepo.insertTransaction(BusinessTransaction(
      transactionDate: sixtyFiveDaysAgoStr,
      transactionType: 'bank_to_cash',
      amountPaise: CurrencyFormatter.rupeesToPaise(40000.0),
      paymentMethod: 'cash',
      referenceNumber: 'ATM-WD-01',
      notes: 'Cash drawn from ATM for shop cash register',
    ));

    // 4. Historical Monthly Bills & Transactions (for last 4 months trends)
    // Month -4 (120 days ago)
    await docRepo.createDocument(
      BusinessDocument(
        docNumber: 'KB-2026-H001',
        docType: 'kaccha_bill',
        partyId: cust3,
        docDate: oneTwentyDaysAgoStr,
        dueDate: formatDate(now.subtract(const Duration(days: 105))),
        discountPaise: 0,
        notes: 'Historical wholesale bill',
        items: [
          DocumentItem(
            itemName: 'Royal Zari Lace 2-Inch Golden Border',
            quantity: 500,
            unit: 'meter',
            ratePaise: CurrencyFormatter.rupeesToPaise(65.0),
            inventoryItemId: inv1,
          ),
          DocumentItem(
            itemName: 'Cotton Crochet Lace 1.5-Inch Off-White',
            quantity: 200,
            unit: 'meter',
            ratePaise: CurrencyFormatter.rupeesToPaise(42.0),
            inventoryItemId: inv2,
          ),
        ],
      ),
      advancePaymentPaise: CurrencyFormatter.rupeesToPaise(32000.0),
      paymentMethod: 'bank_transfer',
    );
    await txRepo.insertTransaction(BusinessTransaction(
      transactionDate: oneTwentyDaysAgoStr,
      transactionType: 'expense',
      amountPaise: CurrencyFormatter.rupeesToPaise(6500.0),
      paymentMethod: 'cash',
      expenseCategory: 'Labour / Karigar',
      notes: 'Historical wage payments',
    ));

    // Month -3 (95 days ago)
    await docRepo.createDocument(
      BusinessDocument(
        docNumber: 'KB-2026-H002',
        docType: 'kaccha_bill',
        partyId: cust1,
        docDate: ninetyFiveDaysAgoStr,
        dueDate: formatDate(now.subtract(const Duration(days: 80))),
        discountPaise: 0,
        notes: 'Historical bill',
        items: [
          DocumentItem(
            itemName: 'Glitter Sequence Gota Patti Ribbon 9m Roll',
            quantity: 150,
            unit: 'roll',
            ratePaise: CurrencyFormatter.rupeesToPaise(195.0),
            inventoryItemId: inv3,
          ),
          DocumentItem(
            itemName: 'Heavy Designer Beaded Latkan Dori Pair',
            quantity: 120,
            unit: 'piece',
            ratePaise: CurrencyFormatter.rupeesToPaise(145.0),
            inventoryItemId: inv5,
          ),
        ],
      ),
      advancePaymentPaise: CurrencyFormatter.rupeesToPaise(38000.0),
      paymentMethod: 'upi',
    );
    await txRepo.insertTransaction(BusinessTransaction(
      transactionDate: ninetyFiveDaysAgoStr,
      transactionType: 'expense',
      amountPaise: CurrencyFormatter.rupeesToPaise(7000.0),
      paymentMethod: 'bank_transfer',
      expenseCategory: 'Shop Rent',
      notes: 'Shop monthly rent',
    ));

    // Month -2 (65 days ago)
    await docRepo.createDocument(
      BusinessDocument(
        docNumber: 'KB-2026-H003',
        docType: 'kaccha_bill',
        partyId: cust4,
        docDate: sixtyFiveDaysAgoStr,
        dueDate: formatDate(now.subtract(const Duration(days: 50))),
        discountPaise: 0,
        notes: 'Fancy saree borders consignment',
        items: [
          DocumentItem(
            itemName: 'Heavy Embroidered Mirror Dupatta Border',
            quantity: 100,
            unit: 'meter',
            ratePaise: CurrencyFormatter.rupeesToPaise(350.0),
            inventoryItemId: inv4,
          ),
          DocumentItem(
            itemName: 'Cutwork Embroidered Velvet Border 3-Inch',
            quantity: 80,
            unit: 'meter',
            ratePaise: CurrencyFormatter.rupeesToPaise(240.0),
            inventoryItemId: inv6,
          ),
        ],
      ),
      advancePaymentPaise: CurrencyFormatter.rupeesToPaise(45000.0),
      paymentMethod: 'bank_transfer',
    );
    await txRepo.insertTransaction(BusinessTransaction(
      transactionDate: sixtyFiveDaysAgoStr,
      transactionType: 'expense',
      amountPaise: CurrencyFormatter.rupeesToPaise(9500.0),
      paymentMethod: 'cash',
      expenseCategory: 'Dyeing & Processing',
      notes: 'Mill processing charges',
    ));

    // Month -1 (35 days ago)
    await docRepo.createDocument(
      BusinessDocument(
        docNumber: 'KB-2026-H004',
        docType: 'kaccha_bill',
        partyId: cust2,
        docDate: thirtyFiveDaysAgoStr,
        dueDate: formatDate(now.subtract(const Duration(days: 20))),
        discountPaise: 0,
        notes: 'Bridal boutique order',
        items: [
          DocumentItem(
            itemName: 'Royal Zari Lace 2-Inch Golden Border',
            quantity: 300,
            unit: 'meter',
            ratePaise: CurrencyFormatter.rupeesToPaise(65.0),
            inventoryItemId: inv1,
          ),
          DocumentItem(
            itemName: 'Glitter Sequence Gota Patti Ribbon 9m Roll',
            quantity: 80,
            unit: 'roll',
            ratePaise: CurrencyFormatter.rupeesToPaise(195.0),
            inventoryItemId: inv3,
          ),
        ],
      ),
      advancePaymentPaise: CurrencyFormatter.rupeesToPaise(30000.0),
      paymentMethod: 'upi',
    );
    await txRepo.insertTransaction(BusinessTransaction(
      transactionDate: thirtyFiveDaysAgoStr,
      transactionType: 'expense',
      amountPaise: CurrencyFormatter.rupeesToPaise(8000.0),
      paymentMethod: 'cash',
      expenseCategory: 'Transport',
      notes: 'Freight transport charges',
    ));

    // 5. This Month Data (15 and 20 days ago)
    // Bill 1: 20 days ago to Radha Krishna Sarees (partially paid)
    await docRepo.createDocument(
      BusinessDocument(
        docNumber: 'KB-2026-0001',
        docType: 'kaccha_bill',
        partyId: cust1,
        docDate: twentyDaysAgoStr,
        dueDate: overdueDueDate,
        discountPaise: CurrencyFormatter.rupeesToPaise(250.0),
        notes: 'Wedding season bridal sarees consignment',
        items: [
          DocumentItem(
            itemName: 'Cotton Crochet Lace 1.5-Inch Off-White',
            quantity: 250,
            unit: 'meter',
            ratePaise: CurrencyFormatter.rupeesToPaise(42.0),
            inventoryItemId: inv2,
          ),
          DocumentItem(
            itemName: 'Royal Zari Lace 2-Inch Golden Border',
            quantity: 150,
            unit: 'meter',
            ratePaise: CurrencyFormatter.rupeesToPaise(65.0),
            inventoryItemId: inv1,
          ),
        ],
      ),
      advancePaymentPaise: CurrencyFormatter.rupeesToPaise(12000.0),
      paymentMethod: 'cash',
    );

    // Bill 2: 15 days ago to Surat Saree Sansar
    await docRepo.createDocument(
      BusinessDocument(
        docNumber: 'KB-2026-0002',
        docType: 'kaccha_bill',
        partyId: cust4,
        docDate: fifteenDaysAgoStr,
        dueDate: dueInTenDays,
        discountPaise: 0,
        notes: 'Diwali special fancy assortment',
        items: [
          DocumentItem(
            itemName: 'Glitter Sequence Gota Patti Ribbon 9m Roll',
            quantity: 60,
            unit: 'roll',
            ratePaise: CurrencyFormatter.rupeesToPaise(195.0),
            inventoryItemId: inv3,
          ),
          DocumentItem(
            itemName: 'Heavy Embroidered Mirror Dupatta Border',
            quantity: 40,
            unit: 'meter',
            ratePaise: CurrencyFormatter.rupeesToPaise(350.0),
            inventoryItemId: inv4,
          ),
        ],
      ),
      advancePaymentPaise: CurrencyFormatter.rupeesToPaise(18000.0),
      paymentMethod: 'bank_transfer',
    );

    // Customer Receipt 14 days ago from Shree Balaji Textile Agency (NEFT payment)
    await txRepo.insertTransaction(BusinessTransaction(
      transactionDate: formatDate(now.subtract(const Duration(days: 14))),
      partyId: cust3,
      transactionType: 'customer_receipt',
      amountPaise: CurrencyFormatter.rupeesToPaise(45000.0),
      paymentMethod: 'bank_transfer',
      referenceNumber: 'NEFT-BALAJI-14',
      notes: 'Wholesale outstation consignment payment via Bank',
    ));

    // Supplier payment 16 days ago
    await txRepo.insertTransaction(BusinessTransaction(
      transactionDate: formatDate(now.subtract(const Duration(days: 16))),
      partyId: supp3,
      transactionType: 'supplier_payment',
      amountPaise: CurrencyFormatter.rupeesToPaise(22000.0),
      paymentMethod: 'bank_transfer',
      referenceNumber: 'IMPS-KUBER-16',
      notes: 'Zari thread invoice settlement',
    ));

    // Expense 18 days ago (Shop rent)
    await txRepo.insertTransaction(BusinessTransaction(
      transactionDate: formatDate(now.subtract(const Duration(days: 18))),
      transactionType: 'expense',
      amountPaise: CurrencyFormatter.rupeesToPaise(12000.0),
      paymentMethod: 'bank_transfer',
      expenseCategory: 'Shop Rent',
      notes: 'Monthly showroom rent payment',
    ));

    // 6. This Week Data (2 and 4 days ago)
    // Bill 3: 4 days ago to Radha Krishna Sarees
    await docRepo.createDocument(
      BusinessDocument(
        docNumber: 'KB-2026-0003',
        docType: 'kaccha_bill',
        partyId: cust1,
        docDate: fourDaysAgoStr,
        dueDate: dueInTenDays,
        discountPaise: 0,
        notes: 'Velvet border festival dispatch',
        items: [
          DocumentItem(
            itemName: 'Royal Zari Lace 2-Inch Golden Border',
            quantity: 300,
            unit: 'meter',
            ratePaise: CurrencyFormatter.rupeesToPaise(65.0),
            inventoryItemId: inv1,
          ),
          DocumentItem(
            itemName: 'Cutwork Embroidered Velvet Border 3-Inch',
            quantity: 50,
            unit: 'meter',
            ratePaise: CurrencyFormatter.rupeesToPaise(240.0),
            inventoryItemId: inv6,
          ),
        ],
      ),
      advancePaymentPaise: CurrencyFormatter.rupeesToPaise(15000.0),
      paymentMethod: 'upi',
    );

    // Bill 4: 2 days ago to Shree Balaji Textile Agency
    await docRepo.createDocument(
      BusinessDocument(
        docNumber: 'KB-2026-0004',
        docType: 'kaccha_bill',
        partyId: cust3,
        docDate: twoDaysAgoStr,
        dueDate: dueInTenDays,
        discountPaise: 0,
        notes: 'Regular wholesale lot',
        items: [
          DocumentItem(
            itemName: 'Cotton Crochet Lace 1.5-Inch Off-White',
            quantity: 400,
            unit: 'meter',
            ratePaise: CurrencyFormatter.rupeesToPaise(42.0),
            inventoryItemId: inv2,
          ),
          DocumentItem(
            itemName: 'Glitter Sequence Gota Patti Ribbon 9m Roll',
            quantity: 60,
            unit: 'roll',
            ratePaise: CurrencyFormatter.rupeesToPaise(195.0),
            inventoryItemId: inv3,
          ),
        ],
      ),
      advancePaymentPaise: CurrencyFormatter.rupeesToPaise(18000.0),
      paymentMethod: 'bank_transfer',
    );

    // Supplier payment 4 days ago
    await txRepo.insertTransaction(BusinessTransaction(
      transactionDate: fourDaysAgoStr,
      partyId: supp2,
      transactionType: 'supplier_payment',
      amountPaise: CurrencyFormatter.rupeesToPaise(18000.0),
      paymentMethod: 'bank_transfer',
      referenceNumber: 'RTGS-MAHAVIR-04',
      notes: 'Lace finishing and bleaching lot payment',
    ));

    // Expense 3 days ago (Electricity)
    await txRepo.insertTransaction(BusinessTransaction(
      transactionDate: formatDate(now.subtract(const Duration(days: 3))),
      transactionType: 'expense',
      amountPaise: CurrencyFormatter.rupeesToPaise(2800.0),
      paymentMethod: 'bank_transfer',
      expenseCategory: 'Electricity',
      notes: 'DGVCL shop electricity bill payment',
    ));

    // Customer Cash receipt 3 days ago from Surat Saree Sansar
    await txRepo.insertTransaction(BusinessTransaction(
      transactionDate: formatDate(now.subtract(const Duration(days: 3))),
      partyId: cust4,
      transactionType: 'customer_receipt',
      amountPaise: CurrencyFormatter.rupeesToPaise(4000.0),
      paymentMethod: 'cash',
      referenceNumber: 'CASH-REC-03',
      notes: 'Counter cash payment for matching lace samples',
    ));

    // 6.5. Mid-10-Day Period Data (5, 6, 7, 8, 9, 10 days ago for full 10-day audit)
    final fiveDaysAgoStr = formatDate(now.subtract(const Duration(days: 5)));
    final sixDaysAgoStr = formatDate(now.subtract(const Duration(days: 6)));
    final sevenDaysAgoStr = formatDate(now.subtract(const Duration(days: 7)));
    final eightDaysAgoStr = formatDate(now.subtract(const Duration(days: 8)));
    final nineDaysAgoStr = formatDate(now.subtract(const Duration(days: 9)));
    final tenDaysAgoStr = formatDate(now.subtract(const Duration(days: 10)));

    // Bill 6: 5 days ago to Radha Krishna Sarees
    await docRepo.createDocument(
      BusinessDocument(
        docNumber: 'KB-2026-0006',
        docType: 'kaccha_bill',
        partyId: cust1,
        docDate: fiveDaysAgoStr,
        dueDate: dueInTenDays,
        discountPaise: 0,
        notes: '10-day audit cycle consignment',
        items: [
          DocumentItem(
            itemName: 'Royal Zari Lace 2-Inch Golden Border',
            quantity: 350,
            unit: 'meter',
            ratePaise: CurrencyFormatter.rupeesToPaise(65.0),
            inventoryItemId: inv1,
          ),
        ],
      ),
      advancePaymentPaise: CurrencyFormatter.rupeesToPaise(12000.0),
      paymentMethod: 'upi',
    );

    // Customer Receipt: 6 days ago from Balaji Agency (RTGS)
    await txRepo.insertTransaction(BusinessTransaction(
      transactionDate: sixDaysAgoStr,
      partyId: cust3,
      transactionType: 'customer_receipt',
      amountPaise: CurrencyFormatter.rupeesToPaise(25000.0),
      paymentMethod: 'bank_transfer',
      referenceNumber: 'RTGS-BALAJI-06',
      notes: 'Mid-cycle wholesale clearance',
    ));

    // Bill 7: 7 days ago to Ambaji Designer Boutique
    await docRepo.createDocument(
      BusinessDocument(
        docNumber: 'KB-2026-0007',
        docType: 'kaccha_bill',
        partyId: cust2,
        docDate: sevenDaysAgoStr,
        dueDate: dueInTenDays,
        discountPaise: 0,
        notes: 'Festive mirror laces lot',
        items: [
          DocumentItem(
            itemName: 'Heavy Embroidered Mirror Dupatta Border',
            quantity: 60,
            unit: 'meter',
            ratePaise: CurrencyFormatter.rupeesToPaise(350.0),
            inventoryItemId: inv4,
          ),
        ],
      ),
      advancePaymentPaise: CurrencyFormatter.rupeesToPaise(10000.0),
      paymentMethod: 'cash',
    );

    // Customer Cash receipt: 8 days ago from Surat Saree Sansar
    await txRepo.insertTransaction(BusinessTransaction(
      transactionDate: eightDaysAgoStr,
      partyId: cust4,
      transactionType: 'customer_receipt',
      amountPaise: CurrencyFormatter.rupeesToPaise(15000.0),
      paymentMethod: 'cash',
      referenceNumber: 'CASH-REC-08',
      notes: 'Counter cash payment for boutique lots',
    ));

    // Supplier Payment: 9 days ago to Mahavir Dyeing
    await txRepo.insertTransaction(BusinessTransaction(
      transactionDate: nineDaysAgoStr,
      partyId: supp2,
      transactionType: 'supplier_payment',
      amountPaise: CurrencyFormatter.rupeesToPaise(14500.0),
      paymentMethod: 'bank_transfer',
      referenceNumber: 'NEFT-MAHAVIR-09',
      notes: 'Bleaching & roll finish bill settlement',
    ));

    // Expense: 10 days ago (Freight & Packing Boxes)
    await txRepo.insertTransaction(BusinessTransaction(
      transactionDate: tenDaysAgoStr,
      transactionType: 'expense',
      amountPaise: CurrencyFormatter.rupeesToPaise(2200.0),
      paymentMethod: 'cash',
      expenseCategory: 'Transport',
      notes: 'Heavy carton packing & tempo freight',
    ));

    // 7. Today Data (Fresh Sales, Customer Receipts, Supplier Payments, Expenses)
    // Bill 5: Created Today for Ambaji Designer Boutique
    await docRepo.createDocument(
      BusinessDocument(
        docNumber: 'KB-2026-0005',
        docType: 'kaccha_bill',
        partyId: cust2,
        docDate: todayStr,
        dueDate: dueInTenDays,
        discountPaise: 0,
        notes: 'Fresh boutique samples dispatch',
        items: [
          DocumentItem(
            itemName: 'Heavy Embroidered Mirror Dupatta Border',
            quantity: 30,
            unit: 'meter',
            ratePaise: CurrencyFormatter.rupeesToPaise(350.0),
            inventoryItemId: inv4,
          ),
          DocumentItem(
            itemName: 'Heavy Designer Beaded Latkan Dori Pair',
            quantity: 40,
            unit: 'piece',
            ratePaise: CurrencyFormatter.rupeesToPaise(145.0),
            inventoryItemId: inv5,
          ),
          DocumentItem(
            itemName: 'Royal Zari Lace 2-Inch Golden Border',
            quantity: 25,
            unit: 'meter',
            ratePaise: CurrencyFormatter.rupeesToPaise(65.0),
            inventoryItemId: inv1,
          ),
        ],
      ),
      advancePaymentPaise: CurrencyFormatter.rupeesToPaise(12000.0),
      paymentMethod: 'upi',
    );

    // Today Delivery Challan (Approval sample to Balaji Agency)
    await docRepo.createDocument(
      BusinessDocument(
        docNumber: 'DC-2026-0001',
        docType: 'challan',
        partyId: cust3,
        docDate: todayStr,
        dueDate: dueInTenDays,
        notes: 'Trial delivery on approval for matching party sample',
        items: [
          DocumentItem(
            itemName: 'Royal Zari Lace 2-Inch Golden Border',
            quantity: 120,
            unit: 'meter',
            ratePaise: CurrencyFormatter.rupeesToPaise(65.0),
            inventoryItemId: inv1,
          ),
        ],
      ),
    );

    // Today: Direct Customer Receipt collected from Radha Krishna Sarees
    await txRepo.insertTransaction(BusinessTransaction(
      transactionDate: todayStr,
      partyId: cust1,
      transactionType: 'customer_receipt',
      amountPaise: CurrencyFormatter.rupeesToPaise(6500.0),
      paymentMethod: 'cash',
      referenceNumber: 'CASH-REC-TODAY',
      notes: 'Counter cash collection against outstanding account',
    ));

    // Today: Supplier Payment to Jay Ambe Yarns
    await txRepo.insertTransaction(BusinessTransaction(
      transactionDate: todayStr,
      partyId: supp1,
      transactionType: 'supplier_payment',
      amountPaise: CurrencyFormatter.rupeesToPaise(7500.0),
      paymentMethod: 'bank_transfer',
      referenceNumber: 'IMPS-JAYAMBE-01',
      notes: 'Part payment against raw yarn supply',
    ));

    // Today Expenses: Karigar cutting wages & Tempo transport
    await txRepo.insertTransaction(BusinessTransaction(
      transactionDate: todayStr,
      transactionType: 'expense',
      amountPaise: CurrencyFormatter.rupeesToPaise(1200.0),
      paymentMethod: 'cash',
      expenseCategory: 'Labour / Karigar',
      notes: 'Karigar daily lace cutting & packing wages',
    ));

    await txRepo.insertTransaction(BusinessTransaction(
      transactionDate: todayStr,
      transactionType: 'expense',
      amountPaise: CurrencyFormatter.rupeesToPaise(450.0),
      paymentMethod: 'cash',
      expenseCategory: 'Transport',
      notes: 'Tempo freight from Pandesara mill',
    ));

    // =========================================================================
    // 7. Factory Karigars, Attendance, Machine Katai Production & Wages
    // =========================================================================
    await seedWorkerSampleData(clearExistingWorkers: false);

    // =========================================================================
    // 8. 10-Day Automated Email Reports Configuration (app_settings)
    // =========================================================================
    final db = await dbHelper.database;
    final nowIso = DateTime.now().toIso8601String();
    await db.insert(
      DatabaseTables.tableAppSettings,
      {
        'setting_key': 'auto_email_enabled',
        'setting_value': 'false', // Off by default until user enables
        'updated_at': nowIso,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await db.insert(
      DatabaseTables.tableAppSettings,
      {
        'setting_key': 'auto_email_sender_email',
        'setting_value': 'rahuljangu01@gmail.com',
        'updated_at': nowIso,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await db.insert(
      DatabaseTables.tableAppSettings,
      {
        'setting_key': 'auto_email_recipient',
        'setting_value': 'rahuljangu01@gmail.com',
        'updated_at': nowIso,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await db.insert(
      DatabaseTables.tableAppSettings,
      {
        'setting_key': 'auto_email_sender_app_password',
        'setting_value': 'kllvesigpxfyhvst',
        'updated_at': nowIso,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await db.insert(
      DatabaseTables.tableAppSettings,
      {
        'setting_key': 'auto_email_provider',
        'setting_value': 'gmail_smtp',
        'updated_at': nowIso,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await db.insert(
      DatabaseTables.tableAppSettings,
      {
        'setting_key': 'auto_email_cycle_mode',
        'setting_value': 'rolling_10',
        'updated_at': nowIso,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await db.insert(
      DatabaseTables.tableAppSettings,
      {
        'setting_key': 'auto_email_last_sent_date',
        'setting_value': nowIso, // Start countdown from now, so it waits 10 days
        'updated_at': nowIso,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Seeds realistic Surat lace factory karigars, machine production,
  /// daily attendance, and wage/kharcha advances.
  static Future<void> seedWorkerSampleData({bool clearExistingWorkers = true}) async {
    final dbHelper = DatabaseHelper.instance;
    final db = await dbHelper.database;

    if (clearExistingWorkers) {
      await db.delete(DatabaseTables.tableWorkerPayments);
      await db.delete(DatabaseTables.tableMachineKataiEntries);
      await db.delete(DatabaseTables.tableWorkerAttendance);
      await db.delete(DatabaseTables.tableWorkers);
    }

    final workerRepo = WorkerRepository(dbHelper: dbHelper);

    final now = DateTime.now();
    String formatDate(DateTime dt) => DateFormat('yyyy-MM-dd').format(dt);

    final todayStr = formatDate(now);
    final yesterdayStr = formatDate(now.subtract(const Duration(days: 1)));
    final twoDaysAgoStr = formatDate(now.subtract(const Duration(days: 2)));
    final threeDaysAgoStr = formatDate(now.subtract(const Duration(days: 3)));
    final fiveDaysAgoStr = formatDate(now.subtract(const Duration(days: 5)));
    final sixDaysAgoStr = formatDate(now.subtract(const Duration(days: 6)));
    final sevenDaysAgoStr = formatDate(now.subtract(const Duration(days: 7)));
    final eightDaysAgoStr = formatDate(now.subtract(const Duration(days: 8)));
    final nineDaysAgoStr = formatDate(now.subtract(const Duration(days: 9)));
    final tenDaysAgoStr = formatDate(now.subtract(const Duration(days: 10)));

    // 1. Karigar Masters
    final w1 = await workerRepo.insertWorker(Worker(
      name: 'रमेश भाई (Multihead Operator)',
      phone: '9825199001',
      machineNumber: 'Machine-1 (Multihead)',
      wageType: 'katai_piece',
      ratePaise: CurrencyFormatter.rupeesToPaise(2.50),
      notes: 'Expert in 2-inch and 3-inch zari lace cutting',
    ));

    final w2 = await workerRepo.insertWorker(Worker(
      name: 'मुकेश कुमार (Crochet Cutter)',
      phone: '9898233445',
      machineNumber: 'Machine-2 (Crochet)',
      wageType: 'katai_piece',
      ratePaise: CurrencyFormatter.rupeesToPaise(1.80),
      notes: 'Cotton crochet border cutting specialist',
    ));

    final w3 = await workerRepo.insertWorker(Worker(
      name: 'दिनेश भाई (Master / Checker)',
      phone: '9712344556',
      machineNumber: 'Checking Table',
      wageType: 'daily',
      ratePaise: CurrencyFormatter.rupeesToPaise(600.0),
      notes: 'Quality inspection & packing daily master',
    ));

    final w4 = await workerRepo.insertWorker(Worker(
      name: 'सुनील यादव (Multihead #3)',
      phone: '9909188223',
      machineNumber: 'Machine-3 (Multihead)',
      wageType: 'katai_piece',
      ratePaise: CurrencyFormatter.rupeesToPaise(2.20),
      notes: 'High speed night & day shift operator',
    ));

    // 2. Attendance Records (Today, Yesterday, 2 Days Ago)
    // Today
    await workerRepo.markAttendance(workerId: w1, date: todayStr, status: 'present');
    await workerRepo.markAttendance(workerId: w2, date: todayStr, status: 'overtime', overtimeHours: 2.5);
    await workerRepo.markAttendance(workerId: w3, date: todayStr, status: 'present');
    await workerRepo.markAttendance(workerId: w4, date: todayStr, status: 'present');

    // Yesterday
    await workerRepo.markAttendance(workerId: w1, date: yesterdayStr, status: 'present');
    await workerRepo.markAttendance(workerId: w2, date: yesterdayStr, status: 'present');
    await workerRepo.markAttendance(workerId: w3, date: yesterdayStr, status: 'half_day', notes: 'दोपहर बाद छुट्टी ली');
    await workerRepo.markAttendance(workerId: w4, date: yesterdayStr, status: 'present');

    // 2 Days Ago
    await workerRepo.markAttendance(workerId: w1, date: twoDaysAgoStr, status: 'present');
    await workerRepo.markAttendance(workerId: w2, date: twoDaysAgoStr, status: 'present');
    await workerRepo.markAttendance(workerId: w3, date: twoDaysAgoStr, status: 'present');
    await workerRepo.markAttendance(workerId: w4, date: twoDaysAgoStr, status: 'absent', notes: 'तबीयत खराब थी');

    // 3. Machine Katai Production (मशीन-वार मीटर कटाई)
    // Ramesh on Machine-1
    await workerRepo.insertKataiEntry(MachineKataiEntry(
      date: todayStr,
      machineNumber: 'Machine-1 (Multihead)',
      workerId: w1,
      designCode: 'DM-ZARI-101',
      shift: 'day',
      quantity: 450.0,
      unit: 'meter',
      ratePaise: CurrencyFormatter.rupeesToPaise(2.50),
      notes: 'Clean gold zari cutwork production',
    ));

    await workerRepo.insertKataiEntry(MachineKataiEntry(
      date: yesterdayStr,
      machineNumber: 'Machine-1 (Multihead)',
      workerId: w1,
      designCode: 'DM-ZARI-101',
      shift: 'day',
      quantity: 520.0,
      unit: 'meter',
      ratePaise: CurrencyFormatter.rupeesToPaise(2.50),
      notes: 'Day shift running full speed',
    ));

    // Mukesh on Machine-2
    await workerRepo.insertKataiEntry(MachineKataiEntry(
      date: todayStr,
      machineNumber: 'Machine-2 (Crochet)',
      workerId: w2,
      designCode: 'DM-CRO-301',
      shift: 'day',
      quantity: 380.0,
      unit: 'meter',
      ratePaise: CurrencyFormatter.rupeesToPaise(1.80),
      notes: 'Cotton border 1.5 inch',
    ));

    await workerRepo.insertKataiEntry(MachineKataiEntry(
      date: todayStr,
      machineNumber: 'Machine-2 (Crochet)',
      workerId: w2,
      designCode: 'DM-GOTA-201',
      shift: 'night',
      quantity: 210.0,
      unit: 'meter',
      ratePaise: CurrencyFormatter.rupeesToPaise(1.80),
      notes: 'Night shift extra katai',
    ));

    await workerRepo.insertKataiEntry(MachineKataiEntry(
      date: yesterdayStr,
      machineNumber: 'Machine-2 (Crochet)',
      workerId: w2,
      designCode: 'DM-CRO-301',
      shift: 'day',
      quantity: 410.0,
      unit: 'meter',
      ratePaise: CurrencyFormatter.rupeesToPaise(1.80),
      notes: 'Standard crochet cotton run',
    ));

    // Sunil on Machine-3
    await workerRepo.insertKataiEntry(MachineKataiEntry(
      date: todayStr,
      machineNumber: 'Machine-3 (Multihead)',
      workerId: w4,
      designCode: 'DM-ZARI-101',
      shift: 'day',
      quantity: 480.0,
      unit: 'meter',
      ratePaise: CurrencyFormatter.rupeesToPaise(2.20),
      notes: 'Heavy bridal border cutting',
    ));

    // 4. Advances & Kharcha Given (उठाव / एडवांस)
    await workerRepo.recordPayment(WorkerPayment(
      workerId: w1,
      date: threeDaysAgoStr,
      paymentType: 'advance',
      amountPaise: CurrencyFormatter.rupeesToPaise(1000.0),
      paymentMethod: 'cash',
      notes: 'उठाव / Mid-week household kharcha advance',
    ));

    await workerRepo.recordPayment(WorkerPayment(
      workerId: w2,
      date: yesterdayStr,
      paymentType: 'advance',
      amountPaise: CurrencyFormatter.rupeesToPaise(500.0),
      paymentMethod: 'upi',
      referenceNo: 'UPI-ADV-8832',
      notes: 'Emergency medical advance',
    ));

    await workerRepo.recordPayment(WorkerPayment(
      workerId: w4,
      date: twoDaysAgoStr,
      paymentType: 'advance',
      amountPaise: CurrencyFormatter.rupeesToPaise(800.0),
      paymentMethod: 'cash',
      notes: 'किराया खर्चा उठाव (Rent advance)',
    ));

    // Additional 10-day audit cycle production & advances
    await workerRepo.insertKataiEntry(MachineKataiEntry(
      date: fiveDaysAgoStr,
      machineNumber: 'Machine-1 (Multihead)',
      workerId: w3,
      designCode: 'DM-ZARI-101',
      shift: 'day',
      quantity: 520.0,
      unit: 'meter',
      ratePaise: CurrencyFormatter.rupeesToPaise(2.50),
      notes: 'Heavy bridal border cutting lot',
    ));

    await workerRepo.insertKataiEntry(MachineKataiEntry(
      date: sixDaysAgoStr,
      machineNumber: 'Machine-2 (Crochet)',
      workerId: w2,
      designCode: 'DM-CRO-301',
      shift: 'day',
      quantity: 380.0,
      unit: 'meter',
      ratePaise: CurrencyFormatter.rupeesToPaise(1.80),
      notes: 'Standard crochet cotton run',
    ));

    await workerRepo.insertKataiEntry(MachineKataiEntry(
      date: eightDaysAgoStr,
      machineNumber: 'Machine-3 (Multihead)',
      workerId: w4,
      designCode: 'DM-GOTA-201',
      shift: 'night',
      quantity: 460.0,
      unit: 'meter',
      ratePaise: CurrencyFormatter.rupeesToPaise(2.20),
      notes: 'Night shift sequence border run',
    ));

    await workerRepo.insertKataiEntry(MachineKataiEntry(
      date: tenDaysAgoStr,
      machineNumber: 'Machine-1 (Multihead)',
      workerId: w1,
      designCode: 'DM-ZARI-101',
      shift: 'day',
      quantity: 500.0,
      unit: 'meter',
      ratePaise: CurrencyFormatter.rupeesToPaise(2.50),
      notes: 'Start of 10-day cycle batch cutting',
    ));

    await workerRepo.recordPayment(WorkerPayment(
      workerId: w3,
      date: sevenDaysAgoStr,
      paymentType: 'advance',
      amountPaise: CurrencyFormatter.rupeesToPaise(1500.0),
      paymentMethod: 'cash',
      notes: 'फेस्टिवल खर्च उठाव (Advance)',
    ));

    await workerRepo.recordPayment(WorkerPayment(
      workerId: w4,
      date: nineDaysAgoStr,
      paymentType: 'advance',
      amountPaise: CurrencyFormatter.rupeesToPaise(1000.0),
      paymentMethod: 'upi',
      referenceNo: 'UPI-ADV-9901',
      notes: 'Bank UPI advance transfer',
    ));
  }
}
