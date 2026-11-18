import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/localization/language_provider.dart';
import '../../services/backup_service.dart';
import '../../widgets/confirmation_dialog.dart';

class BackupRestoreScreen extends StatefulWidget {
  final BackupService? service;

  const BackupRestoreScreen({super.key, this.service});

  @override
  State<BackupRestoreScreen> createState() => _BackupRestoreScreenState();
}

class _BackupRestoreScreenState extends State<BackupRestoreScreen> {
  late BackupService _backupService;
  bool _isBackingUp = false;
  bool _isRestoring = false;

  @override
  void initState() {
    super.initState();
    _backupService = widget.service ?? BackupService();
  }

  Future<void> _handleBackup() async {
    setState(() => _isBackingUp = true);
    try {
      await _backupService.exportAndShareBackup();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Backup generated and shared successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Backup failed: $e'), backgroundColor: AppColors.payableRed),
        );
      }
    } finally {
      if (mounted) setState(() => _isBackingUp = false);
    }
  }

  Future<void> _handleRestore() async {
    final textController = TextEditingController();

    final enteredJson = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore Database Backup'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Paste the full JSON content from your previous DM Lace Surat backup file below.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Backup JSON Data:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                TextButton.icon(
                  onPressed: () async {
                    final clip = await Clipboard.getData(Clipboard.kTextPlain);
                    if (clip?.text != null) {
                      textController.text = clip!.text!;
                    }
                  },
                  icon: const Icon(Icons.paste_rounded, size: 14),
                  label: Text(
                    Provider.of<LanguageProvider>(context, listen: false).tr(en: 'Paste from Clipboard', hi: 'क्लिपबोर्ड से पेस्ट करें'),
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            TextField(
              controller: textController,
              maxLines: 6,
              decoration: const InputDecoration(
                hintText: '{"checksum":"...","payload":{...}}',
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(null), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryNavy),
            onPressed: () => Navigator.of(context).pop(textController.text.trim()),
            child: const Text('Verify & Restore'),
          ),
        ],
      ),
    );

    if (enteredJson == null || enteredJson.isEmpty) return;

    final validated = _backupService.validateBackup(enteredJson);
    if (validated == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invalid backup file! Checksum verification failed or format invalid.'),
            backgroundColor: AppColors.payableRed,
          ),
        );
      }
      return;
    }

    if (!mounted) return;
    final confirm = await ConfirmationDialog.show(
      context: context,
      title: 'Replace Current Database?',
      message: 'Restoring will completely replace your current parties, bills, payments, and stock with the data from this backup file. Are you sure you wish to continue?',
      confirmText: 'Replace & Restore',
      isDestructive: true,
    );

    if (confirm != true) return;

    setState(() => _isRestoring = true);
    try {
      final success = await _backupService.restoreBackup(enteredJson);
      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Database successfully restored! All accounts updated.')),
          );
          Navigator.of(context).pop(true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Restore failed during database insertion.'), backgroundColor: AppColors.payableRed),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Restore error: $e'), backgroundColor: AppColors.payableRed),
        );
      }
    } finally {
      if (mounted) setState(() => _isRestoring = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: Text(lang.tr(en: 'Backup & Restore', hi: 'डेटा बैकअप व रीस्टोर')),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Offline-First Notice Card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFFCD34D)),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.lock_clock_outlined, color: Color(0xFFB45309), size: 24),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '100% Offline & Private Storage',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF92400E)),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Your business data is stored locally in an encrypted SQLite database on this device only and is NOT automatically synced to cloud servers. Regular manual backups to WhatsApp, Google Drive or Email are strongly advised.',
                        style: TextStyle(fontSize: 12, color: Color(0xFF78350F), height: 1.3),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Export Backup Card
          Card(
            color: AppColors.surfaceWhite,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.cloud_upload_outlined, color: AppColors.primaryNavy),
                      SizedBox(width: 8),
                      Text('Export Business Backup', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Creates an encrypted, verified JSON backup containing all parties, bills, delivery challans, cashbook transactions, lace inventory, and settings.',
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryNavy,
                      minimumSize: const Size.fromHeight(46),
                    ),
                    icon: _isBackingUp
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.share),
                    label: const Text('Export & Share Backup', style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: _isBackingUp ? null : _handleBackup,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Restore Backup Card
          Card(
            color: AppColors.surfaceWhite,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.restore_page_outlined, color: AppColors.payableRed),
                      SizedBox(width: 8),
                      Text('Restore from Backup', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Restore business records onto this device from a previously created valid backup. Existing data will be safely verified with cryptographic SHA-256 integrity checksum before replacing.',
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.payableRed,
                      side: const BorderSide(color: AppColors.payableRed),
                      minimumSize: const Size.fromHeight(46),
                    ),
                    icon: _isRestoring
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: AppColors.payableRed, strokeWidth: 2))
                        : const Icon(Icons.download_for_offline_outlined),
                    label: const Text('Restore Database', style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: _isRestoring ? null : _handleRestore,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
