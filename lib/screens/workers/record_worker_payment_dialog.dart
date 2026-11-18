import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../models/worker.dart';
import '../../models/worker_payment.dart';
import '../../core/localization/language_provider.dart';
import '../../repositories/worker_repository.dart';

class RecordWorkerPaymentDialog extends StatefulWidget {
  final WorkerRepository repository;
  final List<Worker> workers;
  final Worker? preselectedWorker;

  const RecordWorkerPaymentDialog({
    super.key,
    required this.repository,
    required this.workers,
    this.preselectedWorker,
  });

  static Future<bool?> show(
    BuildContext context, {
    required WorkerRepository repository,
    required List<Worker> workers,
    Worker? preselectedWorker,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => RecordWorkerPaymentDialog(
        repository: repository,
        workers: workers,
        preselectedWorker: preselectedWorker,
      ),
    );
  }

  @override
  State<RecordWorkerPaymentDialog> createState() => _RecordWorkerPaymentDialogState();
}

class _RecordWorkerPaymentDialogState extends State<RecordWorkerPaymentDialog> {
  final _formKey = GlobalKey<FormState>();

  late DateTime _selectedDate;
  int? _selectedWorkerId;
  String _paymentType = 'advance'; // 'advance', 'wage_payout', 'bonus'
  String _paymentMethod = 'cash'; // 'cash', 'upi', 'bank_transfer'

  late TextEditingController _amountController;
  late TextEditingController _referenceController;
  late TextEditingController _notesController;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _amountController = TextEditingController();
    _referenceController = TextEditingController();
    _notesController = TextEditingController();

    if (widget.preselectedWorker != null) {
      _selectedWorkerId = widget.preselectedWorker!.id;
    } else if (widget.workers.isNotEmpty) {
      _selectedWorkerId = widget.workers.first.id;
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _referenceController.dispose();
    _notesController.dispose();
    super.dispose();
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
      final amountRupees = CurrencyFormatter.parseDouble(_amountController.text.trim());
      final amountPaise = CurrencyFormatter.rupeesToPaise(amountRupees);

      final payment = WorkerPayment(
        workerId: _selectedWorkerId!,
        date: dateStr,
        paymentType: _paymentType,
        amountPaise: amountPaise,
        paymentMethod: _paymentMethod,
        referenceNo: _referenceController.text.trim().isEmpty ? null : _referenceController.text.trim(),
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      );

      await widget.repository.recordPayment(payment);

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(lang.tr(en: 'Error saving payment: $e', hi: 'भुगतान सेव करने में त्रुटि: $e')), backgroundColor: Colors.red),
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
              color: Colors.green.shade100,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.payments_rounded, color: Colors.green, size: 24),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              lang.tr(en: 'Pay Worker / Advance', hi: 'कारीगर भुगतान / एडवांस'),
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
                  onChanged: (val) => setState(() => _selectedWorkerId = val),
                  validator: (v) => v == null ? lang.tr(en: 'Select worker', hi: 'कारीगर चुनें') : null,
                ),
                const SizedBox(height: 12),

                // Payment Type Selector
                Text(
                  lang.tr(en: 'Payment Type:', hi: 'भुगतान का प्रकार:'),
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: _paymentType,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.category_rounded),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: 'advance',
                      child: Text(lang.tr(en: 'Advance', hi: 'उठाव / एडवांस')),
                    ),
                    DropdownMenuItem(
                      value: 'wage_payout',
                      child: Text(lang.tr(en: 'Wage Settlement', hi: 'मजदूरी भुगतान')),
                    ),
                    DropdownMenuItem(
                      value: 'bonus',
                      child: Text(lang.tr(en: 'Bonus', hi: 'बोनस / इनाम')),
                    ),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _paymentType = val);
                  },
                ),
                const SizedBox(height: 12),

                // Amount
                TextFormField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: '${lang.tr(en: 'Amount (₹)', hi: 'राशि (₹)')} *',
                    hintText: '0.00',
                    prefixIcon: const Icon(Icons.currency_rupee_rounded),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return lang.tr(en: 'Enter amount', hi: 'राशि दर्ज करें');
                    final amt = CurrencyFormatter.parseDouble(v.trim());
                    if (amt <= 0) return lang.tr(en: 'Enter valid amount', hi: 'मान्य राशि दर्ज करें');
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                // Payment Method
                DropdownButtonFormField<String>(
                  initialValue: _paymentMethod,
                  decoration: InputDecoration(
                    labelText: lang.tr(en: 'Payment Method', hi: 'माध्यम'),
                    prefixIcon: const Icon(Icons.account_balance_wallet_rounded),
                  ),
                  items: [
                    DropdownMenuItem(value: 'cash', child: Text(lang.tr(en: 'Cash', hi: 'नकद'))),
                    const DropdownMenuItem(value: 'upi', child: Text('UPI / GooglePay / PhonePe')),
                    DropdownMenuItem(value: 'bank_transfer', child: Text(lang.tr(en: 'Bank Transfer (NEFT/RTGS)', hi: 'बैंक ट्रांसफर (NEFT/RTGS)'))),
                  ],
                  onChanged: (val) => setState(() => _paymentMethod = val ?? 'cash'),
                ),
                const SizedBox(height: 12),

                // Reference / Notes
                TextFormField(
                  controller: _notesController,
                  decoration: InputDecoration(
                    labelText: lang.tr(en: 'Notes / Remarks', hi: 'रिमार्क / टिप्पणी'),
                    hintText: lang.tr(en: 'e.g. Advance, 15 days settlement', hi: 'e.g. दीवाली एडवांस, 15 दिन का हिसाब'),
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
              : Text(lang.tr(en: 'Confirm Payment', hi: 'पेमेंट दर्ज करें')),
        ),
      ],
    );
  }
}
