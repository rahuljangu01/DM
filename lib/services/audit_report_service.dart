import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:csv/csv.dart';

import '../core/database/database_helper.dart';
import '../core/database/database_tables.dart';
import '../core/utils/currency_formatter.dart';
import '../core/utils/date_formatter.dart';
import '../models/periodic_audit_report.dart';

class AuditReportService {
  final DatabaseHelper _dbHelper;

  AuditReportService({DatabaseHelper? dbHelper}) : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  /// Calculate 10-day start and end date based on Surat market cycle or rolling 10-days
  static Map<String, dynamic> calculateDateRange({
    DateTime? referenceDate,
    bool isMarketCycle = true,
  }) {
    final ref = referenceDate ?? DateTime.now();
    final fmt = DateFormat('yyyy-MM-dd');

    if (!isMarketCycle) {
      // Rolling 10 days (last 10 days ending today)
      final start = ref.subtract(const Duration(days: 9));
      return {
        'startDate': fmt.format(start),
        'endDate': fmt.format(ref),
        'periodTitle': '${DateFormatter.formatReadable(start)} — ${DateFormatter.formatReadable(ref)}',
      };
    }

    // Surat Market 10-Day Billing Cycles:
    // 1-10 (Dispatched on 11th)
    // 11-20 (Dispatched on 21st)
    // 21-End of month (Dispatched on 1st of next month)
    final day = ref.day;
    DateTime cycleStart;
    DateTime cycleEnd;

    if (day <= 10) {
      // Previous cycle was 21st to end of previous month
      final prevMonthEnd = DateTime(ref.year, ref.month, 0);
      cycleStart = DateTime(prevMonthEnd.year, prevMonthEnd.month, 21);
      cycleEnd = prevMonthEnd;
    } else if (day <= 20) {
      // Previous cycle was 1st to 10th of current month
      cycleStart = DateTime(ref.year, ref.month, 1);
      cycleEnd = DateTime(ref.year, ref.month, 10);
    } else {
      // Current period is 11th to 20th of current month
      cycleStart = DateTime(ref.year, ref.month, 11);
      cycleEnd = DateTime(ref.year, ref.month, 20);
    }

    return {
      'startDate': fmt.format(cycleStart),
      'endDate': fmt.format(cycleEnd),
      'periodTitle': '${DateFormatter.formatReadable(cycleStart)} — ${DateFormatter.formatReadable(cycleEnd)}',
    };
  }

