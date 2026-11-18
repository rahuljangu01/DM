import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/localization/language_provider.dart';
import '../../core/security/pin_service.dart';
import '../../core/database/database_helper.dart';
import '../../core/database/database_tables.dart';
import '../../widgets/confirmation_dialog.dart';
import '../../widgets/dmlace_logo.dart';
import '../pin_screen.dart';
import '../business_card/business_card_screen.dart';
import '../upi/upi_qr_management_screen.dart';
import '../../core/security/auth_service.dart';
import '../auth/auth_screen.dart';

class SettingsScreen extends StatefulWidget {
  final VoidCallback? onDataReload;

  const SettingsScreen({super.key, this.onDataReload});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isPinEnabled = PinService.isPinEnabled;
  bool _isLoading = true;
  Map<String, dynamic>? _currentUser;

  // Shop Profile State
  String _firmName = 'DM LACE SURAT';
  String _ownerName = 'Rahul Jangu';
  String _phone = '+91 98765 43210';
  String _address = 'Millennium Textile Market, Ring Road, Surat';
  String _gstin = '24AAACD1234M1Z5';
  String _upiId = 'dmlace@upi';

  @override
  void initState() {
    super.initState();
    _loadShopProfile();
  }

  Future<void> _loadShopProfile() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final rows = await db.query(DatabaseTables.tableAppSettings);
      final map = {for (final r in rows) r['setting_key'] as String: r['setting_value'] as String};

      final user = await AuthService.getCurrentUser();

