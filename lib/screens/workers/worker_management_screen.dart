import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_colors.dart';
import '../../core/localization/language_provider.dart';
import '../../core/utils/currency_formatter.dart';
import '../../models/worker.dart';
import '../../models/worker_attendance.dart';
import '../../models/machine_katai_entry.dart';
import '../../repositories/worker_repository.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/compact_fab.dart';
import 'add_edit_worker_dialog.dart';
import 'record_katai_dialog.dart';
import 'record_worker_payment_dialog.dart';
import 'worker_ledger_screen.dart';

class WorkerManagementScreen extends StatefulWidget {
  final WorkerRepository? repository;
  final int initialTabIndex;

  const WorkerManagementScreen({
    super.key,
    this.repository,
    this.initialTabIndex = 0,
  });

  @override
  State<WorkerManagementScreen> createState() => _WorkerManagementScreenState();
}

class _WorkerManagementScreenState extends State<WorkerManagementScreen>
    with SingleTickerProviderStateMixin {
  late WorkerRepository _repo;
  late TabController _tabController;

  List<Worker> _workers = [];
  List<String> _machines = [];
  bool _isLoading = true;

  // Tab 0: Attendance State
  DateTime _attendanceDate = DateTime.now();
  Map<int, WorkerAttendance> _attendanceMap = {};
  Map<String, int> _attendanceStats = {
    'present': 0,
    'absent': 0,
    'half_day': 0,
    'overtime': 0,
    'total': 0,
  };

  // Tab 1: Katai State
  DateTime _kataiDate = DateTime.now();
  String _selectedKataiMachine = 'all';
  List<MachineKataiEntry> _kataiEntries = [];

  // Tab 2: Wages & Karigars State
  Map<int, Map<String, dynamic>> _workerSummaries = {};
  String _workerSearchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  String _workerBalanceFilter = 'all'; // 'all', 'payable', 'advance'

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? WorkerRepository();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 2),
    );
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {}); // Updates floating action button according to tab
        _loadTabSpecificData();
      }
    });
    _initialLoad();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _initialLoad() async {
    setState(() => _isLoading = true);
    await _loadWorkersAndMachines();
    await Future.wait([
      _loadAttendanceData(),
      _loadKataiData(),
      _loadWagesData(),
    ]);
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadWorkersAndMachines() async {
    final workers = await _repo.getAllWorkers();
    final machines = await _repo.getDistinctMachines();
    if (mounted) {
      setState(() {
        _workers = workers;
        _machines = machines;
      });
    }
  }

  Future<void> _loadTabSpecificData() async {
    final idx = _tabController.index;
    if (idx == 0) await _loadAttendanceData();
    if (idx == 1) await _loadKataiData();
    if (idx == 2) {
      await _loadWorkersAndMachines();
      await _loadWagesData();
    }
  }

  Future<void> _loadAttendanceData() async {
    final dateStr = DateFormat('yyyy-MM-dd').format(_attendanceDate);
    final list = await _repo.getAttendanceForDate(dateStr);
    final stats = await _repo.getAttendanceSummary(dateStr);

    final map = <int, WorkerAttendance>{};
    for (final att in list) {
      map[att.workerId] = att;
    }

    if (mounted) {
      setState(() {
        _attendanceMap = map;
        _attendanceStats = stats;
      });
    }
  }

  Future<void> _loadKataiData() async {
    final dateStr = DateFormat('yyyy-MM-dd').format(_kataiDate);
    final entries = await _repo.getKataiEntries(
      date: dateStr,
      machineNumber: _selectedKataiMachine == 'all' ? null : _selectedKataiMachine,
    );
    if (mounted) {
      setState(() {
        _kataiEntries = entries;
      });
    }
  }

  Future<void> _loadWagesData() async {
    final summaries = <int, Map<String, dynamic>>{};
    for (final w in _workers) {
      if (w.id != null) {
        final s = await _repo.getWorkerWageSummary(w.id!);
        summaries[w.id!] = s;
      }
    }
    if (mounted) {
      setState(() {
        _workerSummaries = summaries;
      });
    }
  }

  // Attendance actions
  Future<void> _setWorkerAttendance(int workerId, String status) async {
    HapticFeedback.selectionClick();
    final dateStr = DateFormat('yyyy-MM-dd').format(_attendanceDate);
    await _repo.markAttendance(workerId: workerId, date: dateStr, status: status);
    await _loadAttendanceData();
  }

  Future<void> _markAllPresent() async {
    HapticFeedback.mediumImpact();
    final dateStr = DateFormat('yyyy-MM-dd').format(_attendanceDate);
    for (final w in _workers) {
      if (w.id != null) {
        await _repo.markAttendance(workerId: w.id!, date: dateStr, status: 'present');
      }
    }
    await _loadAttendanceData();
    if (mounted) {
      final lang = Provider.of<LanguageProvider>(context, listen: false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(lang.tr(en: 'All workers marked present ✔️', hi: 'सभी कारीगरों की उपस्थिति दर्ज हो गई ✔️')),
          backgroundColor: const Color(0xFF0F172A),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  // Date Shift Helpers
  void _shiftAttendanceDate(int days) {
    setState(() {
      _attendanceDate = _attendanceDate.add(Duration(days: days));
    });
    _loadAttendanceData();
  }

  void _shiftKataiDate(int days) {
    setState(() {
      _kataiDate = _kataiDate.add(Duration(days: days));
    });
    _loadKataiData();
  }

  // Phone Call & WhatsApp
  Future<void> _makePhoneCall(String? phone) async {
    if (phone == null || phone.trim().isEmpty) return;
    final clean = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    final uri = Uri.parse('tel:$clean');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _openWhatsApp(String? phone, String workerName) async {
    if (phone == null || phone.trim().isEmpty) return;
    final clean = phone.replaceAll(RegExp(r'[^0-9]'), '');
    final phoneWithCode = clean.length == 10 ? '91$clean' : clean;
    final lang = Provider.of<LanguageProvider>(context, listen: false);
    final text = lang.isHindi
        ? 'नमस्ते $workerName जी, DM Lace Surat से।'
        : 'Hello $workerName ji, from DM Lace Surat.';
    final uri = Uri.parse('https://wa.me/$phoneWithCode?text=${Uri.encodeComponent(text)}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          lang.tr(en: 'Karigar & Production Hub', hi: 'कारीगर व उत्पादन हब'),
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.goldLight),
            tooltip: lang.tr(en: 'Refresh', hi: 'रिफ्रेश करें'),
            onPressed: _initialLoad,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primaryGold,
          labelColor: AppColors.goldLight,
          unselectedLabelColor: Colors.white70,
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: [
            Tab(
              icon: const Icon(Icons.fact_check_rounded, size: 20),
              text: lang.tr(en: 'Attendance', hi: 'दैनिक हाजिरी'),
            ),
            Tab(
              icon: const Icon(Icons.precision_manufacturing_rounded, size: 20),
              text: lang.tr(en: 'Machine Katai', hi: 'मशीन कटाई'),
            ),
            Tab(
              icon: const Icon(Icons.account_balance_wallet_rounded, size: 20),
              text: lang.tr(en: 'Karigars & Wages', hi: 'कारीगर व मजदूरी'),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryGold))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildAttendanceTab(lang),
                _buildKataiTab(lang),
                _buildWagesAndKarigarsTab(lang),
              ],
            ),
      floatingActionButton: _buildContextualFAB(lang),
    );
  }

  Widget? _buildContextualFAB(LanguageProvider lang) {
    if (_tabController.index == 1) {
      // Machine Katai FAB
      return CompactFab(
        heroTag: 'fab_add_katai',
        icon: Icons.add_rounded,
        label: lang.tr(en: 'Record Katai', hi: 'नई कटाई दर्ज करें'),
        onTap: () async {
          final res = await RecordKataiDialog.show(
            context,
            repository: _repo,
            workers: _workers,
            machines: _machines,
          );
          if (res == true) _loadKataiData();
        },
      );
    } else if (_tabController.index == 2) {
      // Add Karigar FAB
      return CompactFab(
        heroTag: 'fab_add_worker',
        icon: Icons.person_add_rounded,
        label: lang.tr(en: 'Add Karigar', hi: 'नया कारीगर जोड़ें'),
        onTap: () async {
          final res = await AddEditWorkerDialog.show(context, _repo);
          if (res == true) _initialLoad();
        },
      );
    }
    return null;
  }

  // =========================================================================
  // TAB 0: ATTENDANCE (दैनिक हाजिरी)
  // =========================================================================
  Widget _buildAttendanceTab(LanguageProvider lang) {
    final now = DateTime.now();
    final isToday = _attendanceDate.year == now.year &&
        _attendanceDate.month == now.month &&
        _attendanceDate.day == now.day;
    final dateDisplay = DateFormat('dd MMM yyyy, EEEE').format(_attendanceDate);

    final presentCount = _attendanceStats['present'] ?? 0;
    final absentCount = _attendanceStats['absent'] ?? 0;
    final halfDayCount = _attendanceStats['half_day'] ?? 0;

    return Column(
      children: [
        // 1. Modern Date Navigation Strip
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              // Previous Day Button
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded, color: Color(0xFF334155), size: 26),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                tooltip: lang.tr(en: 'Previous Day', hi: 'पिछला दिन'),
                onPressed: () => _shiftAttendanceDate(-1),
              ),
              const SizedBox(width: 4),
              // Center Date Picker Card
              Expanded(
                child: InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _attendanceDate,
                      firstDate: DateTime(2025),
                      lastDate: DateTime.now().add(const Duration(days: 30)),
                    );
                    if (picked != null) {
                      setState(() => _attendanceDate = picked);
                      _loadAttendanceData();
                    }
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.calendar_today_rounded, size: 14, color: AppColors.primaryNavy),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            dateDisplay,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.arrow_drop_down_rounded, size: 18, color: Color(0xFF64748B)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              // Next Day Button
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded, color: Color(0xFF334155), size: 26),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                tooltip: lang.tr(en: 'Next Day', hi: 'अगला दिन'),
                onPressed: () => _shiftAttendanceDate(1),
              ),
              // Quick "Today" Chip if not today
              if (!isToday) ...[
                const SizedBox(width: 4),
                InkWell(
                  onTap: () {
                    setState(() => _attendanceDate = DateTime.now());
                    _loadAttendanceData();
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryGold.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.primaryGold),
                    ),
                    child: Text(
                      lang.tr(en: 'Today', hi: 'आज'),
                      style: const TextStyle(color: Color(0xFF854D0E), fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),

        // 2. High-Contrast Attendance Metric Card
        Container(
          margin: const EdgeInsets.fromLTRB(12, 6, 12, 6),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
          child: Row(
            children: [
              // Present Pill
              _buildMetricBadge(
                label: lang.tr(en: 'Present', hi: 'उपस्थित'),
                count: presentCount,
                bgColor: const Color(0xFFDCFCE7),
                textColor: const Color(0xFF15803D),
                dotColor: const Color(0xFF22C55E),
              ),
              const SizedBox(width: 8),
              // Absent Pill
              _buildMetricBadge(
                label: lang.tr(en: 'Absent', hi: 'अनुपस्थित'),
                count: absentCount,
                bgColor: const Color(0xFFFEE2E2),
                textColor: const Color(0xFFB91C1C),
                dotColor: const Color(0xFFEF4444),
              ),
              const SizedBox(width: 8),
              // Half Day Pill
              _buildMetricBadge(
                label: lang.tr(en: 'Half Day', hi: 'आधा दिन'),
                count: halfDayCount,
                bgColor: const Color(0xFFFEF3C7),
                textColor: const Color(0xFFB45309),
                dotColor: const Color(0xFFF59E0B),
              ),
              const Spacer(),
              // Mark All Present Button
              ElevatedButton.icon(
                icon: const Icon(Icons.done_all_rounded, size: 15),
                label: Text(lang.tr(en: 'All Present', hi: 'सब उपस्थित')),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  foregroundColor: AppColors.primaryGold,
                  elevation: 0,
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: _workers.isEmpty ? null : _markAllPresent,
              ),
            ],
          ),
        ),

        // 3. Workers Attendance List
        Expanded(
          child: _workers.isEmpty
              ? EmptyState(
                  icon: Icons.people_outline_rounded,
                  title: lang.isHindi ? 'कोई कारीगर नहीं मिला' : 'No Workers Found',
                  message: lang.isHindi
                      ? 'हाजिरी लगाने हेतु पहले नीचे दिए गए टैब से कारीगर जोड़ें।'
                      : 'Add workers first to track attendance.',
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 6, 12, 24),
                  itemCount: _workers.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final worker = _workers[index];
                    final currentAtt = _attendanceMap[worker.id];
                    final status = currentAtt?.status ?? 'none';

                    Color accentBorderColor = Colors.transparent;
                    if (status == 'present') accentBorderColor = const Color(0xFF22C55E);
                    if (status == 'absent') accentBorderColor = const Color(0xFFEF4444);
                    if (status == 'half_day') accentBorderColor = const Color(0xFFF59E0B);

                    return Card(
                      elevation: 0.5,
                      margin: EdgeInsets.zero,
                      color: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(
                          color: status != 'none' ? accentBorderColor.withValues(alpha: 0.5) : const Color(0xFFE2E8F0),
                          width: status != 'none' ? 1.5 : 1.0,
                        ),
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border(
                            left: BorderSide(
                              color: status != 'none' ? accentBorderColor : const Color(0xFFCBD5E1),
                              width: 4.5,
                            ),
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        child: Row(
                          children: [
                            // Worker Avatar
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: const Color(0xFF0F172A).withValues(alpha: 0.08),
                              child: Text(
                                worker.name.isNotEmpty ? worker.name[0].toUpperCase() : 'W',
                                style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF0F172A), fontSize: 15),
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Worker Details
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          worker.name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14.5,
                                            color: Color(0xFF0F172A),
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  Row(
                                    children: [
                                      // Machine Badge
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF1F5F9),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          worker.machineNumber ?? 'General',
                                          style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      // Wage type display
                                      Flexible(
                                        child: Text(
                                          worker.wageTypeDisplay(lang.isHindi),
                                          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  // Call / WhatsApp quick actions if phone exists
                                  if (worker.phone != null && worker.phone!.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        InkWell(
                                          onTap: () => _makePhoneCall(worker.phone),
                                          borderRadius: BorderRadius.circular(4),
                                          child: Row(
                                            children: [
                                              const Icon(Icons.phone_rounded, size: 12, color: Color(0xFF2563EB)),
                                              const SizedBox(width: 3),
                                              Text(
                                                worker.phone!,
                                                style: const TextStyle(fontSize: 10.5, color: Color(0xFF2563EB), fontWeight: FontWeight.w600),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        InkWell(
                                          onTap: () => _openWhatsApp(worker.phone, worker.name),
                                          borderRadius: BorderRadius.circular(4),
                                          child: const Row(
                                            children: [
                                              Icon(Icons.chat_rounded, size: 12, color: Color(0xFF16A34A)),
                                              SizedBox(width: 3),
                                              Text(
                                                'WhatsApp',
                                                style: TextStyle(fontSize: 10.5, color: Color(0xFF16A34A), fontWeight: FontWeight.w600),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Segmented Attendance Selector: [ P | A | H ]
                            Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              padding: const EdgeInsets.all(2.5),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _buildAttendanceSegmentBtn(
                                    workerId: worker.id!,
                                    label: 'P',
                                    targetStatus: 'present',
                                    currentStatus: status,
                                    activeColor: const Color(0xFF16A34A),
                                  ),
                                  const SizedBox(width: 3),
                                  _buildAttendanceSegmentBtn(
                                    workerId: worker.id!,
                                    label: 'A',
                                    targetStatus: 'absent',
                                    currentStatus: status,
                                    activeColor: const Color(0xFFDC2626),
                                  ),
                                  const SizedBox(width: 3),
                                  _buildAttendanceSegmentBtn(
                                    workerId: worker.id!,
                                    label: 'H',
                                    targetStatus: 'half_day',
                                    currentStatus: status,
                                    activeColor: const Color(0xFFD97706),
                                  ),
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
    );
  }

  Widget _buildMetricBadge({
    required String label,
    required int count,
    required Color bgColor,
    required Color textColor,
    required Color dotColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            '$label: ',
            style: TextStyle(color: textColor, fontSize: 11, fontWeight: FontWeight.w600),
          ),
          Text(
            '$count',
            style: TextStyle(color: textColor, fontSize: 12, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceSegmentBtn({
    required int workerId,
    required String label,
    required String targetStatus,
    required String currentStatus,
    required Color activeColor,
  }) {
    final isSelected = currentStatus == targetStatus;
    return InkWell(
      onTap: () => _setWorkerAttendance(workerId, targetStatus),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 38,
        height: 36,
        decoration: BoxDecoration(
          color: isSelected ? activeColor : Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: activeColor.withValues(alpha: 0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  )
                ]
              : null,
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : const Color(0xFF64748B),
              fontWeight: FontWeight.w900,
              fontSize: 14.5,
            ),
          ),
        ),
      ),
    );
  }

  // =========================================================================
  // TAB 1: MACHINE KATAI (मशीन कटाई व उत्पादन)
  // =========================================================================
  Widget _buildKataiTab(LanguageProvider lang) {
    final now = DateTime.now();
    final isToday = _kataiDate.year == now.year &&
        _kataiDate.month == now.month &&
        _kataiDate.day == now.day;
    final dateDisplay = DateFormat('dd MMM yyyy').format(_kataiDate);

    final totalMeters = _kataiEntries.fold<double>(0.0, (acc, e) => acc + e.quantity);
    final totalAmount = _kataiEntries.fold<double>(0.0, (acc, e) => acc + e.totalAmountRupees);

    return Column(
      children: [
        // 1. Date Bar
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded, color: Color(0xFF334155), size: 26),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                tooltip: lang.tr(en: 'Previous Day', hi: 'पिछला दिन'),
                onPressed: () => _shiftKataiDate(-1),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _kataiDate,
                      firstDate: DateTime(2025),
                      lastDate: DateTime.now().add(const Duration(days: 30)),
                    );
                    if (picked != null) {
                      setState(() => _kataiDate = picked);
                      _loadKataiData();
                    }
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.calendar_today_rounded, size: 14, color: AppColors.primaryNavy),
                        const SizedBox(width: 8),
                        Text(
                          dateDisplay,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.arrow_drop_down_rounded, size: 18, color: Color(0xFF64748B)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded, color: Color(0xFF334155), size: 26),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                tooltip: lang.tr(en: 'Next Day', hi: 'अगला दिन'),
                onPressed: () => _shiftKataiDate(1),
              ),
              if (!isToday) ...[
                const SizedBox(width: 4),
                InkWell(
                  onTap: () {
                    setState(() => _kataiDate = DateTime.now());
                    _loadKataiData();
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryGold.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.primaryGold),
                    ),
                    child: Text(
                      lang.tr(en: 'Today', hi: 'आज'),
                      style: const TextStyle(color: Color(0xFF854D0E), fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),

        // 2. Machine Filter Horizontal Chips Strip
        Container(
          color: Colors.white,
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildMachineChip(
                  label: lang.tr(en: 'All Machines', hi: 'सभी मशीनें'),
                  value: 'all',
                  isSelected: _selectedKataiMachine == 'all',
                ),
                ..._machines.map((m) {
                  return Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: _buildMachineChip(
                      label: m,
                      value: m,
                      isSelected: _selectedKataiMachine == m,
                    ),
                  );
                }),
              ],
            ),
          ),
        ),

        // 3. Total Production KPI Summary Card
        Container(
          margin: const EdgeInsets.fromLTRB(12, 6, 12, 6),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.primaryGold.withValues(alpha: 0.3)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Total meters & records
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.precision_manufacturing_rounded, color: AppColors.primaryGold, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        lang.tr(en: 'TOTAL PRODUCTION', hi: 'कुल उत्पादन कटाई'),
                        style: const TextStyle(color: AppColors.goldLight, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.5),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        totalMeters.toStringAsFixed(1),
                        style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        lang.tr(en: 'Meters', hi: 'मीटर'),
                        style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  Text(
                    '${_kataiEntries.length} ${lang.tr(en: 'Katai Entries', hi: 'कटाई रिकॉर्ड')}',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 11),
                  ),
                ],
              ),
              // Total Wages
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    lang.tr(en: 'TOTAL WAGES', hi: 'कुल मजदूरी राशि'),
                    style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    CurrencyFormatter.format(totalAmount),
                    style: const TextStyle(color: Color(0xFF4ADE80), fontSize: 20, fontWeight: FontWeight.w900),
                  ),
                ],
              ),
            ],
          ),
        ),

        // 4. Katai Entries List
        Expanded(
          child: _kataiEntries.isEmpty
              ? EmptyState(
                  icon: Icons.precision_manufacturing_rounded,
                  title: lang.tr(en: 'No Katai Recorded', hi: 'आज इस मशीन की कोई कटाई दर्ज नहीं है'),
                  message: lang.tr(
                    en: 'Tap "Record Katai" below to enter meter production.',
                    hi: 'मशीन अनुसार मीटर व कारीगर कटाई दर्ज करने हेतु नीचे "नई कटाई दर्ज करें" बटन दबाएं।',
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 6, 12, 80),
                  itemCount: _kataiEntries.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final entry = _kataiEntries[index];
                    return Card(
                      elevation: 0.5,
                      margin: EdgeInsets.zero,
                      color: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          children: [
                            // Top Row: Machine Badge, Shift, Delete Button
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0F172A),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.precision_manufacturing_rounded, size: 12, color: AppColors.primaryGold),
                                      const SizedBox(width: 4),
                                      Text(
                                        entry.machineNumber,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: Colors.white),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                  decoration: BoxDecoration(
                                    color: entry.shift == 'night'
                                        ? const Color(0xFFEDE9FE)
                                        : const Color(0xFFE0F2FE),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    entry.shiftDisplay(lang.isHindi),
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.bold,
                                      color: entry.shift == 'night' ? const Color(0xFF6D28D9) : const Color(0xFF0369A1),
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.redAccent),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                  tooltip: lang.tr(en: 'Delete', hi: 'हटाएं'),
                                  onPressed: () async {
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                        title: Text(lang.tr(en: 'Delete Katai Entry?', hi: 'कटाई एंट्री हटाएं?')),
                                        content: Text(lang.tr(
                                          en: 'Are you sure you want to delete this katai entry?',
                                          hi: 'क्या आप इस कटाई रिकॉर्ड को हटाना चाहते हैं?',
                                        )),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(ctx, false),
                                            child: Text(lang.tr(en: 'Cancel', hi: 'रद्द करें')),
                                          ),
                                          ElevatedButton(
                                            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                            onPressed: () => Navigator.pop(ctx, true),
                                            child: Text(lang.tr(en: 'Delete', hi: 'हटाएं'), style: const TextStyle(color: Colors.white)),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (confirm == true) {
                                      await _repo.deleteKataiEntry(entry.id!);
                                      _loadKataiData();
                                    }
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            // Middle Row: Worker Name & Design Code
                            Row(
                              children: [
                                const Icon(Icons.person_rounded, size: 15, color: Color(0xFF64748B)),
                                const SizedBox(width: 5),
                                Text(
                                  entry.workerName ?? 'N/A',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Color(0xFF0F172A)),
                                ),
                                if (entry.designCode != null && entry.designCode!.isNotEmpty) ...[
                                  const SizedBox(width: 10),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFEF3C7),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      entry.designCode!,
                                      style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF92400E)),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 6),
                            const Divider(height: 1, color: Color(0xFFF1F5F9)),
                            const SizedBox(height: 6),
                            // Bottom Row: Production Qty and Wages Rate & Total
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      '${entry.quantity} ${entry.unit}',
                                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Color(0xFF0F172A)),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      '(@ ₹ ${entry.rateRupees.toStringAsFixed(2)} / ${entry.unit})',
                                      style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                                    ),
                                  ],
                                ),
                                Text(
                                  CurrencyFormatter.format(entry.totalAmountRupees),
                                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Color(0xFF15803D)),
                                ),
                              ],
                            ),
                            if (entry.notes != null && entry.notes!.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(Icons.notes_rounded, size: 12, color: Color(0xFF94A3B8)),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      entry.notes!,
                                      style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontStyle: FontStyle.italic),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildMachineChip({
    required String label,
    required String value,
    required bool isSelected,
  }) {
    return InkWell(
      onTap: () {
        setState(() => _selectedKataiMachine = value);
        _loadKataiData();
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? AppColors.primaryGold : const Color(0xFF475569),
            fontWeight: FontWeight.bold,
            fontSize: 11.5,
          ),
        ),
      ),
    );
  }

  // =========================================================================
  // TAB 2: KARIGARS & WAGES HUB (कारीगर, मजदूरी व खाता पर्ची)
  // =========================================================================
  Widget _buildWagesAndKarigarsTab(LanguageProvider lang) {
    // 1. Calculate Overall Factory Totals
    int totalEarnedPaise = 0;
    int totalAdvancePaise = 0;
    int totalWagePaidPaise = 0;
    int totalNetPayablePaise = 0;

    for (final w in _workers) {
      if (w.id != null) {
        final s = _workerSummaries[w.id];
        if (s != null) {
          totalEarnedPaise += (s['totalEarnedPaise'] as int?) ?? 0;
          totalAdvancePaise += (s['totalAdvancePaise'] as int?) ?? 0;
          totalWagePaidPaise += (s['totalWagePaidPaise'] as int?) ?? 0;
          totalNetPayablePaise += (s['netPayablePaise'] as int?) ?? 0;
        }
      }
    }

    // 2. Filtered Workers List
    final filteredWorkers = _workers.where((w) {
      final query = _workerSearchQuery.trim().toLowerCase();
      final matchesSearch = query.isEmpty ||
          w.name.toLowerCase().contains(query) ||
          (w.machineNumber ?? '').toLowerCase().contains(query) ||
          (w.phone ?? '').contains(query);
      if (!matchesSearch) return false;

      if (_workerBalanceFilter == 'all') return true;
      final summary = _workerSummaries[w.id];
      final netPayable = (summary?['netPayablePaise'] as int?) ?? 0;
      if (_workerBalanceFilter == 'payable') return netPayable > 0;
      if (_workerBalanceFilter == 'advance') return netPayable < 0;
      return true;
    }).toList();

    return Column(
      children: [
        // 1. Factory Payroll Executive Summary Card
        Container(
          margin: const EdgeInsets.fromLTRB(12, 8, 12, 6),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.primaryGold.withValues(alpha: 0.35)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.account_balance_wallet_rounded, color: AppColors.primaryGold, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        lang.tr(en: 'TOTAL FACTORY PAYROLL', hi: 'कारखाना कुल मजदूरी हिसाब'),
                        style: const TextStyle(
                          color: AppColors.goldLight,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primaryGold.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.primaryGold.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      '${_workers.length} ${lang.tr(en: 'Workers', hi: 'कारीगर')}',
                      style: const TextStyle(color: AppColors.goldLight, fontSize: 11, fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        totalNetPayablePaise >= 0
                            ? lang.tr(en: 'Net Wages Payable', hi: 'कारीगरों को देना बाकी')
                            : lang.tr(en: 'Excess Advance Given', hi: 'कारीगरों से लेना बाकी (एडवांस)'),
                        style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11.5, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        CurrencyFormatter.format(CurrencyFormatter.paiseToRupees(totalNetPayablePaise.abs())),
                        style: TextStyle(
                          color: totalNetPayablePaise >= 0 ? const Color(0xFF4ADE80) : const Color(0xFFF87171),
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // 3 Micro Dashboard Tiles
              Row(
                children: [
                  Expanded(
                    child: _buildPayrollSubTile(
                      label: lang.tr(en: 'Earned', hi: 'कुल कमाई'),
                      amount: totalEarnedPaise,
                      textColor: const Color(0xFFE2E8F0),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildPayrollSubTile(
                      label: lang.tr(en: 'Advance', hi: 'उठाव / एडवांस'),
                      amount: totalAdvancePaise,
                      textColor: const Color(0xFFFCA5A5),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildPayrollSubTile(
                      label: lang.tr(en: 'Paid', hi: 'चुकाई मजदूरी'),
                      amount: totalWagePaidPaise,
                      textColor: const Color(0xFF93C5FD),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // 2. Search & Filter Bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) => setState(() => _workerSearchQuery = val),
                    style: const TextStyle(fontSize: 12.5),
                    decoration: InputDecoration(
                      hintText: lang.tr(en: 'Search karigar or machine...', hi: 'कारीगर या मशीन खोजें...'),
                      hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                      prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF64748B)),
                      suffixIcon: _workerSearchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 16, color: Color(0xFF64748B)),
                              padding: EdgeInsets.zero,
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _workerSearchQuery = '');
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 9),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Filter Chips (All, Payable, Advance)
              _buildFilterBadge('all', lang.tr(en: 'All', hi: 'सभी')),
              const SizedBox(width: 4),
              _buildFilterBadge('payable', lang.tr(en: 'Payable', hi: 'बाकी')),
              const SizedBox(width: 4),
              _buildFilterBadge('advance', lang.tr(en: 'Advance', hi: 'एडवांस')),
            ],
          ),
        ),

        // 3. Workers List
        Expanded(
          child: filteredWorkers.isEmpty
              ? EmptyState(
                  icon: Icons.people_outline_rounded,
                  title: lang.isHindi ? 'कोई कारीगर नहीं मिला' : 'No Workers Found',
                  message: lang.isHindi
                      ? 'कारखाने के कारीगर या ऑपरेटर जोड़ने हेतु नीचे बटन दबाएं।'
                      : 'Add factory operators or karigars.',
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 80),
                  itemCount: filteredWorkers.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final worker = filteredWorkers[index];
                    final summary = _workerSummaries[worker.id];
                    final totalEarned = (summary?['totalEarnedPaise'] as int?) ?? 0;
                    final totalAdvance = (summary?['totalAdvancePaise'] as int?) ?? 0;
                    final totalWagePaid = (summary?['totalWagePaidPaise'] as int?) ?? 0;
                    final netPayable = (summary?['netPayablePaise'] as int?) ?? 0;
                    final isPayable = netPayable >= 0;

                    return Card(
                      elevation: 0.5,
                      margin: EdgeInsets.zero,
                      color: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          children: [
                            // Worker Header Row
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 20,
                                  backgroundColor: const Color(0xFF0F172A).withValues(alpha: 0.08),
                                  child: Text(
                                    worker.name.isNotEmpty ? worker.name[0].toUpperCase() : 'W',
                                    style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF0F172A), fontSize: 15),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        worker.name,
                                        style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                      ),
                                      const SizedBox(height: 2),
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFF1F5F9),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              worker.machineNumber ?? 'General',
                                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Flexible(
                                            child: Text(
                                              worker.wageTypeDisplay(lang.isHindi),
                                              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                // Net Balance Badge
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isPayable ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        CurrencyFormatter.format(CurrencyFormatter.paiseToRupees(netPayable.abs())),
                                        style: TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w900,
                                          color: isPayable ? const Color(0xFF15803D) : const Color(0xFFDC2626),
                                        ),
                                      ),
                                      Text(
                                        isPayable
                                            ? lang.tr(en: 'Payable', hi: 'देना बाकी')
                                            : lang.tr(en: 'Advance', hi: 'एडवांस'),
                                        style: TextStyle(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w800,
                                          color: isPayable ? const Color(0xFF15803D) : const Color(0xFFDC2626),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // Context Menu for Edit / Delete
                                PopupMenuButton<String>(
                                  icon: const Icon(Icons.more_vert_rounded, size: 20, color: Color(0xFF64748B)),
                                  onSelected: (val) async {
                                    if (val == 'edit') {
                                      final res = await AddEditWorkerDialog.show(context, _repo, worker);
                                      if (res == true) _initialLoad();
                                    } else if (val == 'delete') {
                                      final confirm = await showDialog<bool>(
                                        context: context,
                                        builder: (ctx) => AlertDialog(
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                          title: Text(lang.tr(en: 'Delete Worker?', hi: 'कारीगर हटाएं?')),
                                          content: Text(lang.tr(
                                            en: 'Are you sure you want to delete ${worker.name}?',
                                            hi: 'क्या आप ${worker.name} को हटाना चाहते हैं?',
                                          )),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.pop(ctx, false),
                                              child: Text(lang.tr(en: 'Cancel', hi: 'रद्द करें')),
                                            ),
                                            ElevatedButton(
                                              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                              onPressed: () => Navigator.pop(ctx, true),
                                              child: Text(lang.tr(en: 'Delete', hi: 'हटाएं'), style: const TextStyle(color: Colors.white)),
                                            ),
                                          ],
                                        ),
                                      );
                                      if (confirm == true) {
                                        await _repo.deleteWorker(worker.id!);
                                        _initialLoad();
                                      }
                                    }
                                  },
                                  itemBuilder: (_) => [
                                    PopupMenuItem(
                                      value: 'edit',
                                      child: Row(
                                        children: [
                                          const Icon(Icons.edit_outlined, size: 18),
                                          const SizedBox(width: 8),
                                          Text(lang.tr(en: 'Edit Worker', hi: 'संपादित करें')),
                                        ],
                                      ),
                                    ),
                                    PopupMenuItem(
                                      value: 'delete',
                                      child: Row(
                                        children: [
                                          const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red),
                                          const SizedBox(width: 8),
                                          Text(lang.tr(en: 'Delete Worker', hi: 'हटाएं'), style: const TextStyle(color: Colors.red)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),

                            // Phone & WhatsApp Strip (if phone present)
                            if (worker.phone != null && worker.phone!.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  InkWell(
                                    onTap: () => _makePhoneCall(worker.phone),
                                    borderRadius: BorderRadius.circular(6),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFEFF6FF),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.phone_rounded, size: 12, color: Color(0xFF2563EB)),
                                          const SizedBox(width: 4),
                                          Text(
                                            worker.phone!,
                                            style: const TextStyle(fontSize: 11, color: Color(0xFF2563EB), fontWeight: FontWeight.w700),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  InkWell(
                                    onTap: () => _openWhatsApp(worker.phone, worker.name),
                                    borderRadius: BorderRadius.circular(6),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFDCFCE7),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.chat_rounded, size: 12, color: Color(0xFF16A34A)),
                                          const SizedBox(width: 4),
                                          Text(
                                            lang.tr(en: 'WhatsApp', hi: 'व्हाट्सएप'),
                                            style: const TextStyle(fontSize: 11, color: Color(0xFF16A34A), fontWeight: FontWeight.w700),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],

                            const SizedBox(height: 8),
                            const Divider(height: 1, color: Color(0xFFF1F5F9)),
                            const SizedBox(height: 8),

                            // Mini Financial Breakdown
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '${lang.tr(en: 'Earned', hi: 'कमाई')}: ${CurrencyFormatter.format(CurrencyFormatter.paiseToRupees(totalEarned))}',
                                  style: const TextStyle(fontSize: 11, color: Color(0xFF475569), fontWeight: FontWeight.w600),
                                ),
                                Text(
                                  '${lang.tr(en: 'Advance', hi: 'उठाव')}: ${CurrencyFormatter.format(CurrencyFormatter.paiseToRupees(totalAdvance))}',
                                  style: const TextStyle(fontSize: 11, color: Color(0xFFDC2626), fontWeight: FontWeight.w600),
                                ),
                                Text(
                                  '${lang.tr(en: 'Paid', hi: 'चुकाया')}: ${CurrencyFormatter.format(CurrencyFormatter.paiseToRupees(totalWagePaid))}',
                                  style: const TextStyle(fontSize: 11, color: Color(0xFF0369A1), fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),

                            const SizedBox(height: 10),

                            // Action Buttons: Ledger, Pay Wages, Record Katai Shortcut
                            Row(
                              children: [
                                // Ledger Button
                                Expanded(
                                  child: OutlinedButton.icon(
                                    icon: const Icon(Icons.receipt_long_rounded, size: 14),
                                    label: Text(lang.tr(en: 'Ledger', hi: 'खाता पर्ची')),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppColors.primaryNavy,
                                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                                      visualDensity: VisualDensity.compact,
                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                                      textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                    onPressed: () async {
                                      await Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => WorkerLedgerScreen(workerId: worker.id!, repository: _repo),
                                        ),
                                      );
                                      _loadWagesData();
                                    },
                                  ),
                                ),
                                const SizedBox(width: 6),
                                // Record Katai direct shortcut
                                Expanded(
                                  child: OutlinedButton.icon(
                                    icon: const Icon(Icons.content_cut_rounded, size: 14),
                                    label: Text(lang.tr(en: 'Katai', hi: 'कटाई दर्ज')),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: const Color(0xFF0F172A),
                                      side: const BorderSide(color: Color(0xFF94A3B8)),
                                      visualDensity: VisualDensity.compact,
                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                                      textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                    onPressed: () async {
                                      final res = await RecordKataiDialog.show(
                                        context,
                                        repository: _repo,
                                        workers: _workers,
                                        machines: _machines,
                                        preselectedWorker: worker,
                                      );
                                      if (res == true) {
                                        _loadKataiData();
                                        _loadWagesData();
                                      }
                                    },
                                  ),
                                ),
                                const SizedBox(width: 6),
                                // Pay Wages Button
                                Expanded(
                                  child: ElevatedButton.icon(
                                    icon: const Icon(Icons.payments_rounded, size: 14),
                                    label: Text(lang.tr(en: 'Pay', hi: 'भुगतान')),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF0D9488),
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      visualDensity: VisualDensity.compact,
                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                                      textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                    onPressed: () async {
                                      final res = await RecordWorkerPaymentDialog.show(
                                        context,
                                        repository: _repo,
                                        workers: [worker],
                                        preselectedWorker: worker,
                                      );
                                      if (res == true) _loadWagesData();
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildPayrollSubTile({
    required String label,
    required int amount,
    required Color textColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 10, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 2),
          Text(
            CurrencyFormatter.format(CurrencyFormatter.paiseToRupees(amount)),
            style: TextStyle(color: textColor, fontSize: 12, fontWeight: FontWeight.w800),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBadge(String key, String label) {
    final isSelected = _workerBalanceFilter == key;
    return InkWell(
      onTap: () => setState(() => _workerBalanceFilter = key),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFF475569),
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
