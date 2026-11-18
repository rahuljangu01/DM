import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../core/localization/language_provider.dart';
import '../core/security/pin_service.dart';
import '../core/security/privacy_provider.dart';
import '../models/dashboard_summary.dart';
import '../repositories/dashboard_repository.dart';
import 'dashboard/dashboard_screen.dart';
import 'parties/parties_list_screen.dart';
import 'bills/bills_list_screen.dart';
import 'bills/create_edit_bill_screen.dart';
import 'challans/create_edit_challan_screen.dart';
import 'transactions/payment_entry_screen.dart';
import 'cashbook/cashbook_screen.dart';
import 'dues/due_tracking_screen.dart';
import 'more/more_menu_screen.dart';
import 'pin_screen.dart';
import '../services/auto_email_dispatch_service.dart';
import '../core/security/auth_service.dart';

class MainNavigationScreen extends StatefulWidget {
  final int initialIndex;

  const MainNavigationScreen({super.key, this.initialIndex = 0});

  @override
  State<MainNavigationScreen> createState() => MainNavigationScreenState();
}

class MainNavigationScreenState extends State<MainNavigationScreen> {
  late int _currentIndex;
  final DashboardRepository _dashboardRepo = DashboardRepository();
  DashboardSummary _summary = const DashboardSummary();
  String _userName = '';

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _loadDashboardSummary();
    _loadUserName();
    AutoEmailDispatchService.checkAndTriggerOnAppStart(context);
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

  Future<void> _loadDashboardSummary() async {
    try {
      final summary = await _dashboardRepo.getDashboardSummary();
      if (mounted) {
        setState(() {
          _summary = summary;
        });
      }
    } catch (_) {
      // Ignored
    }
  }

