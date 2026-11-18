import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_colors.dart';
import '../../core/localization/language_provider.dart';
import '../../core/utils/currency_formatter.dart';
import '../../models/worker.dart';
import '../../models/machine_katai_entry.dart';
import '../../models/worker_payment.dart';
import '../../repositories/worker_repository.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/compact_fab.dart';
import 'record_katai_dialog.dart';
import 'record_worker_payment_dialog.dart';

class WorkerLedgerScreen extends StatefulWidget {
  final int workerId;
  final WorkerRepository repository;

  const WorkerLedgerScreen({
    super.key,
    required this.workerId,
    required this.repository,
  });

  @override
  State<WorkerLedgerScreen> createState() => _WorkerLedgerScreenState();
}

class _WorkerLedgerScreenState extends State<WorkerLedgerScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Worker? _worker;
  Map<String, dynamic>? _summary;
  List<MachineKataiEntry> _kataiEntries = [];
  List<WorkerPayment> _payments = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final w = await widget.repository.getWorkerById(widget.workerId);
    final s = await widget.repository.getWorkerWageSummary(widget.workerId);
    final k = await widget.repository.getKataiEntries(workerId: widget.workerId);
    final p = await widget.repository.getWorkerPayments(widget.workerId);

    if (mounted) {
      setState(() {
        _worker = w;
        _summary = s;
        _kataiEntries = k;
        _payments = p;
        _isLoading = false;
      });
    }
  }

  String _buildStatementText(LanguageProvider lang) {
    if (_worker == null || _summary == null) return '';
    final netPayable = CurrencyFormatter.format(
      CurrencyFormatter.paiseToRupees((_summary!['netPayablePaise'] as int).abs()),
    );
    final isPayable = (_summary!['netPayablePaise'] as int) >= 0;

    if (lang.isHindi) {
      return '''
*DM LACE SURAT*
सूरत टेक्सटाइल मार्केट
----------------------------------------
कारीगर मजदूरी हिसाब
कारीगर: ${_worker!.name}
मोबाइल: ${_worker!.phone ?? "N/A"}
मशीन: ${_worker!.machineNumber ?? "General"}
मजदूरी प्रकार: ${_worker!.wageTypeDisplay(true)}
----------------------------------------
उत्पादन व कमाई:
• कुल कटाई: ${_summary!['totalKataiMeters']} मीटर
• कुल कमाई: ₹ ${CurrencyFormatter.format(CurrencyFormatter.paiseToRupees(_summary!['totalEarnedPaise'] as int), includeSymbol: false)}
• उठाव / एडवांस: ₹ ${CurrencyFormatter.format(CurrencyFormatter.paiseToRupees(_summary!['totalAdvancePaise'] as int), includeSymbol: false)}
• चुकाई गई मजदूरी: ₹ ${CurrencyFormatter.format(CurrencyFormatter.paiseToRupees(_summary!['totalWagePaidPaise'] as int), includeSymbol: false)}
----------------------------------------
शुद्ध बकाया हिसाब: ${isPayable ? "देना बाकी" : "एडवांस निकला"} $netPayable
----------------------------------------
DM Lace Surat • सूरत टेक्सटाइल मार्केट
''';
    } else {
      return '''
*DM LACE SURAT*
Surat Textile Market
----------------------------------------
Worker Wage Statement
Worker: ${_worker!.name}
Mobile: ${_worker!.phone ?? "N/A"}
Machine: ${_worker!.machineNumber ?? "General"}
Wage Type: ${_worker!.wageTypeDisplay(false)}
----------------------------------------
Production & Earnings:
• Total Katai: ${_summary!['totalKataiMeters']} Meters
• Total Earned: ₹ ${CurrencyFormatter.format(CurrencyFormatter.paiseToRupees(_summary!['totalEarnedPaise'] as int), includeSymbol: false)}
• Advance / Loan: ₹ ${CurrencyFormatter.format(CurrencyFormatter.paiseToRupees(_summary!['totalAdvancePaise'] as int), includeSymbol: false)}
• Wages Paid: ₹ ${CurrencyFormatter.format(CurrencyFormatter.paiseToRupees(_summary!['totalWagePaidPaise'] as int), includeSymbol: false)}
----------------------------------------
Net Balance: ${isPayable ? "Net Payable" : "Excess Advance"} $netPayable
----------------------------------------
DM Lace Surat • Surat Textile Market
''';
    }
  }

  void _shareStatement(LanguageProvider lang) {
    final text = _buildStatementText(lang);
    if (text.isEmpty) return;
    // ignore: deprecated_member_use
    Share.share(text);
  }

  Future<void> _shareOnWhatsApp(LanguageProvider lang) async {
    final text = _buildStatementText(lang);
    if (text.isEmpty) return;

    if (_worker!.phone != null && _worker!.phone!.isNotEmpty) {
      final clean = _worker!.phone!.replaceAll(RegExp(r'[^0-9]'), '');
      final phoneWithCode = clean.length == 10 ? '91$clean' : clean;
      final uri = Uri.parse('https://wa.me/$phoneWithCode?text=${Uri.encodeComponent(text)}');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
    }
    // ignore: deprecated_member_use
    Share.share(text);
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text(lang.tr(en: 'Worker Ledger', hi: 'कारीगर हिसाब-किताब'))),
        body: const Center(child: CircularProgressIndicator(color: AppColors.primaryGold)),
      );
    }

    if (_worker == null) {
      return Scaffold(
        appBar: AppBar(title: Text(lang.tr(en: 'Worker Not Found', hi: 'कारीगर नहीं मिला'))),
        body: Center(child: Text(lang.tr(en: 'Worker record not found.', hi: 'कारीगर का रिकॉर्ड नहीं मिला।'))),
      );
    }

    final netPayablePaise = (_summary?['netPayablePaise'] as int?) ?? 0;
    final isPayable = netPayablePaise >= 0;
    final netRupees = CurrencyFormatter.paiseToRupees(netPayablePaise.abs());

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: Text(_worker!.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.chat_rounded, color: Color(0xFF4ADE80)),
            tooltip: lang.tr(en: 'Send statement on WhatsApp', hi: 'WhatsApp पर पर्ची भेजें'),
            onPressed: () => _shareOnWhatsApp(lang),
          ),
          IconButton(
            icon: const Icon(Icons.share_rounded, color: AppColors.goldLight),
            tooltip: lang.tr(en: 'Share statement', hi: 'हिसाब पर्ची शेयर करें'),
            onPressed: () => _shareStatement(lang),
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. Executive VIP Header Card with Wage & Katai Summary
          Container(
            color: AppColors.primaryNavy,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: AppColors.primaryGold.withValues(alpha: 0.2),
                      child: Text(
                        _worker!.name.isNotEmpty ? _worker!.name[0].toUpperCase() : 'W',
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primaryGold),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _worker!.name,
                            style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              if (_worker!.machineNumber != null && _worker!.machineNumber!.isNotEmpty) ...[
                                const Icon(Icons.precision_manufacturing_rounded, size: 13, color: AppColors.goldLight),
                                const SizedBox(width: 4),
                                Text(
                                  _worker!.machineNumber!,
                                  style: const TextStyle(color: AppColors.goldLight, fontSize: 12),
                                ),
                                const SizedBox(width: 10),
                              ],
                              Text(
                                _worker!.wageTypeDisplay(lang.isHindi),
                                style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 11),
                              ),
                            ],
                          ),
                          if (_worker!.phone != null && _worker!.phone!.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            InkWell(
                              onTap: () {
                                Clipboard.setData(ClipboardData(text: _worker!.phone!));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(lang.tr(en: 'Copied: ${_worker!.phone}', hi: 'नंबर कॉपी हुआ: ${_worker!.phone}')),
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                              },
                              child: Row(
                                children: [
                                  const Icon(Icons.phone_rounded, size: 12, color: Colors.greenAccent),
                                  const SizedBox(width: 4),
                                  Text(
                                    _worker!.phone!,
                                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(width: 6),
                                  const Icon(Icons.copy_rounded, size: 11, color: Colors.white60),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // Net Balance Banner
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.navySurface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.primaryGold.withValues(alpha: 0.35)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isPayable
                                ? lang.tr(en: 'NET PAYABLE', hi: 'कुल देना बाकी')
                                : lang.tr(en: 'EXCESS ADVANCE', hi: 'अतिरिक्त उठाव'),
                            style: const TextStyle(color: AppColors.goldLight, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            CurrencyFormatter.format(netRupees),
                            style: TextStyle(
                              color: isPayable ? const Color(0xFF4ADE80) : const Color(0xFFF87171),
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          ElevatedButton.icon(
                            icon: const Icon(Icons.add, size: 15),
                            label: Text(lang.tr(en: 'Pay Wages', hi: 'भुगतान / उठाव')),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryGold,
                              foregroundColor: AppColors.primaryNavy,
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                            onPressed: () async {
                              final res = await RecordWorkerPaymentDialog.show(
                                context,
                                repository: widget.repository,
                                workers: [_worker!],
                                preselectedWorker: _worker,
                              );
                              if (res == true) _loadData();
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                // KPI Mini Bar: Total Katai Meters vs Total Advance
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          children: [
                            Text(lang.tr(en: 'Total Katai', hi: 'कुल कटाई'), style: const TextStyle(color: Colors.white70, fontSize: 10.5)),
                            const SizedBox(height: 2),
                            Text(
                              '${(_summary?['totalKataiMeters'] as num?)?.toStringAsFixed(1) ?? "0"} m',
                              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          children: [
                            Text(lang.tr(en: 'Earned', hi: 'कुल कमाई'), style: const TextStyle(color: Colors.white70, fontSize: 10.5)),
                            const SizedBox(height: 2),
                            Text(
                              CurrencyFormatter.format(CurrencyFormatter.paiseToRupees((_summary?['totalEarnedPaise'] as int?) ?? 0)),
                              style: const TextStyle(color: AppColors.goldLight, fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          children: [
                            Text(lang.tr(en: 'Advance', hi: 'उठाव / एडवांस'), style: const TextStyle(color: Colors.white70, fontSize: 10.5)),
                            const SizedBox(height: 2),
                            Text(
                              CurrencyFormatter.format(CurrencyFormatter.paiseToRupees((_summary?['totalAdvancePaise'] as int?) ?? 0)),
                              style: const TextStyle(color: Color(0xFFFCA5A5), fontSize: 13, fontWeight: FontWeight.bold),
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

          // 2. Tabs: Katai Entries & Payments
          Container(
            color: AppColors.surfaceWhite,
            child: TabBar(
              controller: _tabController,
              labelColor: AppColors.primaryNavy,
              unselectedLabelColor: AppColors.textSecondary,
              indicatorColor: AppColors.primaryGold,
              indicatorWeight: 3,
              tabs: [
                Tab(text: '${lang.tr(en: 'Katai', hi: 'कटाई')} (${_kataiEntries.length})'),
                Tab(text: '${lang.tr(en: 'Payments', hi: 'भुगतान')} (${_payments.length})'),
              ],
            ),
          ),

          // 3. Tab Contents
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Tab 1: Katai Entries List
                _kataiEntries.isEmpty
                    ? EmptyState(
                        icon: Icons.precision_manufacturing_rounded,
                        title: lang.tr(en: 'No Katai Entries Found', hi: 'कोई कटाई एंट्री नहीं मिली'),
                        message: lang.tr(en: 'Tap the button below to record katai for this worker.', hi: 'इस कारीगर की आज या पिछली कटाई दर्ज करने हेतु नीचे बटन दबाएं।'),
                        buttonText: lang.tr(en: 'Record Katai', hi: 'कटाई दर्ज करें'),
                        onButtonPressed: () async {
                          final machines = await widget.repository.getDistinctMachines();
                          if (!context.mounted) return;
                          final res = await RecordKataiDialog.show(
                            context,
                            repository: widget.repository,
                            workers: [_worker!],
                            machines: machines,
                          );
                          if (res == true) _loadData();
                        },
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: _kataiEntries.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final entry = _kataiEntries[index];
                          return _buildKataiCard(entry, lang);
                        },
                      ),

                // Tab 2: Payments List
                _payments.isEmpty
                    ? EmptyState(
                        icon: Icons.payments_outlined,
                        title: lang.tr(en: 'No Payments / Advance Recorded', hi: 'कोई भुगतान / एडवांस नहीं'),
                        message: lang.tr(en: 'Record advance given or weekly wages paid to worker.', hi: 'कारीगर को दिया गया एडवांस या साप्ताहिक मजदूरी दर्ज करें।'),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: _payments.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final payment = _payments[index];
                          return _buildPaymentCard(payment, lang);
                        },
                      ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: CompactFab(
        heroTag: 'fab_worker_ledger',
        icon: Icons.add_rounded,
        label: lang.tr(en: 'New Entry', hi: 'नई एंट्री'),
        onTap: () => _showAddActionSheet(context),
      ),
    );
  }

  void _showAddActionSheet(BuildContext context) {
    final lang = Provider.of<LanguageProvider>(context, listen: false);
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const CircleAvatar(backgroundColor: Color(0xFFFEF3C7), child: Icon(Icons.precision_manufacturing_rounded, color: Color(0xFFB45309))),
                  title: Text(lang.tr(en: 'Record Machine Katai', hi: 'मशीन कटाई दर्ज करें'), style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(lang.tr(en: 'Record meters, thans or pieces production', hi: 'मीटर, थान या पीस उत्पादन रिकॉर्ड')),
                  onTap: () async {
                    Navigator.pop(ctx);
                    final machines = await widget.repository.getDistinctMachines();
                    if (!mounted || !context.mounted) return;
                    final res = await RecordKataiDialog.show(
                      context,
                      repository: widget.repository,
                      workers: [_worker!],
                      machines: machines,
                    );
                    if (res == true) _loadData();
                  },
                ),
                ListTile(
                  leading: const CircleAvatar(backgroundColor: Color(0xFFDCFCE7), child: Icon(Icons.payments_rounded, color: Color(0xFF15803D))),
                  title: Text(lang.tr(en: 'Pay Wages / Advance', hi: 'एडवांस / मजदूरी भुगतान दर्ज करें'), style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(lang.tr(en: 'Record expense advance or wage settlement', hi: 'खर्चा, एडवांस या पगार हिसाब चुकता')),
                  onTap: () async {
                    Navigator.pop(ctx);
                    final res = await RecordWorkerPaymentDialog.show(
                      context,
                      repository: widget.repository,
                      workers: [_worker!],
                      preselectedWorker: _worker,
                    );
                    if (res == true) _loadData();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildKataiCard(MachineKataiEntry entry, LanguageProvider lang) {
    return Card(
      elevation: 0.6,
      color: AppColors.surfaceWhite,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.straighten_rounded, color: Color(0xFFB45309), size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '${entry.quantity} ${entry.unit}',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: entry.shift == 'night' ? const Color(0xFFEDE9FE) : const Color(0xFFE0F2FE),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          entry.shiftDisplay(lang.isHindi),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: entry.shift == 'night' ? const Color(0xFF6D28D9) : const Color(0xFF0369A1),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${lang.tr(en: 'Machine', hi: 'मशीन')}: ${entry.machineNumber} • ${lang.tr(en: 'Rate', hi: 'दर')}: ₹ ${entry.rateRupees.toStringAsFixed(2)} / ${entry.unit}',
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  if (entry.designCode != null && entry.designCode!.isNotEmpty)
                    Text(
                      '${lang.tr(en: 'Design', hi: 'डिज़ाइन')}: ${entry.designCode!}',
                      style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                    ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  CurrencyFormatter.format(entry.totalAmountRupees),
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Color(0xFF15803D)),
                ),
                Text(
                  DateFormat('dd MMM yy').format(DateTime.parse(entry.date)),
                  style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                ),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: Text(lang.tr(en: 'Delete Katai Entry?', hi: 'कटाई एंट्री हटाएं?')),
                    content: Text(lang.tr(
                      en: 'Are you sure you want to delete this katai entry of ${entry.quantity} ${entry.unit}?',
                      hi: 'क्या आप ${entry.quantity} ${entry.unit} की यह कटाई एंट्री हटाना चाहते हैं?',
                    )),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(lang.tr(en: 'Cancel', hi: 'रद्द करें'))),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: Text(lang.tr(en: 'Delete', hi: 'हटाएं'), style: const TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  await widget.repository.deleteKataiEntry(entry.id!);
                  _loadData();
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentCard(WorkerPayment payment, LanguageProvider lang) {
    final isAdvance = payment.paymentType == 'advance';
    return Card(
      elevation: 0.6,
      color: AppColors.surfaceWhite,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isAdvance ? const Color(0xFFFEE2E2) : const Color(0xFFDCFCE7),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                isAdvance ? Icons.arrow_outward_rounded : Icons.check_circle_outline_rounded,
                color: isAdvance ? const Color(0xFFDC2626) : const Color(0xFF15803D),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    payment.paymentTypeDisplay(lang.isHindi),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${lang.tr(en: 'Mode', hi: 'माध्यम')}: ${payment.paymentMethod.toUpperCase()} ${payment.notes != null ? "• ${payment.notes!}" : ""}',
                    style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  CurrencyFormatter.format(payment.amountRupees),
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: isAdvance ? const Color(0xFFDC2626) : const Color(0xFF15803D),
                  ),
                ),
                Text(
                  DateFormat('dd MMM yy').format(DateTime.parse(payment.date)),
                  style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                ),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: Text(lang.tr(en: 'Delete Payment Entry?', hi: 'पेमेंट एंट्री हटाएं?')),
                    content: Text(lang.tr(en: 'Are you sure you want to delete this payment record?', hi: 'क्या आप यह भुगतान रिकॉर्ड हटाना चाहते हैं?')),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(lang.tr(en: 'Cancel', hi: 'रद्द करें'))),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: Text(lang.tr(en: 'Delete', hi: 'हटाएं'), style: const TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  await widget.repository.deletePayment(payment.id!);
                  _loadData();
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
