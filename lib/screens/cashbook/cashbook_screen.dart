import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/localization/language_provider.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';
import '../../core/utils/share_helper.dart';
import '../../models/dashboard_summary.dart';
import '../../models/transaction.dart';
import '../../repositories/dashboard_repository.dart';
import '../../repositories/transaction_repository.dart';
import '../../widgets/badge_chip.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/compact_fab.dart';
import '../transactions/payment_entry_screen.dart';

class CashbookScreen extends StatefulWidget {
  final TransactionRepository? repository;
  final DashboardRepository? dashboardRepository;

  const CashbookScreen({
    super.key,
    this.repository,
    this.dashboardRepository,
  });

  @override
  State<CashbookScreen> createState() => _CashbookScreenState();
}

class _CashbookScreenState extends State<CashbookScreen> with SingleTickerProviderStateMixin {
  late TransactionRepository _repo;
  late DashboardRepository _dashRepo;
  late TabController _moduleTabController;

  // Ledger state
  List<BusinessTransaction> _transactions = [];
  Map<String, double> _balances = {'cash': 0.0, 'bank': 0.0, 'total': 0.0};
  double _todayExpenses = 0.0;
  bool _isLoadingLedger = true;
  String _selectedTxFilter = 'all';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  // Trends & Analytics state
  DashboardSummary? _financeSummary;
  bool _isLoadingAnalytics = true;
  String _chartType = 'bar'; // 'bar' or 'line'

  final List<Map<String, String>> _txFilterOptions = [
    {'id': 'all', 'hi': 'सभी लेन-देन', 'en': 'All'},
    {'id': 'expense', 'hi': '☕ दैनिक खर्चा (चाय, भाड़ा)', 'en': 'Expenses'},
    {'id': 'supplier_payment', 'hi': '📤 पार्टी को दिया', 'en': 'Payments'},
    {'id': 'customer_receipt', 'hi': '📥 पार्टी से मिला', 'en': 'Receipts'},
  ];

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? TransactionRepository();
    _dashRepo = widget.dashboardRepository ?? DashboardRepository();
    _moduleTabController = TabController(length: 2, vsync: this);
    _moduleTabController.addListener(() {
      if (!_moduleTabController.indexIsChanging) {
        setState(() {});
      }
    });