  /// Gather all financial, party, and karigar records for the 10-day period
  Future<PeriodicAuditReport> gather10DayReportData({
    String? explicitStartDate,
    String? explicitEndDate,
    DateTime? referenceDate,
    bool isMarketCycle = false, // Default to rolling 10-days for immediate relevance
  }) async {
    final db = await _dbHelper.database;

    String start;
    String end;
    String title;

    if (explicitStartDate != null && explicitEndDate != null) {
      start = explicitStartDate;
      end = explicitEndDate;
      title = '$start — $end';
    } else {
      final range = calculateDateRange(referenceDate: referenceDate, isMarketCycle: isMarketCycle);
      start = range['startDate'] as String;
      end = range['endDate'] as String;
      title = range['periodTitle'] as String;
    }

    // 1. Sales Documents in Period
    final salesRes = await db.rawQuery('''
      SELECT COUNT(*) as doc_count, COALESCE(SUM(grand_total_paise), 0) as total_sales
      FROM ${DatabaseTables.tableDocuments}
      WHERE doc_date >= ? AND doc_date <= ? AND doc_type IN ('kaccha_bill', 'tax_invoice') AND is_cancelled = 0
    ''', [start, end]);

    final totalSalesCount = (salesRes.first['doc_count'] as num?)?.toInt() ?? 0;
    final totalSalesPaise = (salesRes.first['total_sales'] as num?)?.toInt() ?? 0;

    // 2. Receipts, Payments & Expenses
    final receiptsRes = await db.rawQuery('''
      SELECT 
        COALESCE(SUM(amount_paise), 0) as total_receipts,
        COALESCE(SUM(CASE WHEN payment_method = 'cash' THEN amount_paise ELSE 0 END), 0) as cash_receipts,
        COALESCE(SUM(CASE WHEN payment_method = 'upi' THEN amount_paise ELSE 0 END), 0) as upi_receipts,
        COALESCE(SUM(CASE WHEN payment_method IN ('bank_transfer', 'cheque') THEN amount_paise ELSE 0 END), 0) as bank_receipts
      FROM ${DatabaseTables.tableTransactions}
      WHERE transaction_date >= ? AND transaction_date <= ? AND transaction_type = 'customer_receipt'
    ''', [start, end]);

    final totalReceiptsPaise = (receiptsRes.first['total_receipts'] as num?)?.toInt() ?? 0;
    final cashReceiptsPaise = (receiptsRes.first['cash_receipts'] as num?)?.toInt() ?? 0;
    final upiReceiptsPaise = (receiptsRes.first['upi_receipts'] as num?)?.toInt() ?? 0;
    final bankReceiptsPaise = (receiptsRes.first['bank_receipts'] as num?)?.toInt() ?? 0;

    final paymentsRes = await db.rawQuery('''
      SELECT COALESCE(SUM(amount_paise), 0) as total_payments
      FROM ${DatabaseTables.tableTransactions}
      WHERE transaction_date >= ? AND transaction_date <= ? AND transaction_type = 'supplier_payment'
    ''', [start, end]);
    final totalPaymentsPaise = (paymentsRes.first['total_payments'] as num?)?.toInt() ?? 0;

    final expensesRes = await db.rawQuery('''
      SELECT COALESCE(SUM(amount_paise), 0) as total_expenses
      FROM ${DatabaseTables.tableTransactions}
      WHERE transaction_date >= ? AND transaction_date <= ? AND transaction_type = 'expense'
    ''', [start, end]);
    final totalExpensesPaise = (expensesRes.first['total_expenses'] as num?)?.toInt() ?? 0;

    // 3. Factory Machine Katai Production in Period
    final kataiRes = await db.rawQuery('''
      SELECT 
        COALESCE(SUM(quantity), 0.0) as total_meters,
        COALESCE(SUM(total_amount_paise), 0) as total_amount
      FROM ${DatabaseTables.tableMachineKataiEntries}
      WHERE date >= ? AND date <= ?
    ''', [start, end]);
    final totalKataiMeters = (kataiRes.first['total_meters'] as num?)?.toDouble() ?? 0.0;
    final totalKataiAmountPaise = (kataiRes.first['total_amount'] as num?)?.toInt() ?? 0;

    // Worker production summaries (Joining tableWorkers to get Karigar name)
    final workerRes = await db.rawQuery('''
      SELECT 
        COALESCE(w.name, 'Karigar') as worker_name, 
        k.machine_number, 
        COALESCE(SUM(k.quantity), 0.0) as meters, 
        COALESCE(SUM(k.total_amount_paise), 0) as total_earned
      FROM ${DatabaseTables.tableMachineKataiEntries} k
      LEFT JOIN ${DatabaseTables.tableWorkers} w ON k.worker_id = w.id
      WHERE k.date >= ? AND k.date <= ?
      GROUP BY k.worker_id, k.machine_number
      ORDER BY meters DESC
    ''', [start, end]);

    final workerSummaries = workerRes.map((r) => {
      'worker_name': r['worker_name'] as String? ?? 'Karigar',
      'machine_number': r['machine_number'] as String? ?? '-',
      'meters': (r['meters'] as num?)?.toDouble() ?? 0.0,
      'earned_rupees': ((r['total_earned'] as num?)?.toInt() ?? 0) / 100.0,
    }).toList();

    // Worker Advances taken in period
    final advanceRes = await db.rawQuery('''
      SELECT COALESCE(SUM(amount_paise), 0) as total_advance
      FROM ${DatabaseTables.tableWorkerPayments}
      WHERE date >= ? AND date <= ? AND payment_type = 'advance'
    ''', [start, end]);
    final totalWorkerAdvancesPaise = (advanceRes.first['total_advance'] as num?)?.toInt() ?? 0;

    // 4. Current Market Outstandings (Top Customers with Balance Due)
    final custDueRes = await db.rawQuery('''
      SELECT name, phone, current_balance_paise
      FROM ${DatabaseTables.tableParties}
      WHERE (type = 'customer' OR type = 'wholesaler' OR type = 'retailer' OR type = 'both')
        AND is_archived = 0 AND current_balance_paise > 0
      ORDER BY current_balance_paise DESC
      LIMIT 10
    ''');
    final topCustomersDue = custDueRes.map((r) => {
      'name': r['name'] as String,
      'phone': r['phone'] as String? ?? '-',
      'balance_rupees': ((r['current_balance_paise'] as num).toDouble()) / 100.0,
    }).toList();

    // 5. Detailed Transactions during the 10 Days (Joining tableParties for names)
    final txListRes = await db.rawQuery('''
      SELECT 
        t.transaction_date, 
        COALESCE(t.reference_number, 'TX-' || t.id) as tx_number, 
        t.transaction_type, 
        COALESCE(p.name, t.expense_category, 'General') as party_name, 
        t.amount_paise, 
        t.payment_method as mode, 
        t.reference_number as ref, 
        t.notes
      FROM ${DatabaseTables.tableTransactions} t
      LEFT JOIN ${DatabaseTables.tableParties} p ON t.party_id = p.id
      WHERE t.transaction_date >= ? AND t.transaction_date <= ?
      ORDER BY t.transaction_date DESC, t.id DESC
    ''', [start, end]);

    final transactions = txListRes.map((r) => {
      'date': r['transaction_date'] as String,
      'tx_number': r['tx_number'] as String? ?? '',
      'type': r['transaction_type'] as String,
      'party_name': r['party_name'] as String? ?? 'General',
      'amount_rupees': ((r['amount_paise'] as num).toDouble()) / 100.0,
      'mode': (r['mode'] as String? ?? 'cash').toUpperCase(),
      'ref': r['ref'] as String? ?? '',
      'notes': r['notes'] as String? ?? '',
    }).toList();

    return PeriodicAuditReport(
      startDate: start,
      endDate: end,
      periodTitle: title,
      generatedAt: DateTime.now(),
      totalSalesPaise: totalSalesPaise,
      totalSalesCount: totalSalesCount,
      totalReceiptsPaise: totalReceiptsPaise,
      cashReceiptsPaise: cashReceiptsPaise,
      upiReceiptsPaise: upiReceiptsPaise,
      bankReceiptsPaise: bankReceiptsPaise,
      totalPaymentsPaise: totalPaymentsPaise,
      totalExpensesPaise: totalExpensesPaise,
      totalKataiMeters: totalKataiMeters,
      totalKataiAmountPaise: totalKataiAmountPaise,
      totalWorkerAdvancesPaise: totalWorkerAdvancesPaise,
      workerSummaries: workerSummaries,
      topCustomersDue: topCustomersDue,
      transactions: transactions,
    );
  }

