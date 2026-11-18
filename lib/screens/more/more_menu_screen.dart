import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/localization/language_provider.dart';
import '../../core/database/database_helper.dart';
import '../../core/database/database_tables.dart';
import '../../core/security/auth_service.dart';
import '../../core/utils/share_helper.dart';
import '../../widgets/confirmation_dialog.dart';
import '../reports/reports_screen.dart';
import '../dues/due_tracking_screen.dart';
import '../inventory/inventory_catalog_hub_screen.dart';
import '../catalog/catalog_screen.dart';
import '../challans/challans_list_screen.dart';
import '../settings/settings_screen.dart';
import '../settings/auto_email_settings_screen.dart';
import '../business_card/business_card_screen.dart';
import '../workers/worker_management_screen.dart';
import '../upi/upi_qr_management_screen.dart';
import '../auth/auth_screen.dart';

class MoreMenuScreen extends StatefulWidget {
  final VoidCallback? onDataReload;

  const MoreMenuScreen({super.key, this.onDataReload});

  @override
  State<MoreMenuScreen> createState() => _MoreMenuScreenState();
}

class _MoreMenuScreenState extends State<MoreMenuScreen> {
  String _shopName = 'DM LACE SURAT';
  String _shopAddress = 'Limbayat, Surat (Gujarat)';
  Map<String, dynamic>? _currentUser;

  @override
  void initState() {
    super.initState();
    _loadShopProfile();
  }