      if (mounted) {
        setState(() {
          if (map.containsKey('shop_name')) {
            _firmName = map['shop_name']!;
          } else if (map.containsKey('biz_card_firm')) {
            _firmName = map['biz_card_firm']!;
          }

          if (map.containsKey('shop_owner')) {
            _ownerName = map['shop_owner']!;
          } else if (map.containsKey('biz_card_owner')) {
            _ownerName = map['biz_card_owner']!;
          }

          if (map.containsKey('shop_phone')) {
            _phone = map['shop_phone']!;
          } else if (map.containsKey('biz_card_phone')) {
            _phone = map['biz_card_phone']!;
          }

          if (map.containsKey('shop_address')) {
            _address = map['shop_address']!;
          } else if (map.containsKey('biz_card_address')) {
            _address = map['biz_card_address']!;
          }

          if (map.containsKey('shop_gstin')) {
            _gstin = map['shop_gstin']!;
          } else if (map.containsKey('biz_card_gstin')) {
            _gstin = map['biz_card_gstin']!;
          }

          if (map.containsKey('shop_upi')) {
            _upiId = map['shop_upi']!;
          }

          _currentUser = user;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSetting(String key, String value) async {
    final db = await DatabaseHelper.instance.database;
    await db.rawInsert('''
      INSERT OR REPLACE INTO ${DatabaseTables.tableAppSettings} (setting_key, setting_value, updated_at)
      VALUES (?, ?, datetime('now'))
    ''', [key, value]);
  }

  Future<void> _openEditShopDialog(LanguageProvider lang) async {
    final firmCtrl = TextEditingController(text: _firmName);
    final ownerCtrl = TextEditingController(text: _ownerName);
    final phoneCtrl = TextEditingController(text: _phone);
    final addressCtrl = TextEditingController(text: _address);
    final gstinCtrl = TextEditingController(text: _gstin);
    final upiCtrl = TextEditingController(text: _upiId);

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.storefront_rounded, color: AppColors.primaryGold, size: 22),
            const SizedBox(width: 8),
            Text(
              lang.isHindi ? 'दुकान प्रोफ़ाइल बदलें' : 'Edit Shop Profile',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDialogField(lang.isHindi ? 'दुकान / फ़र्म का नाम' : 'Shop / Firm Name', firmCtrl),
              const SizedBox(height: 10),
              _buildDialogField(lang.isHindi ? 'मालिक / संचालक का नाम' : 'Owner / Manager Name', ownerCtrl),
              const SizedBox(height: 10),
              _buildDialogField(lang.isHindi ? 'मोबाइल / व्हाट्सएप नंबर' : 'Phone / WhatsApp', phoneCtrl, isPhone: true),
              const SizedBox(height: 10),
              _buildDialogField(lang.isHindi ? 'सूरत मार्केट पता' : 'Market Address', addressCtrl, maxLines: 2),
              const SizedBox(height: 10),
              _buildDialogField(lang.isHindi ? 'GSTIN नंबर (वैकल्पिक)' : 'GSTIN (Optional)', gstinCtrl),
              const SizedBox(height: 10),
              _buildDialogField(lang.isHindi ? 'UPI ID (भुगतान प्राप्ति हेतु)' : 'UPI ID (For Payments)', upiCtrl),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(lang.isHindi ? 'रद्द करें' : 'Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGold,
              foregroundColor: AppColors.primaryNavy,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(lang.isHindi ? 'सेव करें' : 'Save Details', style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (saved == true) {
      final newFirm = firmCtrl.text.trim().isEmpty ? _firmName : firmCtrl.text.trim();
      final newOwner = ownerCtrl.text.trim().isEmpty ? _ownerName : ownerCtrl.text.trim();
      final newPhone = phoneCtrl.text.trim().isEmpty ? _phone : phoneCtrl.text.trim();
      final newAddress = addressCtrl.text.trim().isEmpty ? _address : addressCtrl.text.trim();
      final newGstin = gstinCtrl.text.trim();
      final newUpi = upiCtrl.text.trim();

      await _saveSetting('shop_name', newFirm);
      await _saveSetting('biz_card_firm', newFirm);

      await _saveSetting('shop_owner', newOwner);
      await _saveSetting('biz_card_owner', newOwner);

      await _saveSetting('shop_phone', newPhone);
      await _saveSetting('biz_card_phone', newPhone);

      await _saveSetting('shop_address', newAddress);
      await _saveSetting('biz_card_address', newAddress);

      await _saveSetting('shop_gstin', newGstin);
      await _saveSetting('biz_card_gstin', newGstin);

      await _saveSetting('shop_upi', newUpi);

      setState(() {
        _firmName = newFirm;
        _ownerName = newOwner;
        _phone = newPhone;
        _address = newAddress;
        _gstin = newGstin;
        _upiId = newUpi;
      });

      widget.onDataReload?.call();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(lang.isHindi ? 'दुकान प्रोफ़ाइल सफलतापूर्वक अपडेट हो गई!' : 'Shop Profile updated successfully!'),
            backgroundColor: const Color(0xFF0F172A),
          ),
        );
      }
    }
  }

  Widget _buildDialogField(String label, TextEditingController ctrl, {bool isPhone = false, int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF475569))),
        const SizedBox(height: 4),
        TextField(
          controller: ctrl,
          maxLines: maxLines,
          keyboardType: isPhone ? TextInputType.phone : TextInputType.text,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        title: Text(lang.isHindi ? 'दुकान प्रोफ़ाइल व सेटिंग्स' : 'Shop Profile & Settings'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryGold))
          : ListView(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 28),
              children: [
                // 1. Sleek Editable Shop Profile Card
                _buildShopProfileCard(lang),

                const SizedBox(height: 16),

                // 2. UPI Multi-QR Section (PhonePe Style)
                _buildSectionHeader(lang.isHindi ? 'UPI एवं भुगतान QR' : 'UPI & PAYMENT QR CODES'),
                _buildUpiQrCard(lang),

                const SizedBox(height: 16),

                // 2. Language Preference Section
                _buildSectionHeader(lang.isHindi ? 'भाषा (Language)' : 'LANGUAGE PREFERENCE'),
                _buildLanguageCard(lang),

                const SizedBox(height: 16),

                // 3. App Security & PIN Access Section
                _buildSectionHeader(lang.isHindi ? 'सुरक्षा व 4-अंकों का PIN लॉक' : 'APP SECURITY & PIN'),
                _buildSecurityCard(lang),

                const SizedBox(height: 16),

                // 4. Account & Email Login Section
                _buildSectionHeader(lang.isHindi ? 'खाता एवं ईमेल लॉगिन' : 'ACCOUNT & EMAIL LOGIN'),
                _buildAccountCard(lang),
              ],
            ),
    );
  }

  Widget _buildShopProfileCard(LanguageProvider lang) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row with Logo & Edit Button
          Row(
            children: [
              const DmLaceLogo(size: 46, showText: false),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _firmName,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.primaryNavy),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${lang.isHindi ? "संचालक:" : "Proprietor:"} $_ownerName',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0D9488)),
                    ),
                  ],
                ),
              ),
              IconButton(
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.primaryNavy.withValues(alpha: 0.06),
                ),
                icon: const Icon(Icons.edit_note_rounded, color: AppColors.primaryNavy, size: 22),
                tooltip: lang.isHindi ? 'दुकान जानकारी बदलें' : 'Edit Shop Profile',
                onPressed: () => _openEditShopDialog(lang),
              ),
            ],
          ),
          const Divider(height: 22, color: Color(0xFFF1F5F9)),

          // Info Rows
          _buildProfileInfoRow(Icons.phone_rounded, lang.isHindi ? 'फोन / व्हाट्सएप' : 'Phone / WhatsApp', _phone),
          const SizedBox(height: 8),
          _buildProfileInfoRow(Icons.location_on_rounded, lang.isHindi ? 'मार्केट पता' : 'Market Address', _address),
          const SizedBox(height: 8),
          _buildProfileInfoRow(Icons.receipt_long_rounded, lang.isHindi ? 'GSTIN' : 'GSTIN', _gstin.isNotEmpty ? _gstin : 'Unregistered (Composition)'),
          if (_upiId.isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildProfileInfoRow(Icons.qr_code_rounded, lang.isHindi ? 'UPI ID' : 'UPI ID', _upiId),
          ],

          const SizedBox(height: 14),

          // Digital Visiting Card Quick View Shortcut Button
          InkWell(
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const BusinessCardScreen()),
              );
            },
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.badge_rounded, color: AppColors.primaryGold, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    lang.isHindi ? 'विज़िटिंग कार्ड' : 'Visiting Card',
                    style: const TextStyle(color: Color(0xFFFDE047), fontWeight: FontWeight.w800, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: const Color(0xFF64748B)),
        const SizedBox(width: 8),
        SizedBox(
          width: 105,
          child: Text(
            label,
            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
          ),
        ),
      ],
    );
  }

  Widget _buildUpiQrCard(LanguageProvider lang) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0F172A), Color(0xFF1E3A8A)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.qr_code_2_rounded, color: Color(0xFFFDE047), size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          lang.isHindi ? 'दुकान UPI QR' : 'Shop UPI QR',
                          style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: AppColors.primaryNavy),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('PRO', style: TextStyle(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.w900)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      lang.isHindi
                          ? 'बैंक व UPI QR कोड'
                          : 'Configure Bank & UPI QR codes',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F172A),
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const UpiQrManagementScreen()),
                );
                _loadShopProfile();
              },
              icon: const Icon(Icons.settings_suggest_rounded, color: Color(0xFFFDE047), size: 18),
              label: Text(
                lang.isHindi ? 'QR कोड सेट व प्रबंधित करें' : 'Manage & Set QR Codes',
                style: const TextStyle(color: Color(0xFFFDE047), fontWeight: FontWeight.w800, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageCard(LanguageProvider lang) {
    return Card(
      margin: EdgeInsets.zero,
      color: Colors.white,
      elevation: 0.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: Color(0xFFE2E8F0))),
      child: Column(
        children: [
          RadioListTile<AppLanguage>(
            value: AppLanguage.english,
            groupValue: lang.currentLanguage,
            activeColor: AppColors.primaryNavy,
            title: const Row(
              children: [
                Text('🇬🇧 English', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                SizedBox(width: 8),
                Text('(Default)', style: TextStyle(fontSize: 11, color: AppColors.primaryGold, fontWeight: FontWeight.w700)),
              ],
            ),
            subtitle: const Text('All dashboard labels and menus in English', style: TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
            onChanged: (val) {
              if (val != null) lang.setLanguage(val);
            },
          ),
          const Divider(height: 1, indent: 56, color: Color(0xFFF1F5F9)),
          RadioListTile<AppLanguage>(
            value: AppLanguage.hindi,
            groupValue: lang.currentLanguage,
            activeColor: AppColors.primaryNavy,
            title: const Text('🇮🇳 हिन्दी (Hindi)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
            subtitle: const Text('डैशबोर्ड, बटन व बहीखाता हिन्दी भाषा में', style: TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
            onChanged: (val) {
              if (val != null) lang.setLanguage(val);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSecurityCard(LanguageProvider lang) {
    return Card(
      margin: EdgeInsets.zero,
      color: Colors.white,
      elevation: 0.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: Color(0xFFE2E8F0))),
      child: Column(
        children: [
          SwitchListTile(
            secondary: const Icon(Icons.lock_outline_rounded, color: AppColors.primaryNavy),
            title: Text(lang.isHindi ? 'पासकोड सुरक्षा PIN' : 'Security PIN Protection', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
            subtitle: Text(lang.isHindi ? 'ऐप खोलते समय 4-अंकों का PIN अनिवार्य करें' : 'Require 4-digit PIN to open application', style: const TextStyle(fontSize: 11.5)),
            value: _isPinEnabled,
            activeThumbColor: AppColors.primaryGold,
            onChanged: (enabled) async {
              final messenger = ScaffoldMessenger.of(context);
              if (enabled) {
                final success = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(builder: (_) => const PinScreen(isSettingPin: true)),
                );
                if (success == true) {
                  if (!mounted) return;
                  setState(() => _isPinEnabled = true);
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(lang.isHindi ? 'सुरक्षा PIN सफलतापूर्वक चालू कर दिया गया है ✔️' : 'Security PIN enabled successfully ✔️'),
                      backgroundColor: AppColors.successGreen,
                    ),
                  );
                }
              } else {
                final confirm = await ConfirmationDialog.show(
                  context: context,
                  title: lang.isHindi ? 'PIN लॉक बंद करें?' : 'Disable PIN Lock?',
                  message: lang.isHindi
                      ? 'PIN लॉक बंद करने के बाद ऐप खोलते समय कोई पासवर्ड नहीं पूछा जाएगा। क्या आप इसे बंद करना चाहते हैं?'
                      : 'App will open directly without asking for a password. Are you sure you want to disable PIN lock?',
                  confirmText: lang.isHindi ? 'हाँ, PIN बंद करें' : 'Yes, Disable PIN',
                  isDestructive: true,
                );
                if (confirm == true) {
                  await PinService.disablePin();
                  if (!mounted) return;
                  setState(() => _isPinEnabled = false);
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(lang.isHindi ? 'PIN लॉक बंद कर दिया गया है। अब ऐप सीधे खुलेगी ✔️' : 'PIN Lock disabled. App will open directly ✔️'),
                      backgroundColor: AppColors.primaryNavy,
                    ),
                  );
                }
              }
            },
          ),
          if (_isPinEnabled) ...[
            const Divider(height: 1, indent: 56, color: Color(0xFFF1F5F9)),
            ListTile(
              leading: const Icon(Icons.password_rounded, color: AppColors.primaryNavy),
              title: Text(lang.isHindi ? 'सुरक्षा PIN बदलें' : 'Change Security PIN', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              trailing: const Icon(Icons.chevron_right, size: 20),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const PinScreen(isSettingPin: true)),
                );
              },
            ),
            const Divider(height: 1, indent: 56, color: Color(0xFFF1F5F9)),
            ListTile(
              leading: const Icon(Icons.lock_clock_rounded, color: AppColors.payableRed),
              title: Text(lang.isHindi ? 'ऐप तुरंत लॉक करें' : 'Lock Application Now', style: const TextStyle(fontSize: 14, color: AppColors.payableRed, fontWeight: FontWeight.bold)),
              subtitle: Text(lang.isHindi ? 'सुरक्षा PIN से पुनः खोलना होगा' : 'Require PIN to re-enter', style: const TextStyle(fontSize: 11)),
              trailing: const Icon(Icons.chevron_right, size: 20, color: AppColors.payableRed),
              onTap: () {
                PinService.setLocked(true);
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const PinScreen()),
                  (route) => false,
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAccountCard(LanguageProvider lang) {
    if (_currentUser != null) {
      return Card(
        margin: EdgeInsets.zero,
        color: Colors.white,
        elevation: 0.5,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: Color(0xFFE2E8F0))),
        child: Column(
          children: [
            ListTile(
              leading: const Icon(Icons.account_circle_rounded, color: AppColors.receivableGreen, size: 28),
              title: Text(_currentUser!['name'] as String? ?? 'User', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
              subtitle: Text(_currentUser!['email'] as String? ?? '', style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(6)),
                child: const Text('Active', style: TextStyle(color: Color(0xFF059669), fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ),
            const Divider(height: 1, indent: 56, color: Color(0xFFF1F5F9)),
            ListTile(
              leading: const Icon(Icons.logout_rounded, color: AppColors.payableRed),
              title: Text(lang.isHindi ? 'खाते से लॉगआउट करें' : 'Logout of Account', style: const TextStyle(fontSize: 13.5, color: AppColors.payableRed, fontWeight: FontWeight.w700)),
              onTap: () async {
                final confirm = await ConfirmationDialog.show(
                  context: context,
                  title: lang.tr(en: 'Logout?', hi: 'लॉगआउट करें?'),
                  message: lang.tr(en: 'Are you sure you want to sign out?', hi: 'क्या आप वाकई लॉगआउट करना चाहते हैं?'),
                  confirmText: lang.tr(en: 'Logout', hi: 'लॉगआउट'),
                  isDestructive: true,
                );
                if (confirm == true) {
                  await AuthService.logout();
                  if (!mounted) return;
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const AuthScreen(initialIsSignUp: false)),
                    (route) => false,
                  );
                }
              },
            ),
          ],
        ),
      );
    } else {
      return Card(
        margin: EdgeInsets.zero,
        color: Colors.white,
        elevation: 0.5,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: Color(0xFFE2E8F0))),
        child: ListTile(
          leading: const Icon(Icons.login_rounded, color: AppColors.primaryNavy),
          title: Text(lang.isHindi ? 'खाता लॉगिन या नया साइन अप करें' : 'Sign In or Register Account', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          subtitle: Text(lang.isHindi ? 'ईमेल से खाता जोड़ें' : 'Connect email account to secure your data', style: const TextStyle(fontSize: 11.5)),
          trailing: const Icon(Icons.chevron_right, size: 20),
          onTap: () async {
            await Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AuthScreen()),
            );
            _loadShopProfile();
          },
        ),
      );
    }
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
      child: Text(
        title,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary, letterSpacing: 0.8),
      ),
    );
  }
}
