import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../models/document.dart';
import '../../repositories/document_repository.dart';

class ConvertChallanDialog extends StatefulWidget {
  final BusinessDocument challan;
  final DocumentRepository? repository;

  const ConvertChallanDialog({super.key, required this.challan, this.repository});

  static Future<int?> show({
    required BuildContext context,
    required BusinessDocument challan,
    DocumentRepository? repository,
  }) {
    return showDialog<int>(
      context: context,
      builder: (context) => ConvertChallanDialog(challan: challan, repository: repository),
    );
  }

  @override
  State<ConvertChallanDialog> createState() => _ConvertChallanDialogState();
}

class _ConvertChallanDialogState extends State<ConvertChallanDialog> {
  late DocumentRepository _repo;
  String _targetDocType = 'kaccha_bill';
  final TextEditingController _discountController = TextEditingController(text: '0');
  final TextEditingController _advanceController = TextEditingController(text: '0');
  String _paymentMethod = 'cash';
  bool _isConverting = false;

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? DocumentRepository();
  }

  @override
  void dispose() {
    _discountController.dispose();
    _advanceController.dispose();
    super.dispose();
  }

  Future<void> _convert() async {
    setState(() => _isConverting = true);
    final discountRupees = CurrencyFormatter.parseDouble(_discountController.text);
    final advanceRupees = CurrencyFormatter.parseDouble(_advanceController.text);

    try {
      final newDocId = await _repo.convertChallanToInvoice(
        challanId: widget.challan.id!,
        targetDocType: _targetDocType,
        discountPaise: CurrencyFormatter.rupeesToPaise(discountRupees),
        advancePaymentPaise: CurrencyFormatter.rupeesToPaise(advanceRupees),
        paymentMethod: _paymentMethod,
      );

      if (mounted) {
        Navigator.of(context).pop(newDocId);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to convert: $e'), backgroundColor: AppColors.payableRed),
        );
      }
    } finally {
      if (mounted) setState(() => _isConverting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.transform_rounded, color: AppColors.primaryGold),
          const SizedBox(width: 8),
          const Text('Convert Challan to Bill', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Challan #${widget.challan.docNumber}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            Text('Party: ${widget.challan.partyName ?? "Customer"}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.surfaceMuted,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Converting will add this sales revenue to the party\'s ledger without duplicating inventory stock deductions.',
                style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
            ),
            const SizedBox(height: 14),
            const Text('Select Invoice Type:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'kaccha_bill', label: Text('Kaccha Bill')),
                ButtonSegment(value: 'tax_invoice', label: Text('Tax Invoice')),
              ],
              selected: {_targetDocType},
              onSelectionChanged: (v) => setState(() => _targetDocType = v.first),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _discountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Discount (₹)',
                isDense: true,
              ),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _advanceController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Advance Payment Received (₹)',
                isDense: true,
              ),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: _paymentMethod,
              isDense: true,
              decoration: const InputDecoration(
                labelText: 'Payment Mode',
              ),
              items: const [
                DropdownMenuItem(value: 'cash', child: Text('Cash')),
                DropdownMenuItem(value: 'upi', child: Text('UPI')),
                DropdownMenuItem(value: 'bank_transfer', child: Text('Bank Transfer')),
              ],
              onChanged: (v) => setState(() => _paymentMethod = v!),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryNavy),
          onPressed: _isConverting ? null : _convert,
          child: _isConverting
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Text('Convert & Post to Ledger'),
        ),
      ],
    );
  }
}
