import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_colors.dart';
import '../../core/database/database_helper.dart';
import '../../core/database/database_tables.dart';
import '../../core/localization/language_provider.dart';
import '../../services/cloudinary_service.dart';
import '../../services/firebase_sync_service.dart';

class FirebaseSyncScreen extends StatefulWidget {
  const FirebaseSyncScreen({super.key});

  @override
  State<FirebaseSyncScreen> createState() => _FirebaseSyncScreenState();
}

class _FirebaseSyncScreenState extends State<FirebaseSyncScreen> {
  final FirebaseSyncService _syncService = FirebaseSyncService();
  final CloudinaryService _cloudinaryService = CloudinaryService();
  final TextEditingController _projectIdController = TextEditingController();
  final TextEditingController _cloudinaryCloudNameController = TextEditingController();
  final TextEditingController _cloudinaryPresetController = TextEditingController();

  bool _isLoading = true;
  bool _isSyncing = false;
  bool _isTestingCloudinary = false;
  String? _cloudinaryTestResult;
  bool _autoSyncEnabled = true;
  String? _lastSyncTime;

  int _localBillsCount = 0;
  int _localPhotosCount = 0;
  int _localTxsCount = 0;
  int _localCatalogCount = 0;
  int _localPartiesCount = 0;
  int _localWorkersCount = 0;
  int _localKataiCount = 0;

  @override
  void initState() {
    super.initState();
    _loadSettingsAndCounts();
  }

  @override
  void dispose() {
    _projectIdController.dispose();
    _cloudinaryCloudNameController.dispose();
    _cloudinaryPresetController.dispose();
    super.dispose();
  }

  Future<void> _loadSettingsAndCounts() async {
    setState(() => _isLoading = true);

    final projectId = await _syncService.getProjectId();
    final autoSync = await _syncService.isAutoSyncEnabled();
    final lastSync = await _syncService.getLastSyncTime();
    final cloudName = await _cloudinaryService.getCloudName();
    final preset = await _cloudinaryService.getUploadPreset();

    final db = await DatabaseHelper.instance.database;
    final bills = await db.rawQuery('SELECT COUNT(*) as cnt FROM ${DatabaseTables.tableDocuments};');
    final photos = await db.rawQuery('SELECT COUNT(*) as cnt FROM ${DatabaseTables.tableDocuments} WHERE (image_path IS NOT NULL AND image_path != "") OR (image_base64 IS NOT NULL AND image_base64 != "") OR (image_url IS NOT NULL AND image_url != "");');
    final txs = await db.rawQuery('SELECT COUNT(*) as cnt FROM ${DatabaseTables.tableTransactions};');
    final catalog = await db.rawQuery('SELECT COUNT(*) as cnt FROM ${DatabaseTables.tableInventoryItems};');
    final parties = await db.rawQuery('SELECT COUNT(*) as cnt FROM ${DatabaseTables.tableParties};');
    final workers = await db.rawQuery('SELECT COUNT(*) as cnt FROM ${DatabaseTables.tableWorkers};');
    final katai = await db.rawQuery('SELECT COUNT(*) as cnt FROM ${DatabaseTables.tableMachineKataiEntries};');

    if (mounted) {
      setState(() {
        _projectIdController.text = projectId;
        _cloudinaryCloudNameController.text = cloudName;
        _cloudinaryPresetController.text = preset;
        _autoSyncEnabled = autoSync;
        _lastSyncTime = lastSync;
        _localBillsCount = (bills.first['cnt'] as int?) ?? 0;
        _localPhotosCount = (photos.first['cnt'] as int?) ?? 0;
        _localTxsCount = (txs.first['cnt'] as int?) ?? 0;
        _localCatalogCount = (catalog.first['cnt'] as int?) ?? 0;
        _localPartiesCount = (parties.first['cnt'] as int?) ?? 0;
        _localWorkersCount = (workers.first['cnt'] as int?) ?? 0;
        _localKataiCount = (katai.first['cnt'] as int?) ?? 0;
        _isLoading = false;
      });
    }
  }

