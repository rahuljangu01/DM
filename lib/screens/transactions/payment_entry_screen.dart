import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/localization/language_provider.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';
import '../../models/party.dart';
import '../../models/transaction.dart';
import '../../repositories/party_repository.dart';
import '../../repositories/transaction_repository.dart';
import '../../services/firebase_sync_service.dart';

class PaymentEntryScreen extends StatefulWidget {
  final int? initialPartyId;
  final String? initialTxType;
  final int? initialRelatedDocId;
  final double? initialAmountRupees;
  final TransactionRepository? txRepository;
  final PartyRepository? partyRepository;

  const PaymentEntryScreen({
    super.key,
    this.initialPartyId,
    this.initialTxType,
    this.initialRelatedDocId,
    this.initialAmountRupees,
    this.txRepository,
    this.partyRepository,
  });

  @override
  State<PaymentEntryScreen> createState() => _PaymentEntryScreenState();
}

class _PaymentEntryScreenState extends State<PaymentEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  late TransactionRepository _txRepo;
  late PartyRepository _partyRepo;

  DateTime _txDate = DateTime.now();
  String _txType = 'expense';
  Party? _selectedParty;
  List<Party> _parties = [];

  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _customExpenseCategoryController = TextEditingController();
  String _paymentMethod = 'cash'; // 'cash' or 'upi'
  String _selectedExpenseCategory = 'चाय/पानी';
  bool _isLoading = true;
  bool _isSaving = false;

  List<Map<String, String>> _getQuickExpenseChips(LanguageProvider lang) => [
    {
      'label': lang.tr(en: '☕ Tea / Water', hi: '☕ चाय/पानी'),
      'category': 'चाय/पानी',
    },
    {
      'label': lang.tr(en: '🛺 Carting / Freight', hi: '🛺 रिक्शा/भाड़ा'),
      'category': 'रिक्शा/भाड़ा',
    },
    {
      'label': lang.tr(en: '📦 Packing Material', hi: '📦 पैकिंग सामान'),
      'category': 'पैकिंग सामान',
    },
    {
      'label': lang.tr(en: '💡 Shop / Electricity', hi: '💡 दुकान/बिजली'),
      'category': 'दुकान खर्च',
    },
    {
      'label': lang.tr(en: '⚙️ Machine Parts', hi: '⚙️ मशीनरी सामान'),
      'category': 'मशीनरी सामान',
    },
    {
      'label': lang.tr(en: '🧵 Raw Material', hi: '🧵 कच्चा माल'),
      'category': 'कच्चा माल',
    },
    {
      'label': lang.tr(en: '📝 Other Expense', hi: '📝 अन्य खर्च'),
      'category': 'अन्य खर्च',
    },
  ];

  @override
  void initState() {
    super.initState();
    _txRepo = widget.txRepository ?? TransactionRepository();
    _partyRepo = widget.partyRepository ?? PartyRepository();

    if (widget.initialTxType != null) {
      _txType = widget.initialTxType!;
    } else if (widget.initialPartyId != null) {
      _txType = 'supplier_payment';
    }

    if (widget.initialAmountRupees != null && widget.initialAmountRupees! > 0) {
      _amountController.text = widget.initialAmountRupees!.toStringAsFixed(0);
    }

    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final parties = await _partyRepo.getAllParties();

    Party? matchedParty;
    if (widget.initialPartyId != null) {
      matchedParty = parties.where((p) => p.id == widget.initialPartyId).firstOrNull;
    }

    if (mounted) {
      setState(() {
        _parties = parties;
        _selectedParty = matchedParty;
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    _customExpenseCategoryController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _txDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primaryNavy,
              onPrimary: AppColors.primaryGold,
              onSurface: AppColors.primaryNavy,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _txDate = picked);
    }
  }

  Future<void> _openQuickAddPartyDialog(LanguageProvider lang) async {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          lang.tr(en: 'Add New Party', hi: 'नई पार्टी जोड़ें'),
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              autofocus: true,
              decoration: InputDecoration(
                labelText: lang.tr(en: 'Business / Firm Name *', hi: 'व्यापारी / फर्म का नाम *'),
                hintText: lang.tr(en: 'e.g. Chun Lace, Sant Ashish', hi: 'उदा. चुन लेस, संत आशिष'),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: lang.tr(en: 'Mobile Number (Optional)', hi: 'मोबाइल नंबर (वैकल्पिक)'),
                hintText: '9876543210',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(lang.tr(en: 'Cancel', hi: 'रद्द करें')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryNavy,
              foregroundColor: AppColors.primaryGold,
            ),
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) return;
              final newParty = Party(
                name: nameCtrl.text.trim(),
                phone: phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(),
                type: _txType == 'supplier_payment' ? 'supplier' : 'customer',
              );
              final newId = await _partyRepo.insertParty(newParty);
              if (newId > 0 && ctx.mounted) {
                Navigator.pop(ctx, true);
              }
            },
            child: Text(lang.tr(en: 'Save', hi: 'सुरक्षित करें')),
          ),
        ],
      ),
    );

    if (result == true) {
      final updatedParties = await _partyRepo.getAllParties();
      if (mounted) {
        setState(() {
          _parties = updatedParties;
          _selectedParty = updatedParties.isNotEmpty ? updatedParties.last : null;
        });
      }
    }
  }

  Future<void> _saveTransaction(LanguageProvider lang) async {
    if (!_formKey.currentState!.validate()) return;

    final amountRupees = CurrencyFormatter.parseDouble(_amountController.text);
    if (amountRupees <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(lang.tr(en: 'Please enter a valid amount', hi: 'कृपया वैध रकम भरें')),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_txType != 'expense' && _selectedParty == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(lang.tr(en: 'Please select a party', hi: 'कृपया व्यापारी / पार्टी का नाम चुनें')),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      String? expenseCat;
      if (_txType == 'expense') {
        if (_selectedExpenseCategory == 'अन्य खर्च') {
          final custom = _customExpenseCategoryController.text.trim();
          expenseCat = custom.isNotEmpty ? custom : (lang.isHindi ? 'अन्य खर्च' : 'Other Expense');
        } else {
          expenseCat = _selectedExpenseCategory;
        }
      }

      final notesText = _notesController.text.trim().isNotEmpty
          ? _notesController.text.trim()
          : (_txType == 'expense' ? expenseCat : null);

      final tx = BusinessTransaction(
        transactionDate: DateFormatter.toIso(_txDate).substring(0, 10),
        partyId: _selectedParty?.id,
        partyName: _selectedParty?.name,
        transactionType: _txType,
        amountPaise: CurrencyFormatter.rupeesToPaise(amountRupees),
        paymentMethod: _paymentMethod,
        expenseCategory: expenseCat,
        notes: notesText,
      );

      final txId = await _txRepo.insertTransaction(tx);

      // Real-time Cloud Mirroring
      try {
        final syncService = FirebaseSyncService();
        final cloudMap = Map<String, dynamic>.from(tx.toMap());
        cloudMap['id'] = txId;
        if (_selectedParty != null) {
          cloudMap['party_name'] = _selectedParty!.name;
        }
        await syncService.pushSingleRecord(
          collection: 'transactions',
          id: txId.toString(),
          data: cloudMap,
        );
        syncService.triggerAutoSync();
      } catch (_) {}

      if (mounted) {
        String msg = lang.tr(
          en: '✅ Expense ($expenseCat) recorded!',
          hi: '✅ खर्चा ($expenseCat) दर्ज हो गया!',
        );
        if (_txType == 'supplier_payment') {
          msg = lang.tr(en: '✅ Party payment recorded!', hi: '✅ पार्टी को भुगतान दर्ज हो गया!');
        } else if (_txType == 'customer_receipt') {
          msg = lang.tr(en: '✅ Party receipt recorded!', hi: '✅ पार्टी से जमा रकम दर्ज हो गई!');
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: const Color(0xFF0F172A)),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(lang.tr(en: 'Error: $e', hi: 'त्रुटि: $e')),
            backgroundColor: Colors.red,
          ),
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
        appBar: AppBar(
          title: Text(lang.tr(en: 'Payment & Expense', hi: 'खर्चा व भुगतान')),
        ),
        body: const Center(child: CircularProgressIndicator(color: AppColors.primaryGold)),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        title: Text(
          lang.tr(en: 'Payment & Expense Entry', hi: 'खर्चा व भुगतान एंट्री'),
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 32),
          children: [
            // 1. Transaction Type Toggle (3 Big Clear Buttons)
            _buildTypeSelector(lang),

            const SizedBox(height: 14),

            // 2. Main Details Card
            _buildDetailsCard(lang),

            const SizedBox(height: 22),

            // 3. Save Button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  foregroundColor: const Color(0xFFD4AF37),
                  elevation: 2.5,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _isSaving ? null : () => _saveTransaction(lang),
                child: _isSaving
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(color: Color(0xFFD4AF37), strokeWidth: 2.5),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _txType == 'expense'
                                ? Icons.coffee_rounded
                                : (_txType == 'supplier_payment' ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded),
                            color: const Color(0xFFD4AF37),
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _txType == 'expense'
                                ? lang.tr(en: 'Record Shop Expense', hi: 'दुकान का खर्चा दर्ज करें')
                                : (_txType == 'supplier_payment'
                                    ? lang.tr(en: 'Save Party Payment', hi: 'पार्टी भुगतान सुरक्षित करें')
                                    : lang.tr(en: 'Save Party Receipt', hi: 'पार्टी जमा सुरक्षित करें')),
                            style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w900),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 1. 3 Big Clear Pills: 1) दुकान खर्च  2) पार्टी को दिया  3) पार्टी से मिला
  Widget _buildTypeSelector(LanguageProvider lang) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(5),
      child: Row(
        children: [
          // 1. Expense
          Expanded(
            child: _buildTypeButton(
              type: 'expense',
              icon: Icons.coffee_rounded,
              label: lang.tr(en: 'Shop Expense', hi: 'दुकान खर्च'),
              activeColor: const Color(0xFFD97706),
              activeBg: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(width: 5),
          // 2. Paid to Party
          Expanded(
            child: _buildTypeButton(
              type: 'supplier_payment',
              icon: Icons.arrow_upward_rounded,
              label: lang.tr(en: 'Paid to Party', hi: 'पार्टी को दिया'),
              activeColor: const Color(0xFFF87171),
              activeBg: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(width: 5),
          // 3. Received from Party
          Expanded(
            child: _buildTypeButton(
              type: 'customer_receipt',
              icon: Icons.arrow_downward_rounded,
              label: lang.tr(en: 'Party Receipt', hi: 'पार्टी से मिला'),
              activeColor: const Color(0xFF4ADE80),
              activeBg: const Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeButton({
    required String type,
    required IconData icon,
    required String label,
    required Color activeColor,
    required Color activeBg,
  }) {
    final isSelected = _txType == type;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() {
          _txType = type;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        decoration: BoxDecoration(
          color: isSelected ? activeBg : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: isSelected ? Border.all(color: activeColor, width: 1.2) : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected ? activeColor : const Color(0xFF64748B),
            ),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: isSelected ? activeColor : const Color(0xFF475569),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 2. Main Details Card
  Widget _buildDetailsCard(LanguageProvider lang) {
    final chips = _getQuickExpenseChips(lang);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Case 1: Daily Expense Preset Chips
          if (_txType == 'expense') ...[
            Text(
              lang.tr(en: 'Expense Type (1-Tap Select)', hi: 'खर्च का प्रकार (1-टैप चुनें)'),
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF1E293B)),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: chips.map((c) {
                final isSelected = _selectedExpenseCategory == c['category'];
                return ChoiceChip(
                  label: Text(
                    c['label']!,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                      color: isSelected ? const Color(0xFFFDE047) : const Color(0xFF334155),
                    ),
                  ),
                  selected: isSelected,
                  selectedColor: const Color(0xFF0F172A),
                  backgroundColor: const Color(0xFFF1F5F9),
                  showCheckmark: false,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  side: BorderSide(
                    color: isSelected ? const Color(0xFFD4AF37) : const Color(0xFFCBD5E1),
                    width: isSelected ? 1.2 : 0.8,
                  ),
                  onSelected: (selected) {
                    if (selected) {
                      HapticFeedback.selectionClick();
                      setState(() {
                        _selectedExpenseCategory = c['category']!;
                        if (_selectedExpenseCategory != 'अन्य खर्च') {
                          _customExpenseCategoryController.clear();
                        }
                      });
                    }
                  },
                );
              }).toList(),
            ),

            // If "अन्य खर्च" is selected: show dedicated manual input field
            if (_selectedExpenseCategory == 'अन्य खर्च') ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7).withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFF59E0B), width: 1.2),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.edit_note_rounded, size: 18, color: Color(0xFFB45309)),
                        const SizedBox(width: 6),
                        Text(
                          lang.tr(
                            en: 'What is this expense for? (Name) *',
                            hi: 'किस चीज़ का खर्च है? (खर्च का नाम लिखें) *',
                          ),
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 12.5,
                            color: Color(0xFF92400E),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _customExpenseCategoryController,
                      autofocus: true,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                      decoration: InputDecoration(
                        isDense: true,
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        hintText: lang.tr(
                          en: 'e.g. Stationery, Cleaning, Printing, Repair...',
                          hi: 'उदा. स्टेशनरी, ऑफिस सफाई, प्रिंटिंग, रिपेयर...',
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Color(0xFFD97706)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Color(0xFF0F172A), width: 1.5),
                        ),
                      ),
                      validator: (val) {
                        if (_txType == 'expense' && _selectedExpenseCategory == 'अन्य खर्च') {
                          if (val == null || val.trim().isEmpty) {
                            return lang.tr(
                              en: 'Please enter expense name (e.g. Stationery)',
                              hi: 'कृपया खर्च का नाम लिखें (उदा. स्टेशनरी)',
                            );
                          }
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
          ],

          // Case 2: Party Selection (for Party Payments & Receipts)
          if (_txType != 'expense') ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _txType == 'supplier_payment'
                      ? lang.tr(en: 'Paid to Supplier / Party *', hi: 'व्यापारी / पार्टी को दिया *')
                      : lang.tr(en: 'Received from Customer / Party *', hi: 'व्यापारी / पार्टी से मिला *'),
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF1E293B)),
                ),
                InkWell(
                  onTap: () => _openQuickAddPartyDialog(lang),
                  child: Row(
                    children: [
                      const Icon(Icons.add_circle_outline_rounded, size: 15, color: Color(0xFF2563EB)),
                      const SizedBox(width: 3),
                      Text(
                        lang.tr(en: '+ New Party', hi: '+ नई पार्टी'),
                        style: const TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.w800, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 7),
            DropdownButtonFormField<Party>(
              initialValue: _selectedParty,
              isExpanded: true,
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                prefixIcon: const Icon(Icons.person_outline_rounded, size: 20, color: Color(0xFF64748B)),
              ),
              items: _parties.map((p) {
                return DropdownMenuItem<Party>(
                  value: p,
                  child: Text(
                    '${p.name} (${lang.tr(en: 'Due', hi: 'बाकी')}: ${CurrencyFormatter.format(p.currentBalanceRupees)})',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              onChanged: (p) => setState(() => _selectedParty = p),
              validator: (p) => p == null ? lang.tr(en: 'Select party', hi: 'पार्टी चुनें') : null,
            ),
            const SizedBox(height: 16),
          ],

          // Amount Field (Big and Bold)
          Text(
            lang.tr(en: 'Amount (₹) *', hi: 'रकम (Amount ₹) *'),
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: Color(0xFF1E293B)),
          ),
          const SizedBox(height: 7),
          TextFormField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              prefixIcon: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Text('₹', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Color(0xFFD4AF37))),
              ),
              hintText: _txType == 'expense' ? '50' : '5000',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF0F172A), width: 1.8),
              ),
            ),
            validator: (val) {
              if (val == null || val.trim().isEmpty) {
                return lang.tr(en: 'Please enter amount', hi: 'रकम दर्ज करें');
              }
              final n = CurrencyFormatter.parseDouble(val.trim());
              if (n <= 0) {
                return lang.tr(en: 'Please enter valid amount', hi: 'वैध रकम दर्ज करें');
              }
              return null;
            },
          ),

          const SizedBox(height: 16),

          // Date & Payment Mode in One Row
          Row(
            children: [
              // Date
              Expanded(
                flex: 5,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lang.tr(en: 'Date *', hi: 'तारीख *'),
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5, color: Color(0xFF1E293B)),
                    ),
                    const SizedBox(height: 6),
                    InkWell(
                      onTap: _selectDate,
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today_rounded, size: 15, color: Color(0xFF64748B)),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                DateFormatter.format(_txDate),
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              // Payment Method Toggle (Cash vs UPI)
              Expanded(
                flex: 6,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lang.tr(en: 'Mode *', hi: 'माध्यम *'),
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5, color: Color(0xFF1E293B)),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => _paymentMethod = 'cash'),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  color: _paymentMethod == 'cash' ? const Color(0xFF0F172A) : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Center(
                                  child: Text(
                                    lang.tr(en: '💵 Cash', hi: '💵 नकद'),
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w800,
                                      color: _paymentMethod == 'cash' ? const Color(0xFFFDE047) : const Color(0xFF475569),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => _paymentMethod = 'upi'),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  color: _paymentMethod == 'upi' ? const Color(0xFF0F172A) : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Center(
                                  child: Text(
                                    '📱 UPI',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w800,
                                      color: _paymentMethod == 'upi' ? const Color(0xFF38BDF8) : const Color(0xFF475569),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Optional Description / Notes
          Text(
            _txType == 'expense'
                ? lang.tr(en: 'Remarks / Notes (Optional)', hi: 'विवरण (वैकल्पिक टिप्पणी)')
                : lang.tr(en: 'Notes / Remarks (Optional)', hi: 'नोट्स / टिप्पणी (वैकल्पिक)'),
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5, color: Color(0xFF1E293B)),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: _notesController,
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              hintText: _getNotesHint(lang),
              prefixIcon: const Icon(Icons.edit_note_rounded, size: 20, color: Color(0xFF64748B)),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  String _getNotesHint(LanguageProvider lang) {
    if (_txType != 'expense') {
      return lang.tr(en: 'e.g. Cheque number or reference', hi: 'उदा. चेक नंबर या हवाला विवरण');
    }
    switch (_selectedExpenseCategory) {
      case 'चाय/पानी':
        return lang.tr(en: 'e.g. Evening tea 5 cups', hi: 'उदा. शाम की चाय 5 कप');
      case 'रिक्शा/भाड़ा':
        return lang.tr(en: 'e.g. Ring road to shop tempo freight', hi: 'उदा. रिंग रोड से दुकान टेम्पो भाड़ा');
      case 'पैकिंग सामान':
        return lang.tr(en: 'e.g. Box, tape or plastic cover', hi: 'उदा. बॉक्स, टेप या प्लास्टिक कवर');
      case 'दुकान खर्च':
        return lang.tr(en: 'e.g. Electricity bill or shop maintenance', hi: 'उदा. बिजली बिल या दुकान मेंटेनेंस');
      case 'मशीनरी सामान':
        return lang.tr(en: 'e.g. Lace machine needle, oil, belt or parts', hi: 'उदा. लेस मशीन सुई, तेल, बेल्ट या पार्ट्स');
      case 'कच्चा माल':
        return lang.tr(en: 'e.g. Zari, yarn, roll or raw cloth', hi: 'उदा. ज़री, धागा, रोल या कच्चा कपड़ा');
      case 'अन्य खर्च':
        return lang.tr(en: 'e.g. Bill/receipt no. or extra remarks', hi: 'उदा. बिल/रसीद नंबर या अतिरिक्त विवरण');
      default:
        return lang.tr(en: 'e.g. Extra expense remarks', hi: 'उदा. खर्च का अतिरिक्त विवरण');
    }
  }
}
