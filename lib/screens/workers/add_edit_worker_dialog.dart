import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../models/worker.dart';
import '../../core/localization/language_provider.dart';
import '../../repositories/worker_repository.dart';

class AddEditWorkerDialog extends StatefulWidget {
  final Worker? worker;
  final WorkerRepository repository;

  const AddEditWorkerDialog({super.key, this.worker, required this.repository});

  static Future<bool?> show(BuildContext context, WorkerRepository repository, [Worker? worker]) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AddEditWorkerDialog(worker: worker, repository: repository),
    );
  }

  @override
  State<AddEditWorkerDialog> createState() => _AddEditWorkerDialogState();
}

class _AddEditWorkerDialogState extends State<AddEditWorkerDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _machineController;
  late TextEditingController _rateController;
  late TextEditingController _notesController;

  String _wageType = 'katai_piece'; // 'katai_piece', 'daily', 'monthly'
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final w = widget.worker;
    _nameController = TextEditingController(text: w?.name ?? '');
    _phoneController = TextEditingController(text: w?.phone ?? '');
    _machineController = TextEditingController(text: w?.machineNumber ?? '');
    _rateController = TextEditingController(
      text: w != null && w.ratePaise > 0
          ? CurrencyFormatter.format(w.rateRupees, includeSymbol: false)
          : '',
    );
    _notesController = TextEditingController(text: w?.notes ?? '');
    if (w != null) {
      _wageType = w.wageType;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _machineController.dispose();
    _rateController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final rateRupees = CurrencyFormatter.parseDouble(_rateController.text);
      final ratePaise = CurrencyFormatter.rupeesToPaise(rateRupees);

      if (widget.worker == null) {
        final newWorker = Worker(
          name: _nameController.text.trim(),
          phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
          machineNumber: _machineController.text.trim().isEmpty ? null : _machineController.text.trim(),
          wageType: _wageType,
          ratePaise: ratePaise,
          notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        );
        await widget.repository.insertWorker(newWorker);
      } else {
        final updated = widget.worker!.copyWith(
          name: _nameController.text.trim(),
          phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
          machineNumber: _machineController.text.trim().isEmpty ? null : _machineController.text.trim(),
          wageType: _wageType,
          ratePaise: ratePaise,
          notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        );
        await widget.repository.updateWorker(updated);
      }

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving worker: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageProvider>(context);
    final isEditing = widget.worker != null;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primaryGold.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.person_pin_rounded, color: AppColors.goldDark, size: 24),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isEditing
                  ? lang.tr(en: 'Edit Worker', hi: 'कारीगर संपादित करें')
                  : lang.tr(en: 'Add New Worker', hi: 'नया कारीगर जोड़ें'),
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
                // Karigar Name
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: '${lang.tr(en: 'Worker Name', hi: 'कारीगर / ऑपरेटर का नाम')} *',
                    hintText: 'e.g. Ramesh Bhai Karigar',
                    prefixIcon: const Icon(Icons.person_rounded),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? lang.tr(en: 'Name is required', hi: 'नाम दर्ज करना अनिवार्य है')
                      : null,
                ),
                const SizedBox(height: 12),

                // Mobile Number
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: lang.tr(en: 'Mobile Number', hi: 'मोबाइल नंबर'),
                    hintText: 'e.g. 9825123456',
                    prefixIcon: const Icon(Icons.phone_android_rounded),
                  ),
                ),
                const SizedBox(height: 12),

                // Assigned Machine Number
                TextFormField(
                  controller: _machineController,
                  decoration: InputDecoration(
                    labelText: lang.tr(en: 'Assigned Machine', hi: 'मशीन नंबर'),
                    hintText: lang.tr(en: 'e.g. Machine 1', hi: 'उदा. मशीन 1'),
                    prefixIcon: const Icon(Icons.precision_manufacturing_rounded),
                  ),
                ),
                const SizedBox(height: 14),

                // Wage Type Selection
                Text(
                  lang.tr(en: 'Wage / Salary Type:', hi: 'मजदूरी / पगार का प्रकार:'),
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: _wageType,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.payments_rounded),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: 'katai_piece',
                      child: Text(lang.tr(en: 'Per Meter Katai Rate', hi: 'कटाई दर / प्रति मीटर')),
                    ),
                    DropdownMenuItem(
                      value: 'daily',
                      child: Text(lang.tr(en: 'Daily Wage', hi: 'दैनिक हाजिरी')),
                    ),
                    DropdownMenuItem(
                      value: 'monthly',
                      child: Text(lang.tr(en: 'Monthly Salary', hi: 'मासिक पगार')),
                    ),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _wageType = val);
                  },
                ),
                const SizedBox(height: 12),

                // Rate Input
                TextFormField(
                  controller: _rateController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: _wageType == 'katai_piece'
                        ? lang.tr(en: 'Rate per Meter (₹)', hi: 'कटाई दर प्रति मीटर (₹)')
                        : (_wageType == 'daily'
                            ? lang.tr(en: 'Daily Rate (₹)', hi: 'प्रति दिन हाजिरी दर (₹)')
                            : lang.tr(en: 'Monthly Salary (₹)', hi: 'मासिक पगार (₹)')),
                    hintText: '0.00',
                    prefixIcon: const Icon(Icons.currency_rupee_rounded),
                  ),
                ),
                const SizedBox(height: 12),

                // Notes
                TextFormField(
                  controller: _notesController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: lang.tr(en: 'Notes / Remarks', hi: 'टिप्पणी / संदर्भ'),
                    hintText: 'e.g. Day shift karigar, Katargam unit',
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
              : Text(isEditing ? lang.tr(en: 'Update', hi: 'अपडेट करें') : lang.tr(en: 'Save', hi: 'सेव करें')),
        ),
      ],
    );
  }
}
