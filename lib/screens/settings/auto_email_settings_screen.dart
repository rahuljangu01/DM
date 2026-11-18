import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../../core/localization/language_provider.dart';
import '../../core/security/auth_service.dart';
import '../../services/audit_report_service.dart';
import '../../services/auto_email_dispatch_service.dart';

class AutoEmailSettingsScreen extends StatefulWidget {
  const AutoEmailSettingsScreen({super.key});

  @override
  State<AutoEmailSettingsScreen> createState() => _AutoEmailSettingsScreenState();
}

class _AutoEmailSettingsScreenState extends State<AutoEmailSettingsScreen> {
  final _emailController = TextEditingController();
  final _senderEmailController = TextEditingController();
  final _senderAppPasswordController = TextEditingController();

  bool _isEnabled = false;
  int _intervalDays = 10; // Default 10 days
  String _lastSentDate = '';
  bool _isLoading = true;
  bool _isDispatching = false;
  bool _showAdvancedApi = false;
  bool _obscurePassword = true;

  final List<int> _presetDays = [7, 10, 15, 30];

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _senderEmailController.dispose();
    _senderAppPasswordController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    final settings = await AutoEmailDispatchService.getSettings();
    final user = await AuthService.getCurrentUser();
    final userEmail = user?['email'] as String? ?? '';
    final savedRecipient = settings[AutoEmailDispatchService.keyRecipient] ?? '';

    int days = 10;
    if (settings[AutoEmailDispatchService.keyIntervalDays] != null) {
      final parsed = int.tryParse(settings[AutoEmailDispatchService.keyIntervalDays]!);
      if (parsed != null && parsed > 0) days = parsed;
    } else if (settings[AutoEmailDispatchService.keyCycleMode] != null) {
      final mode = settings[AutoEmailDispatchService.keyCycleMode]!;
      if (mode.startsWith('days_')) {
        final parsed = int.tryParse(mode.substring(5));
        if (parsed != null && parsed > 0) days = parsed;
      }
    }