  void switchTab(int index) {
    if (mounted) {
      setState(() {
        _currentIndex = index;
      });
      _loadDashboardSummary();
      _loadUserName();
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();

    final pages = [
      DashboardScreen(
        summary: _summary,
        onRefresh: _loadDashboardSummary,
        onNewBill: () async {
          final res = await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const CreateEditBillScreen()),
          );
          if (res == true) _loadDashboardSummary();
        },
        onNewChallan: () async {
          final res = await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const CreateEditChallanScreen()),
          );
          if (res == true) _loadDashboardSummary();
        },
        onNewPayment: () async {
          final res = await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const PaymentEntryScreen()),
          );
          if (res == true) _loadDashboardSummary();
        },
        onViewParties: () => switchTab(1),
        onViewOverdue: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const DueTrackingScreen()),
          );
          _loadDashboardSummary();
        },
      ),
      const PartiesListScreen(),
      const BillsListScreen(),
      const CashbookScreen(),
      MoreMenuScreen(onDataReload: _loadDashboardSummary),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 850;

        if (isDesktop) {
          return Scaffold(
            body: Row(
              children: [
                _buildDesktopSidebar(context, lang),
                Expanded(
                  child: IndexedStack(
                    index: _currentIndex,
                    children: pages,
                  ),
                ),
              ],
            ),
          );
        }

        // Mobile Layout: Bottom Navigation Bar Dock
        return Scaffold(
          body: IndexedStack(
            index: _currentIndex,
            children: pages,
          ),
          bottomNavigationBar: _buildBottomNav(lang),
        );
      },
    );
  }

  Widget _buildDesktopSidebar(BuildContext context, LanguageProvider lang) {
    return Container(
      width: 250,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF030712),
            Color(0xFF091B33),
            Color(0xFF0F2647),
          ],
        ),
        border: Border(
          right: BorderSide(
            color: Color(0xFFD4AF37),
            width: 1.0,
          ),
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 20),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF040A14),
                    border: Border.all(color: const Color(0xFFD4AF37), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFD4AF37).withValues(alpha: 0.35),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: Padding(
                      padding: const EdgeInsets.all(3.0),
                      child: Image.asset(
                        'assets/images/dm_lace_logo.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'DM LACE',
                        style: TextStyle(
                          color: Color(0xFFFDE047),
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.4,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Container(
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
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.verified_rounded,
                              size: 11,
                              color: Color(0xFF38BDF8),
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
          const Divider(height: 1, color: Color(0x33D4AF37)),
          const SizedBox(height: 12),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              children: [
                _buildDesktopSidebarItem(
                  index: 0,
                  label: lang.tr(en: 'Dashboard Overview', hi: 'डैशबोर्ड'),
                  icon: Icons.dashboard_outlined,
                  activeIcon: Icons.dashboard_rounded,
                ),
                _buildDesktopSidebarItem(
                  index: 1,
                  label: lang.tr(en: 'Parties & Ledgers', hi: 'पार्टियां व खाते'),
                  icon: Icons.people_outline_rounded,
                  activeIcon: Icons.people_rounded,
                ),
                _buildDesktopSidebarItem(
                  index: 2,
                  label: lang.tr(en: 'Bills & Invoices', hi: 'बिल व इनवॉइस'),
                  icon: Icons.receipt_long_outlined,
                  activeIcon: Icons.receipt_long_rounded,
                ),
                _buildDesktopSidebarItem(
                  index: 3,
                  label: lang.tr(en: 'Cash & Expenses', hi: 'गल्ला व खर्चा'),
                  icon: Icons.account_balance_wallet_outlined,
                  activeIcon: Icons.account_balance_wallet_rounded,
                ),
                _buildDesktopSidebarItem(
                  index: 4,
                  label: lang.tr(en: 'More Operations', hi: 'अन्य विकल्प'),
                  icon: Icons.grid_view_outlined,
                  activeIcon: Icons.grid_view_rounded,
                ),
              ],
            ),
          ),
          // Sidebar Security & Privacy Controls
          Container(
            padding: const EdgeInsets.all(10),
            margin: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0x33D4AF37)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Consumer<PrivacyProvider>(
                  builder: (context, privacy, _) {
                    return InkWell(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        privacy.togglePrivacyMode();
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
                        child: Row(
                          children: [
                            Icon(
                              privacy.isPrivacyMode ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                              size: 16,
                              color: privacy.isPrivacyMode ? const Color(0xFFFDE047) : const Color(0xFF94A3B8),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                privacy.isPrivacyMode
                                    ? lang.tr(en: 'Privacy Mode: ON', hi: 'प्राइवेसी: चालू')
                                    : lang.tr(en: 'Hide Balances', hi: 'बैलेंस छिपाएं'),
                                style: TextStyle(
                                  color: privacy.isPrivacyMode ? const Color(0xFFFDE047) : const Color(0xFFCBD5E1),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                if (PinService.isPinEnabled) ...[
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: () {
                      HapticFeedback.vibrate();
                      PinService.setLocked(true);
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => const PinScreen()),
                        (route) => false,
                      );
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
                      child: Row(
                        children: [
                          const Icon(Icons.lock_outline_rounded, size: 16, color: Color(0xFFEF4444)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              lang.tr(en: 'Lock App Now', hi: 'ऐप तुरंत लॉक करें'),
                              style: const TextStyle(
                                color: Color(0xFFFCA5A5),
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                const Divider(height: 1, color: Color(0x22FFFFFF)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.security_rounded, size: 14, color: Color(0xFF22C55E)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        lang.tr(en: '100% Offline SQLite', hi: '100% सुरक्षित ऑफलाइन बहीखाता'),
                        style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 10, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopSidebarItem({
    required int index,
    required String label,
    required IconData icon,
    required IconData activeIcon,
  }) {
    final isSelected = _currentIndex == index;
    return Container(
      margin: const EdgeInsets.only(bottom: 5),
      decoration: BoxDecoration(
        gradient: isSelected
            ? LinearGradient(
                colors: [
                  const Color(0xFFD4AF37).withValues(alpha: 0.22),
                  const Color(0xFF1E3A8A).withValues(alpha: 0.18),
                ],
              )
            : null,
        borderRadius: BorderRadius.circular(12),
        border: isSelected
            ? Border.all(
                color: const Color(0xFFFDE047).withValues(alpha: 0.70),
                width: 1.1,
              )
            : Border.all(color: Colors.transparent),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: const Color(0xFFD4AF37).withValues(alpha: 0.20),
                  blurRadius: 8,
                ),
              ]
            : null,
      ),
      child: ListTile(
        dense: true,
        leading: Icon(
          isSelected ? activeIcon : icon,
          color: isSelected ? const Color(0xFFFDE047) : const Color(0xFF94A3B8),
          size: 20,
        ),
        title: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected ? const Color(0xFFFFFBEB) : const Color(0xFFE2E8F0),
            letterSpacing: 0.3,
          ),
        ),
        trailing: isSelected
            ? Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFFDE047),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFDE047).withValues(alpha: 0.8),
                      blurRadius: 5,
                    ),
                  ],
                ),
              )
            : null,
        onTap: () {
          HapticFeedback.lightImpact();
          switchTab(index);
        },
      ),
    );
  }

  Widget _buildBottomNav(LanguageProvider lang) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFFFFFFF), // Crisp Pearl White Top
            Color(0xFFFCFCFD), // Soft Pearl Mid
            Color(0xFFF1F5F9), // Light Ice Base
          ],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        border: const Border(
          top: BorderSide(
            color: Color(0xFFD4AF37),
            width: 1.5,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, -4),
          ),
          BoxShadow(
            color: const Color(0xFFD4AF37).withValues(alpha: 0.15),
            blurRadius: 10,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Container(
          height: 66,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(
                index: 0,
                label: lang.tr(en: 'Home', hi: 'होम'),
                icon: Icons.dashboard_outlined,
                activeIcon: Icons.dashboard_rounded,
                isSelected: _currentIndex == 0,
              ),
              _buildNavItem(
                index: 1,
                label: lang.tr(en: 'Parties', hi: 'पार्टियां'),
                icon: Icons.people_outline_rounded,
                activeIcon: Icons.people_rounded,
                isSelected: _currentIndex == 1,
                badgeCount: _summary.overdueCount > 0 ? _summary.overdueCount : null,
              ),
              _buildNavItem(
                index: 2,
                label: lang.tr(en: 'Bills', hi: 'बिल'),
                icon: Icons.receipt_long_outlined,
                activeIcon: Icons.receipt_long_rounded,
                isSelected: _currentIndex == 2,
              ),
              _buildNavItem(
                index: 3,
                label: lang.tr(en: 'Cash', hi: 'गल्ला'),
                icon: Icons.account_balance_wallet_outlined,
                activeIcon: Icons.account_balance_wallet_rounded,
                isSelected: _currentIndex == 3,
              ),
              _buildNavItem(
                index: 4,
                label: lang.tr(en: 'More', hi: 'अन्य'),
                icon: Icons.grid_view_outlined,
                activeIcon: Icons.grid_view_rounded,
                isSelected: _currentIndex == 4,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required String label,
    required IconData icon,
    required IconData activeIcon,
    required bool isSelected,
    int? badgeCount,
  }) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            switchTab(index);
          },
          borderRadius: BorderRadius.circular(16),
          splashColor: const Color(0xFF091B33).withValues(alpha: 0.12),
          highlightColor: Colors.transparent,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                padding: EdgeInsets.symmetric(
                  horizontal: isSelected ? 12 : 6,
                  vertical: isSelected ? 4 : 2,
                ),
                decoration: BoxDecoration(
                  gradient: isSelected
                      ? const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFF061426),
                            Color(0xFF0B203E),
                            Color(0xFF142E56),
                          ],
                        )
                      : null,
                  borderRadius: BorderRadius.circular(16),
                  border: isSelected
                      ? Border.all(
                          color: const Color(0xFFD4AF37),
                          width: 1.2,
                        )
                      : null,
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: const Color(0xFF091B33).withValues(alpha: 0.25),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ]
                      : null,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.center,
                      children: [
                        AnimatedScale(
                          scale: isSelected ? 1.10 : 1.0,
                          duration: const Duration(milliseconds: 180),
                          curve: Curves.easeOutBack,
                          child: Icon(
                            isSelected ? activeIcon : icon,
                            size: isSelected ? 21 : 22,
                            color: isSelected
                                ? const Color(0xFFFDE047)
                                : const Color(0xFF0F172A),
                          ),
                        ),
                        if (badgeCount != null && badgeCount > 0)
                          Positioned(
                            top: -4,
                            right: -9,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEF4444),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: Colors.white,
                                  width: 1,
                                ),
                              ),
                              constraints: const BoxConstraints(
                                minWidth: 14,
                                minHeight: 14,
                              ),
                              child: Text(
                                badgeCount > 99 ? '99+' : '$badgeCount',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: isSelected ? 10.5 : 10,
                        fontWeight: isSelected ? FontWeight.w900 : FontWeight.w800,
                        color: isSelected
                            ? const Color(0xFFFFFBEB)
                            : const Color(0xFF0F172A),
                        letterSpacing: isSelected ? 0.3 : 0.1,
                      ),
                    ),
                  ],
                ),
              ),
              // Golden Jewel Dot below Active Tab
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: isSelected ? 4 : 0,
                height: isSelected ? 4 : 0,
                margin: const EdgeInsets.only(top: 2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected ? const Color(0xFFD4AF37) : Colors.transparent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
