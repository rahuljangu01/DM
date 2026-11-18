import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/localization/language_provider.dart';
import '../../core/utils/date_formatter.dart';
import '../../services/audit_service.dart';

class AuditLogsScreen extends StatefulWidget {
  const AuditLogsScreen({super.key});

  @override
  State<AuditLogsScreen> createState() => _AuditLogsScreenState();
}

class _AuditLogsScreenState extends State<AuditLogsScreen> {
  final AuditService _auditService = AuditService.instance;
  List<AuditLogEntry> _logs = [];
  bool _isLoading = true;
  String _selectedFilter = 'All';

  final List<String> _filters = ['All', 'BILL', 'PAYMENT', 'PARTY', 'INVENTORY', 'SECURITY'];

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    setState(() => _isLoading = true);
    final logs = await _auditService.getLogs();
    if (mounted) {
      setState(() {
        _logs = logs;
        _isLoading = false;
      });
    }
  }

  String _normalizeType(String type) {
    final t = type.toUpperCase();
    if (t == 'DOCUMENT') return 'BILL';
    if (t == 'TRANSACTION') return 'PAYMENT';
    return t;
  }

  List<AuditLogEntry> get _filteredLogs {
    if (_selectedFilter == 'All') return _logs;
    return _logs.where((l) => _normalizeType(l.entityType) == _selectedFilter).toList();
  }

  IconData _getIconForType(String type) {
    switch (_normalizeType(type)) {
      case 'BILL':
        return Icons.receipt_long_rounded;
      case 'PAYMENT':
        return Icons.currency_rupee_rounded;
      case 'PARTY':
        return Icons.person_outline_rounded;
      case 'INVENTORY':
        return Icons.inventory_2_outlined;
      case 'SECURITY':
        return Icons.shield_outlined;
      default:
        return Icons.info_outline_rounded;
    }
  }

  Color _getColorForAction(String action) {
    final act = action.toUpperCase();
    if (act.contains('DELETE') || act.contains('REMOVE') || act.contains('CANCEL') || act.contains('DISABLE')) {
      return AppColors.payableRed;
    } else if (act.contains('CREATE') || act.contains('ADD') || act.contains('ENABLE')) {
      return AppColors.successGreen;
    } else if (act.contains('UPDATE') || act.contains('EDIT')) {
      return const Color(0xFF2563EB);
    }
    return const Color(0xFFD97706);
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final logs = _filteredLogs;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        title: Text(lang.tr(en: 'Security & Audit Trail', hi: 'सुरक्षा ऑडिट ट्रेल')),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Logs',
            onPressed: _loadLogs,
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Column(
            children: [
              // Security Header Banner
              Container(
                margin: const EdgeInsets.all(12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF060F1E), Color(0xFF132B4F)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 8, offset: const Offset(0, 2)),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFDE047).withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFFD4AF37)),
                      ),
                      child: const Icon(Icons.verified_user_rounded, color: Color(0xFFFDE047), size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Tamper-Proof Audit Logging Active',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            lang.tr(
                              en: 'All bill, payment, stock, and security changes are permanently recorded locally.',
                              hi: 'सभी बिल, भुगतान, स्टॉक और सुरक्षा बदलाव यहां स्थायी रूप से दर्ज होते हैं।',
                            ),
                            style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Filter Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: _filters.map((f) {
                    final isSelected = _selectedFilter == f;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6.0),
                      child: ChoiceChip(
                        label: Text(f, style: TextStyle(fontSize: 11.5, fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600, color: isSelected ? Colors.white : AppColors.textPrimary)),
                        selected: isSelected,
                        selectedColor: AppColors.primaryNavy,
                        backgroundColor: Colors.white,
                        showCheckmark: false,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        onSelected: (val) {
                          if (val) setState(() => _selectedFilter = f);
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 10),

              // Log Items
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(color: AppColors.primaryNavy))
                    : logs.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.shield_outlined, size: 54, color: Color(0xFFCBD5E1)),
                                const SizedBox(height: 10),
                                Text(
                                  lang.tr(en: 'No Audit Records Found', hi: 'कोई ऑडिट रिकॉर्ड नहीं मिला'),
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                            itemCount: logs.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 8),
                            itemBuilder: (context, idx) {
                              final entry = logs[idx];
                              final actionColor = _getColorForAction(entry.action);

                              return Card(
                                color: Colors.white,
                                elevation: 1,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: actionColor.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Icon(_getIconForType(entry.entityType), color: actionColor, size: 20),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: actionColor.withValues(alpha: 0.12),
                                                    borderRadius: BorderRadius.circular(6),
                                                  ),
                                                  child: Text(
                                                    '${_normalizeType(entry.entityType)} • ${entry.action.toUpperCase()}',
                                                    style: TextStyle(color: actionColor, fontWeight: FontWeight.w900, fontSize: 10.5),
                                                  ),
                                                ),
                                                Text(
                                                  DateFormatter.formatWithTime(DateFormatter.parse(entry.createdAt)),
                                                  style: const TextStyle(color: AppColors.textMuted, fontSize: 10),
                                                ),
                                              ],
                                            ),
                                            if (entry.details != null && entry.details!.isNotEmpty) ...[
                                              const SizedBox(height: 5),
                                              Text(
                                                entry.details!,
                                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
