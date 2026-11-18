import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_colors.dart';
import '../../core/localization/language_provider.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';
import '../../core/utils/share_helper.dart';
import '../../repositories/report_repository.dart';
import '../../repositories/party_repository.dart';
import '../../repositories/document_repository.dart';
import '../../repositories/transaction_repository.dart';
import '../../repositories/inventory_repository.dart';
import '../../services/csv_service.dart';

class ReportsScreen extends StatefulWidget {
  final ReportRepository? repository;

  const ReportsScreen({super.key, this.repository});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  late ReportRepository _reportRepo;

  String _selectedReport = 'daily'; // daily, cust_due, supp_due, expense, profit
  bool _isLoading = true;

  Map<String, dynamic> _dailyData = {};
  List<Map<String, dynamic>> _custDueList = [];
  List<Map<String, dynamic>> _suppDueList = [];
  List<Map<String, dynamic>> _expenseList = [];
  Map<String, dynamic> _profitData = {};

  @override
  void initState() {
    super.initState();
    _reportRepo = widget.repository ?? ReportRepository();
    _loadReport();
  }

  Future<void> _loadReport() async {
    setState(() => _isLoading = true);
    final today = DateFormatter.toIso(DateTime.now()).substring(0, 10);

    if (_selectedReport == 'daily') {
      _dailyData = await _reportRepo.getDailySummary(today);
    } else if (_selectedReport == 'cust_due') {
      _custDueList = await _reportRepo.getCustomerOutstanding();
    } else if (_selectedReport == 'supp_due') {
      _suppDueList = await _reportRepo.getSupplierOutstanding();
    } else if (_selectedReport == 'expense') {
      _expenseList = await _reportRepo.getExpenseBreakdown();
    } else if (_selectedReport == 'profit') {
      _profitData = await _reportRepo.getProfitAndLossSummary();
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _exportCsv() async {
    HapticFeedback.lightImpact();
    if (_selectedReport == 'cust_due' || _selectedReport == 'supp_due') {
      final parties = await PartyRepository().getAllParties();
      await CsvService.exportParties(parties);
    } else if (_selectedReport == 'daily') {
      final docs = await DocumentRepository().getDocuments();
      await CsvService.exportDocuments(docs);
    } else if (_selectedReport == 'expense') {
      final txs = await TransactionRepository().getTransactions(type: 'expense');
      await CsvService.exportTransactions(txs);
    } else {
      final items = await InventoryRepository().getItems();
      await CsvService.exportInventory(items);
    }
  }

  void _shareActiveReport(LanguageProvider lang) {
    HapticFeedback.lightImpact();
    if (_selectedReport == 'daily') {
      _shareDailySummary(lang);
    } else if (_selectedReport == 'cust_due') {
      _shareCustDueSummary(lang);
    } else if (_selectedReport == 'supp_due') {
      _shareSuppDueSummary(lang);
    } else if (_selectedReport == 'expense') {
      _shareExpenseSummary(lang);
    } else if (_selectedReport == 'profit') {
      _shareProfitSummary(lang);
    }
  }

  void _shareDailySummary(LanguageProvider lang) {
    final count = _dailyData['doc_count'] ?? 0;
    final sales = CurrencyFormatter.format(_dailyData['total_sales_rupees'] ?? 0.0);
    final receipts = CurrencyFormatter.format(_dailyData['total_receipts_rupees'] ?? 0.0);
    final payments = CurrencyFormatter.format(_dailyData['total_payments_rupees'] ?? 0.0);
    final expenses = CurrencyFormatter.format(_dailyData['total_expenses_rupees'] ?? 0.0);
    final netRupees = (_dailyData['total_receipts_rupees'] ?? 0.0) -
        (_dailyData['total_payments_rupees'] ?? 0.0) -
        (_dailyData['total_expenses_rupees'] ?? 0.0);
    final net = CurrencyFormatter.format(netRupees);

    final msg = lang.isHindi
        ? '''*DM LACE SURAT*
दैनिक क्लोजिंग रिपोर्ट (${DateFormatter.today()})
----------------------------------------
कुल बिक्री: $sales
आज के बिल: $count
जमा कलेक्शन: $receipts
सप्लायर भुगतान: $payments
दुकान खर्च: $expenses
----------------------------------------
नेट कैश स्थिति: $net
----------------------------------------'''
        : '''*DM LACE SURAT*
Daily Closing Report (${DateFormatter.today()})
----------------------------------------
Total Sales: $sales
Bills Created: $count
Collections: $receipts
Supplier Payments: $payments
Daily Expenses: $expenses
----------------------------------------
Net Cash Flow: $net
----------------------------------------''';

    ShareHelper.shareText(msg, subject: 'DM Lace Surat - Daily Closing');
  }

  void _shareCustDueSummary(LanguageProvider lang) {
    final totalDue = _custDueList.fold<double>(0.0, (acc, c) => acc + (c['balance_rupees'] as double));
    final buffer = StringBuffer();
    if (lang.isHindi) {
      buffer.writeln('*DM LACE SURAT*');
      buffer.writeln('मार्केट लेना सारांश (Market Receivables)');
      buffer.writeln('कुल बकाया: ${CurrencyFormatter.format(totalDue)} (${_custDueList.length} पार्टियां)');
      buffer.writeln('----------------------------------------');
      for (int i = 0; i < _custDueList.length && i < 25; i++) {
        final c = _custDueList[i];
        buffer.writeln('${i + 1}. *${c['name']}*: ${CurrencyFormatter.format(c['balance_rupees'] as double)}');
      }
      buffer.writeln('----------------------------------------');
    } else {
      buffer.writeln('*DM LACE SURAT*');
      buffer.writeln('Market Receivables Summary');
      buffer.writeln('Total Outstanding: ${CurrencyFormatter.format(totalDue)} (${_custDueList.length} Parties)');
      buffer.writeln('----------------------------------------');
      for (int i = 0; i < _custDueList.length && i < 25; i++) {
        final c = _custDueList[i];
        buffer.writeln('${i + 1}. *${c['name']}*: ${CurrencyFormatter.format(c['balance_rupees'] as double)}');
      }
      buffer.writeln('----------------------------------------');
    }
    ShareHelper.shareText(buffer.toString(), subject: 'Market Receivables Summary');
  }

  void _shareSuppDueSummary(LanguageProvider lang) {
    final totalDue = _suppDueList.fold<double>(0.0, (acc, s) => acc + (s['balance_rupees'] as double));
    final buffer = StringBuffer();
    if (lang.isHindi) {
      buffer.writeln('*DM LACE SURAT*');
      buffer.writeln('सप्लायर देना सारांश (Supplier Payables)');
      buffer.writeln('कुल देना: ${CurrencyFormatter.format(totalDue)} (${_suppDueList.length} सप्लायर)');
      buffer.writeln('----------------------------------------');
      for (int i = 0; i < _suppDueList.length && i < 25; i++) {
        final s = _suppDueList[i];
        buffer.writeln('${i + 1}. *${s['name']}*: ${CurrencyFormatter.format(s['balance_rupees'] as double)}');
      }
      buffer.writeln('----------------------------------------');
    } else {
      buffer.writeln('*DM LACE SURAT*');
      buffer.writeln('Supplier Payables Summary');
      buffer.writeln('Total Payable: ${CurrencyFormatter.format(totalDue)} (${_suppDueList.length} Suppliers)');
      buffer.writeln('----------------------------------------');
      for (int i = 0; i < _suppDueList.length && i < 25; i++) {
        final s = _suppDueList[i];
        buffer.writeln('${i + 1}. *${s['name']}*: ${CurrencyFormatter.format(s['balance_rupees'] as double)}');
      }
      buffer.writeln('----------------------------------------');
    }
    ShareHelper.shareText(buffer.toString(), subject: 'Supplier Payables Summary');
  }

  void _shareExpenseSummary(LanguageProvider lang) {
    final totalExp = _expenseList.fold<double>(0.0, (acc, e) => acc + (e['amount_rupees'] as double));
    final buffer = StringBuffer();
    if (lang.isHindi) {
      buffer.writeln('*DM LACE SURAT*');
      buffer.writeln('दुकान खर्च विवरण (Expense Summary)');
      buffer.writeln('कुल खर्च: ${CurrencyFormatter.format(totalExp)}');
      buffer.writeln('----------------------------------------');
      for (final e in _expenseList) {
        buffer.writeln('• *${e['category']}*: ${CurrencyFormatter.format(e['amount_rupees'] as double)} (${e['count']} एंट्री)');
      }
      buffer.writeln('----------------------------------------');
    } else {
      buffer.writeln('*DM LACE SURAT*');
      buffer.writeln('Expense Summary Breakdown');
      buffer.writeln('Total Expenses: ${CurrencyFormatter.format(totalExp)}');
      buffer.writeln('----------------------------------------');
      for (final e in _expenseList) {
        buffer.writeln('• *${e['category']}*: ${CurrencyFormatter.format(e['amount_rupees'] as double)} (${e['count']} entries)');
      }
      buffer.writeln('----------------------------------------');
    }
    ShareHelper.shareText(buffer.toString(), subject: 'Expense Summary');
  }

  void _shareProfitSummary(LanguageProvider lang) {
    final sales = _profitData['total_sales'] as double? ?? 0.0;
    final cogs = _profitData['cost_of_goods'] as double? ?? 0.0;
    final gross = _profitData['gross_profit'] as double? ?? 0.0;
    final expenses = _profitData['total_expenses'] as double? ?? 0.0;
    final net = _profitData['net_profit'] as double? ?? 0.0;
    final netMargin = sales > 0 ? ((net / sales) * 100).toStringAsFixed(1) : '0.0';

    final msg = lang.isHindi
        ? '''*DM LACE SURAT*
मुनाफ़ा व लाभ सारांश (P&L Report)
----------------------------------------
कुल बिक्री: ${CurrencyFormatter.format(sales)}
माल लागत: - ${CurrencyFormatter.format(cogs)}
सकल लाभ: ${CurrencyFormatter.format(gross)}
दुकान खर्च: - ${CurrencyFormatter.format(expenses)}
----------------------------------------
शुद्ध बचत (Net Profit): ${CurrencyFormatter.format(net)}
नेट मार्जिन: $netMargin%
----------------------------------------'''
        : '''*DM LACE SURAT*
Profit & Loss Statement
----------------------------------------
Total Sales: ${CurrencyFormatter.format(sales)}
Cost of Goods: - ${CurrencyFormatter.format(cogs)}
Gross Profit: ${CurrencyFormatter.format(gross)}
Operating Expenses: - ${CurrencyFormatter.format(expenses)}
----------------------------------------
Net Profit: ${CurrencyFormatter.format(net)}
Net Margin: $netMargin%
----------------------------------------''';

    ShareHelper.shareText(msg, subject: 'DM Lace Surat - Profit & Loss');
  }

  Future<void> _makeCall(String phone) async {
    HapticFeedback.lightImpact();
    final clean = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    final uri = Uri.parse('tel:$clean');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    } catch (_) {}
  }

  Future<void> _sendWhatsAppReminder(String phone, String name, double amount, LanguageProvider lang) async {
    HapticFeedback.lightImpact();
    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
    final formattedPhone = cleanPhone.length == 10 ? '91$cleanPhone' : cleanPhone;
    final formattedAmount = CurrencyFormatter.format(amount);

    final msg = lang.isHindi
        ? '''*DM LACE SURAT*
भुगतान सूचना (Payment Reminder)
----------------------------------------
सादर $name जी,
आपके खाते का वर्तमान बकाया: $formattedAmount
कृपया समयानुसार भुगतान कराने की कृपा करें।
----------------------------------------
धन्यवाद, DM Lace Surat'''
        : '''*DM LACE SURAT*
Payment Reminder
----------------------------------------
Dear $name,
Your current outstanding balance is: $formattedAmount
Kindly arrange the payment at your earliest convenience.
----------------------------------------
Thank you, DM Lace Surat''';

    final uri = Uri.parse('whatsapp://send?phone=$formattedPhone&text=${Uri.encodeComponent(msg)}');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        ShareHelper.shareText(msg, subject: 'Payment Reminder - $name');
      }
    } catch (_) {
      ShareHelper.shareText(msg, subject: 'Payment Reminder - $name');
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          lang.isHindi ? 'बिज़नेस रिपोर्ट' : 'Business Reports',
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined, color: AppColors.goldLight),
            onPressed: () => _shareActiveReport(lang),
            tooltip: 'Share Report on WhatsApp',
          ),
          IconButton(
            icon: const Icon(Icons.file_download_outlined, color: AppColors.goldLight),
            onPressed: _exportCsv,
            tooltip: 'Export CSV',
          ),
        ],
      ),
      body: Column(
        children: [
          // Professional Category Chip Segment Bar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildTypeChip(lang.isHindi ? 'दैनिक सारांश' : 'Daily', 'daily', Icons.today_rounded),
                  const SizedBox(width: 8),
                  _buildTypeChip(lang.isHindi ? 'मार्केट लेना' : 'Receivables', 'cust_due', Icons.south_west_rounded),
                  const SizedBox(width: 8),
                  _buildTypeChip(lang.isHindi ? 'सप्लायर देना' : 'Payables', 'supp_due', Icons.north_east_rounded),
                  const SizedBox(width: 8),
                  _buildTypeChip(lang.isHindi ? 'दुकान खर्च' : 'Expenses', 'expense', Icons.receipt_long_rounded),
                  const SizedBox(width: 8),
                  _buildTypeChip(lang.isHindi ? 'मुनाफ़ा (P&L)' : 'Profit & Loss', 'profit', Icons.trending_up_rounded),
                ],
              ),
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),

          // Main View Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primaryNavy))
                : RefreshIndicator(
                    onRefresh: _loadReport,
                    color: AppColors.primaryNavy,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(14, 14, 14, 30),
                      children: [
                        if (_selectedReport == 'daily') _buildDailyView(lang),
                        if (_selectedReport == 'cust_due') _buildCustDueView(lang),
                        if (_selectedReport == 'supp_due') _buildSuppDueView(lang),
                        if (_selectedReport == 'expense') _buildExpenseView(lang),
                        if (_selectedReport == 'profit') _buildProfitView(lang),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeChip(String label, String value, IconData icon) {
    final isSelected = _selectedReport == value;
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() => _selectedReport = value);
        _loadReport();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? const Color(0xFFD4AF37) : const Color(0xFFE2E8F0),
            width: isSelected ? 1.2 : 0.8,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected ? const Color(0xFFFDE047) : AppColors.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? const Color(0xFFFDE047) : AppColors.textPrimary,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                fontSize: 12.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 1. Executive Daily Business Summary View
  Widget _buildDailyView(LanguageProvider lang) {
    final sales = _dailyData['total_sales_rupees'] as double? ?? 0.0;
    final receipts = _dailyData['total_receipts_rupees'] as double? ?? 0.0;
    final payments = _dailyData['total_payments_rupees'] as double? ?? 0.0;
    final expenses = _dailyData['total_expenses_rupees'] as double? ?? 0.0;
    final docCount = _dailyData['doc_count'] as int? ?? 0;
    final netCash = receipts - payments - expenses;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Hero Net Cash Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.calendar_today_rounded, size: 14, color: AppColors.primaryNavy),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        DateFormatter.today(),
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '$docCount ${lang.isHindi ? 'बिल' : 'Bills'}',
                      style: const TextStyle(color: Color(0xFF1D4ED8), fontSize: 11, fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                lang.isHindi ? 'आज का नेट कैश फ्लो' : 'Today Net Cash Flow',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMuted),
              ),
              const SizedBox(height: 2),
              Text(
                CurrencyFormatter.format(netCash),
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: netCash >= 0 ? AppColors.receivableGreen : AppColors.payableRed,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 14),
              // WhatsApp Share Action Pill Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => _shareDailySummary(lang),
                  icon: const Icon(Icons.share_rounded, size: 16),
                  label: Text(
                    lang.isHindi ? 'आज का हिसाब WhatsApp पर भेजें' : 'Share Daily Closing on WhatsApp',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // 4-Tile Modern KPI Grid
        Row(
          children: [
            Expanded(
              child: _buildMetricTile(
                title: lang.isHindi ? 'कुल बिक्री' : 'Total Sales',
                amount: sales,
                icon: Icons.point_of_sale_rounded,
                accentColor: const Color(0xFF1E3A8A),
                bgColor: const Color(0xFFEFF6FF),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildMetricTile(
                title: lang.isHindi ? 'जमा रकम' : 'Collections',
                amount: receipts,
                icon: Icons.south_west_rounded,
                accentColor: AppColors.receivableGreen,
                bgColor: const Color(0xFFECFDF5),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildMetricTile(
                title: lang.isHindi ? 'सप्लायर भुगतान' : 'Payments',
                amount: payments,
                icon: Icons.north_east_rounded,
                accentColor: AppColors.payableRed,
                bgColor: const Color(0xFFFEF2F2),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildMetricTile(
                title: lang.isHindi ? 'दुकान खर्च' : 'Daily Expenses',
                amount: expenses,
                icon: Icons.receipt_long_rounded,
                accentColor: const Color(0xFFD97706),
                bgColor: const Color(0xFFFFFBEB),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricTile({
    required String title,
    required double amount,
    required IconData icon,
    required Color accentColor,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, color: accentColor, size: 16),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            CurrencyFormatter.format(amount),
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: accentColor),
          ),
        ],
      ),
    );
  }

  // 2. Customer Receivables View
  Widget _buildCustDueView(LanguageProvider lang) {
    final totalDue = _custDueList.fold<double>(0.0, (acc, c) => acc + (c['balance_rupees'] as double));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Summary Header Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lang.isHindi ? 'मार्केट कुल बकाया' : 'Total Market Receivables',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    CurrencyFormatter.format(totalDue),
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.receivableGreen),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${_custDueList.length} ${lang.isHindi ? 'पार्टियों से लेना बाकी' : 'Parties Outstanding'}',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                  ),
                ],
              ),
              IconButton(
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366).withValues(alpha: 0.12),
                  foregroundColor: const Color(0xFF25D366),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.share_rounded, size: 20),
                onPressed: () => _shareCustDueSummary(lang),
                tooltip: 'Share Receivables Summary',
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        if (_custDueList.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Column(
                children: [
                  const Icon(Icons.check_circle_outline_rounded, size: 48, color: AppColors.receivableGreen),
                  const SizedBox(height: 8),
                  Text(
                    lang.isHindi ? 'कोई बकाया नहीं है!' : 'No pending receivables!',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.textPrimary),
                  ),
                ],
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _custDueList.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, idx) {
              final item = _custDueList[idx];
              final name = item['name'] as String;
              final phone = item['phone'] as String?;
              final balance = item['balance_rupees'] as double;
              final initial = name.isNotEmpty ? name[0].toUpperCase() : 'C';

              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: const Color(0xFF0F172A),
                      child: Text(
                        initial,
                        style: const TextStyle(color: Color(0xFFFDE047), fontWeight: FontWeight.w800, fontSize: 14),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.textPrimary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            phone != null && phone.isNotEmpty ? phone : (lang.isHindi ? 'फोन नंबर नहीं' : 'No phone'),
                            style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          CurrencyFormatter.format(balance),
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: AppColors.receivableGreen),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (phone != null && phone.isNotEmpty) ...[
                              GestureDetector(
                                onTap: () => _makeCall(phone),
                                child: Container(
                                  padding: const EdgeInsets.all(5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Icon(Icons.phone_outlined, size: 14, color: AppColors.primaryNavy),
                                ),
                              ),
                              const SizedBox(width: 6),
                              GestureDetector(
                                onTap: () => _sendWhatsAppReminder(phone, name, balance, lang),
                                child: Container(
                                  padding: const EdgeInsets.all(5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF25D366).withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Icon(Icons.chat_rounded, size: 14, color: Color(0xFF25D366)),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  // 3. Supplier Payables View
  Widget _buildSuppDueView(LanguageProvider lang) {
    final totalDue = _suppDueList.fold<double>(0.0, (acc, s) => acc + (s['balance_rupees'] as double));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Summary Header Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lang.isHindi ? 'सप्लायर कुल देना' : 'Total Supplier Payables',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    CurrencyFormatter.format(totalDue),
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.payableRed),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${_suppDueList.length} ${lang.isHindi ? 'सप्लायर्स को भुगतान बाकी' : 'Suppliers to pay'}',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                  ),
                ],
              ),
              IconButton(
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366).withValues(alpha: 0.12),
                  foregroundColor: const Color(0xFF25D366),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.share_rounded, size: 20),
                onPressed: () => _shareSuppDueSummary(lang),
                tooltip: 'Share Payables Summary',
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        if (_suppDueList.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Column(
                children: [
                  const Icon(Icons.check_circle_outline_rounded, size: 48, color: AppColors.receivableGreen),
                  const SizedBox(height: 8),
                  Text(
                    lang.isHindi ? 'कोई सप्लायर बकाया नहीं है!' : 'No pending supplier payables!',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.textPrimary),
                  ),
                ],
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _suppDueList.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, idx) {
              final item = _suppDueList[idx];
              final name = item['name'] as String;
              final phone = item['phone'] as String?;
              final balance = item['balance_rupees'] as double;
              final initial = name.isNotEmpty ? name[0].toUpperCase() : 'S';

              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: const Color(0xFF1E293B),
                      child: Text(
                        initial,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.textPrimary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            phone != null && phone.isNotEmpty ? phone : (lang.isHindi ? 'फोन नंबर नहीं' : 'No phone'),
                            style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          CurrencyFormatter.format(balance),
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: AppColors.payableRed),
                        ),
                        if (phone != null && phone.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          GestureDetector(
                            onTap: () => _makeCall(phone),
                            child: Container(
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Icon(Icons.phone_outlined, size: 14, color: AppColors.primaryNavy),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  // 4. Shop Expenses Breakdown View
  Widget _buildExpenseView(LanguageProvider lang) {
    final totalExp = _expenseList.fold<double>(0.0, (acc, e) => acc + (e['amount_rupees'] as double));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Summary Header Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lang.isHindi ? 'कुल दुकान खर्च' : 'Total Shop Expenses',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    CurrencyFormatter.format(totalExp),
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFFD97706)),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${_expenseList.length} ${lang.isHindi ? 'श्रेणियों में खर्च' : 'Expense Categories'}',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                  ),
                ],
              ),
              IconButton(
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366).withValues(alpha: 0.12),
                  foregroundColor: const Color(0xFF25D366),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.share_rounded, size: 20),
                onPressed: () => _shareExpenseSummary(lang),
                tooltip: 'Share Expense Breakdown',
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        if (_expenseList.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Column(
                children: [
                  const Icon(Icons.receipt_long_outlined, size: 48, color: Color(0xFFCBD5E1)),
                  const SizedBox(height: 8),
                  Text(
                    lang.isHindi ? 'कोई खर्च दर्ज नहीं है' : 'No expenses recorded',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.textPrimary),
                  ),
                ],
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _expenseList.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, idx) {
              final item = _expenseList[idx];
              final cat = item['category'] as String;
              final amount = item['amount_rupees'] as double;
              final count = item['count'] as int;
              final percent = totalExp > 0 ? (amount / totalExp) : 0.0;

              final iconData = _getExpenseCategoryIcon(cat);

              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: iconData.bgColor,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(iconData.icon, color: iconData.accentColor, size: 18),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                cat,
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: AppColors.textPrimary),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '$count ${lang.isHindi ? 'लेन-देन' : 'transactions'} • ${(percent * 100).toStringAsFixed(1)}%',
                                style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          CurrencyFormatter.format(amount),
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFFD97706)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Proportional Visual Bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: percent.clamp(0.0, 1.0),
                        backgroundColor: const Color(0xFFF1F5F9),
                        valueColor: AlwaysStoppedAnimation<Color>(iconData.accentColor),
                        minHeight: 5,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  ({IconData icon, Color accentColor, Color bgColor}) _getExpenseCategoryIcon(String cat) {
    final lower = cat.toLowerCase();
    if (lower.contains('चाय') || lower.contains('tea')) {
      return (icon: Icons.coffee_rounded, accentColor: const Color(0xFF854D0E), bgColor: const Color(0xFFFEF9C3));
    } else if (lower.contains('रिक्शा') || lower.contains('भाड़ा') || lower.contains('freight')) {
      return (icon: Icons.local_shipping_outlined, accentColor: const Color(0xFF1D4ED8), bgColor: const Color(0xFFEFF6FF));
    } else if (lower.contains('पैकिंग') || lower.contains('packing')) {
      return (icon: Icons.inventory_2_outlined, accentColor: const Color(0xFF0D9488), bgColor: const Color(0xFFCCFBF1));
    } else if (lower.contains('बिजली') || lower.contains('light')) {
      return (icon: Icons.lightbulb_outlined, accentColor: const Color(0xFFCA8A04), bgColor: const Color(0xFFFEF08A));
    } else if (lower.contains('मशीन') || lower.contains('machinery')) {
      return (icon: Icons.settings_suggest_outlined, accentColor: const Color(0xFF7C3AED), bgColor: const Color(0xFFF3E8FF));
    } else if (lower.contains('कच्चा') || lower.contains('raw')) {
      return (icon: Icons.texture_rounded, accentColor: const Color(0xFF4338CA), bgColor: const Color(0xFFE0E7FF));
    }
    return (icon: Icons.receipt_long_rounded, accentColor: const Color(0xFF475569), bgColor: const Color(0xFFF1F5F9));
  }

  // 5. Executive Profit & Loss (P&L) View
  Widget _buildProfitView(LanguageProvider lang) {
    final sales = _profitData['total_sales'] as double? ?? 0.0;
    final cogs = _profitData['cost_of_goods'] as double? ?? 0.0;
    final gross = _profitData['gross_profit'] as double? ?? 0.0;
    final expenses = _profitData['total_expenses'] as double? ?? 0.0;
    final net = _profitData['net_profit'] as double? ?? 0.0;

    final grossMargin = sales > 0 ? ((gross / sales) * 100).toStringAsFixed(1) : '0.0';
    final netMargin = sales > 0 ? ((net / sales) * 100).toStringAsFixed(1) : '0.0';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Hero Net Profit Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    lang.isHindi ? 'शुद्ध बचत (Net Profit)' : 'Net Operating Profit',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textMuted),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: net >= 0 ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      net >= 0 ? (lang.isHindi ? 'मुनाफ़ा' : 'Profitable') : (lang.isHindi ? 'घाटा' : 'Loss'),
                      style: TextStyle(
                        color: net >= 0 ? AppColors.receivableGreen : AppColors.payableRed,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                CurrencyFormatter.format(net),
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: net >= 0 ? AppColors.receivableGreen : AppColors.payableRed,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 12),
              // Executive Margin Badges
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            lang.isHindi ? 'सकल मार्जिन' : 'Gross Margin',
                            style: const TextStyle(fontSize: 10, color: AppColors.textMuted, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$grossMargin%',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: AppColors.primaryNavy),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            lang.isHindi ? 'नेट मार्जिन' : 'Net Margin',
                            style: const TextStyle(fontSize: 10, color: AppColors.textMuted, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$netMargin%',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: net >= 0 ? AppColors.receivableGreen : AppColors.payableRed,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Income Statement Breakdown Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                lang.isHindi ? 'आय व लागत विवरण' : 'Income Statement',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 12),
              _buildReportLine(
                label: lang.isHindi ? 'कुल बिक्री (Revenue)' : 'Billed Sales Revenue',
                value: CurrencyFormatter.format(sales),
                color: AppColors.primaryNavy,
              ),
              const Divider(height: 20, color: Color(0xFFF1F5F9)),
              _buildReportLine(
                label: lang.isHindi ? 'माल लागत (COGS)' : 'Cost of Goods Sold',
                value: '- ${CurrencyFormatter.format(cogs)}',
                color: AppColors.textSecondary,
              ),
              const Divider(height: 20, color: Color(0xFFF1F5F9)),
              _buildReportLine(
                label: lang.isHindi ? 'सकल लाभ (Gross Profit)' : 'Gross Profit',
                value: CurrencyFormatter.format(gross),
                isBold: true,
                color: gross >= 0 ? AppColors.receivableGreen : AppColors.payableRed,
              ),
              const Divider(height: 20, color: Color(0xFFF1F5F9)),
              _buildReportLine(
                label: lang.isHindi ? 'दुकान खर्च (Expenses)' : 'Operating Expenses',
                value: '- ${CurrencyFormatter.format(expenses)}',
                color: AppColors.payableRed,
              ),
              const Divider(height: 20, color: Color(0xFFE2E8F0)),
              _buildReportLine(
                label: lang.isHindi ? 'शुद्ध बचत (Net Profit)' : 'Net Operating Profit',
                value: CurrencyFormatter.format(net),
                isBold: true,
                fontSize: 16,
                color: net >= 0 ? AppColors.receivableGreen : AppColors.payableRed,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Share P&L Button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF25D366),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => _shareProfitSummary(lang),
            icon: const Icon(Icons.share_rounded, size: 18),
            label: Text(
              lang.isHindi ? 'मुनाफ़ा रिपोर्ट WhatsApp पर भेजें' : 'Share P&L on WhatsApp',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReportLine({
    required String label,
    required String value,
    bool isBold = false,
    double fontSize = 13.5,
    Color? color,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isBold ? fontSize : 13,
            fontWeight: isBold ? FontWeight.w800 : FontWeight.w500,
            color: isBold ? AppColors.textPrimary : AppColors.textSecondary,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: isBold ? FontWeight.w900 : FontWeight.w700,
            color: color ?? AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