    _loadLedgerData();
    _loadAnalyticsData();
  }

  @override
  void dispose() {
    _moduleTabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadLedgerData() async {
    setState(() => _isLoadingLedger = true);
    final txs = await _repo.getTransactions(
      type: _selectedTxFilter,
      searchQuery: _searchQuery,
    );
    final balances = await _repo.getLiquidBalances();

    final todayStr = DateFormatter.toIso(DateTime.now()).substring(0, 10);
    double todayExp = 0.0;
    try {
      final allExpenses = await _repo.getTransactions(type: 'expense');
      for (final t in allExpenses) {
        if (t.transactionDate.startsWith(todayStr)) {
          todayExp += t.amountRupees;
        }
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        _transactions = txs;
        _balances = balances;
        _todayExpenses = todayExp;
        _isLoadingLedger = false;
      });
    }
  }

  Future<void> _loadAnalyticsData() async {
    setState(() => _isLoadingAnalytics = true);
    try {
      final summary = await _dashRepo.getDashboardSummary(period: 'all');
      if (mounted) {
        setState(() {
          _financeSummary = summary;
          _isLoadingAnalytics = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingAnalytics = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          lang.isHindi ? 'गल्ला व दैनिक खर्चा' : 'Cash & Daily Kharcha',
          style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.5),
        ),
        bottom: TabBar(
          controller: _moduleTabController,
          indicatorColor: AppColors.primaryGold,
          labelColor: AppColors.goldLight,
          unselectedLabelColor: Colors.white70,
          indicatorWeight: 3.2,
          tabs: [
            Tab(
              icon: const Icon(Icons.menu_book_rounded, size: 18),
              text: lang.isHindi ? 'दैनिक रोकड़ व खर्चा' : 'Daily Cash & Kharcha',
            ),
            Tab(
              icon: const Icon(Icons.insights_rounded, size: 18),
              text: lang.isHindi ? 'मासिक चार्ट व रुझान' : '12-Mo Trends & Analytics',
            ),
          ],
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            children: [
              // 1. Finance KPI Dashboard Header
              _buildFinanceKpiDashboard(lang),

              // 2. Tab Views
              Expanded(
                child: TabBarView(
                  controller: _moduleTabController,
                  children: [
                    _buildLedgerTab(lang),
                    _buildAnalyticsTab(lang),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: CompactFab(
        heroTag: 'fab_cashbook_new_entry',
        icon: Icons.add_rounded,
        label: lang.isHindi ? 'खर्चा या भुगतान लिखें' : 'Record Kharcha / Pay',
        onTap: () async {
          final res = await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const PaymentEntryScreen()),
          );
          if (res == true) {
            _loadLedgerData();
            _loadAnalyticsData();
          }
        },
      ),
    );
  }

  // Finance KPI Dashboard Header
  Widget _buildFinanceKpiDashboard(LanguageProvider lang) {
    final cash = _balances['cash'] ?? 0.0;
    final bank = _balances['bank'] ?? 0.0;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.primaryNavy,
        border: Border(
          bottom: BorderSide(
            color: const Color(0xFFD4AF37).withValues(alpha: 0.35),
            width: 1,
          ),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Row(
        children: [
          // 1. Cash in Hand
          Expanded(
            child: _buildKpiBox(
              title: lang.isHindi ? 'दुकान गल्ला' : 'Shop Cash',
              value: CurrencyFormatter.format(cash),
              icon: Icons.payments_rounded,
              accentColor: const Color(0xFFFDE047), // Gold
            ),
          ),
          const SizedBox(width: 8),

          // 2. Bank Balance
          Expanded(
            child: _buildKpiBox(
              title: lang.isHindi ? 'बैंक / UPI खाता' : 'Bank Balance',
              value: CurrencyFormatter.format(bank),
              icon: Icons.account_balance_rounded,
              accentColor: const Color(0xFF38BDF8), // Sky Blue
            ),
          ),
          const SizedBox(width: 8),

          // 3. Today's Expenses
          Expanded(
            child: _buildKpiBox(
              title: lang.isHindi ? 'आज का खर्चा' : "Today's Kharcha",
              value: CurrencyFormatter.format(_todayExpenses),
              icon: Icons.local_cafe_rounded,
              accentColor: const Color(0xFFFCA5A5), // Rose Red
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiBox({
    required String title,
    required String value,
    required IconData icon,
    required Color accentColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accentColor.withValues(alpha: 0.35), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, size: 12, color: accentColor),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFCBD5E1),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w900,
                color: accentColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // TAB 1: Daily Ledger
  Widget _buildLedgerTab(LanguageProvider lang) {
    return Column(
      children: [
        // Search & Filter Bar
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Column(
            children: [
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: lang.isHindi
                      ? 'पार्टी नाम, खाता या विवरण खोजें...'
                      : 'Search by party name or description...',
                  prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary, size: 20),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                            _loadLedgerData();
                          },
                        )
                      : null,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.borderLight),
                  ),
                ),
                onChanged: (val) {
                  setState(() => _searchQuery = val);
                  _loadLedgerData();
                },
              ),
              const SizedBox(height: 8),

              // Tactile Filter Pills
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _txFilterOptions.map((f) {
                    final isSelected = _selectedTxFilter == f['id'];
                    Color activeAccent = const Color(0xFF0F172A);
                    if (f['id'] == 'expense') activeAccent = const Color(0xFFEA580C);
                    if (f['id'] == 'supplier_payment') activeAccent = const Color(0xFFDC2626);
                    if (f['id'] == 'customer_receipt') activeAccent = const Color(0xFF16A34A);

                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _selectedTxFilter = f['id']!);
                          _loadLedgerData();
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7.5),
                          decoration: BoxDecoration(
                            color: isSelected ? activeAccent : Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelected ? activeAccent : const Color(0xFFE2E8F0),
                              width: isSelected ? 1.4 : 1.0,
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: activeAccent.withValues(alpha: 0.30),
                                      blurRadius: 7,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.03),
                                      blurRadius: 4,
                                      offset: const Offset(0, 1),
                                    ),
                                  ],
                          ),
                          child: Text(
                            lang.isHindi ? f['hi']! : f['en']!,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                              color: isSelected ? Colors.white : const Color(0xFF475569),
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),

        // Transactions List
        Expanded(
          child: _isLoadingLedger
              ? const Center(child: CircularProgressIndicator(color: AppColors.primaryGold))
              : _transactions.isEmpty
                  ? EmptyState(
                      icon: Icons.account_balance_wallet_outlined,
                      title: lang.isHindi ? 'कोई लेन-देन नहीं मिला' : 'No Transactions',
                      message: lang.isHindi
                          ? 'इस फ़िल्टर में कोई रोकड़ या बैंक लेन-देन नहीं मिला।'
                          : 'No cash or bank transactions recorded for this filter.',
                    )
                  : RefreshIndicator(
                      color: AppColors.primaryGold,
                      onRefresh: _loadLedgerData,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(10),
                        itemCount: _transactions.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 6),
                        itemBuilder: (context, index) {
                          final tx = _transactions[index];
                          return _buildTransactionCard(tx, lang);
                        },
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _buildTransactionCard(BusinessTransaction tx, LanguageProvider lang) {
    final isCredit = tx.isCustomerReceipt || tx.isIncome || tx.transactionType == 'owner_capital';
    final isTransfer = tx.isTransfer;

    BadgeType badgeType = BadgeType.income;
    if (tx.isExpense || tx.isSupplierPayment) badgeType = BadgeType.expense;
    if (isTransfer) badgeType = BadgeType.transfer;

    String typeLabel;
    if (tx.isExpense) {
      typeLabel = tx.expenseCategory != null && tx.expenseCategory!.isNotEmpty
          ? '☕ ${tx.expenseCategory}'
          : (lang.isHindi ? '☕ दुकान खर्चा' : 'Expense');
    } else if (tx.isSupplierPayment) {
      typeLabel = lang.isHindi ? '📤 पार्टी को दिया' : 'Party Paid';
    } else if (tx.isCustomerReceipt) {
      typeLabel = lang.isHindi ? '📥 पार्टी से मिला' : 'Party Receipt';
    } else if (isTransfer) {
      typeLabel = lang.isHindi ? '🔄 ट्रांसफर' : 'Transfer';
    } else {
      typeLabel = tx.transactionType.replaceAll('_', ' ').toUpperCase();
    }

    return Card(
      elevation: 0.6,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.borderLight.withValues(alpha: 0.8)),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: isTransfer
                    ? const Color(0xFFE0F2FE)
                    : (isCredit ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2)),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isTransfer
                    ? Icons.swap_horiz_rounded
                    : (isCredit ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded),
                color: isTransfer
                    ? const Color(0xFF0369A1)
                    : (isCredit ? const Color(0xFF15803D) : const Color(0xFFB91C1C)),
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          tx.partyName ?? (tx.expenseCategory ?? tx.notes ?? (lang.isHindi ? 'व्यापारिक लेन-देन' : 'Transaction')),
                          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      BadgeChip(label: typeLabel, type: badgeType),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Text(
                        DateFormatter.format(DateFormatter.parse(tx.transactionDate)),
                        style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          tx.paymentMethod.toUpperCase(),
                          style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
                        ),
                      ),
                      if (tx.referenceNumber != null && tx.referenceNumber!.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            'Ref: ${tx.referenceNumber}',
                            style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${isCredit ? "+" : (isTransfer ? "" : "-")} ${CurrencyFormatter.format(tx.amountRupees)}',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: isTransfer
                        ? const Color(0xFF0369A1)
                        : (isCredit ? const Color(0xFF15803D) : const Color(0xFFB91C1C)),
                  ),
                ),
                const SizedBox(height: 2),
                InkWell(
                  onTap: () => _shareTxReceipt(tx, lang),
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: const EdgeInsets.all(2.0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.share_outlined, size: 12, color: Color(0xFF25D366)),
                        const SizedBox(width: 3),
                        Text(
                          lang.isHindi ? 'रसीद' : 'Receipt',
                          style: const TextStyle(fontSize: 10, color: Color(0xFF15803D), fontWeight: FontWeight.w700),
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
    );
  }

  void _shareTxReceipt(BusinessTransaction tx, LanguageProvider lang) {
    final isCredit = tx.isCustomerReceipt || tx.isIncome || tx.transactionType == 'owner_capital';
    final isHi = lang.isHindi;
    final message = isHi
        ? '''
*DM LACE SURAT*
सूरत टेक्सटाइल मार्केट
----------------------------------------
लेन-देन रसीद
प्रकार: ${isCredit ? 'जमा (Receipt)' : 'भुगतान (Payment)'}
खाता / पार्टी: ${tx.partyName ?? tx.expenseCategory ?? "नकद लेन-देन"}
तारीख: ${DateFormatter.format(DateFormatter.parse(tx.transactionDate))}
रकम: ${CurrencyFormatter.format(tx.amountRupees)}
माध्यम: ${tx.paymentMethod.toUpperCase()} ${tx.referenceNumber != null ? "(Ref: ${tx.referenceNumber})" : ""}
----------------------------------------
धन्यवाद! • DM Lace Surat
'''
        : '''
*DM LACE SURAT*
Surat Textile Market
----------------------------------------
Transaction Receipt
Type: ${isCredit ? 'Receipt' : 'Payment'}
Account / Party: ${tx.partyName ?? tx.expenseCategory ?? "Cash Transaction"}
Date: ${DateFormatter.format(DateFormatter.parse(tx.transactionDate))}
Amount: ${CurrencyFormatter.format(tx.amountRupees)}
Mode: ${tx.paymentMethod.toUpperCase()} ${tx.referenceNumber != null ? "(Ref: ${tx.referenceNumber})" : ""}
----------------------------------------
Thank You! • DM Lace Surat
''';

    ShareHelper.shareText(message, subject: 'Payment Receipt - ${tx.partyName ?? "DM Lace"}');
  }

  // TAB 2: 12-Month Trends & Analytics
  Widget _buildAnalyticsTab(LanguageProvider lang) {
    if (_isLoadingAnalytics) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primaryGold));
    }

    final trends = _financeSummary?.monthlyTrends ?? [];
    if (trends.isEmpty) {
      return EmptyState(
        icon: Icons.insights_rounded,
        title: lang.isHindi ? 'पर्याप्त डेटा उपलब्ध नहीं' : 'No Trend Data Yet',
        message: lang.isHindi
            ? 'बिल और भुगतान प्रविष्टियां करने के बाद यहाँ 12 महीने का वित्तीय ग्राफ़ दिखेगा।'
            : 'Record bills and payments to visualize 12-month financial trends here.',
      );
    }

    final totalSales = trends.fold<double>(0, (sum, p) => sum + p.sales);
    final totalReceipts = trends.fold<double>(0, (sum, p) => sum + p.receipts);
    final recoveryPct = totalSales > 0 ? ((totalReceipts / totalSales) * 100).toStringAsFixed(1) : '0';

    double maxY = 10000;
    for (final t in trends) {
      if (t.sales > maxY) maxY = t.sales;
      if (t.receipts > maxY) maxY = t.receipts;
    }
    maxY = maxY * 1.15;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Chart Card
          Card(
            color: Colors.white,
            elevation: 1.0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: AppColors.borderLight, width: 0.8),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14.0),
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
                              color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.analytics_rounded, color: Color(0xFF2563EB), size: 18),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                lang.isHindi ? '12-माह बिक्री बनाम वसूली' : '12-Mo Sales vs Recovery',
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                              ),
                              Text(
                                lang.isHindi ? 'मासिक वित्तीय प्रदर्शन' : 'Monthly Financial Performance',
                                style: const TextStyle(fontSize: 10.5, color: AppColors.textMuted),
                              ),
                            ],
                          ),
                        ],
                      ),
                      // Bar / Line toggle
                      Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildTogglePill('बार (Bar)', 'bar'),
                            _buildTogglePill('कर्व (Curve)', 'line'),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Summary Badges
                  Row(
                    children: [
                      _buildMetricBadge(
                        label: lang.isHindi ? 'कुल बिक्री' : 'Sales',
                        value: CurrencyFormatter.formatCompact(totalSales),
                        color: const Color(0xFF2563EB),
                        bgColor: const Color(0xFFEFF6FF),
                      ),
                      const SizedBox(width: 6),
                      _buildMetricBadge(
                        label: lang.isHindi ? 'कुल वसूली' : 'Receipts',
                        value: CurrencyFormatter.formatCompact(totalReceipts),
                        color: const Color(0xFF10B981),
                        bgColor: const Color(0xFFECFDF5),
                      ),
                      const SizedBox(width: 6),
                      _buildMetricBadge(
                        label: lang.isHindi ? 'वसूली दर' : 'Recovery',
                        value: '$recoveryPct%',
                        color: const Color(0xFF8B5CF6),
                        bgColor: const Color(0xFFF5F3FF),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Chart Canvas
                  SizedBox(
                    height: 200,
                    child: _chartType == 'bar'
                        ? _buildBarChart(trends, maxY, lang)
                        : _buildLineChart(trends, maxY, lang),
                  ),
                  const SizedBox(height: 10),

                  // Legend
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildLegendDot(lang.isHindi ? 'बिक्री (Sales)' : 'Sales', const Color(0xFF2563EB)),
                      const SizedBox(width: 16),
                      _buildLegendDot(lang.isHindi ? 'वसूली (Receipts)' : 'Receipts', const Color(0xFF10B981)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Monthly Breakdown Table
          Card(
            color: Colors.white,
            elevation: 1.0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: AppColors.borderLight, width: 0.8),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lang.isHindi ? '📋 महीना-दर-महीना विवरण' : '📋 Month-by-Month Statement',
                    style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 8),
                  const Divider(height: 1),
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: trends.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, idx) {
                      final item = trends[idx];
                      final mPct = item.sales > 0 ? ((item.receipts / item.sales) * 100).toStringAsFixed(0) : '—';

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: Text(
                                item.month,
                                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                              ),
                            ),
                            Expanded(
                              flex: 4,
                              child: Text(
                                'बिक्री: ${CurrencyFormatter.formatCompact(item.sales)}',
                                style: const TextStyle(fontSize: 11.5, color: Color(0xFF2563EB), fontWeight: FontWeight.w700),
                              ),
                            ),
                            Expanded(
                              flex: 4,
                              child: Text(
                                'जमा: ${CurrencyFormatter.formatCompact(item.receipts)}',
                                style: const TextStyle(fontSize: 11.5, color: Color(0xFF10B981), fontWeight: FontWeight.w700),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '$mPct%',
                                style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: AppColors.textSecondary),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTogglePill(String label, String key) {
    final isSelected = _chartType == key;
    return InkWell(
      onTap: () {
        if (_chartType != key) {
          setState(() => _chartType = key);
        }
      },
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          boxShadow: isSelected
              ? [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 4)]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected ? AppColors.primaryNavy : AppColors.textMuted,
          ),
        ),
      ),
    );
  }

  Widget _buildMetricBadge({
    required String label,
    required String value,
    required Color color,
    required Color bgColor,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: 0.25), width: 0.8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 9.5, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
            Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendDot(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
      ],
    );
  }

  Widget _buildBarChart(List<MonthlyTrendPoint> trends, double maxY, LanguageProvider lang) {
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxY,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final month = trends[group.x.toInt()].month;
              final isSales = rodIndex == 0;
              final label = isSales ? 'बिक्री' : 'जमा';
              return BarTooltipItem(
                '$month\n$label: ₹${rod.toY.toInt()}',
                const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (val, meta) {
                final idx = val.toInt();
                if (idx >= 0 && idx < trends.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      trends[idx].month,
                      style: const TextStyle(fontSize: 9.5, color: AppColors.textMuted, fontWeight: FontWeight.w600),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        barGroups: trends.asMap().entries.map((e) {
          return BarChartGroupData(
            x: e.key,
            barRods: [
              BarChartRodData(
                toY: e.value.sales,
                color: const Color(0xFF2563EB),
                width: 7,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
              ),
              BarChartRodData(
                toY: e.value.receipts,
                color: const Color(0xFF10B981),
                width: 7,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildLineChart(List<MonthlyTrendPoint> trends, double maxY, LanguageProvider lang) {
    return LineChart(
      LineChartData(
        maxY: maxY,
        minY: 0,
        gridData: const FlGridData(show: false),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (val, meta) {
                final idx = val.toInt();
                if (idx >= 0 && idx < trends.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      trends[idx].month,
                      style: const TextStyle(fontSize: 9.5, color: AppColors.textMuted, fontWeight: FontWeight.w600),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: trends.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.sales)).toList(),
            isCurved: true,
            color: const Color(0xFF2563EB),
            barWidth: 2.5,
            dotData: const FlDotData(show: true),
          ),
          LineChartBarData(
            spots: trends.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.receipts)).toList(),
            isCurved: true,
            color: const Color(0xFF10B981),
            barWidth: 2.5,
            dotData: const FlDotData(show: true),
          ),
        ],
      ),
    );
  }
}
