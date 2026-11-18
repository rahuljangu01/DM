import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/database/database_helper.dart';
import '../../core/database/database_tables.dart';
import '../../core/localization/language_provider.dart';
import '../../models/party.dart';
import '../../repositories/party_repository.dart';
import '../../widgets/empty_state.dart';

class RecycleBinScreen extends StatefulWidget {
  const RecycleBinScreen({super.key});

  @override
  State<RecycleBinScreen> createState() => _RecycleBinScreenState();
}

class _RecycleBinScreenState extends State<RecycleBinScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final PartyRepository _partyRepo = PartyRepository();

  List<Map<String, dynamic>> _deletedRecords = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDeletedRecords();
  }

  Future<void> _loadDeletedRecords() async {
    setState(() => _isLoading = true);
    final db = await _dbHelper.database;
    final records = await db.query(
      DatabaseTables.tableDeletedRecords,
      where: 'is_restored = 0',
      orderBy: 'id DESC',
    );
    if (mounted) {
      setState(() {
        _deletedRecords = records;
        _isLoading = false;
      });
    }
  }

  Future<void> _restoreRecord(Map<String, dynamic> record, LanguageProvider lang) async {
    HapticFeedback.mediumImpact();
    final db = await _dbHelper.database;
    final id = record['id'] as int;
    final entityType = record['entity_type'] as String;
    final jsonStr = record['details_json'] as String;

    try {
      if (entityType == 'party') {
        final data = jsonDecode(jsonStr) as Map<String, dynamic>;
        data.remove('id');
        data['is_archived'] = 0;
        await _partyRepo.insertParty(Party.fromMap(data));
      }

      await db.update(
        DatabaseTables.tableDeletedRecords,
        {'is_restored': 1},
        where: 'id = ?',
        whereArgs: [id],
      );

      _loadDeletedRecords();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Color(0xFF22C55E)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  lang.tr(
                    en: '${record['title']} restored successfully!',
                    hi: '${record['title']} सफलतापूर्वक वापस आ गया!',
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF0F172A),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to restore: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppColors.primaryNavy,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              lang.tr(en: 'Recycle Bin & Safe Archive', hi: 'रीसायकल बिन व सुरक्षित आर्काइव'),
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16.5, color: Colors.white),
            ),
            Text(
              lang.tr(
                en: 'Firebase Cloud & Local Protected Vault',
                hi: 'Google Firebase व फ़ोन में सुरक्षित रिकॉर्ड्स',
              ),
              style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: AppColors.primaryGold),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryGold))
          : _deletedRecords.isEmpty
              ? EmptyState(
                  icon: Icons.delete_sweep_rounded,
                  title: lang.tr(en: 'Recycle Bin is Empty', hi: 'रीसायकल बिन खाली है'),
                  message: lang.tr(
                    en: 'Whenever you delete any party, bill, or payment, a copy is automatically preserved here and in Firebase.',
                    hi: 'जब भी आप कोई पार्टी, बिल या पेमेंट डिलीट करेंगे, उसकी एक सुरक्षित कॉपी यहाँ और Firebase में हमेशा सेफ़ रहेगी।',
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 14, 12, 30),
                  itemCount: _deletedRecords.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final item = _deletedRecords[index];
                    final entityType = (item['entity_type'] as String?) ?? 'record';
                    final title = item['title'] as String? ?? 'Untitled';
                    final subtitle = item['subtitle'] as String? ?? '';
                    final deletedAt = item['deleted_at'] as String? ?? '';
                    final formattedDate = deletedAt.length >= 16 ? deletedAt.substring(0, 16).replaceAll('T', ' ') : deletedAt;

                    Color badgeColor;
                    String badgeLabel;
                    IconData iconData;

                    switch (entityType) {
                      case 'party':
                        badgeColor = const Color(0xFFD97706);
                        badgeLabel = lang.tr(en: 'PARTY', hi: 'पार्टी');
                        iconData = Icons.person_rounded;
                        break;
                      case 'bill':
                        badgeColor = const Color(0xFF2563EB);
                        badgeLabel = lang.tr(en: 'BILL', hi: 'कच्चा बिल');
                        iconData = Icons.receipt_long_rounded;
                        break;
                      case 'transaction':
                        badgeColor = const Color(0xFF10B981);
                        badgeLabel = lang.tr(en: 'PAYMENT', hi: 'पेमेंट');
                        iconData = Icons.currency_rupee_rounded;
                        break;
                      default:
                        badgeColor = const Color(0xFF64748B);
                        badgeLabel = entityType.toUpperCase();
                        iconData = Icons.archive_rounded;
                    }

                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        leading: CircleAvatar(
                          radius: 20,
                          backgroundColor: const Color(0xFFFEE2E2),
                          child: Icon(iconData, size: 20, color: const Color(0xFFDC2626)),
                        ),
                        title: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: badgeColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                badgeLabel,
                                style: TextStyle(
                                  color: badgeColor,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13.5,
                                  color: Color(0xFF0F172A),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (subtitle.isNotEmpty) ...[
                              const SizedBox(height: 3),
                              Text(
                                subtitle,
                                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                              ),
                            ],
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.cloud_done_rounded, size: 12, color: Color(0xFF10B981)),
                                const SizedBox(width: 4),
                                const Text(
                                  'Firebase Vault • ',
                                  style: TextStyle(fontSize: 10, color: Color(0xFF10B981), fontWeight: FontWeight.w700),
                                ),
                                Text(
                                  formattedDate,
                                  style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
                                ),
                              ],
                            ),
                          ],
                        ),
                        trailing: ElevatedButton.icon(
                          onPressed: () => _restoreRecord(item, lang),
                          icon: const Icon(Icons.restore_rounded, size: 15),
                          label: Text(
                            lang.tr(en: 'Restore', hi: 'वापस लाएं'),
                            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFECFDF5),
                            foregroundColor: const Color(0xFF059669),
                            elevation: 0,
                            side: const BorderSide(color: Color(0xFFA7F3D0)),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