  Future<void> _handleSyncNow(LanguageProvider lang) async {
    HapticFeedback.mediumImpact();
    setState(() => _isSyncing = true);

    final result = await _syncService.syncAllToCloud();

    if (!mounted) return;
    setState(() {
      _isSyncing = false;
      _lastSyncTime = result.timestamp.toIso8601String();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Color(0xFF22C55E)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                lang.tr(
                  en: 'Cloud Sync Complete! All bills & catalog secured.',
                  hi: 'क्लाउड सिंक पूरा हुआ! सभी बिल व कैटलॉग सुरक्षित हैं।',
                ),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF0F172A),
      ),
    );
  }

  Future<void> _saveConfig(LanguageProvider lang) async {
    HapticFeedback.lightImpact();
    await _syncService.saveSettings(
      projectId: _projectIdController.text.trim(),
      autoSync: _autoSyncEnabled,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(lang.tr(en: 'Settings saved successfully!', hi: 'सेटिंग्स सफलतापूर्वक सेव हो गईं!')),
        backgroundColor: const Color(0xFF0F172A),
      ),
    );
  }

  Future<void> _saveCloudinaryConfig(LanguageProvider lang) async {
    HapticFeedback.lightImpact();
    await _cloudinaryService.saveConfig(
      cloudName: _cloudinaryCloudNameController.text.trim(),
      uploadPreset: _cloudinaryPresetController.text.trim(),
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(lang.tr(en: 'Cloudinary configuration saved!', hi: 'Cloudinary सेटिंग्स सफलतापूर्वक सेव हो गईं!')),
        backgroundColor: const Color(0xFF0F172A),
      ),
    );
  }

  Future<void> _testCloudinaryConnection(LanguageProvider lang) async {
    HapticFeedback.mediumImpact();
    setState(() {
      _isTestingCloudinary = true;
      _cloudinaryTestResult = null;
    });

    // 1x1 transparent PNG pixel bytes for connection test
    final testPixelBytes = Uint8List.fromList([
      0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
      0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
      0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
      0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
      0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
      0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
    ]);

    final res = await _cloudinaryService.uploadBytes(
      testPixelBytes,
      filename: 'connection_test.png',
      tag: 'test_connection',
    );

    if (!mounted) return;
    setState(() {
      _isTestingCloudinary = false;
      if (res.success && res.url != null) {
        _cloudinaryTestResult = res.url;
      } else {
        _cloudinaryTestResult = 'ERR: ${res.errorMessage ?? "Upload failed"}';
      }
    });

    if (res.success) {
      final lang = Provider.of<LanguageProvider>(context, listen: false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(lang.tr(
            en: '✅ Cloudinary connection active! Photos will upload directly to cloud.',
            hi: '✅ Cloudinary कनेक्शन 100% चालू है! फोटो सीधे क्लाउड लिंक में सेव होंगी।',
          )),
          backgroundColor: const Color(0xFF15803D),
        ),
      );
    } else {
      final lang = Provider.of<LanguageProvider>(context, listen: false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(lang.tr(
            en: '❌ Cloudinary test failed: ${res.errorMessage}',
            hi: '❌ Cloudinary टेस्ट फ़ेल: ${res.errorMessage}',
          )),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        backgroundColor: const Color(0xFF030713),
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              lang.tr(en: 'Google Firebase Cloud Sync', hi: 'Google Firebase क्लाउड सिंक'),
              style: const TextStyle(
                color: Color(0xFFFDE047),
                fontSize: 16.5,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              ),
            ),
            Text(
              lang.tr(
                en: '100% Free Lifetime • Multi-Device Access',
                hi: '100% मुफ़्त आजीवन • किसी भी डिवाइस में देखें',
              ),
              style: const TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 10.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryGold))
          : ListView(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 30),
              children: [
                // 1. VIP Live Cloud Status Card
                _buildCloudStatusCard(lang),

                const SizedBox(height: 14),

                // 2. 4-Grid Metric Counter (Bills, Txs, Catalog, Parties)
                _buildMetricsGrid(lang),

                const SizedBox(height: 16),

                // 3. Main Sync Now Action Button
                ElevatedButton(
                  onPressed: _isSyncing ? null : () => _handleSyncNow(lang),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD4AF37),
                    foregroundColor: const Color(0xFF0F172A),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _isSyncing
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0F172A))),
                            const SizedBox(width: 10),
                            Text(
                              lang.tr(en: 'Syncing data to cloud...', hi: 'क्लाउड में डेटा भेजा जा रहा है...'),
                              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                            ),
                          ],
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.cloud_upload_rounded, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              lang.tr(en: 'Sync All Data Now', hi: 'क्लाउड में सिंक करें'),
                              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                            ),
                          ],
                        ),
                ),

                const SizedBox(height: 16),

                // 4. Live Cloud Database View Card
                _buildLiveCloudViewerCard(lang),

                const SizedBox(height: 16),

                // 5. Cloudinary Image Storage Card
                _buildCloudinaryCard(lang),

                const SizedBox(height: 16),

                // 6. Cloud Settings (Project ID & Auto Sync Switch)
                _buildSettingsCard(lang),
              ],
            ),
    );
  }

  Widget _buildCloudStatusCard(LanguageProvider lang) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF040B18), Color(0xFF0A1832), Color(0xFF142444)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFD4AF37).withValues(alpha: 0.65), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD4AF37).withValues(alpha: 0.20),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: Color(0xFF22C55E),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                lang.tr(en: 'GOOGLE FIREBASE CLOUD ACTIVE', hi: 'GOOGLE FIREBASE क्लाउड एक्टिव'),
                style: const TextStyle(
                  color: Color(0xFF4ADE80),
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFD4AF37).withValues(alpha: 0.20),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFDE047), width: 0.8),
                ),
                child: const Text(
                  '100% FREE',
                  style: TextStyle(color: Color(0xFFFDE047), fontSize: 9.5, fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            lang.tr(
              en: 'Your Surat Textile Ledger is Connected',
              hi: 'सूरत टेक्सटाइल बहीखाता क्लाउड से जुड़ा है',
            ),
            style: const TextStyle(color: Color(0xFFFFFBEB), fontSize: 16, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(
            _lastSyncTime != null
                ? '${lang.tr(en: 'Last Synced: ', hi: 'अंतिम सिंक: ')}${_lastSyncTime!.substring(0, 10)} ${_lastSyncTime!.substring(11, 16)}'
                : lang.tr(en: 'Ready to sync all local data to cloud', hi: 'सभी बिल व कैटलॉग क्लाउड में सिंक करने हेतु तैयार'),
            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11.5, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          // Multi-Device Badges
          Row(
            children: [
              _buildDeviceBadge(Icons.smartphone_rounded, 'Mobile'),
              const SizedBox(width: 6),
              _buildDeviceBadge(Icons.laptop_chromebook_rounded, 'Laptop'),
              const SizedBox(width: 6),
              _buildDeviceBadge(Icons.desktop_windows_rounded, 'Desktop'),
              const SizedBox(width: 6),
              _buildDeviceBadge(Icons.language_rounded, 'Browser'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceBadge(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: const Color(0xFFFDE047)),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(color: Color(0xFFE2E8F0), fontSize: 9.5, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _buildMetricsGrid(LanguageProvider lang) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _buildMetricTile(lang.tr(en: 'Parties', hi: 'पार्टी'), _localPartiesCount, Icons.people_alt_rounded, const Color(0xFFD97706))),
            const SizedBox(width: 8),
            Expanded(child: _buildMetricTile(lang.tr(en: 'Bills & Challans', hi: 'चालान व बिल'), _localBillsCount, Icons.receipt_long_rounded, const Color(0xFF1E3A8A))),
            const SizedBox(width: 8),
            Expanded(child: _buildMetricTile(lang.tr(en: 'Slip Photos 📷', hi: 'पर्ची फोटो 📷'), _localPhotosCount, Icons.photo_camera_rounded, const Color(0xFFB45309))),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _buildMetricTile(lang.tr(en: 'Payments', hi: 'लेन-देन'), _localTxsCount, Icons.currency_rupee_rounded, const Color(0xFF10B981))),
            const SizedBox(width: 8),
            Expanded(child: _buildMetricTile(lang.tr(en: 'Catalog', hi: 'लेस स्टॉक'), _localCatalogCount, Icons.photo_library_rounded, const Color(0xFF8B5CF6))),
            const SizedBox(width: 8),
            Expanded(
              child: _buildMetricTile(
                lang.tr(en: 'Karigar/Katai', hi: 'कारीगर/कटाई'),
                _localWorkersCount,
                Icons.engineering_rounded,
                const Color(0xFF0D9488),
                subtitle: _localKataiCount > 0 ? '$_localKataiCount ${lang.tr(en: 'rolls', hi: 'कटाई')}' : null,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLiveCloudViewerCard(LanguageProvider lang) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD4AF37).withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD4AF37).withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.public_rounded, color: Color(0xFFFDE047), size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lang.tr(en: 'Live Online Cloud Database', hi: 'लाइव ऑनलाइन क्लाउड डेटाबेस'),
                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                    ),
                    Text(
                      lang.tr(
                        en: 'View all bills, parties & items live in any browser',
                        hi: 'किसी भी ब्राउज़र (Chrome/Mobile) में लाइव डेटा देखें',
                      ),
                      style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final uri = Uri.parse(FirebaseSyncService.liveCloudViewerUrl);
                    try {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    } catch (_) {}
                  },
                  icon: const Icon(Icons.open_in_new_rounded, size: 15),
                  label: Text(
                    lang.tr(en: 'Open in Browser', hi: 'ब्राउज़र में खोलें'),
                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF0F172A),
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () {
                  Clipboard.setData(const ClipboardData(text: FirebaseSyncService.liveCloudViewerUrl));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        lang.tr(en: 'Cloud Database link copied!', hi: 'क्लाउड डेटाबेस लिंक कॉपी हो गया!'),
                      ),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
                icon: const Icon(Icons.copy_rounded, size: 15),
                label: Text(
                  lang.tr(en: 'Copy Link', hi: 'लिंक कॉपी करें'),
                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF0F172A),
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile(String title, int count, IconData icon, Color color, {String? subtitle}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 4),
          Text(
            '$count',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
          ),
          Text(
            title,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (subtitle != null)
            Text(
              subtitle,
              style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.w600, color: Color(0xFF0D9488)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
    );
  }

  Widget _buildSettingsCard(LanguageProvider lang) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            lang.tr(en: 'Firebase Cloud Configuration', hi: 'Firebase क्लाउड सेटिंग्स'),
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _projectIdController,
            decoration: InputDecoration(
              labelText: lang.tr(en: 'Firebase Project ID', hi: 'Firebase प्रोजेक्ट ID'),
              hintText: 'dm-lace-surat',
              labelStyle: const TextStyle(fontSize: 12),
              isDense: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              lang.tr(en: 'Auto-Sync on Bill Save', hi: 'बिल सेव होते ही ऑटो सिंक'),
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
            ),
            subtitle: Text(
              lang.tr(en: 'Automatically push every new bill & payment to cloud', hi: 'हर नए बिल व पेमेंट को तुरंत क्लाउड में सुरक्षित भेजें'),
              style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
            ),
            value: _autoSyncEnabled,
            activeThumbColor: AppColors.primaryGold,
            onChanged: (val) => setState(() => _autoSyncEnabled = val),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => _saveConfig(lang),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF0F172A)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(
                lang.tr(en: 'Save Configuration', hi: 'कॉन्फ़िगरेशन सेव करें'),
                style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCloudinaryCard(LanguageProvider lang) {
    final hasSuccess = _cloudinaryTestResult != null && !_cloudinaryTestResult!.startsWith('ERR:');

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasSuccess ? const Color(0xFF22C55E) : const Color(0xFF0284C7).withValues(alpha: 0.3),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0284C7).withValues(alpha: 0.05),
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
                  color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.cloud_circle_rounded, color: Color(0xFF0284C7), size: 20),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lang.tr(en: 'Cloudinary Image Vault (100% Free)', hi: 'Cloudinary पर्ची फोटो क्लाउड (100% मुफ़्त)'),
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                    ),
                    Text(
                      lang.tr(en: 'Direct HTTPS links saved in Firebase Firestore', hi: 'Firebase में सीधी HTTPS लिंक सेव होती है'),
                      style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFF86EFAC)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.lock_rounded, size: 10, color: Color(0xFF15803D)),
                    SizedBox(width: 3),
                    Text(
                      'SECURE',
                      style: TextStyle(color: Color(0xFF15803D), fontSize: 9.5, fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _cloudinaryCloudNameController,
            decoration: InputDecoration(
              labelText: lang.tr(en: 'Cloudinary Cloud Name', hi: 'Cloudinary Cloud Name (खाता नाम)'),
              hintText: 'dmlace',
              labelStyle: const TextStyle(fontSize: 12),
              isDense: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _cloudinaryPresetController,
            decoration: InputDecoration(
              labelText: lang.tr(en: 'Upload Preset (Unsigned)', hi: 'Upload Preset (अपलोड प्रीसेट)'),
              hintText: 'dm_slips',
              labelStyle: const TextStyle(fontSize: 12),
              isDense: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          if (_cloudinaryTestResult != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: hasSuccess ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: hasSuccess ? const Color(0xFF86EFAC) : const Color(0xFFFECACA)),
              ),
              child: Row(
                children: [
                  Icon(
                    hasSuccess ? Icons.check_circle_rounded : Icons.error_rounded,
                    size: 16,
                    color: hasSuccess ? const Color(0xFF15803D) : const Color(0xFFDC2626),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      hasSuccess
                          ? lang.tr(
                              en: '✅ Connection active! Test photo uploaded:\n${_cloudinaryTestResult!}',
                              hi: '✅ कनेक्शन सक्रिय! टेस्ट फोटो अपलोड हुई:\n${_cloudinaryTestResult!}',
                            )
                          : lang.tr(
                              en: '❌ Test failed: ${_cloudinaryTestResult!.replaceFirst("ERR: ", "")}',
                              hi: '❌ टेस्ट विफल: ${_cloudinaryTestResult!.replaceFirst("ERR: ", "")}',
                            ),
                      style: TextStyle(
                        fontSize: 10.5,
                        color: hasSuccess ? const Color(0xFF15803D) : const Color(0xFFDC2626),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _saveCloudinaryConfig(lang),
                  icon: const Icon(Icons.save_rounded, size: 16, color: Color(0xFF0F172A)),
                  label: Text(
                    lang.tr(en: 'Save Settings', hi: 'सेटिंग्स सेव करें'),
                    style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w800, fontSize: 12),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF0F172A)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isTestingCloudinary ? null : () => _testCloudinaryConnection(lang),
                  icon: _isTestingCloudinary
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.send_rounded, size: 16),
                  label: Text(
                    lang.tr(en: 'Test Upload', hi: 'टेस्ट अपलोड'),
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0284C7),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
