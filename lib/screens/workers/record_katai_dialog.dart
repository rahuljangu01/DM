import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../models/worker.dart';
import '../../models/machine_katai_entry.dart';
import '../../core/localization/language_provider.dart';
import '../../repositories/worker_repository.dart';

class RecordKataiDialog extends StatefulWidget {
  final WorkerRepository repository;
  final List<Worker> workers;
  final List<String> machines;
  final Worker? preselectedWorker;

  const RecordKataiDialog({
    super.key,
    required this.repository,
    required this.workers,
    required this.machines,
    this.preselectedWorker,
  });

  static Future<bool?> show(
    BuildContext context, {
    required WorkerRepository repository,
    required List<Worker> workers,
    required List<String> machines,
    Worker? preselectedWorker,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => RecordKataiDialog(
        repository: repository,
        workers: workers,
        machines: machines,
        preselectedWorker: preselectedWorker,
      ),
    );
  }

  @override
  State<RecordKataiDialog> createState() => _RecordKataiDialogState();
}

class _RecordKataiDialogState extends State<RecordKataiDialog> {
  final _formKey = GlobalKey<FormState>();

  late DateTime _selectedDate;
  int? _selectedWorkerId;
  String? _selectedMachine;
  String _shift = 'day'; // 'day', 'night'
  String _unit = 'meter'; // 'meter', 'piece', 'than'

  late TextEditingController _designController;
  late TextEditingController _qtyController;
  late TextEditingController _rateController;
  late TextEditingController _notesController;

  double _totalCalculatedRupees = 0.0;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _designController = TextEditingController();
    _qtyController = TextEditingController();
    _rateController = TextEditingController();
    _notesController = TextEditingController();

    if (widget.preselectedWorker != null) {
      _selectedWorkerId = widget.preselectedWorker!.id;
      if (widget.preselectedWorker!.ratePaise > 0) {
        _rateController.text = CurrencyFormatter.format(widget.preselectedWorker!.rateRupees, includeSymbol: false);
      }
      if (widget.preselectedWorker!.machineNumber != null && widget.preselectedWorker!.machineNumber!.isNotEmpty) {
        _selectedMachine = widget.preselectedWorker!.machineNumber;
      }
    } else if (widget.workers.isNotEmpty) {
      _selectedWorkerId = widget.workers.first.id;
      if (widget.workers.first.ratePaise > 0) {
        _rateController.text = CurrencyFormatter.format(widget.workers.first.rateRupees, includeSymbol: false);
      }
      if (widget.workers.first.machineNumber != null && widget.workers.first.machineNumber!.isNotEmpty) {
        _selectedMachine = widget.workers.first.machineNumber;
      }
    }

    if (_selectedMachine == null && widget.machines.isNotEmpty) {
      _selectedMachine = widget.machines.first;
    }