  Future<void> _loadShopProfile() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final rows = await db.query(DatabaseTables.tableAppSettings);
      final map = {for (var r in rows) r['setting_key'] as String: r['setting_value'] as String};
      final user = await AuthService.getCurrentUser();
      if (mounted) {
        setState(() {
          _currentUser = user;
          if (map['shop_name'] != null && map['shop_name']!.trim().isNotEmpty) {
            _shopName = map['shop_name']!.trim();
          } else if (map['biz_card_firm'] != null && map['biz_card_firm']!.trim().isNotEmpty) {
            _shopName = map['biz_card_firm']!.trim();
          }
          if (map['shop_address'] != null && map['shop_address']!.trim().isNotEmpty) {
            _shopAddress = map['shop_address']!.trim();
          } else if (map['biz_card_address'] != null && map['biz_card_address']!.trim().isNotEmpty) {
            _shopAddress = map['biz_card_address']!.trim();
          }
        });
      }
    } catch (_) {}
  }

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SettingsScreen(
          onDataReload: () {
            widget.onDataReload?.call();
            _loadShopProfile();
          },
        ),
      ),
    );
  }

  void _shareApp(LanguageProvider lang) {
    HapticFeedback.lightImpact();
    ShareHelper.shareText(
      '🌟 *DM Lace Surat - डिजिटल बहीखाता व लेस कैटलॉग*\n\n'
      'सूरत टेक्सटाइल मार्केट का सबसे भरोसेमंद, 100% ऑफ़लाइन व सुरक्षित बहीखाता ऐप!\n'
      '• पार्टी लेज़र, बिलिंग व डिलीवरी चालान\n'
      '• 3D डिजिटल विज़िटिंग कार्ड व UPI QR कोड\n'
      '• लेस डिज़ाइन कैटलॉग व कारीगर कटाई हिसाब\n'
      '• 10-दिन ऑटो ईमेल रिपोर्ट व सुरक्षित बैकअप\n\n'
      '📲 सूरत के सभी व्यापारी भाइयों के लिए खास तैयार किया गया!',
      subject: 'DM Lace Surat - डिजिटल बहीखाता ऐप',
    );
  }

  void _showHelpSupportDialog(BuildContext context, LanguageProvider lang) {
    HapticFeedback.lightImpact();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        actionsPadding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.support_agent_rounded, color: Color(0xFF2563EB), size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                lang.tr(en: 'Merchant Helpdesk', hi: 'व्यापारी सहायता केंद्र'),
                style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSupportItem(
              icon: Icons.phone_in_talk_rounded,
              iconColor: const Color(0xFF10B981),
              title: lang.tr(en: 'Surat Market Support', hi: 'सूरत मार्केट हेल्पलाइन'),
              subtitle: '+91 98251 00000 / Ring Road, Surat',
            ),
            const SizedBox(height: 12),
            _buildSupportItem(
              icon: Icons.email_outlined,
              iconColor: const Color(0xFF2563EB),
              title: lang.tr(en: 'Email Helpdesk', hi: 'ईमेल सपोर्ट'),
              subtitle: 'support@dmlacesurat.com',
            ),
            const SizedBox(height: 12),
            _buildSupportItem(
              icon: Icons.verified_user_outlined,
              iconColor: const Color(0xFFD97706),
              title: lang.tr(en: '100% Offline & Secure', hi: '100% ऑफ़लाइन व सुरक्षित डेटा'),
              subtitle: lang.tr(
                en: 'Your data stays safely on this device with email backup protection.',
                hi: 'आपका पूरा बहीखाता केवल आपके फ़ोन में सुरक्षित रहता है और ईमेल रिपोर्ट से बैकअप रहता है।',
              ),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F172A),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(
                lang.tr(en: 'Close', hi: 'ठीक है'),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSupportItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: iconColor),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _handleLogout(LanguageProvider lang) async {
    final confirmed = await ConfirmationDialog.show(
      context: context,
      title: lang.tr(en: 'Logout of Account?', hi: 'खाते से लॉगआउट करें?'),
      message: lang.tr(
        en: 'Are you sure you want to sign out from your account (${_currentUser?['email']})?',
        hi: 'क्या आप वाकई अपने खाते (${_currentUser?['email']}) से लॉगआउट करना चाहते हैं?',
      ),
      confirmText: lang.tr(en: 'Yes, Logout', hi: 'हाँ, लॉगआउट करें'),
      isDestructive: true,
    );
    if (confirmed == true) {
      await AuthService.logout();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AuthScreen(initialIsSignUp: false)),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          // 1. Sleek Executive Merchant Profile Header
          _buildProfileHeader(context, lang),

          // 2. Main Scrollable Content
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              physics: const BouncingScrollPhysics(),
              children: [
                // Group 1: Business & Sales
                _buildGroupHeader(
                  icon: Icons.storefront_outlined,
                  iconColor: const Color(0xFF2563EB),
                  title: lang.tr(en: 'SALES & BUSINESS', hi: 'व्यापार व बिक्री'),
                ),
                const SizedBox(height: 8),
                _buildCardGroup(
                  items: [
                    _buildMenuTile(
                      icon: Icons.local_shipping_outlined,
                      iconColor: const Color(0xFF2563EB),
                      iconBg: const Color(0xFFEFF6FF),
                      title: lang.tr(en: 'Delivery Challans', hi: 'डिलीवरी चालान'),
                      subtitle: lang.tr(en: 'Parcel delivery slips & dispatch', hi: 'माल भेजने व डिलीवरी की पर्चियां'),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const ChallansListScreen()),
                      ),
                    ),
                    _buildDivider(),
                    _buildMenuTile(
                      icon: Icons.notifications_active_outlined,
                      iconColor: const Color(0xFFEA580C),
                      iconBg: const Color(0xFFFFF7ED),
                      title: lang.tr(en: 'Payment Reminders', hi: 'उधारी तकादा'),
                      subtitle: lang.tr(en: 'Send WhatsApp payment reminders', hi: 'बाकी पेमेंट का WhatsApp तकादा'),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const DueTrackingScreen()),
                      ),
                    ),
                    _buildDivider(),
                    _buildMenuTile(
                      icon: Icons.auto_awesome_mosaic_outlined,
                      iconColor: const Color(0xFF9333EA),
                      iconBg: const Color(0xFFFAF5FF),
                      title: lang.tr(en: 'Lace Design Catalog', hi: 'लेस डिज़ाइन कैटलॉग'),
                      subtitle: lang.tr(en: 'Wholesale photos & rate book', hi: 'डिज़ाइन फोटो, रेट व WhatsApp शेयर'),
                      trailingBadge: _buildBadge(text: 'CATALOG', bg: const Color(0xFFFAF5FF), border: const Color(0xFFE9D5FF), textCol: const Color(0xFF9333EA)),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const CatalogScreen()),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Group 2: Stock, Production & QR
                _buildGroupHeader(
                  icon: Icons.inventory_2_outlined,
                  iconColor: const Color(0xFF0D9488),
                  title: lang.tr(en: 'STOCK & OPERATIONS', hi: 'स्टॉक व दुकान संचालन'),
                ),
                const SizedBox(height: 8),
                _buildCardGroup(
                  items: [
                    _buildMenuTile(
                      icon: Icons.analytics_outlined,
                      iconColor: const Color(0xFF2563EB),
                      iconBg: const Color(0xFFEFF6FF),
                      title: lang.tr(en: 'Business Reports', hi: 'व्यापार रिपोर्ट्स'),
                      subtitle: lang.tr(en: 'Sales, purchase & profit statements', hi: 'बिक्री, ख़रीद व मुनाफ़ा स्टेटमेंट'),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const ReportsScreen()),
                      ),
                    ),
                    _buildDivider(),
                    _buildMenuTile(
                      icon: Icons.inventory_2_outlined,
                      iconColor: const Color(0xFF0D9488),
                      iconBg: const Color(0xFFF0FDFA),
                      title: lang.tr(en: 'Inventory Stock', hi: 'गोदाम लेस स्टॉक'),
                      subtitle: lang.tr(en: 'Stock balance & low-stock alerts', hi: 'लेस स्टॉक मात्रा व लो-स्टॉक अलर्ट'),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const InventoryCatalogHubScreen()),
                      ),
                    ),
                    _buildDivider(),
                    _buildMenuTile(
                      icon: Icons.precision_manufacturing_outlined,
                      iconColor: const Color(0xFFE11D48),
                      iconBg: const Color(0xFFFFF1F2),
                      title: lang.tr(en: 'Karigar & Production', hi: 'कारीगर व कटाई हिसाब'),
                      subtitle: lang.tr(en: 'Worker attendance, piece-rate & advances', hi: 'कारीगर हाजिरी, कटाई दर व खर्चा हिसाब'),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const WorkerManagementScreen()),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Group 3: Automated Email Reports & Backup
                _buildGroupHeader(
                  icon: Icons.mark_email_read_outlined,
                  iconColor: const Color(0xFF4F46E5),
                  title: lang.tr(en: 'EMAIL REPORT & BACKUP', hi: 'ईमेल हिसाब व बैकअप'),
                ),
                const SizedBox(height: 8),
                _buildCardGroup(
                  items: [
                    _buildMenuTile(
                      icon: Icons.mark_email_read_outlined,
                      iconColor: const Color(0xFF4F46E5),
                      iconBg: const Color(0xFFEEF2FF),
                      title: lang.tr(en: 'Email Account Report', hi: 'ईमेल हिसाब रिपोर्ट'),
                      subtitle: lang.tr(en: 'Receive full shop accounts on email', hi: 'दुकान का पूरा हिसाब ईमेल पर पाएं'),
                      trailingBadge: _buildBadge(text: 'AUTO / QUICK', bg: const Color(0xFFEEF2FF), border: const Color(0xFFC7D2FE), textCol: const Color(0xFF4F46E5)),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const AutoEmailSettingsScreen()),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Help & Share Hub
                Row(
                  children: [
                    Expanded(
                      child: _buildActionCard(
                        icon: Icons.share_rounded,
                        iconColor: const Color(0xFF2563EB),
                        iconBg: const Color(0xFFEFF6FF),
                        title: lang.tr(en: 'Share App', hi: 'ऐप शेयर करें'),
                        subtitle: lang.tr(en: 'With merchants', hi: 'साथी व्यापारियों को'),
                        onTap: () => _shareApp(lang),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildActionCard(
                        icon: Icons.support_agent_rounded,
                        iconColor: const Color(0xFF0D9488),
                        iconBg: const Color(0xFFF0FDFA),
                        title: lang.tr(en: 'Help & FAQ', hi: 'सहायता केंद्र'),
                        subtitle: lang.tr(en: 'Surat helpline', hi: 'हेल्पडेस्क गाइड'),
                        onTap: () => _showHelpSupportDialog(context, lang),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Single Dedicated Logout Button (At the very bottom)
                _buildLogoutButton(context, lang),

                const SizedBox(height: 24),

                // Clean Minimal Brand Footer
                _buildMinimalFooter(lang),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Sleek Executive Merchant Profile Header with 2-Touchpoint Quick Strip
  Widget _buildProfileHeader(BuildContext context, LanguageProvider lang) {
    final userName = _currentUser?['name'] as String? ?? 'व्यापारी';
    final userEmail = _currentUser?['email'] as String? ?? '';
    final initial = userName.trim().isNotEmpty ? userName.trim()[0].toUpperCase() : 'D';

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0B132B), Color(0xFF1C2541)],
        ),
        border: Border(bottom: BorderSide(color: Color(0xFF334155), width: 1)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Top Bar: Shop Name + Verified Badge + Language & Settings
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD4AF37).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFD4AF37).withValues(alpha: 0.35)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.workspace_premium_rounded, size: 14, color: Color(0xFFFDE047)),
                      const SizedBox(width: 5),
                      Text(
                        _shopName,
                        style: const TextStyle(
                          color: Color(0xFFFDE047),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.verified_rounded, size: 15, color: Color(0xFF38BDF8)),
                const Spacer(),

                // Language Switcher Pill
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    lang.setLanguage(lang.isHindi ? AppLanguage.english : AppLanguage.hindi);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF334155), width: 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.translate_rounded, size: 13, color: Color(0xFF38BDF8)),
                        const SizedBox(width: 5),
                        Text(
                          lang.isHindi ? 'English' : 'हिन्दी',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Settings & PIN Lock Shortcut Button
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    _openSettings();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF334155), width: 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.settings_outlined, size: 13, color: Color(0xFFFDE047)),
                        const SizedBox(width: 4),
                        Text(
                          lang.tr(en: 'Settings', hi: 'सेटिंग्स'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
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

            // Profile Card Row
            InkWell(
              onTap: () {
                HapticFeedback.lightImpact();
                _openSettings();
              },
              borderRadius: BorderRadius.circular(12),
              child: Row(
                children: [
                  // Circular Luxury Avatar with initial & online dot
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFDE047), Color(0xFFD4AF37), Color(0xFFB45309)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFD4AF37).withValues(alpha: 0.35),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          initial,
                          style: const TextStyle(
                            color: Color(0xFF0F172A),
                            fontSize: 23,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981),
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFF0B132B), width: 2),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 14),

                  // User Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                userName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.3,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFD4AF37).withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFFD4AF37).withValues(alpha: 0.4), width: 0.8),
                              ),
                              child: Text(
                                lang.tr(en: 'OWNER', hi: 'प्रोपराइटर'),
                                style: const TextStyle(
                                  color: Color(0xFFFDE047),
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        if (userEmail.isNotEmpty)
                          Row(
                            children: [
                              const Icon(Icons.mail_outline_rounded, size: 12, color: Color(0xFF94A3B8)),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  userEmail,
                                  style: const TextStyle(
                                    color: Color(0xFF94A3B8),
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(Icons.location_on_outlined, size: 12, color: Color(0xFF64748B)),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                _shopAddress,
                                style: const TextStyle(
                                  color: Color(0xFF64748B),
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const Icon(Icons.chevron_right_rounded, color: Color(0xFF64748B), size: 20),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // Balanced 2-Touchpoint Quick Strip (3D Card & UPI QR)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B).withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF334155), width: 1),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildQuickPill(
                      icon: Icons.badge_outlined,
                      iconColor: const Color(0xFFF59E0B),
                      label: lang.tr(en: '3D Visiting Card', hi: '3D विज़िटिंग कार्ड'),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const BusinessCardScreen()),
                      ),
                    ),
                  ),
                  Container(width: 1, height: 20, color: const Color(0xFF334155)),
                  Expanded(
                    child: _buildQuickPill(
                      icon: Icons.qr_code_2_rounded,
                      iconColor: const Color(0xFF10B981),
                      label: lang.tr(en: 'Shop UPI QR', hi: 'दुकान UPI QR'),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const UpiQrManagementScreen()),
                      ),
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

  /// Compact header quick pill
  Widget _buildQuickPill({
    required IconData icon,
    required Color iconColor,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: iconColor),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFFE2E8F0),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Section Header with Icon
  Widget _buildGroupHeader({
    required IconData icon,
    required Color iconColor,
    required String title,
  }) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: iconColor),
          const SizedBox(width: 6),
          Text(
            title,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: Color(0xFF64748B),
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }

  /// Modern Card Group Container
  Widget _buildCardGroup({required List<Widget> items}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.1),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.025),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(children: items),
      ),
    );
  }

  /// Modern List Tile
  Widget _buildMenuTile({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    required String subtitle,
    required VoidCallback? onTap,
    Widget? trailingBadge,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap?.call();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (trailingBadge != null) ...[
                trailingBadge,
                const SizedBox(width: 6),
              ],
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFF94A3B8),
                size: 19,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return const Divider(
      height: 1,
      indent: 62,
      endIndent: 14,
      color: Color(0xFFF1F5F9),
    );
  }

  /// Reusable Chip Badge
  Widget _buildBadge({
    required String text,
    required Color bg,
    required Color border,
    required Color textCol,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6.5, vertical: 2.5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border, width: 0.8),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: textCol,
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  /// Side-by-side action card (Share & Help)
  Widget _buildActionCard({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.1),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.025),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            onTap();
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: iconColor, size: 19),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 1),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 10.5,
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
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
    );
  }

  /// Single Dedicated Logout Button at the Bottom
  Widget _buildLogoutButton(BuildContext context, LanguageProvider lang) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFEE2E2), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFEF4444).withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.mediumImpact();
            _handleLogout(lang);
          },
          borderRadius: BorderRadius.circular(16),
          splashColor: const Color(0xFFFEF2F2),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFECACA), width: 1),
                  ),
                  child: const Icon(
                    Icons.power_settings_new_rounded,
                    color: Color(0xFFDC2626),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        lang.tr(en: 'Log Out of Account', hi: 'खाते से लॉगआउट करें'),
                        style: const TextStyle(
                          color: Color(0xFFDC2626),
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.2,
                        ),
                      ),
                      if (_currentUser != null && _currentUser!['email'] != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          '${_currentUser!['email']}',
                          style: const TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 15,
                  color: Color(0xFFF87171),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Clean Minimal Brand Footer
  Widget _buildMinimalFooter(LanguageProvider lang) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF0F172A),
                  border: Border.all(color: const Color(0xFFD4AF37), width: 1),
                ),
                child: ClipOval(
                  child: Padding(
                    padding: const EdgeInsets.all(1.5),
                    child: Image.asset('assets/images/dm_lace_logo.png', fit: BoxFit.contain),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              const Text(
                'DM LACE SURAT',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            lang.tr(
              en: 'Surat Textile Market • Version 1.0.0 (100% Offline & Secure)',
              hi: 'सूरत टेक्सटाइल मार्केट • v1.0.0 (100% ऑफ़लाइन व सुरक्षित बहीखाता)',
            ),
            style: const TextStyle(
              fontSize: 10.5,
              color: Color(0xFF94A3B8),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