    if (mounted) {
      setState(() {
        _isEnabled = settings[AutoEmailDispatchService.keyEnabled] == 'true';
        _intervalDays = days;
        _emailController.text = savedRecipient.isNotEmpty
            ? savedRecipient
            : (userEmail.isNotEmpty ? userEmail : 'rahuljangu01@gmail.com');
        _senderEmailController.text = (settings[AutoEmailDispatchService.keySenderEmail] ?? '').isNotEmpty
            ? settings[AutoEmailDispatchService.keySenderEmail]!
            : 'rahuljangu01@gmail.com';
        _senderAppPasswordController.text = (settings[AutoEmailDispatchService.keySenderAppPassword] ?? '').isNotEmpty
            ? settings[AutoEmailDispatchService.keySenderAppPassword]!
            : 'kllvesigpxfyhvst';
        _lastSentDate = settings[AutoEmailDispatchService.keyLastSentDate] ?? '';
        _isLoading = false;
      });
    }
  }

  Future<void> _saveSettings({bool showToast = true}) async {
    final lang = Provider.of<LanguageProvider>(context, listen: false);
    final email = _emailController.text.trim();
    if (_isEnabled && (email.isEmpty || !email.contains('@'))) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(lang.tr(en: 'Please enter a valid email address.', hi: 'कृपया एक वैध ईमेल आईडी दर्ज करें।')),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    await AutoEmailDispatchService.saveSettings(
      enabled: _isEnabled,
      recipientEmail: email,
      cycleMode: 'days_$_intervalDays',
      intervalDays: _intervalDays,
      senderEmail: _senderEmailController.text.trim(),
      senderAppPassword: _senderAppPasswordController.text.trim(),
      lastSentDate: _lastSentDate.isNotEmpty ? _lastSentDate : null,
    );

    if (showToast && mounted) {
      HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(lang.tr(en: 'Settings saved successfully!', hi: 'सेटिंग्स सुरक्षित हो गईं!')),
            ],
          ),
          backgroundColor: const Color(0xFF059669),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /// Quick Send Now - 1-Click Fast Delivery
  Future<void> _quickSendNow() async {
    final lang = Provider.of<LanguageProvider>(context, listen: false);
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(lang.tr(en: 'Please enter your email ID first.', hi: 'कृपया पहले अपनी ईमेल आईडी दर्ज करें।')),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    await _saveSettings(showToast: false);

    setState(() => _isDispatching = true);
    HapticFeedback.selectionClick();

    final result = await AutoEmailDispatchService.dispatchReport(
      overrideRecipient: email,
      isManualTest: true,
    );

    if (!mounted) return;
    setState(() => _isDispatching = false);

    if (result.success) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Color(0xFF059669), size: 26),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  lang.tr(en: 'Email Sent Successfully!', hi: 'ईमेल भेज दी गई!'),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                lang.tr(
                  en: 'Full shop accounts and reports sent to $email.',
                  hi: 'दुकान का पूरा हिसाब $email पर सफलतापूर्वक भेज दिया गया है।',
                ),
                style: const TextStyle(fontSize: 13, height: 1.4, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lang.tr(en: '📁 Attached Files:', hi: '📁 साथ में भेजी गई फ़ाइलें:'),
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 4),
                    const Text('• DM_Lace_Report.pdf (VIP लेज़र हिसाब)', style: TextStyle(fontSize: 11.5, color: Color(0xFF475569))),
                    const Text('• DM_Lace_Transactions.csv (Excel फ़ाइल)', style: TextStyle(fontSize: 11.5, color: Color(0xFF475569))),
                  ],
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
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 11),
                ),
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(lang.tr(en: 'Done', hi: 'ठीक है'), style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<void> _previewPdfReport() async {
    setState(() => _isDispatching = true);
    final reportService = AuditReportService();
    final report = await reportService.gather10DayReportData();
    final pdfFile = await reportService.generatePdfReport(report);
    final pdfBytes = await pdfFile.readAsBytes();

    if (!mounted) return;
    setState(() => _isDispatching = false);

    await Printing.layoutPdf(
      onLayout: (_) async => pdfBytes,
      name: 'DM_Lace_Report_${report.startDate}_${report.endDate}.pdf',
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageProvider>(context);

    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          lang.tr(en: 'Email Account Report', hi: 'ईमेल हिसाब रिपोर्ट'),
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
        ),
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.check_rounded, color: Colors.white),
            tooltip: lang.tr(en: 'Save', hi: 'सेव करें'),
            onPressed: () => _saveSettings(showToast: true),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Status Toggle Card (ON / OFF)
            _buildStatusHeroCard(lang),
            const SizedBox(height: 14),

            // 2. Your Email ID Card
            _buildEmailCard(lang),
            const SizedBox(height: 14),

            // 3. Set Interval Days (कितने दिनों बाद भेजें?)
            _buildDaysSelectorCard(lang),
            const SizedBox(height: 16),

            // 4. Quick Action Buttons (तुरंत अभी भेजें / PDF देखें)
            _buildQuickActionButtons(lang),
            const SizedBox(height: 20),

            // 5. Optional Advanced Sender Settings (Collapsed by default)
            _buildAdvancedSettings(lang),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  /// Clean & Simple Status Toggle Card
  Widget _buildStatusHeroCard(LanguageProvider lang) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _isEnabled
              ? [const Color(0xFF065F46), const Color(0xFF059669)]
              : [const Color(0xFF1E293B), const Color(0xFF334155)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: (_isEnabled ? const Color(0xFF059669) : Colors.black).withValues(alpha: 0.18),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _isEnabled ? Icons.mark_email_read_rounded : Icons.mark_email_unread_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lang.tr(en: 'Automatic Email Report', hi: 'ऑटो ईमेल रिपोर्ट'),
                      style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _isEnabled
                          ? lang.tr(
                              en: '🟢 Active: Reports sent every $_intervalDays days',
                              hi: '🟢 चालू है — हर $_intervalDays दिन में ईमेल जाएगी',
                            )
                          : lang.tr(en: '⚪ Inactive: Email reports turned off', hi: '⚪ बंद है — ईमेल रिपोर्ट बंद है'),
                      style: TextStyle(
                        color: _isEnabled ? const Color(0xFFA7F3D0) : const Color(0xFFE2E8F0),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _isEnabled,
                activeThumbColor: const Color(0xFF10B981),
                activeTrackColor: Colors.white,
                inactiveThumbColor: const Color(0xFF94A3B8),
                inactiveTrackColor: Colors.white30,
                onChanged: (val) {
                  final nowIso = DateTime.now().toIso8601String();
                  setState(() {
                    _isEnabled = val;
                    if (val) {
                      _lastSentDate = nowIso;
                    }
                  });
                  _saveSettings(showToast: false);
                  HapticFeedback.mediumImpact();
                },
              ),
            ],
          ),
          if (_lastSentDate.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Divider(color: Colors.white24, height: 1),
            const SizedBox(height: 8),
            Text(
              lang.tr(en: 'Last Sent: $_lastSentDate', hi: 'पिछली रिपोर्ट: $_lastSentDate'),
              style: const TextStyle(color: Colors.white70, fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }

  /// Simple Clean Email Address Input Card
  Widget _buildEmailCard(LanguageProvider lang) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.02),
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
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.email_outlined, color: Color(0xFF2563EB), size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lang.tr(en: 'Your Email ID', hi: 'आपकी ईमेल आईडी'),
                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      lang.tr(en: 'Full shop accounts and reports will be sent here', hi: 'दुकान का पूरा हिसाब इस ईमेल पर भेजा जाएगा'),
                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
            decoration: InputDecoration(
              hintText: 'e.g. rahuljangu01@gmail.com',
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5)),
              prefixIcon: const Icon(Icons.alternate_email_rounded, color: Color(0xFF64748B), size: 18),
            ),
          ),
        ],
      ),
    );
  }

  /// Direct Days Selector Card (कितने दिनों बाद भेजें?)
  Widget _buildDaysSelectorCard(LanguageProvider lang) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.02),
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
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFAF5FF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.calendar_month_outlined, color: Color(0xFF9333EA), size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lang.tr(en: 'Send After How Many Days?', hi: 'कितने दिनों के बाद भेजें?'),
                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      lang.tr(
                        en: 'Choose interval days for automatic email',
                        hi: 'जितने दिन सेट करेंगे, उतने दिन बाद रिपोर्ट ईमेल पर जाएगी',
                      ),
                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Preset Chips Row
          Row(
            children: _presetDays.map((days) {
              final isSelected = _intervalDays == days;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: InkWell(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      setState(() => _intervalDays = days);
                      _saveSettings(showToast: false);
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0),
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '$days ${lang.tr(en: 'Days', hi: 'दिन')}',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: isSelected ? Colors.white : const Color(0xFF334155),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 14),

          // Stepper Row (- / +)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  lang.tr(en: 'Custom Interval:', hi: 'तय दिन (Custom):'),
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                ),
                Row(
                  children: [
                    // Minus Button
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline_rounded, color: Color(0xFF2563EB), size: 26),
                      onPressed: _intervalDays > 1
                          ? () {
                              HapticFeedback.lightImpact();
                              setState(() => _intervalDays--);
                              _saveSettings(showToast: false);
                            }
                          : null,
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: Text(
                        '$_intervalDays ${lang.tr(en: 'Days', hi: 'दिन')}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    // Plus Button
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline_rounded, color: Color(0xFF2563EB), size: 26),
                      onPressed: _intervalDays < 90
                          ? () {
                              HapticFeedback.lightImpact();
                              setState(() => _intervalDays++);
                              _saveSettings(showToast: false);
                            }
                          : null,
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

  /// ⚡ Quick Send Now & View PDF Buttons
  Widget _buildQuickActionButtons(LanguageProvider lang) {
    return Column(
      children: [
        // ⚡ Quick Send Now Button
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF047857),
              foregroundColor: Colors.white,
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: _isDispatching
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.flash_on_rounded, size: 20),
            label: Text(
              _isDispatching
                  ? lang.tr(en: 'Sending Email...', hi: 'ईमेल भेजी जा रही है...')
                  : lang.tr(en: '⚡ Quick Send Now (तुरंत अभी भेजें)', hi: '⚡ तुरंत अभी ईमेल भेजें (Quick Send)'),
              style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800),
            ),
            onPressed: _isDispatching ? null : _quickSendNow,
          ),
        ),
        const SizedBox(height: 10),
        // View PDF Button
        SizedBox(
          width: double.infinity,
          height: 44,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF0F172A),
              side: const BorderSide(color: Color(0xFF0F172A), width: 1.2),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
            label: Text(
              lang.tr(en: 'View PDF Report 👁️', hi: 'PDF रिपोर्ट देखें 👁️'),
              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
            ),
            onPressed: _isDispatching ? null : _previewPdfReport,
          ),
        ),
      ],
    );
  }

  /// Advanced Settings (Collapsed by default so user is not burdened)
  Widget _buildAdvancedSettings(LanguageProvider lang) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            ListTile(
              onTap: () {
                HapticFeedback.lightImpact();
                setState(() => _showAdvancedApi = !_showAdvancedApi);
              },
              leading: Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.tune_rounded, color: Color(0xFF475569), size: 18),
              ),
              title: Text(
                lang.tr(en: 'Advanced Sender Config', hi: 'उन्नत सेटिंग्स (वैकल्पिक)'),
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
              ),
              subtitle: Text(
                lang.tr(en: 'Pre-configured & ready to send', hi: 'सिस्टम द्वारा पहले से सेट है'),
                style: const TextStyle(fontSize: 11, color: Color(0xFF059669), fontWeight: FontWeight.w600),
              ),
              trailing: Icon(
                _showAdvancedApi ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                color: const Color(0xFF64748B),
              ),
            ),
            if (_showAdvancedApi) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Divider(height: 1, color: Color(0xFFF1F5F9)),
                    const SizedBox(height: 12),
                    Text(
                      lang.tr(en: 'Sender Gmail', hi: 'भेजने वाला Gmail'),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _senderEmailController,
                      keyboardType: TextInputType.emailAddress,
                      style: const TextStyle(fontSize: 13),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      lang.tr(en: 'Google App Password', hi: 'Google App Password'),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _senderAppPasswordController,
                      obscureText: _obscurePassword,
                      style: const TextStyle(fontSize: 13),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                        suffixIcon: IconButton(
                          icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, size: 18),
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
