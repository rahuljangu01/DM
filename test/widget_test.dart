import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:dm_lace_surat/main.dart';
import 'package:dm_lace_surat/core/database/database_helper.dart';
import 'package:dm_lace_surat/core/utils/currency_formatter.dart';
import 'package:dm_lace_surat/core/utils/date_formatter.dart';
import 'package:dm_lace_surat/models/party.dart';
import 'package:dm_lace_surat/models/worker.dart';
import 'package:dm_lace_surat/models/worker_attendance.dart';
import 'package:dm_lace_surat/models/machine_katai_entry.dart';
import 'package:dm_lace_surat/models/worker_payment.dart';
import 'package:dm_lace_surat/models/dashboard_summary.dart';
import 'package:dm_lace_surat/models/periodic_audit_report.dart';
import 'package:dm_lace_surat/core/database/sample_data_seeder.dart';
import 'package:dm_lace_surat/services/audit_report_service.dart';
import 'package:dm_lace_surat/services/auto_email_dispatch_service.dart';
import 'package:dm_lace_surat/core/security/auth_service.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    AutoEmailDispatchService.enablePeriodicTimer = false;
    AuthService.bypassAuthForTesting = true;
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    DatabaseHelper.resetForTesting(null, inMemoryDatabasePath);
  });
  testWidgets('DM Lace Surat app loads splash and shows branding', (WidgetTester tester) async {
    await tester.pumpWidget(const DmLaceApp());

    // Expect brand name text in splash
    expect(find.textContaining('DM LACE SURAT'), findsWidgets);

    // Tap the button to enter Dashboard
    final enterButton = find.text('Open Shop Accounts ➔').evaluate().isNotEmpty
        ? find.text('Open Shop Accounts ➔')
        : (find.text('दुकान हिसाब खोलें ➔').evaluate().isNotEmpty
            ? find.text('दुकान हिसाब खोलें ➔')
            : (find.text('Enter Dashboard ➔').evaluate().isNotEmpty
                ? find.text('Enter Dashboard ➔')
                : find.textContaining('➔')));
    await tester.tap(enterButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Should now be on the Dashboard / Home
    expect(
      find.text('Home').evaluate().isNotEmpty
          ? find.text('Home')
          : (find.text('होम').evaluate().isNotEmpty
              ? find.text('होम')
              : (find.text('Dashboard').evaluate().isNotEmpty
                  ? find.text('Dashboard')
                  : find.text('डैशबोर्ड'))),
      findsWidgets,
    );

    // Verify Financial Ledger VIP Hero Card elements are present
    expect(
      find.textContaining('Overview').evaluate().isNotEmpty
          ? find.textContaining('Overview')
          : find.textContaining('हिसाब'),
      findsWidgets,
    );

    // Verify Business Trend Analytics Graph is present on Dashboard
    final trendGraph = find.textContaining('Trend').evaluate().isNotEmpty
        ? find.textContaining('Trend')
        : find.textContaining('रुझान');
    expect(trendGraph, findsOneWidget);
  });

  test('CurrencyFormatter handles Indian format and paise conversions accurately', () {
    // 1 Lakh 50 Thousand
    expect(CurrencyFormatter.format(150000.0), '₹ 1,50,000.00');

    // Decimal paise conversion
    expect(CurrencyFormatter.rupeesToPaise(1250.75), 125075);
    expect(CurrencyFormatter.paiseToRupees(125075), 1250.75);

    // Compact format
    expect(CurrencyFormatter.formatCompact(450000), '₹ 4.50 L');
    expect(CurrencyFormatter.formatCompact(15000000), '₹ 1.50 Cr');
  });

  test('DateFormatter handles Indian DD-MM-YYYY format', () {
    final date = DateTime(2026, 10, 25);
    expect(DateFormatter.format(date), '25-10-2026');
    expect(DateFormatter.formatReadable(date), '25 Oct 2026');

    final parsed = DateFormatter.parse('25-10-2026');
    expect(parsed?.year, 2026);
    expect(parsed?.month, 10);
    expect(parsed?.day, 25);
  });

  test('Party model correctly handles Wholesalers, Retailers, Manufacturers & Raw Materials with phone numbers', () {
    final wholesaler = Party(
      name: 'Balaji Lace Wholesalers',
      type: 'wholesaler',
      phone: '9825012345',
      address: 'Shop 101, Avadh Market, Surat',
    );
    final retailer = Party(
      name: 'Pooja Fashion Retailers',
      type: 'retailer',
      phone: '9825023456',
      address: 'Shop 45, Ring Road, Surat',
    );
    final manufacturer = Party(
      name: 'Shree Krishna Lace Factory',
      type: 'manufacturer',
      phone: '9825034567',
      address: 'Plot 12, Sachin GIDC, Surat',
    );
    final materialSupplier = Party(
      name: 'Golden Zari & Raw Materials',
      type: 'material',
      phone: '9825045678',
      address: 'Khatodara, Surat',
    );

    expect(wholesaler.isWholesaler, isTrue);
    expect(wholesaler.isCustomer, isTrue);
    expect(wholesaler.isSupplier, isFalse);
    expect(wholesaler.typeDisplayName(true), contains('होलसेलर'));
    expect(wholesaler.phone, '9825012345');

    expect(retailer.isRetailer, isTrue);
    expect(retailer.isCustomer, isTrue);
    expect(retailer.typeDisplayName(false), 'Retailer');
    expect(retailer.phone, '9825023456');

    expect(manufacturer.isManufacturer, isTrue);
    expect(manufacturer.isSupplier, isTrue);
    expect(manufacturer.isCustomer, isFalse);
    expect(manufacturer.typeDisplayName(true), contains('मैन्युफैक्चरर'));

    expect(materialSupplier.isMaterial, isTrue);
    expect(materialSupplier.isSupplier, isTrue);
    expect(materialSupplier.typeDisplayName(true), contains('कच्चा माल'));

    final map = wholesaler.toMap();
    expect(map['type'], 'wholesaler');
    expect(map['phone'], '9825012345');

    final reconstructed = Party.fromMap(map);
    expect(reconstructed.name, 'Balaji Lace Wholesalers');
    expect(reconstructed.type, 'wholesaler');
    expect(reconstructed.phone, '9825012345');
  });

  test('Worker & Katai production models handle piece-rate katai, attendance & kharcha advances accurately', () {
    // 1. Worker
    final worker = Worker(
      id: 1,
      name: 'Ramesh Bhai Operator',
      phone: '9825199001',
      machineNumber: 'Machine-1 (Multihead)',
      wageType: 'katai_piece',
      ratePaise: CurrencyFormatter.rupeesToPaise(2.50),
      currentBalancePaise: CurrencyFormatter.rupeesToPaise(1500.0),
    );

    expect(worker.wageType, 'katai_piece');
    expect(worker.rateRupees, 2.50);
    expect(worker.wageTypeDisplay(true), contains('कटाई दर'));
    expect(worker.wageTypeDisplay(false), contains('Per Meter Katai'));

    final workerMap = worker.toMap();
    final workerLoaded = Worker.fromMap(workerMap);
    expect(workerLoaded.name, 'Ramesh Bhai Operator');
    expect(workerLoaded.machineNumber, 'Machine-1 (Multihead)');

    // 2. Machine Katai Production Entry
    final katai = MachineKataiEntry(
      id: 101,
      date: '2026-10-28',
      machineNumber: 'Machine-1 (Multihead)',
      workerId: 1,
      workerName: 'Ramesh Bhai Operator',
      designCode: 'DM-ZARI-101',
      shift: 'day',
      quantity: 450.0,
      unit: 'meter',
      ratePaise: CurrencyFormatter.rupeesToPaise(2.50),
    );

    // 450 meters * 2.50 = 1125.00 Rupees = 112500 paise
    expect(katai.totalAmountPaise, 112500);
    expect(katai.totalAmountRupees, 1125.0);
    expect(katai.shiftDisplay(true), contains('दिन शिफ्ट'));

    final kataiMap = katai.toMap();
    final kataiLoaded = MachineKataiEntry.fromMap(kataiMap);
    expect(kataiLoaded.quantity, 450.0);
    expect(kataiLoaded.totalAmountRupees, 1125.0);

    // 3. Worker Attendance
    final attendance = WorkerAttendance(
      id: 201,
      workerId: 1,
      date: '2026-10-28',
      status: 'overtime',
      overtimeHours: 2.5,
    );
    expect(attendance.statusDisplay(true), contains('ओवरटाइम'));
    expect(attendance.overtimeHours, 2.5);

    final attMap = attendance.toMap();
    final attLoaded = WorkerAttendance.fromMap(attMap);
    expect(attLoaded.status, 'overtime');
    expect(attLoaded.overtimeHours, 2.5);

    // 4. Worker Payment (Advance / Kharcha)
    final advance = WorkerPayment(
      id: 301,
      workerId: 1,
      date: '2026-10-27',
      paymentType: 'advance',
      amountPaise: CurrencyFormatter.rupeesToPaise(1000.0),
      paymentMethod: 'cash',
      notes: 'उठाव / Mid-week household kharcha',
    );
    expect(advance.paymentType, 'advance');
    expect(advance.amountRupees, 1000.0);
    expect(advance.paymentTypeDisplay(true), contains('उठाव'));

    final payMap = advance.toMap();
    final payLoaded = WorkerPayment.fromMap(payMap);
    expect(payLoaded.amountRupees, 1000.0);
    expect(payLoaded.paymentType, 'advance');
  });

  test('MonthlyTrendPoint accurately tracks sales, receipts, and recovery metrics for dashboard graph', () {
    const pt1 = MonthlyTrendPoint(month: 'Aug', sales: 120000.0, receipts: 95000.0);
    const pt2 = MonthlyTrendPoint(month: 'Sep', sales: 180000.0, receipts: 140000.0);
    const pt3 = MonthlyTrendPoint(month: 'Oct', sales: 250000.0, receipts: 200000.0);

    final trends = [pt1, pt2, pt3];
    double totalSales = 0;
    double totalReceipts = 0;
    for (final t in trends) {
      totalSales += t.sales;
      totalReceipts += t.receipts;
    }
    expect(totalSales, 550000.0);
    expect(totalReceipts, 435000.0);
    final recoveryPct = ((totalReceipts / totalSales) * 100).round();
    expect(recoveryPct, 79);
  });

  test('AuditReportService calculates 10-day rolling and Surat market billing cycles correctly', () {
    // 1. Rolling 10 Days
    final ref = DateTime(2026, 10, 28);
    final rolling = AuditReportService.calculateDateRange(referenceDate: ref, isMarketCycle: false);
    expect(rolling['startDate'], '2026-10-19');
    expect(rolling['endDate'], '2026-10-28');

    // 2. Surat Market Cycle: on 25th of month, previous cycle was 11th to 20th
    final cycleMid = AuditReportService.calculateDateRange(referenceDate: DateTime(2026, 10, 25), isMarketCycle: true);
    expect(cycleMid['startDate'], '2026-10-11');
    expect(cycleMid['endDate'], '2026-10-20');

    // 3. Surat Market Cycle: on 5th of month, previous cycle was 21st to end of previous month
    final cycleStart = AuditReportService.calculateDateRange(referenceDate: DateTime(2026, 11, 5), isMarketCycle: true);
    expect(cycleStart['startDate'], '2026-10-21');
    expect(cycleStart['endDate'], '2026-10-31');
  });

  test('PeriodicAuditReport accurately aggregates finances, factory katai and generates HTML email', () {
    final report = PeriodicAuditReport(
      startDate: '2026-10-19',
      endDate: '2026-10-28',
      periodTitle: '19 Oct 2026 — 28 Oct 2026',
      generatedAt: DateTime(2026, 10, 28, 22, 0),
      totalSalesPaise: CurrencyFormatter.rupeesToPaise(450000.0),
      totalSalesCount: 18,
      totalReceiptsPaise: CurrencyFormatter.rupeesToPaise(320000.0),
      cashReceiptsPaise: CurrencyFormatter.rupeesToPaise(120000.0),
      upiReceiptsPaise: CurrencyFormatter.rupeesToPaise(200000.0),
      totalPaymentsPaise: CurrencyFormatter.rupeesToPaise(100000.0),
      totalExpensesPaise: CurrencyFormatter.rupeesToPaise(25000.0),
      totalKataiMeters: 3850.0,
      totalKataiAmountPaise: CurrencyFormatter.rupeesToPaise(9625.0),
      totalWorkerAdvancesPaise: CurrencyFormatter.rupeesToPaise(4000.0),
      workerSummaries: const [
        {'worker_name': 'Ramesh Operator', 'machine_number': 'M-1', 'meters': 2100.0, 'earned_rupees': 5250.0},
      ],
      topCustomersDue: const [
        {'name': 'Shree Balaji Wholesalers', 'phone': '9825012345', 'balance_rupees': 85000.0},
      ],
    );

    expect(report.totalSalesRupees, 450000.0);
    expect(report.totalReceiptsRupees, 320000.0);
    expect(report.netCashFlowRupees, 195000.0);
    expect(report.totalKataiMeters, 3850.0);

    final html = AuditReportService.generateHtmlEmail(report);
    expect(html, contains('DM LACE SURAT'));
    expect(html, contains('19 Oct 2026 — 28 Oct 2026'));
    expect(html, contains('Shree Balaji Wholesalers'));
    expect(html, contains('Ramesh Operator'));
  });

  test('AutoEmailDispatchService saves settings and detects report due schedules', () async {
    // 1. Test Enabled with 10-day rolling
    await AutoEmailDispatchService.saveSettings(
      enabled: true,
      recipientEmail: 'rahuljangu01@gmail.com',
      cycleMode: 'rolling_10',
    );

    var settings = await AutoEmailDispatchService.getSettings();
    expect(settings[AutoEmailDispatchService.keyEnabled], 'true');
    expect(settings[AutoEmailDispatchService.keyRecipient], 'rahuljangu01@gmail.com');
    expect(settings[AutoEmailDispatchService.keyCycleMode], 'rolling_10');

    // 2. Test Disabled (OFF toggle)
    await AutoEmailDispatchService.saveSettings(
      enabled: false,
      recipientEmail: 'rahuljangu01@gmail.com',
      cycleMode: 'rolling_10',
    );
    settings = await AutoEmailDispatchService.getSettings();
    expect(settings[AutoEmailDispatchService.keyEnabled], 'false');
    final dueWhenDisabled = await AutoEmailDispatchService.isReportDue();
    expect(dueWhenDisabled, isFalse);

    // 3. Test 5-minute cycle
    await AutoEmailDispatchService.saveSettings(
      enabled: true,
      recipientEmail: 'rahuljangu01@gmail.com',
      cycleMode: 'every_5_min',
    );
    final due5min = await AutoEmailDispatchService.isReportDue();
    expect(due5min, isTrue);
  });

  test('AutoEmailDispatchService gathers 10-day DB data and executes dispatchReport without errors', () async {
    // 1. Seed realistic database
    await SampleDataSeeder.seedSampleData();

    // 2. Gather 10-day data from SQLite
    final report = await AuditReportService().gather10DayReportData();
    expect(report.totalSalesCount, greaterThan(0));
    expect(report.totalSalesRupees, greaterThan(0));
    expect(report.workerSummaries, isNotEmpty);
    expect(report.transactions, isNotEmpty);

    // 3. Dispatch report test
    final result = await AutoEmailDispatchService.dispatchReport(
      overrideRecipient: 'dmlace.surat@gmail.com',
      isManualTest: true,
    );

    expect(result.success, isTrue);
    expect(result.pdfFile, isNotNull);
    expect(result.csvFile, isNotNull);
  });
}
