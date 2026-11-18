import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/localization/language_provider.dart';
import '../../core/security/privacy_provider.dart';
import '../../core/security/auth_service.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/share_helper.dart';
import '../../models/dashboard_summary.dart';
import '../../repositories/dashboard_repository.dart';
import '../cashbook/cashbook_screen.dart';
import '../parties/parties_list_screen.dart';

class DashboardScreen extends StatefulWidget {
  final DashboardSummary summary;
  final VoidCallback? onNewBill;
  final VoidCallback? onNewChallan;
  final VoidCallback? onNewPayment;
  final VoidCallback? onViewParties;
  final VoidCallback? onViewOverdue;
  final VoidCallback? onRefresh;

  const DashboardScreen({
    super.key,
    required this.summary,
    this.onNewBill,
    this.onNewChallan,
    this.onNewPayment,
    this.onViewParties,
    this.onViewOverdue,
    this.onRefresh,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String _selectedPeriod = 'today';
  DashboardSummary? _currentSummary;
  bool _isLoadingPeriod = false;
  final DashboardRepository _dashboardRepo = DashboardRepository();

  // Interactive Business Graph state
  String _graphTimeframe = 'monthly'; // 'monthly', 'weekly'
  String _graphMetric = 'both'; // 'both', 'sales', 'receipts'
  String _graphChartType = 'bar'; // 'bar', 'line'

  String _userName = '';

  DashboardSummary get currentSummary => _currentSummary ?? widget.summary;

  @override
  void initState() {
    super.initState();
    _currentSummary = widget.summary;
    _loadUserName();
    _loadPeriodSummary(_selectedPeriod);
  }

  Future<void> _loadUserName() async {
    final name = AuthService.currentUserName;
    if (mounted && name.isNotEmpty && name != 'User') {
      setState(() => _userName = name);
    }
    final user = await AuthService.getCurrentUser();
    if (mounted && user != null && user['name'] != null) {
      final freshName = user['name'] as String;
      if (freshName.isNotEmpty && freshName != _userName) {
        setState(() => _userName = freshName);
      }
    }
  }

  @override
  void didUpdateWidget(covariant DashboardScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _loadUserName();
    if (oldWidget.summary != widget.summary) {
      _currentSummary = widget.summary;
    }
    _loadPeriodSummary(_selectedPeriod);
  }

  Future<void> _loadPeriodSummary(String period) async {
    setState(() => _isLoadingPeriod = true);
    try {
      final updated = await _dashboardRepo.getDashboardSummary(period: period);
      if (mounted) {
        setState(() {
          _currentSummary = updated;
          _isLoadingPeriod = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingPeriod = false);
    }
  }

  void _shareTransaction(RecentActivityItem item, LanguageProvider lang) {
    final isHi = lang.isHindi;
    final message = isHi
        ? '''
*DM LACE SURAT*
सूरत टेक्सटाइल मार्केट
----------------------------------------
लेन-देन रसीद
प्रकार: ${item.isCredit ? 'जमा (Receipt)' : 'भुगतान (Payment)'}
खाता / पार्टी: ${item.title}
तारीख: ${item.subtitle}
रकम: ₹ ${CurrencyFormatter.format(item.amount)}
माध्यम: ${item.badge}
----------------------------------------
धन्यवाद! • DM Lace Surat
'''
        : '''
*DM LACE SURAT*
Surat Textile Market
----------------------------------------
Transaction Receipt
Type: ${item.isCredit ? 'Receipt' : 'Payment'}
Account / Party: ${item.title}
Date: ${item.subtitle}
Amount: ₹ ${CurrencyFormatter.format(item.amount)}
Mode: ${item.badge}
----------------------------------------
Thank You! • DM Lace Surat
''';

    ShareHelper.shareText(
      message,
      subject: 'DM Lace Surat Transaction Receipt',
    );
  }

  void _openCashbook() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const CashbookScreen()),
    );
  }

  void _openParties() {
    if (widget.onViewParties != null) {
      widget.onViewParties!();
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const PartiesListScreen()),
      );
    }
  }

  void _showUserProfileSheet(BuildContext sheetContext, LanguageProvider lang) async {
    final user = await AuthService.getCurrentUser();
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final name = (user?['name'] as String? ?? _userName).trim();
        final email = user?['email'] as String? ?? '';
        final shop = user?['shop_name'] as String? ?? 'DM LACE SURAT';
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          decoration: const BoxDecoration(
            color: Color(0xFF0F172A),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(top: BorderSide(color: Color(0xFFD4AF37), width: 1.5)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFF475569),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFDE047), Color(0xFFD4AF37)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFD4AF37).withValues(alpha: 0.45),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : 'U',
                      style: const TextStyle(
                        color: Color(0xFF0F172A),
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Icon(
                              Icons.verified_rounded,
                              size: 16,
                              color: Color(0xFF38BDF8),
                            ),
                          ],
                        ),
                        if (email.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            email,
                            style: const TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 12.5,
                            ),
                          ),
                        ],
                        const SizedBox(height: 2),
                        Text(
                          shop,
                          style: const TextStyle(
                            color: Color(0xFFFDE047),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_rounded, size: 16, color: Color(0xFF22C55E)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        lang.isHindi ? 'सक्रिय बहीखाता सत्र • 100% सुरक्षित' : 'Active Ledger Session • 100% Secure',
                        style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final privacy = context.watch<PrivacyProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: Column(
        children: [
          // 1. Executive Fixed Top Navbar
          _buildExecutiveNavbar(lang),

          // 2. Main Executive Body
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                widget.onRefresh?.call();
                await _loadPeriodSummary(_selectedPeriod);
              },
              color: AppColors.primaryGold,
              backgroundColor: AppColors.primaryNavy,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 30),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1200),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Period Filter Pills
                        _buildPeriodFilterChips(lang),
                        const SizedBox(height: 12),

                        // Executive Hero Liquidity & Profit Overview Card
                        _buildExecutiveHeroCard(lang, privacy),
                        const SizedBox(height: 16),

                        // Interactive Business Graph & Trend Analytics Card
                        _buildBusinessGraphCard(lang),
                        const SizedBox(height: 16),

                        // Recent Activity Feed
                        if (currentSummary.recentActivities.isNotEmpty) ...[
                          _buildRecentTransactionsFeed(context, lang),
                          const SizedBox(height: 16),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Executive Top Navbar
  Widget _buildExecutiveNavbar(LanguageProvider lang) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF030713),
            Color(0xFF091830),
            Color(0xFF0E2244),
          ],
        ),
        border: Border(
          bottom: BorderSide(
            color: const Color(0xFFD4AF37).withValues(alpha: 0.45),
            width: 1.2,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: SafeArea(
        bottom: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Brand Logo & Title
            Expanded(
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF040A14),
                      border: Border.all(color: const Color(0xFFD4AF37), width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFD4AF37).withValues(alpha: 0.40),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: Padding(
                        padding: const EdgeInsets.all(2.5),
                        child: Image.asset(
                          'assets/images/dm_lace_logo.png',
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) => const Icon(
                            Icons.workspace_premium_rounded,
                            color: Color(0xFFFDE047),
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'DM LACE SURAT',
                          style: TextStyle(
                            color: Color(0xFFFDE047),
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2.5),
                        InkWell(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            _showUserProfileSheet(context, lang);
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFF0F2342),
                                  Color(0xFF08162B),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: const Color(0xFFD4AF37).withValues(alpha: 0.40),
                                width: 0.85,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.35),
                                  blurRadius: 4,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 14,
                                  height: 14,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFFFDE047), Color(0xFFD4AF37)],
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFFD4AF37).withValues(alpha: 0.45),
                                        blurRadius: 3,
                                      ),
                                    ],
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    (_userName.isNotEmpty ? _userName[0] : (lang.isHindi ? 'व' : 'U')).toUpperCase(),
                                    style: const TextStyle(
                                      color: Color(0xFF0A1629),
                                      fontSize: 8.5,
                                      fontWeight: FontWeight.w900,
                                      height: 1.1,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Flexible(
                                  child: Text(
                                    _userName.isNotEmpty
                                        ? _userName
                                        : (lang.isHindi ? 'व्यापारी' : 'Owner'),
                                    style: const TextStyle(
                                      color: Color(0xFFF8FAFC),
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.25,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(
                                  Icons.verified_rounded,
                                  size: 11.5,
                                  color: Color(0xFF38BDF8),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),

            // Right: Live Surat Timepiece
            StreamBuilder<DateTime>(
              stream: Stream.periodic(const Duration(seconds: 1), (_) => DateTime.now()),
              initialData: DateTime.now(),
              builder: (context, snapshot) {
                final now = snapshot.data ?? DateTime.now();
                final hour = now.hour == 0 ? 12 : (now.hour > 12 ? now.hour - 12 : now.hour);
                final minute = now.minute.toString().padLeft(2, '0');
                final period = now.hour >= 12 ? 'PM' : 'AM';
                final timeStr = '${hour.toString().padLeft(2, '0')}:$minute $period';

                const enMonths = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
                final monthStr = enMonths[now.month - 1];
                final dayStr = now.day.toString().padLeft(2, '0');
                final dateStr = '$dayStr $monthStr';

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4.5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF14243D).withValues(alpha: 0.90),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFD4AF37).withValues(alpha: 0.50), width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.access_time_filled_rounded, size: 12, color: Color(0xFFFDE047)),
                      const SizedBox(width: 5),
                      Text(
                        '$timeStr • $dateStr',
                        style: const TextStyle(
                          color: Color(0xFFFFFBEB),
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.4,
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
    );
  }

  // Period Filter Chips
  Widget _buildPeriodFilterChips(LanguageProvider lang) {
    final periods = [
      {'id': 'today', 'label': lang.isHindi ? 'आज' : 'Today'},
      {'id': 'week', 'label': lang.isHindi ? 'इस हफ्ते' : 'This Week'},
      {'id': 'month', 'label': lang.isHindi ? 'इस महीने' : 'This Month'},
      {'id': 'all', 'label': lang.isHindi ? 'कुल हिसाब' : 'All Time'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: periods.map((p) {
              final isSelected = _selectedPeriod == p['id'];
              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: GestureDetector(
                  onTap: () {
                    if (!isSelected) {
                      HapticFeedback.selectionClick();
                      setState(() => _selectedPeriod = p['id']!);
                      _loadPeriodSummary(p['id']!);
                    }
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 7.5),
                    decoration: BoxDecoration(
                      gradient: isSelected
                          ? const LinearGradient(
                              colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : null,
                      color: isSelected ? null : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected ? const Color(0xFFD4AF37) : const Color(0xFFE2E8F0),
                        width: isSelected ? 1.4 : 1.0,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: const Color(0xFF0F172A).withValues(alpha: 0.25),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                              BoxShadow(
                                color: const Color(0xFFD4AF37).withValues(alpha: 0.18),
                                blurRadius: 6,
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
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isSelected) ...[
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xFFFDE047),
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        Text(
                          p['label']!,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                            color: isSelected ? const Color(0xFFFDE047) : const Color(0xFF64748B),
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        if (_isLoadingPeriod) ...[
          const SizedBox(height: 4),
          const LinearProgressIndicator(minHeight: 2, color: AppColors.primaryGold, backgroundColor: Colors.transparent),
        ],
      ],
    );
  }

  // Executive Hero Liquidity & Profit Card
  Widget _buildExecutiveHeroCard(LanguageProvider lang, PrivacyProvider privacy) {
    final netLiquidFunds = currentSummary.cashBalance + currentSummary.bankBalance;

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF030712), // Midnight Obsidian
            Color(0xFF081426), // Royal Sapphire Deep
            Color(0xFF0D223F), // Deep Velvet Navy
            Color(0xFF050B14), // Pure Slate Void
          ],
          stops: [0.0, 0.30, 0.70, 1.0],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFD4AF37).withValues(alpha: 0.65),
          width: 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.55),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: const Color(0xFFD4AF37).withValues(alpha: 0.16),
            blurRadius: 14,
            spreadRadius: 1,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            // Ambient Radial Golden Specular Glow - Top Right
            Positioned(
              top: -30,
              right: -30,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFFD4AF37).withValues(alpha: 0.22),
                      const Color(0xFF0284C7).withValues(alpha: 0.08),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            // Ambient Emerald Glow - Bottom Left
            Positioned(
              bottom: -35,
              left: -35,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF10B981).withValues(alpha: 0.15),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            // Main Content
            Padding(
              padding: const EdgeInsets.all(15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Top Header: Title, Live Pulse Dot, and Privacy Toggle
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFFF59E0B), Color(0xFFB45309)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFF59E0B).withValues(alpha: 0.4),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 16),
                            ),
                            const SizedBox(width: 9),
                            Expanded(
                              child: Text(
                                lang.isHindi ? 'हिसाब' : 'Overview',
                                style: const TextStyle(
                                  color: Color(0xFFFDE68A),
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.3,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Privacy Toggle Button
                      InkWell(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          privacy.togglePrivacyMode();
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4.5),
                          decoration: BoxDecoration(
                            color: privacy.isPrivacyMode
                                ? const Color(0xFFD4AF37).withValues(alpha: 0.25)
                                : Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: privacy.isPrivacyMode
                                  ? const Color(0xFFFDE047)
                                  : const Color(0xFFD4AF37).withValues(alpha: 0.45),
                              width: 0.9,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                privacy.isPrivacyMode ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                                size: 13,
                                color: const Color(0xFFFDE047),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                privacy.isPrivacyMode
                                    ? (lang.isHindi ? 'छिपा' : 'Hidden')
                                    : (lang.isHindi ? 'प्राइवेसी' : 'Privacy'),
                                style: TextStyle(
                                  color: privacy.isPrivacyMode ? const Color(0xFFFDE047) : Colors.white,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // 2. Executive Hero Figure: Total Liquidity & Profit
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Total Available Liquid Funds (रोकड़ + बैंक)
                      Expanded(
                        flex: 6,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.flash_on_rounded, size: 12, color: Color(0xFF38BDF8)),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    lang.isHindi ? 'कुल नकद' : 'Total Cash',
                                    style: const TextStyle(
                                      color: Color(0xFF94A3B8),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.2,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                CurrencyFormatter.formatWithPrivacy(netLiquidFunds, isPrivacyMode: privacy.isPrivacyMode),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 26,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.6,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),

                      // Net Margin / Estimated Profit
                      Expanded(
                        flex: 5,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Color(0xFF064E3B),
                                Color(0xFF042F2E),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFF2DD4BF).withValues(alpha: 0.45),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF059669).withValues(alpha: 0.18),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(2.5),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF10B981).withValues(alpha: 0.25),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.trending_up_rounded, size: 12, color: Color(0xFF5EEAD4)),
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      lang.isHindi ? 'बचत' : 'Net Profit',
                                      style: const TextStyle(
                                        color: Color(0xFF5EEAD4),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                      ),
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
                                  CurrencyFormatter.formatWithPrivacy(currentSummary.estimatedProfit, isPrivacyMode: privacy.isPrivacyMode),
                                  style: const TextStyle(
                                    color: Color(0xFFFDE047),
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Golden Hairline Divider
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 12),
                    height: 1,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          const Color(0xFFD4AF37).withValues(alpha: 0.4),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),

                  // 3. Dual Liquid Split Cards (Cash vs Bank) - 1-Tap Tappable
                  Row(
                    children: [
                      // Cash in Hand
                      Expanded(
                        child: InkWell(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            _openCashbook();
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF78350F).withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFFF59E0B).withValues(alpha: 0.35),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.payments_rounded, size: 15, color: Color(0xFFFDE047)),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        lang.isHindi ? 'दुकान गल्ला' : 'Shop Cash',
                                        style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 10.5, fontWeight: FontWeight.w700),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        CurrencyFormatter.formatWithPrivacy(currentSummary.cashBalance, isPrivacyMode: privacy.isPrivacyMode),
                                        style: const TextStyle(color: Color(0xFFFFFBEB), fontSize: 13.5, fontWeight: FontWeight.w900),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Bank Balance
                      Expanded(
                        child: InkWell(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            _openCashbook();
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0369A1).withValues(alpha: 0.22),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFF38BDF8).withValues(alpha: 0.35),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF38BDF8).withValues(alpha: 0.2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.account_balance_rounded, size: 15, color: Color(0xFF7DD3FC)),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        lang.isHindi ? 'बैंक खाता (UPI)' : 'Bank / UPI',
                                        style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 10.5, fontWeight: FontWeight.w700),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        CurrencyFormatter.formatWithPrivacy(currentSummary.bankBalance, isPrivacyMode: privacy.isPrivacyMode),
                                        style: const TextStyle(color: Color(0xFFFFFBEB), fontSize: 13.5, fontWeight: FontWeight.w900),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // 4. Market Khata Status: Receivables vs Payables (1-Tap Tappable)
                  Row(
                    children: [
                      // Market Receivables (बाज़ार से लेना)
                      Expanded(
                        child: InkWell(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            _openParties();
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF065F46).withValues(alpha: 0.22),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFF10B981).withValues(alpha: 0.35),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981).withValues(alpha: 0.2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.arrow_downward_rounded, size: 15, color: Color(0xFF4ADE80)),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        lang.isHindi ? 'मार्केट लेना' : 'Market Dues',
                                        style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 10.5, fontWeight: FontWeight.w700),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        CurrencyFormatter.formatWithPrivacy(currentSummary.totalReceivables, isPrivacyMode: privacy.isPrivacyMode),
                                        style: const TextStyle(color: Color(0xFF4ADE80), fontSize: 13.5, fontWeight: FontWeight.w900),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Supplier Payables (सप्लायर को देना)
                      Expanded(
                        child: InkWell(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            _openParties();
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF991B1B).withValues(alpha: 0.22),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFFF87171).withValues(alpha: 0.35),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEF4444).withValues(alpha: 0.2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.arrow_upward_rounded, size: 15, color: Color(0xFFF87171)),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        lang.isHindi ? 'सप्लायर देना' : 'Supplier Dues',
                                        style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 10.5, fontWeight: FontWeight.w700),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        CurrencyFormatter.formatWithPrivacy(currentSummary.totalPayables, isPrivacyMode: privacy.isPrivacyMode),
                                        style: const TextStyle(color: Color(0xFFF87171), fontSize: 13.5, fontWeight: FontWeight.w900),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // 5. Period Trading Flow Strip (बिक्री, जमा, भुगतान)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.08), width: 0.8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.shopping_bag_outlined, size: 12, color: Color(0xFF93C5FD)),
                            const SizedBox(width: 4),
                            Text(
                              '${lang.isHindi ? "बिक्री:" : "Sales:"} ${CurrencyFormatter.formatWithPrivacy(currentSummary.todaySales, isPrivacyMode: privacy.isPrivacyMode)}',
                              style: const TextStyle(color: Color(0xFFE2E8F0), fontSize: 11, fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            const Icon(Icons.call_received_rounded, size: 12, color: Color(0xFF86EFAC)),
                            const SizedBox(width: 4),
                            Text(
                              '${lang.isHindi ? "आया (जमा):" : "Received:"} ${CurrencyFormatter.formatWithPrivacy(currentSummary.todayReceipts, isPrivacyMode: privacy.isPrivacyMode)}',
                              style: const TextStyle(color: Color(0xFF86EFAC), fontSize: 11, fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            const Icon(Icons.call_made_rounded, size: 12, color: Color(0xFFFCA5A5)),
                            const SizedBox(width: 4),
                            Text(
                              '${lang.isHindi ? "गया (खर्च):" : "Paid:"} ${CurrencyFormatter.formatWithPrivacy(currentSummary.todayPayments, isPrivacyMode: privacy.isPrivacyMode)}',
                              style: const TextStyle(color: Color(0xFFFCA5A5), fontSize: 11, fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Interactive Business Graph Card (Monthly / Weekly & Sales / Receipts)
  Widget _buildBusinessGraphCard(LanguageProvider lang) {
    final rawTrends = _graphTimeframe == 'monthly'
        ? currentSummary.monthlyTrends
        : currentSummary.weeklyTrends;

    final displayTrends = rawTrends.isNotEmpty
        ? rawTrends
        : (_graphTimeframe == 'monthly'
            ? (lang.isHindi
                ? const [
                    MonthlyTrendPoint(month: 'मई', sales: 0, receipts: 0),
                    MonthlyTrendPoint(month: 'जून', sales: 0, receipts: 0),
                    MonthlyTrendPoint(month: 'जुलाई', sales: 0, receipts: 0),
                    MonthlyTrendPoint(month: 'अगस्त', sales: 0, receipts: 0),
                    MonthlyTrendPoint(month: 'सितम्बर', sales: 0, receipts: 0),
                    MonthlyTrendPoint(month: 'अक्टूबर', sales: 0, receipts: 0),
                  ]
                : const [
                    MonthlyTrendPoint(month: 'May', sales: 0, receipts: 0),
                    MonthlyTrendPoint(month: 'Jun', sales: 0, receipts: 0),
                    MonthlyTrendPoint(month: 'Jul', sales: 0, receipts: 0),
                    MonthlyTrendPoint(month: 'Aug', sales: 0, receipts: 0),
                    MonthlyTrendPoint(month: 'Sep', sales: 0, receipts: 0),
                    MonthlyTrendPoint(month: 'Oct', sales: 0, receipts: 0),
                  ])
            : (lang.isHindi
                ? const [
                    MonthlyTrendPoint(month: 'सोम', sales: 0, receipts: 0),
                    MonthlyTrendPoint(month: 'मंगल', sales: 0, receipts: 0),
                    MonthlyTrendPoint(month: 'बुध', sales: 0, receipts: 0),
                    MonthlyTrendPoint(month: 'गुरु', sales: 0, receipts: 0),
                    MonthlyTrendPoint(month: 'शुक्र', sales: 0, receipts: 0),
                    MonthlyTrendPoint(month: 'शनि', sales: 0, receipts: 0),
                    MonthlyTrendPoint(month: 'रवि', sales: 0, receipts: 0),
                  ]
                : const [
                    MonthlyTrendPoint(month: 'Mon', sales: 0, receipts: 0),
                    MonthlyTrendPoint(month: 'Tue', sales: 0, receipts: 0),
                    MonthlyTrendPoint(month: 'Wed', sales: 0, receipts: 0),
                    MonthlyTrendPoint(month: 'Thu', sales: 0, receipts: 0),
                    MonthlyTrendPoint(month: 'Fri', sales: 0, receipts: 0),
                    MonthlyTrendPoint(month: 'Sat', sales: 0, receipts: 0),
                    MonthlyTrendPoint(month: 'Sun', sales: 0, receipts: 0),
                  ]));

    final totalSales = displayTrends.fold<double>(0, (sum, p) => sum + p.sales);
    final totalReceipts = displayTrends.fold<double>(0, (sum, p) => sum + p.receipts);
    final recoveryPct = totalSales > 0 ? ((totalReceipts / totalSales) * 100).toStringAsFixed(1) : '0';

    double maxY = 1000.0;
    for (final t in displayTrends) {
      if (_graphMetric == 'both' || _graphMetric == 'sales') {
        if (t.sales > maxY) maxY = t.sales;
      }
      if (_graphMetric == 'both' || _graphMetric == 'receipts') {
        if (t.receipts > maxY) maxY = t.receipts;
      }
    }
    maxY = maxY * 1.20;

    return Card(
      color: Colors.white,
      elevation: 1.0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.borderLight, width: 0.9),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Header with Icon, Title, and Bar/Curve toggle
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.insights_rounded, color: Color(0xFF2563EB), size: 18),
                    ),
                    const SizedBox(width: 9),
                    Text(
                      lang.isHindi ? 'रुझान' : 'Trends',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                    ),
                  ],
                ),
                // Chart Type Toggle (Bar vs Curve)
                Container(
                  padding: const EdgeInsets.all(3.0),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildGraphTogglePill('', 'bar', _graphChartType, (val) => setState(() => _graphChartType = val), icon: Icons.bar_chart_rounded),
                      const SizedBox(width: 2),
                      _buildGraphTogglePill('', 'line', _graphChartType, (val) => setState(() => _graphChartType = val), icon: Icons.show_chart_rounded),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 2. Dual Controls: Timeframe (Monthly/Weekly) & Metric Filter (Both/Sale/Receipt)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                // Timeframe Selector: Monthly / Weekly
                Container(
                  padding: const EdgeInsets.all(3.0),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildGraphTogglePill(
                        lang.isHindi ? 'मासिक' : 'Monthly',
                        'monthly',
                        _graphTimeframe,
                        (val) => setState(() => _graphTimeframe = val),
                        icon: Icons.calendar_month_rounded,
                      ),
                      const SizedBox(width: 3),
                      _buildGraphTogglePill(
                        lang.isHindi ? 'साप्ताहिक' : 'Weekly',
                        'weekly',
                        _graphTimeframe,
                        (val) => setState(() => _graphTimeframe = val),
                        icon: Icons.date_range_rounded,
                      ),
                    ],
                  ),
                ),

                // Metric Filter: Both / Sales / Receipts
                Container(
                  padding: const EdgeInsets.all(3.0),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildGraphTogglePill(
                        lang.isHindi ? 'दोनों' : 'Both',
                        'both',
                        _graphMetric,
                        (val) => setState(() => _graphMetric = val),
                        activeColor: const Color(0xFF0F172A),
                        icon: Icons.swap_vert_rounded,
                      ),
                      const SizedBox(width: 3),
                      _buildGraphTogglePill(
                        lang.isHindi ? 'बिक्री' : 'Sales',
                        'sales',
                        _graphMetric,
                        (val) => setState(() => _graphMetric = val),
                        activeColor: const Color(0xFF2563EB),
                        icon: Icons.trending_up_rounded,
                      ),
                      const SizedBox(width: 3),
                      _buildGraphTogglePill(
                        lang.isHindi ? 'वसूली' : 'Receipts',
                        'receipts',
                        _graphMetric,
                        (val) => setState(() => _graphMetric = val),
                        activeColor: const Color(0xFF10B981),
                        icon: Icons.check_circle_outline_rounded,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 3. Summary Metric Badges
            Row(
              children: [
                if (_graphMetric == 'both' || _graphMetric == 'sales') ...[
                  Expanded(
                    child: _buildGraphMetricBadge(
                      label: lang.isHindi ? 'कुल बिक्री' : 'Sales',
                      value: CurrencyFormatter.formatCompact(totalSales),
                      color: const Color(0xFF2563EB),
                      bgColor: const Color(0xFFEFF6FF),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                if (_graphMetric == 'both' || _graphMetric == 'receipts') ...[
                  Expanded(
                    child: _buildGraphMetricBadge(
                      label: lang.isHindi ? 'कुल वसूली' : 'Receipts',
                      value: CurrencyFormatter.formatCompact(totalReceipts),
                      color: const Color(0xFF10B981),
                      bgColor: const Color(0xFFECFDF5),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                if (_graphMetric == 'both')
                  Expanded(
                    child: _buildGraphMetricBadge(
                      label: lang.isHindi ? 'वसूली दर' : 'Recovery',
                      value: '$recoveryPct%',
                      color: const Color(0xFF8B5CF6),
                      bgColor: const Color(0xFFF5F3FF),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),

            // 4. Chart Canvas
            SizedBox(
              height: 190,
              child: _graphChartType == 'bar'
                  ? _buildBarChart(displayTrends, maxY, lang)
                  : _buildLineChart(displayTrends, maxY, lang),
            ),
            const SizedBox(height: 10),

            // 5. Legend
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_graphMetric == 'both' || _graphMetric == 'sales')
                  _buildGraphLegendDot(lang.isHindi ? 'बिक्री (Sales)' : 'Sales', const Color(0xFF2563EB)),
                if (_graphMetric == 'both')
                  const SizedBox(width: 18),
                if (_graphMetric == 'both' || _graphMetric == 'receipts')
                  _buildGraphLegendDot(lang.isHindi ? 'वसूली / जमा (Receipts)' : 'Receipts', const Color(0xFF10B981)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGraphTogglePill(
    String label,
    String value,
    String currentValue,
    ValueChanged<String> onChanged, {
    Color? activeColor,
    IconData? icon,
  }) {
    final isSelected = value == currentValue;
    final color = activeColor ?? const Color(0xFF0F172A);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onChanged(value);
        },
        borderRadius: BorderRadius.circular(9),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: EdgeInsets.symmetric(
            horizontal: label.isEmpty ? 8 : 11,
            vertical: 6.5,
          ),
          decoration: BoxDecoration(
            color: isSelected
                ? (activeColor != null ? color : Colors.white)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: activeColor != null
                          ? color.withValues(alpha: 0.35)
                          : Colors.black.withValues(alpha: 0.08),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 14,
                  color: isSelected
                      ? (activeColor != null ? Colors.white : color)
                      : const Color(0xFF64748B),
                ),
                if (label.isNotEmpty) const SizedBox(width: 5),
              ],
              if (label.isNotEmpty)
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                    color: isSelected
                        ? (activeColor != null ? Colors.white : color)
                        : const Color(0xFF64748B),
                    letterSpacing: 0.2,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGraphMetricBadge({
    required String label,
    required String value,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: color),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildGraphLegendDot(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color),
        ),
      ],
    );
  }

  Widget _buildBarChart(List<MonthlyTrendPoint> trends, double maxY, LanguageProvider lang) {
    final showSales = _graphMetric == 'both' || _graphMetric == 'sales';
    final showReceipts = _graphMetric == 'both' || _graphMetric == 'receipts';

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxY,
        minY: 0,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final idx = group.x.toInt();
              if (idx < 0 || idx >= trends.length) return null;
              final label = trends[idx].month;
              String rodLabel;
              if (_graphMetric == 'sales') {
                rodLabel = lang.isHindi ? 'बिक्री' : 'Sales';
              } else if (_graphMetric == 'receipts') {
                rodLabel = lang.isHindi ? 'वसूली' : 'Receipts';
              } else {
                rodLabel = rodIndex == 0 ? (lang.isHindi ? 'बिक्री' : 'Sales') : (lang.isHindi ? 'वसूली' : 'Receipts');
              }
              return BarTooltipItem(
                '$label\n$rodLabel: ₹${CurrencyFormatter.format(rod.toY)}',
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
                      style: const TextStyle(fontSize: 9.5, color: AppColors.textMuted, fontWeight: FontWeight.w700),
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
          final rods = <BarChartRodData>[];
          if (showSales) {
            rods.add(
              BarChartRodData(
                toY: e.value.sales,
                color: const Color(0xFF2563EB),
                width: _graphMetric == 'both' ? 7 : 12,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
              ),
            );
          }
          if (showReceipts) {
            rods.add(
              BarChartRodData(
                toY: e.value.receipts,
                color: const Color(0xFF10B981),
                width: _graphMetric == 'both' ? 7 : 12,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
              ),
            );
          }
          return BarChartGroupData(
            x: e.key,
            barRods: rods,
          );
        }).toList(),
      ),
    );
  }

  Widget _buildLineChart(List<MonthlyTrendPoint> trends, double maxY, LanguageProvider lang) {
    final showSales = _graphMetric == 'both' || _graphMetric == 'sales';
    final showReceipts = _graphMetric == 'both' || _graphMetric == 'receipts';

    final lines = <LineChartBarData>[];

    if (showSales) {
      lines.add(
        LineChartBarData(
          spots: trends.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.sales)).toList(),
          isCurved: true,
          color: const Color(0xFF2563EB),
          barWidth: 2.8,
          isStrokeCapRound: true,
          dotData: const FlDotData(show: true),
          belowBarData: BarAreaData(
            show: true,
            color: const Color(0xFF2563EB).withValues(alpha: 0.10),
          ),
        ),
      );
    }

    if (showReceipts) {
      lines.add(
        LineChartBarData(
          spots: trends.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.receipts)).toList(),
          isCurved: true,
          color: const Color(0xFF10B981),
          barWidth: 2.8,
          isStrokeCapRound: true,
          dotData: const FlDotData(show: true),
          belowBarData: BarAreaData(
            show: true,
            color: const Color(0xFF10B981).withValues(alpha: 0.10),
          ),
        ),
      );
    }

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
                      style: const TextStyle(fontSize: 9.5, color: AppColors.textMuted, fontWeight: FontWeight.w700),
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
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final idx = spot.x.toInt();
                final label = (idx >= 0 && idx < trends.length) ? trends[idx].month : '';
                final isSales = _graphMetric == 'sales' || (_graphMetric == 'both' && spot.barIndex == 0);
                final title = isSales ? (lang.isHindi ? 'बिक्री' : 'Sales') : (lang.isHindi ? 'वसूली' : 'Receipts');
                return LineTooltipItem(
                  '$label\n$title: ₹${CurrencyFormatter.format(spot.y)}',
                  const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                );
              }).toList();
            },
          ),
        ),
        lineBarsData: lines,
      ),
    );
  }

  // Recent Transactions Feed
  Widget _buildRecentTransactionsFeed(BuildContext context, LanguageProvider lang) {
    final activities = currentSummary.recentActivities;

    return Card(
      color: Colors.white,
      elevation: 0.8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.borderLight, width: 0.8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: AppColors.primaryNavy.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(Icons.history_rounded, color: AppColors.primaryNavy, size: 16),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      lang.isHindi ? 'लेन-देन' : 'Transactions',
                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                    ),
                  ],
                ),
                Text(
                  '${activities.length} ${lang.isHindi ? "रिकॉर्ड" : "Records"}',
                  style: const TextStyle(fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Divider(height: 1),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: activities.length,
              separatorBuilder: (_, _) => const Divider(height: 8, color: AppColors.borderLight),
              itemBuilder: (context, idx) {
                final item = activities[idx];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2.0),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: item.isCredit ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                        ),
                        child: Icon(
                          item.isCredit ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                          size: 13,
                          color: item.isCredit ? const Color(0xFF15803D) : const Color(0xFFB91C1C),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.title,
                              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(item.subtitle, style: const TextStyle(fontSize: 10.5, color: AppColors.textMuted)),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${item.isCredit ? '+' : '-'} ₹${CurrencyFormatter.format(item.amount)}',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: item.isCredit ? const Color(0xFF15803D) : const Color(0xFFB91C1C),
                            ),
                          ),
                          InkWell(
                            onTap: () => _shareTransaction(item, lang),
                            child: const Padding(
                              padding: EdgeInsets.all(2.0),
                              child: Icon(Icons.share_rounded, size: 12, color: Color(0xFF25D366)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