    _qtyController.addListener(_calculateTotal);
    _rateController.addListener(_calculateTotal);
  }

  @override
  void dispose() {
    _qtyController.removeListener(_calculateTotal);
    _rateController.removeListener(_calculateTotal);
    _designController.dispose();
    _qtyController.dispose();
    _rateController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _calculateTotal() {
    final qty = double.tryParse(_qtyController.text.trim()) ?? 0.0;
    final rate = CurrencyFormatter.parseDouble(_rateController.text.trim());
    setState(() {
      _totalCalculatedRupees = qty * rate;
    });
  }

  void _onWorkerChanged(int? workerId) {
    setState(() {
      _selectedWorkerId = workerId;
      if (workerId != null) {
        final worker = widget.workers.firstWhere((w) => w.id == workerId);
        if (worker.ratePaise > 0) {
          _rateController.text = CurrencyFormatter.format(worker.rateRupees, includeSymbol: false);
        }
        if (worker.machineNumber != null && worker.machineNumber!.isNotEmpty) {
          _selectedMachine = worker.machineNumber;
        }
      }
    });
    _calculateTotal();
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2025),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _save() async {
    final lang = Provider.of<LanguageProvider>(context, listen: false);
    if (!_formKey.currentState!.validate()) return;
    if (_selectedWorkerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(lang.tr(en: 'Please select worker', hi: 'कृपया कारीगर चुनें'))),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
      final qty = double.parse(_qtyController.text.trim());
      final rateRupees = CurrencyFormatter.parseDouble(_rateController.text.trim());
      final ratePaise = CurrencyFormatter.rupeesToPaise(rateRupees);
      final totalPaise = (qty * ratePaise).round();

      final entry = MachineKataiEntry(
        date: dateStr,
        machineNumber: _selectedMachine ?? 'Machine 1',
        workerId: _selectedWorkerId!,
        designCode: _designController.text.trim().isEmpty ? null : _designController.text.trim(),
        shift: _shift,
        quantity: qty,
        unit: _unit,
        ratePaise: ratePaise,
        totalAmountPaise: totalPaise,
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      );

      await widget.repository.insertKataiEntry(entry);

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(lang.tr(en: 'Error saving entry: $e', hi: 'कटाई एंट्री सेव करने में त्रुटि: $e')), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageProvider>(context);
    final dateDisplay = DateFormat('dd MMM yyyy (EEEE)').format(_selectedDate);

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.amber.shade100,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.precision_manufacturing_rounded, color: Colors.amber, size: 24),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              lang.tr(en: 'Record Machine Katai', hi: 'मशीन कटाई दर्ज करें'),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 440,
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Date Picker
                InkWell(
                  onTap: _selectDate,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.backgroundLight,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.borderLight),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_month_rounded, size: 18, color: AppColors.primaryNavy),
                        const SizedBox(width: 8),
                        Text(
                          dateDisplay,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        const Spacer(),
                        Text(
                          lang.tr(en: 'Change', hi: 'बदलें'),
                          style: const TextStyle(color: AppColors.primaryNavy, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Machine Selector
                DropdownButtonFormField<String>(
                  initialValue: _selectedMachine,
                  decoration: InputDecoration(
                    labelText: '${lang.tr(en: 'Machine Number', hi: 'मशीन नंबर')} *',
                    prefixIcon: const Icon(Icons.settings_outlined),
                  ),
                  items: widget.machines.map((m) {
                    return DropdownMenuItem(value: m, child: Text(m));
                  }).toList(),
                  onChanged: (val) => setState(() => _selectedMachine = val),
                  validator: (v) => (v == null || v.isEmpty) ? lang.tr(en: 'Select machine', hi: 'मशीन चुनें') : null,
                ),
                const SizedBox(height: 12),

                // Worker Selector
                DropdownButtonFormField<int>(
                  initialValue: _selectedWorkerId,
                  decoration: InputDecoration(
                    labelText: '${lang.tr(en: 'Worker / Operator', hi: 'कारीगर / ऑपरेटर')} *',
                    prefixIcon: const Icon(Icons.person_outline_rounded),
                  ),
                  items: widget.workers.map((w) {
                    return DropdownMenuItem(
                      value: w.id,
                      child: Text('${w.name} ${w.machineNumber != null ? "(${w.machineNumber})" : ""}'),
                    );
                  }).toList(),
                  onChanged: _onWorkerChanged,
                  validator: (v) => v == null ? lang.tr(en: 'Select worker', hi: 'कारीगर चुनें') : null,
                ),
                const SizedBox(height: 12),

                // Shift & Unit Selection
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _shift,
                        decoration: InputDecoration(
                          labelText: lang.tr(en: 'Shift', hi: 'शिफ्ट'),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        ),
                        items: [
                          DropdownMenuItem(value: 'day', child: Text(lang.tr(en: 'Day Shift', hi: 'दिन'))),
                          DropdownMenuItem(value: 'night', child: Text(lang.tr(en: 'Night Shift', hi: 'रात'))),
                        ],
                        onChanged: (val) => setState(() => _shift = val ?? 'day'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _unit,
                        decoration: InputDecoration(
                          labelText: lang.tr(en: 'Unit', hi: 'इकाई'),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        ),
                        items: [
                          DropdownMenuItem(value: 'meter', child: Text(lang.tr(en: 'Meters', hi: 'मीटर'))),
                          DropdownMenuItem(value: 'than', child: Text(lang.tr(en: 'Thans', hi: 'थान'))),
                          DropdownMenuItem(value: 'piece', child: Text(lang.tr(en: 'Pieces', hi: 'पीस'))),
                        ],
                        onChanged: (val) => setState(() => _unit = val ?? 'meter'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Design / Lace Code
                TextFormField(
                  controller: _designController,
                  decoration: InputDecoration(
                    labelText: lang.tr(en: 'Design / Lace Code', hi: 'डिज़ाइन / लेस का नाम'),
                    hintText: 'e.g. DM-ZARI-101, 2-Inch Golden Border',
                    prefixIcon: const Icon(Icons.style_outlined),
                  ),
                ),
                const SizedBox(height: 12),

                // Quantity & Rate Row
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _qtyController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: '${lang.tr(en: 'Katai Qty', hi: 'कटाई मात्रा')} *',
                          hintText: 'e.g. 450',
                          prefixIcon: const Icon(Icons.straighten_rounded),
                          suffixText: _unit,
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return lang.tr(en: 'Enter quantity', hi: 'मात्रा भरें');
                          if (double.tryParse(v.trim()) == null || double.parse(v.trim()) <= 0) {
                            return lang.tr(en: 'Enter valid number', hi: 'सही संख्या दें');
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _rateController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: '${lang.tr(en: 'Rate per', hi: 'दर प्रति')} $_unit *',
                          hintText: '0.00',
                          prefixIcon: const Icon(Icons.currency_rupee_rounded),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return lang.tr(en: 'Enter rate', hi: 'दर भरें');
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Live Total Calculated Amount Banner
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF15803D).withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        lang.tr(en: 'Total Katai Wages:', hi: 'कुल कटाई मजदूरी:'),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF15803D)),
                      ),
                      Text(
                        CurrencyFormatter.format(_totalCalculatedRupees),
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF15803D)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Notes
                TextFormField(
                  controller: _notesController,
                  decoration: InputDecoration(
                    labelText: lang.tr(en: 'Notes / Remarks', hi: 'रिमार्क / टिप्पणी'),
                    hintText: lang.tr(en: 'e.g. Work completed smoothly', hi: 'e.g. धागा टूटने से 1 घंटा लेट, पूरा माल ओके'),
                    prefixIcon: const Icon(Icons.note_alt_outlined),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: Text(lang.tr(en: 'Cancel', hi: 'रद्द करें')),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryNavy,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
          child: _isSaving
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : Text(lang.tr(en: 'Save Katai', hi: 'कटाई सेव करें')),
        ),
      ],
    );
  }
}