  /// Safe output directory resolver (gracefully falls back to system temp if path_provider fails)
  static Future<Directory> _getSafeOutputDir() async {
    try {
      return await getTemporaryDirectory();
    } catch (_) {
      return Directory.systemTemp;
    }
  }

  /// Cleans text to 100% ASCII-compatible characters for standard PDF Helvetica font
  static String _cleanAscii(String text) {
    final replaced = text
        .replaceAll('₹', 'Rs. ')
        .replaceAll('—', '-')
        .replaceAll('–', '-')
        .replaceAll('•', '-')
        .replaceAll('॥', '')
        .replaceAll('’', "'")
        .replaceAll('‘', "'")
        .replaceAll('“', '"')
        .replaceAll('”', '"');
    final sb = StringBuffer();
    for (final char in replaced.runes) {
      if (char <= 127) {
        sb.writeCharCode(char);
      }
    }
    final res = sb.toString().trim();
    return res.isEmpty ? '-' : res;
  }

  static String _formatPdfRupees(double amount) {
    return 'Rs. ${CurrencyFormatter.format(amount, includeSymbol: false, showDecimals: false)}';
  }

  /// Generate Executive PDF Report
  Future<File> generatePdfReport(PeriodicAuditReport report) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (pw.Context context) {
          return [
            // Header with Brand and Period
            pw.Container(
              padding: const pw.EdgeInsets.only(bottom: 12),
              decoration: const pw.BoxDecoration(
                border: pw.Border(bottom: pw.BorderSide(color: PdfColors.blueGrey800, width: 1.5)),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'DM LACE SURAT',
                        style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#091B33')),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'Millennium Textile Market, Ring Road, Surat (Gujarat)',
                        style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
                      ),
                      pw.Text(
                        'Official 10-Day Business Audit and Ledger Statement',
                        style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#047857')),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: pw.BoxDecoration(
                          color: PdfColor.fromHex('#EFF6FF'),
                          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                          border: pw.Border.all(color: PdfColor.fromHex('#2563EB'), width: 0.8),
                        ),
                        child: pw.Text(
                          '10-DAY PERIOD',
                          style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#1E3A8A')),
                        ),
                      ),
                      pw.SizedBox(height: 3),
                      pw.Text(
                        _cleanAscii(report.periodTitle),
                        style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                      ),
                      pw.Text(
                        'Generated: ${_cleanAscii(report.generatedAtDisplay)}',
                        style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            pw.SizedBox(height: 14),

            // 4 Executive Summary Metrics Grid
            pw.Row(
              children: [
                _buildPdfMetricBox('TOTAL SALES', _formatPdfRupees(report.totalSalesRupees), '${report.totalSalesCount} Bills', '#1E3A8A', '#EFF6FF'),
                pw.SizedBox(width: 8),
                _buildPdfMetricBox('TOTAL RECEIPTS', _formatPdfRupees(report.totalReceiptsRupees), 'Cash: ${_formatPdfRupees(report.cashReceiptsRupees)}', '#047857', '#ECFDF5'),
                pw.SizedBox(width: 8),
                _buildPdfMetricBox('FACTORY KATAI', '${report.totalKataiMeters.toStringAsFixed(0)} Mtr', _formatPdfRupees(report.totalKataiAmountRupees), '#6D28D9', '#F5F3FF'),
                pw.SizedBox(width: 8),
                _buildPdfMetricBox('NET CASH FLOW', _formatPdfRupees(report.netCashFlowRupees), 'In - Out - Expense', report.netCashFlowRupees >= 0 ? '#0D9488' : '#DC2626', '#F0FDFA'),
              ],
            ),

            pw.SizedBox(height: 16),

            // Top Customers Pending Balances
            if (report.topCustomersDue.isNotEmpty) ...[
              pw.Text('TOP MARKET OUTSTANDING (CUSTOMER BALANCES)', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#091B33'))),
              pw.SizedBox(height: 5),
              pw.TableHelper.fromTextArray(
                headers: ['Party Name', 'Phone', 'Pending Amount'],
                headerStyle: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                headerDecoration: pw.BoxDecoration(color: PdfColor.fromHex('#1E3A8A')),
                cellStyle: const pw.TextStyle(fontSize: 8.5),
                cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3.5),
                data: report.topCustomersDue.map((c) => [
                  _cleanAscii(c['name'] as String),
                  _cleanAscii(c['phone'] as String),
                  _formatPdfRupees(c['balance_rupees'] as double),
                ]).toList(),
              ),
              pw.SizedBox(height: 14),
            ],

            // Factory & Karigar Katai Summary
            if (report.workerSummaries.isNotEmpty) ...[
              pw.Text('FACTORY KARIGAR & MACHINE PRODUCTION (KATAI)', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#091B33'))),
              pw.SizedBox(height: 5),
              pw.TableHelper.fromTextArray(
                headers: ['Karigar Name', 'Machine Number', 'Cut Meters', 'Wages Earned'],
                headerStyle: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                headerDecoration: pw.BoxDecoration(color: PdfColor.fromHex('#0D9488')),
                cellStyle: const pw.TextStyle(fontSize: 8.5),
                cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3.5),
                data: report.workerSummaries.map((w) => [
                  _cleanAscii(w['worker_name'] as String),
                  _cleanAscii(w['machine_number'] as String),
                  '${(w['meters'] as double).toStringAsFixed(1)} Mtr',
                  _formatPdfRupees(w['earned_rupees'] as double),
                ]).toList(),
              ),
              pw.SizedBox(height: 14),
            ],

            // 10-Day Transaction Log Table
            pw.Text('10-DAY TRANSACTION LOG (${report.transactions.length} ENTRIES)', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#091B33'))),
            pw.SizedBox(height: 5),
            pw.TableHelper.fromTextArray(
              headers: ['Date', 'Tx #', 'Type', 'Party', 'Amount', 'Mode'],
              headerStyle: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
              headerDecoration: pw.BoxDecoration(color: PdfColor.fromHex('#334155')),
              cellStyle: const pw.TextStyle(fontSize: 8),
              cellPadding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 3),
              data: report.transactions.take(35).map((t) => [
                _cleanAscii(t['date'] as String),
                _cleanAscii(t['tx_number'] as String),
                _cleanAscii((t['type'] as String).replaceAll('_', ' ').toUpperCase()),
                _cleanAscii(t['party_name'] as String),
                _formatPdfRupees(t['amount_rupees'] as double),
                _cleanAscii(t['mode'] as String),
              ]).toList(),
            ),

            pw.SizedBox(height: 12),
            pw.Divider(color: PdfColors.grey400, thickness: 0.8),
            pw.SizedBox(height: 4),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('DM Lace Surat - Fully Automated 10-Day Ledger Backup System', style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600)),
                pw.Text('Shubh Labh - Safe & Confidential', style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700)),
              ],
            ),
          ];
        },
      ),
    );

    final outputDir = await _getSafeOutputDir();
    final cleanStart = report.startDate.replaceAll('-', '');
    final cleanEnd = report.endDate.replaceAll('-', '');
    final file = File('${outputDir.path}/DM_Lace_Report_${cleanStart}_$cleanEnd.pdf');
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  static pw.Widget _buildPdfMetricBox(String label, String value, String sub, String primaryHex, String bgHex) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(8),
        decoration: pw.BoxDecoration(
          color: PdfColor.fromHex(bgHex),
          border: pw.Border.all(color: PdfColor.fromHex(primaryHex), width: 0.8),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(label, style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex(primaryHex))),
            pw.SizedBox(height: 3),
            pw.Text(value, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#091B33'))),
            pw.SizedBox(height: 2),
            pw.Text(sub, style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700)),
          ],
        ),
      ),
    );
  }

  /// Generate CSV Spreadsheet File
  Future<File> generateCsvReport(PeriodicAuditReport report) async {
    final List<List<dynamic>> rows = [
      ['DM LACE SURAT - 10-DAY BUSINESS & AUDIT REPORT'],
      ['Period', report.periodTitle],
      ['Generated On', report.generatedAt.toIso8601String()],
      [],
      ['EXECUTIVE SUMMARY'],
      ['Metric', 'Amount (INR)', 'Details'],
      ['Total Sales Billed', report.totalSalesRupees, '${report.totalSalesCount} Bills'],
      ['Total Receipts Collected', report.totalReceiptsRupees, 'Cash: ${report.cashReceiptsRupees}, UPI: ${report.upiReceiptsRupees}, Bank: ${report.bankReceiptsRupees}'],
      ['Total Supplier Payments', report.totalPaymentsRupees],
      ['Total Business Expenses', report.totalExpensesRupees],
      ['Net Cash Flow', report.netCashFlowRupees],
      ['Total Factory Katai Production', report.totalKataiAmountRupees, '${report.totalKataiMeters} Meters'],
      ['Total Karigar Advances (Kharcha)', report.totalWorkerAdvancesRupees],
      [],
      ['TOP CUSTOMERS WITH OUTSTANDING BALANCE'],
      ['Customer Name', 'Phone', 'Pending Amount (INR)'],
      ...report.topCustomersDue.map((c) => [c['name'], c['phone'], c['balance_rupees']]),
      [],
      ['KARIGAR MACHINE PRODUCTION (KATAI)'],
      ['Worker Name', 'Machine Number', 'Cut Meters', 'Wages Earned (INR)'],
      ...report.workerSummaries.map((w) => [w['worker_name'], w['machine_number'], w['meters'], w['earned_rupees']]),
      [],
      ['ALL TRANSACTIONS DURING 10-DAY PERIOD'],
      ['Date', 'Tx Number', 'Type', 'Party Name', 'Amount (INR)', 'Payment Mode', 'Reference', 'Notes'],
      ...report.transactions.map((t) => [
        t['date'],
        t['tx_number'],
        t['type'],
        t['party_name'],
        t['amount_rupees'],
        t['mode'],
        t['ref'],
        t['notes'],
      ]),
    ];

    final csvContent = csv.encode(rows);
    final outputDir = await _getSafeOutputDir();
    final cleanStart = report.startDate.replaceAll('-', '');
    final cleanEnd = report.endDate.replaceAll('-', '');
    final file = File('${outputDir.path}/DM_Lace_Transactions_${cleanStart}_$cleanEnd.csv');
    await file.writeAsString(csvContent);
    return file;
  }

  /// Generate Executive HTML Email Body
  static String generateHtmlEmail(PeriodicAuditReport report) {
    final salesFmt = CurrencyFormatter.format(report.totalSalesRupees, showDecimals: false);
    final receiptsFmt = CurrencyFormatter.format(report.totalReceiptsRupees, showDecimals: false);
    final kataiFmt = CurrencyFormatter.format(report.totalKataiAmountRupees, showDecimals: false);
    final cashFlowFmt = CurrencyFormatter.format(report.netCashFlowRupees, showDecimals: false);

    final custRows = report.topCustomersDue.take(6).map((c) {
      final bal = CurrencyFormatter.format(c['balance_rupees'] as double, showDecimals: false);
      return '''
        <tr>
          <td style="padding: 8px 12px; border-bottom: 1px solid #e2e8f0; font-size: 13px; font-weight: bold; color: #1e293b;">${c['name']}</td>
          <td style="padding: 8px 12px; border-bottom: 1px solid #e2e8f0; font-size: 13px; color: #64748b;">${c['phone']}</td>
          <td style="padding: 8px 12px; border-bottom: 1px solid #e2e8f0; font-size: 13px; font-weight: 800; color: #dc2626; text-align: right;">$bal</td>
        </tr>
      ''';
    }).join('');

    final workerRows = report.workerSummaries.take(5).map((w) {
      final earned = CurrencyFormatter.format(w['earned_rupees'] as double, showDecimals: false);
      return '''
        <tr>
          <td style="padding: 8px 12px; border-bottom: 1px solid #e2e8f0; font-size: 13px; font-weight: bold; color: #0f172a;">${w['worker_name']}</td>
          <td style="padding: 8px 12px; border-bottom: 1px solid #e2e8f0; font-size: 13px; color: #475569;">${w['machine_number']}</td>
          <td style="padding: 8px 12px; border-bottom: 1px solid #e2e8f0; font-size: 13px; font-weight: 600; text-align: right;">${(w['meters'] as double).toStringAsFixed(1)} Mtr</td>
          <td style="padding: 8px 12px; border-bottom: 1px solid #e2e8f0; font-size: 13px; font-weight: 800; color: #059669; text-align: right;">$earned</td>
        </tr>
      ''';
    }).join('');

    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>DM LACE SURAT • 10-Day Audit Report</title>
</head>
<body style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; background-color: #f8fafc; margin: 0; padding: 20px; color: #1e293b;">
  <div style="max-width: 650px; margin: 0 auto; background: #ffffff; border-radius: 16px; overflow: hidden; border: 1px solid #e2e8f0; box-shadow: 0 4px 16px rgba(0,0,0,0.06);">
    
    <!-- Header Banner -->
    <div style="background: linear-gradient(135deg, #091B33 0%, #1E3A8A 100%); padding: 24px; color: #ffffff; text-align: center;">
      <h1 style="margin: 0; font-size: 22px; font-weight: 900; letter-spacing: 1px; color: #ffffff;">DM LACE SURAT</h1>
      <p style="margin: 4px 0 0 0; font-size: 12px; color: #93c5fd;">सूरत का प्रतिष्ठित लेस, ज़री एवं बॉर्डर निर्माता • 10-दिवसीय ऑडिट व व्यापार रिपोर्ट</p>
      <div style="display: inline-block; margin-top: 12px; padding: 4px 14px; background: rgba(255,255,255,0.15); border-radius: 20px; font-size: 12px; font-weight: 700; color: #f8fafc;">
        📅 अवधि: ${report.periodTitle}
      </div>
    </div>

    <!-- Executive Metrics Grid -->
    <div style="padding: 20px;">
      <table style="width: 100%; border-collapse: separate; border-spacing: 10px; margin-top: -5px;">
        <tr>
          <td style="width: 50%; background: #eff6ff; border: 1px solid #bfdbfe; border-radius: 12px; padding: 14px;">
            <div style="font-size: 11px; font-weight: 700; color: #1e40af; text-transform: uppercase;">कुल बिक्री (Total Sales)</div>
            <div style="font-size: 20px; font-weight: 900; color: #1e3a8a; margin-top: 4px;">$salesFmt</div>
            <div style="font-size: 11px; color: #64748b; margin-top: 2px;">${report.totalSalesCount} पक्के/कच्चे बिल</div>
          </td>
          <td style="width: 50%; background: #ecfdf5; border: 1px solid #a7f3d0; border-radius: 12px; padding: 14px;">
            <div style="font-size: 11px; font-weight: 700; color: #047857; text-transform: uppercase;">कुल वसूली (Total Receipts)</div>
            <div style="font-size: 20px; font-weight: 900; color: #065f46; margin-top: 4px;">$receiptsFmt</div>
            <div style="font-size: 11px; color: #64748b; margin-top: 2px;">नकद, UPI व बैंक जमा</div>
          </td>
        </tr>
        <tr>
          <td style="width: 50%; background: #f5f3ff; border: 1px solid #ddd6fe; border-radius: 12px; padding: 14px;">
            <div style="font-size: 11px; font-weight: 700; color: #6d28d9; text-transform: uppercase;">कारखाना कटाई (Factory Katai)</div>
            <div style="font-size: 20px; font-weight: 900; color: #5b21b6; margin-top: 4px;">${report.totalKataiMeters.toStringAsFixed(0)} Mtr</div>
            <div style="font-size: 11px; color: #64748b; margin-top: 2px;">मजदूरी: $kataiFmt</div>
          </td>
          <td style="width: 50%; background: #f0fdfa; border: 1px solid #99f6e4; border-radius: 12px; padding: 14px;">
            <div style="font-size: 11px; font-weight: 700; color: #0d9488; text-transform: uppercase;">शुद्ध नकदी प्रवाह (Net Cash Flow)</div>
            <div style="font-size: 20px; font-weight: 900; color: #115e59; margin-top: 4px;">$cashFlowFmt</div>
            <div style="font-size: 11px; color: #64748b; margin-top: 2px;">वसूली - पेमेंट - खर्चे</div>
          </td>
        </tr>
      </table>

      <!-- Top Customer Outstandings -->
      <div style="margin-top: 20px;">
        <h3 style="margin: 0 0 10px 0; font-size: 14px; font-weight: 800; color: #0f172a;">👥 मार्केट उधारी (Pending Party Balances)</h3>
        <table style="width: 100%; border-collapse: collapse; background: #ffffff; border: 1px solid #e2e8f0; border-radius: 8px; overflow: hidden;">
          <tr style="background: #f1f5f9; text-align: left;">
            <th style="padding: 8px 12px; font-size: 11px; color: #475569;">पार्टी का नाम</th>
            <th style="padding: 8px 12px; font-size: 11px; color: #475569;">फ़ोन</th>
            <th style="padding: 8px 12px; font-size: 11px; color: #475569; text-align: right;">बाकी रकम (₹)</th>
          </tr>
          $custRows
        </table>
      </div>

      <!-- Factory Production Summary -->
      <div style="margin-top: 20px;">
        <h3 style="margin: 0 0 10px 0; font-size: 14px; font-weight: 800; color: #0f172a;">🏭 कारीगर कटाई उत्पादन (Karigar Katai)</h3>
        <table style="width: 100%; border-collapse: collapse; background: #ffffff; border: 1px solid #e2e8f0; border-radius: 8px; overflow: hidden;">
          <tr style="background: #f1f5f9; text-align: left;">
            <th style="padding: 8px 12px; font-size: 11px; color: #475569;">कारीगर</th>
            <th style="padding: 8px 12px; font-size: 11px; color: #475569;">मशीन</th>
            <th style="padding: 8px 12px; font-size: 11px; color: #475569; text-align: right;">मीटर</th>
            <th style="padding: 8px 12px; font-size: 11px; color: #475569; text-align: right;">कुल कमाई</th>
          </tr>
          $workerRows
        </table>
      </div>

      <!-- Attachments Notice -->
      <div style="margin-top: 22px; padding: 14px; background: #f8fafc; border-radius: 10px; border: 1px dashed #cbd5e1; text-align: center;">
        <span style="font-size: 16px;">📎</span>
        <span style="font-size: 12px; font-weight: 700; color: #334155; margin-left: 6px;">
          इस ईमेल के साथ 2 महत्वपूर्ण फ़ाइलें अटैच हैं:
        </span>
        <div style="margin-top: 6px; font-size: 11.5px; color: #64748b;">
          1. <b>DM_Lace_10Day_Report.pdf</b> (कलरफुल VIP प्रिंट-रेडी रिपोर्ट)<br>
          2. <b>DM_Lace_Transactions.csv</b> (Excel में खोलने योग्य कच्ची खाता-बही)
        </div>
      </div>

    </div>

    <!-- Footer -->
    <div style="background: #f1f5f9; padding: 14px 20px; text-align: center; border-top: 1px solid #e2e8f0; font-size: 11px; color: #64748b;">
      DM LACE SURAT • 100% ऑफ़लाइन सुरक्षित ऑटोमेटेड बहीखाता • Limbayat, Surat (Gujarat)<br>
      <span style="color: #b45309; font-weight: bold; margin-top: 4px; display: inline-block;">॥ शुभ लाभ • ऋद्धि-सिद्धि • सुरक्षित व गोपनीय हिसाब ॥</span>
    </div>

  </div>
</body>
</html>
''';
  }
}
