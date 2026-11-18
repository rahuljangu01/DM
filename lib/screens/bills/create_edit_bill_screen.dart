import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/localization/language_provider.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';
import '../../models/document.dart';
import '../../models/document_item.dart';
import '../../models/party.dart';
import '../../repositories/document_repository.dart';
import '../../repositories/party_repository.dart';

class CreateEditBillScreen extends StatefulWidget {
  final int? initialPartyId;
  final DocumentRepository? docRepository;
  final PartyRepository? partyRepository;

  const CreateEditBillScreen({
    super.key,
    this.initialPartyId,
    this.docRepository,
    this.partyRepository,
  });

  @override
  State<CreateEditBillScreen> createState() => _CreateEditBillScreenState();
}

class _CreateEditBillScreenState extends State<CreateEditBillScreen> {
  final _formKey = GlobalKey<FormState>();
  late DocumentRepository _docRepo;
  late PartyRepository _partyRepo;

  List<Party> _parties = [];
  Party? _selectedParty;
  String _docType = 'kaccha_bill'; // 'kaccha_bill' or 'tax_invoice'
  String _docNumber = '';
  DateTime _docDate = DateTime.now();
  DateTime _dueDate = DateTime.now().add(const Duration(days: 15));

  final TextEditingController _discountController = TextEditingController(text: '0');
  final TextEditingController _advancePaymentController = TextEditingController(text: '0');
  final TextEditingController _notesController = TextEditingController();
  String _paymentMethod = 'cash';

  // Line items
  final List<_BillItemDraft> _items = [];
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _docRepo = widget.docRepository ?? DocumentRepository();
    _partyRepo = widget.partyRepository ?? PartyRepository();
    _initData();
  }

  Future<void> _initData() async {
    setState(() => _isLoading = true);
    final parties = await _partyRepo.getAllParties();
    final nextNumber = await _docRepo.generateNextDocNumber(_docType);

    Party? matchedParty;
    if (widget.initialPartyId != null) {
      matchedParty = parties.where((p) => p.id == widget.initialPartyId).firstOrNull;
    }
    matchedParty ??= parties.isNotEmpty ? parties.first : null;

    // Start with 1 blank item
    _items.add(_BillItemDraft());

    if (mounted) {
      setState(() {
        _parties = parties;
        _selectedParty = matchedParty;
        _docNumber = nextNumber;
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _discountController.dispose();
    _advancePaymentController.dispose();
    _notesController.dispose();
    for (final item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  int get _subtotalPaise {
    int total = 0;
    for (final item in _items) {
      total += item.taxableAmountPaise;
    }
    return total;
  }

  int get _taxPaise {
    int total = 0;
    for (final item in _items) {
      total += (item.lineTotalPaise - item.taxableAmountPaise);
    }
    return total;
  }

  int get _discountPaise {
    final d = CurrencyFormatter.parseDouble(_discountController.text);
    return CurrencyFormatter.rupeesToPaise(d);
  }

  int get _grandTotalPaise {
    final total = _subtotalPaise + _taxPaise - _discountPaise;
    return total > 0 ? total : 0;
  }

  int get _advancePaise {
    final d = CurrencyFormatter.parseDouble(_advancePaymentController.text);
    final paise = CurrencyFormatter.rupeesToPaise(d);
    return paise.clamp(0, _grandTotalPaise);
  }

  int get _remainingBalancePaise {
    return _grandTotalPaise - _advancePaise;
  }

  Future<void> _pickDocDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _docDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      setState(() => _docDate = picked);
    }
  }

  Future<void> _pickDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      setState(() => _dueDate = picked);
    }
  }

  Future<void> _saveBill() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedParty == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select or create a party first')),
      );
      return;
    }

    if (_items.isEmpty || _items.every((it) => it.nameController.text.trim().isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one lace line item')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final lineItems = _items
          .where((it) => it.nameController.text.trim().isNotEmpty)
          .map((it) => it.toDocumentItem())
          .toList();

      final doc = BusinessDocument(
        docNumber: _docNumber,
        docType: _docType,
        partyId: _selectedParty!.id!,
        partyName: _selectedParty!.name,
        docDate: DateFormatter.toIso(_docDate).substring(0, 10),
        dueDate: DateFormatter.toIso(_dueDate).substring(0, 10),
        discountPaise: _discountPaise,
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        items: lineItems,
      );

      await _docRepo.createDocument(
        doc,
        advancePaymentPaise: _advancePaise,
        paymentMethod: _paymentMethod,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Bill $_docNumber generated successfully'),
            backgroundColor: AppColors.primaryNavy,
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating bill: $e'), backgroundColor: AppColors.payableRed),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text(lang.tr(en: 'Create Bill', hi: 'बिल बनाएं'))),
        body: const Center(child: CircularProgressIndicator(color: AppColors.primaryGold)),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: Text(
          _docType == 'kaccha_bill'
              ? lang.tr(en: 'New Kaccha Bill', hi: 'नया कच्चा बिल')
              : lang.tr(en: 'New GST Tax Invoice', hi: 'नया टैक्स इनवॉयस'),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(14),
          children: [
            // Bill Type & Doc Number
            Card(
              color: AppColors.surfaceWhite,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: SegmentedButton<String>(
                            segments: [
                              ButtonSegment(
                                value: 'kaccha_bill',
                                label: Text(lang.tr(en: 'Kaccha Bill', hi: 'कच्चा बिल')),
                              ),
                              ButtonSegment(
                                value: 'tax_invoice',
                                label: Text(lang.tr(en: 'Tax Invoice', hi: 'टैक्स इनवॉयस')),
                              ),
                            ],
                            selected: {_docType},
                            onSelectionChanged: (val) async {
                              final newType = val.first;
                              final nextNum = await _docRepo.generateNextDocNumber(newType);
                              setState(() {
                                _docType = newType;
                                _docNumber = nextNum;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${lang.tr(en: 'Bill Number', hi: 'बिल नंबर')}: $_docNumber',
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.primaryNavy),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Party & Dates
            Card(
              color: AppColors.surfaceWhite,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    DropdownButtonFormField<Party>(
                      initialValue: _selectedParty,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: lang.tr(en: 'Select Customer *', hi: 'ग्राहक चुनें *'),
                        prefixIcon: const Icon(Icons.person_outline, color: AppColors.primaryNavy),
                      ),
                      items: _parties.map((p) {
                        return DropdownMenuItem<Party>(
                          value: p,
                          child: Text(
                            '${p.name} (${CurrencyFormatter.format(p.currentBalanceRupees)})',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 14),
                          ),
                        );
                      }).toList(),
                      onChanged: (val) => setState(() => _selectedParty = val),
                      validator: (val) => val == null ? 'Please select party' : null,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: _pickDocDate,
                            child: InputDecorator(
                              decoration: InputDecoration(
                                labelText: lang.tr(en: 'Bill Date', hi: 'बिल तारीख'),
                                prefixIcon: const Icon(Icons.calendar_today, size: 18),
                              ),
                              child: Text(DateFormatter.format(_docDate), style: const TextStyle(fontSize: 13)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: InkWell(
                            onTap: _pickDueDate,
                            child: InputDecorator(
                              decoration: InputDecoration(
                                labelText: lang.tr(en: 'Due Date', hi: 'अंतिम तारीख'),
                                prefixIcon: const Icon(Icons.event, size: 18),
                              ),
                              child: Text(DateFormatter.format(_dueDate), style: const TextStyle(fontSize: 13)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Line Items Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  lang.tr(en: 'Lace Items & Quantities', hi: 'माल का विवरण'),
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.add, size: 16),
                  label: Text(lang.tr(en: 'Add Item', hi: 'माल जोड़ें'), style: const TextStyle(fontWeight: FontWeight.w700)),
                  onPressed: () {
                    setState(() {
                      _items.add(_BillItemDraft());
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 6),

            ..._items.asMap().entries.map((entry) {
              final idx = entry.key;
              final item = entry.value;
              return _buildItemCard(idx, item);
            }),

            const SizedBox(height: 14),

            // Totals & Discount Card
            Card(
              color: AppColors.surfaceWhite,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    _buildSummaryRow(lang.tr(en: 'Subtotal', hi: 'कुल माल कीमत'), CurrencyFormatter.formatPaise(_subtotalPaise)),
                    if (_docType == 'tax_invoice' && _taxPaise > 0) ...[
                      const SizedBox(height: 6),
                      _buildSummaryRow(lang.tr(en: 'GST Tax', hi: 'जीएसटी (कर)'), CurrencyFormatter.formatPaise(_taxPaise)),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            lang.tr(en: 'Overall Discount (₹)', hi: 'छूट (डिस्काउंट ₹)'),
                            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                          ),
                        ),
                        SizedBox(
                          width: 110,
                          child: TextFormField(
                            controller: _discountController,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.right,
                            decoration: const InputDecoration(
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 20),
                    _buildSummaryRow(
                      lang.tr(en: 'Grand Total', hi: 'कुल देय राशि'),
                      CurrencyFormatter.formatPaise(_grandTotalPaise),
                      isBold: true,
                      color: AppColors.primaryNavy,
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            lang.tr(en: 'Advance Paid (₹)', hi: 'जमा राशि (₹)'),
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.successGreen),
                          ),
                        ),
                        SizedBox(
                          width: 110,
                          child: TextFormField(
                            controller: _advancePaymentController,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.right,
                            decoration: const InputDecoration(
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                      ],
                    ),
                    if (_advancePaise > 0) ...[
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(lang.tr(en: 'Payment Mode:', hi: 'भुगतान माध्यम:'), style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                          DropdownButton<String>(
                            value: _paymentMethod,
                            underline: const SizedBox.shrink(),
                            items: [
                              DropdownMenuItem(value: 'cash', child: Text(lang.tr(en: 'Cash', hi: 'नकद'))),
                              const DropdownMenuItem(value: 'upi', child: Text('UPI (GPay / PhonePe)')),
                              DropdownMenuItem(value: 'bank_transfer', child: Text(lang.tr(en: 'Bank Transfer', hi: 'बैंक ट्रांसफर'))),
                              DropdownMenuItem(value: 'cheque', child: Text(lang.tr(en: 'Cheque', hi: 'चेक'))),
                            ],
                            onChanged: (v) => setState(() => _paymentMethod = v!),
                          ),
                        ],
                      ),
                    ],
                    const Divider(height: 20),
                    _buildSummaryRow(
                      lang.tr(en: 'Remaining Balance', hi: 'बाकी राशि'),
                      CurrencyFormatter.formatPaise(_remainingBalancePaise),
                      isBold: true,
                      color: _remainingBalancePaise > 0 ? AppColors.payableRed : AppColors.successGreen,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Notes
            TextFormField(
              controller: _notesController,
              decoration: InputDecoration(
                labelText: lang.tr(en: 'Notes / Transport Memo', hi: 'रिमार्क / ट्रांसपोर्ट विवरण'),
                hintText: lang.tr(en: 'e.g. Sent via Tempo #882', hi: 'उदा. टेम्पो भाड़ा, ट्रांसपोर्ट बिल्टी नंबर'),
              ),
            ),
            const SizedBox(height: 24),

            // Submit Button
            ElevatedButton(
              onPressed: _isSaving ? null : _saveBill,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryNavy,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isSaving
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text(lang.tr(en: 'Save Bill $_docNumber', hi: 'बिल बनाएं $_docNumber'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemCard(int index, _BillItemDraft item) {
    return Card(
      color: AppColors.surfaceWhite,
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor: AppColors.primaryNavy.withValues(alpha: 0.1),
                  child: Text('${index + 1}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primaryNavy)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: item.nameController,
                    decoration: const InputDecoration(
                      hintText: 'Lace Design Name (e.g. Zari Border 2")',
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                if (_items.length > 1)
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: AppColors.payableRed, size: 20),
                    onPressed: () {
                      setState(() {
                        _items.removeAt(index);
                      });
                    },
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                // Qty
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: item.qtyController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Qty',
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 6),
                // Unit
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String>(
                    initialValue: item.unit,
                    isDense: true,
                    decoration: const InputDecoration(
                      labelText: 'Unit',
                      contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'meter', child: Text('Mtr')),
                      DropdownMenuItem(value: 'roll', child: Text('Roll')),
                      DropdownMenuItem(value: 'piece', child: Text('Pc')),
                      DropdownMenuItem(value: 'kg', child: Text('Kg')),
                    ],
                    onChanged: (v) => setState(() => item.unit = v!),
                  ),
                ),
                const SizedBox(width: 6),
                // Rate
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: item.rateController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Rate ₹',
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 6),
                // Line Total
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text('Total', style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
                      Text(
                        CurrencyFormatter.formatPaise(item.lineTotalPaise),
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.primaryNavy),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isBold = false, Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isBold ? 14 : 13,
            fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
            color: color ?? AppColors.textSecondary,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isBold ? 16 : 14,
            fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
            color: color ?? AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _BillItemDraft {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController qtyController = TextEditingController(text: '1');
  final TextEditingController rateController = TextEditingController(text: '0');
  String unit = 'meter';

  void dispose() {
    nameController.dispose();
    qtyController.dispose();
    rateController.dispose();
  }

  double get quantity => double.tryParse(qtyController.text) ?? 1.0;
  double get rateRupees => CurrencyFormatter.parseDouble(rateController.text);
  int get ratePaise => CurrencyFormatter.rupeesToPaise(rateRupees);
  int get taxableAmountPaise => (quantity * ratePaise).round();
  int get lineTotalPaise => taxableAmountPaise;

  DocumentItem toDocumentItem() {
    return DocumentItem(
      itemName: nameController.text.trim(),
      quantity: quantity,
      unit: unit,
      ratePaise: ratePaise,
      discountPaise: 0,
      taxableAmountPaise: taxableAmountPaise,
      lineTotalPaise: lineTotalPaise,
    );
  }
}
