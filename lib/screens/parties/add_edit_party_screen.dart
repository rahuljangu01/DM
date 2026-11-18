import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/localization/language_provider.dart';
import '../../core/utils/currency_formatter.dart';
import '../../models/party.dart';
import '../../repositories/party_repository.dart';
import '../../widgets/party_avatar.dart';

class AddEditPartyScreen extends StatefulWidget {
  final Party? party;
  final PartyRepository? repository;

  const AddEditPartyScreen({super.key, this.party, this.repository});

  @override
  State<AddEditPartyScreen> createState() => _AddEditPartyScreenState();
}

class _AddEditPartyScreenState extends State<AddEditPartyScreen> {
  final _formKey = GlobalKey<FormState>();
  late PartyRepository _repo;
  final ImagePicker _picker = ImagePicker();

  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _addressController;
  late TextEditingController _openingBalanceController;
  late TextEditingController _notesController;

  String? _imagePath;
  String _partyType = 'customer';
  String _balanceType = 'receivable'; // 'receivable', 'payable'
  bool _isSaving = false;
  bool _showMoreDetails = false;

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? PartyRepository();
    final p = widget.party;
    _imagePath = p?.imagePath;
    _nameController = TextEditingController(text: p?.name ?? '');
    _phoneController = TextEditingController(text: p?.phone ?? '');
    _addressController = TextEditingController(text: p?.address ?? '');
    _openingBalanceController = TextEditingController(
      text: p != null && p.openingBalancePaise > 0
          ? CurrencyFormatter.format(p.openingBalanceRupees, includeSymbol: false)
          : '',
    );
    _notesController = TextEditingController(text: p?.notes ?? '');
    if (p != null) {
      _partyType = p.type;
      _balanceType = p.balanceType;
      // Auto-expand optional fields if existing party has opening balance or notes
      _showMoreDetails = p.openingBalancePaise > 0 || (p.notes != null && p.notes!.trim().isNotEmpty);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _openingBalanceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      if (picked != null) {
        setState(() {
          _imagePath = picked.path;
        });
      }
    } catch (e) {
      if (mounted) {
        final lang = context.read<LanguageProvider>();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(lang.isHindi ? 'फोटो चुनने में समस्या आई: $e' : 'Failed to pick image: $e')),
        );
      }
    }
  }

  void _showPhotoOptions() {
    HapticFeedback.lightImpact();
    final lang = context.read<LanguageProvider>();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text(
                lang.isHindi ? 'प्रोफ़ाइल फोटो' : 'Profile Photo',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primaryNavy,
                ),
              ),
              const SizedBox(height: 14),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.camera_alt_rounded, color: Color(0xFF10B981), size: 20),
                ),
                title: Text(
                  lang.isHindi ? 'कैमरा से फोटो खींचें' : 'Take Photo (Camera)',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.photo_library_rounded, color: Color(0xFF0284C7), size: 20),
                ),
                title: Text(
                  lang.isHindi ? 'गैलरी से फोटो चुनें' : 'Choose from Gallery',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.gallery);
                },
              ),
              if (_imagePath != null) ...[
                const Divider(height: 1),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 20),
                  ),
                  title: Text(
                    lang.isHindi ? 'फोटो हटाएं (नाम का डिफ़ॉल्ट आइकन रखें)' : 'Remove Photo (Use Name Initial)',
                    style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFFEF4444)),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    setState(() {
                      _imagePath = null;
                    });
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveParty() async {
    if (!_formKey.currentState!.validate()) return;

    HapticFeedback.lightImpact();
    setState(() => _isSaving = true);
    final openingRupees = CurrencyFormatter.parseDouble(_openingBalanceController.text);
    final openingPaise = CurrencyFormatter.rupeesToPaise(openingRupees);

    try {
      var phoneVal = _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim();
      var addressVal = _addressController.text.trim().isEmpty ? null : _addressController.text.trim();
      // Smart detection: if phone was left empty but address contains a phone number
      if (phoneVal == null && addressVal != null) {
        final digits = addressVal.replaceAll(RegExp(r'[^0-9]'), '');
        if (digits.length >= 5 && !RegExp(r'[a-zA-Z\u0900-\u097F]').hasMatch(addressVal)) {
          phoneVal = addressVal;
          addressVal = null;
        }
      }

      if (widget.party == null) {
        final newParty = Party(
          name: _nameController.text.trim(),
          type: _partyType,
          phone: phoneVal,
          address: addressVal,
          imagePath: _imagePath,
          openingBalancePaise: openingPaise,
          balanceType: _balanceType,
          notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        );
        await _repo.insertParty(newParty);
      } else {
        final updated = widget.party!.copyWith(
          name: _nameController.text.trim(),
          type: _partyType,
          phone: phoneVal,
          address: addressVal,
          imagePath: _imagePath,
          clearImagePath: _imagePath == null,
          openingBalancePaise: openingPaise,
          balanceType: _balanceType,
          notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        );
        await _repo.updateParty(updated);
      }

      if (mounted) {
        final lang = context.read<LanguageProvider>();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.party == null
                  ? (lang.isHindi ? 'नया संपर्क सफलतापूर्वक सहेजा गया!' : 'Contact saved successfully!')
                  : (lang.isHindi ? 'संपर्क जानकारी अपडेट हो गई!' : 'Contact updated successfully!'),
            ),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save contact: $e'),
            backgroundColor: AppColors.payableRed,
            behavior: SnackBarBehavior.floating,
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
    final isEditing = widget.party != null;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        title: Text(
          isEditing
              ? (lang.isHindi ? 'संपर्क संपादित करें' : 'Edit Contact')
              : (lang.isHindi ? 'नया संपर्क' : 'New Contact'),
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
        ),
        actions: [
          TextButton.icon(
            onPressed: _isSaving ? null : _saveParty,
            icon: const Icon(Icons.check_rounded, color: AppColors.primaryGold, size: 20),
            label: Text(
              lang.isHindi ? 'सहेजें' : 'Save',
              style: const TextStyle(
                color: AppColors.primaryGold,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              // Mobile Contact Style Avatar Header with Profile Photo Upload
              Center(
                child: Column(
                  children: [
                    PartyAvatar(
                      name: _nameController.text.trim(),
                      imagePath: _imagePath,
                      size: 92,
                      fontSize: 34,
                      showCameraBadge: true,
                      onCameraTap: _showPhotoOptions,
                      onTap: _showPhotoOptions,
                    ),
                    const SizedBox(height: 10),
                    InkWell(
                      onTap: _showPhotoOptions,
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A).withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFCBD5E1), width: 0.8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _imagePath != null ? Icons.photo_library_outlined : Icons.add_a_photo_outlined,
                              size: 15,
                              color: AppColors.primaryNavy,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _imagePath != null
                                  ? (lang.isHindi ? 'फोटो बदलें या हटाएं' : 'Change/Remove Photo')
                                  : (lang.isHindi ? 'प्रोफाइल फोटो लगाएं' : 'Add Profile Photo'),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primaryNavy,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      lang.isHindi
                          ? 'खाली रखने पर नाम के पहले अक्षर का डिफ़ॉल्ट आइकन दिखेगा'
                          : 'Defaults to name initial if no photo is added',
                      style: const TextStyle(
                        fontSize: 10.5,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Simple Phone-Style Form Card
              Card(
                elevation: 0.8,
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Column(
                    children: [
                      // 1. Name Field
                      TextFormField(
                        controller: _nameController,
                        textCapitalization: TextCapitalization.words,
                        decoration: InputDecoration(
                          icon: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E3A8A).withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.person_rounded, color: Color(0xFF1E3A8A), size: 20),
                          ),
                          labelText: lang.isHindi ? 'नाम / फर्म का नाम *' : 'Name / Business Name *',
                          labelStyle: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                          hintText: lang.isHindi ? 'उदा. राजेश भाई / बालाजी लेस' : 'e.g. Rajesh Bhai / Balaji Lace',
                          hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                          border: InputBorder.none,
                          suffixIcon: _nameController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  onPressed: () {
                                    _nameController.clear();
                                    setState(() {});
                                  },
                                )
                              : null,
                        ),
                        onChanged: (_) => setState(() {}),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? (lang.isHindi ? 'कृपया संपर्क का नाम दर्ज करें' : 'Please enter contact name')
                            : null,
                      ),
                      const Divider(height: 1, color: Color(0xFFF1F5F9)),

                      // 2. Mobile Phone Field
                      TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+]'))],
                        decoration: InputDecoration(
                          icon: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.phone_rounded, color: Color(0xFF10B981), size: 20),
                          ),
                          labelText: lang.isHindi ? 'मोबाइल नंबर (Phone Number)' : 'Mobile Phone (WhatsApp)',
                          labelStyle: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                          hintText: lang.isHindi ? '10 अंकों का नंबर (उदा. 9825123456)' : '10-digit number (e.g. 9825123456)',
                          hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                          border: InputBorder.none,
                          suffixIcon: _phoneController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  onPressed: () {
                                    _phoneController.clear();
                                    setState(() {});
                                  },
                                )
                              : null,
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                      const Divider(height: 1, color: Color(0xFFF1F5F9)),

                      // 3. Market / Address Field (Optional)
                      TextFormField(
                        controller: _addressController,
                        maxLines: 2,
                        minLines: 1,
                        decoration: InputDecoration(
                          icon: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.location_on_outlined, color: Color(0xFF6366F1), size: 20),
                          ),
                          labelText: lang.isHindi ? 'दुकान / मार्केट का पता' : 'Market / Shop Address',
                          labelStyle: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                          hintText: lang.isHindi ? 'उदा. शॉप 204, मिलेनियम मार्केट, सूरत' : 'e.g. Shop 204, Millennium Market, Surat',
                          hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                          border: InputBorder.none,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Collapsible / Optional More Fields Toggle (Google / Apple Contacts Style)
              InkWell(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _showMoreDetails = !_showMoreDetails);
                },
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _showMoreDetails ? Icons.keyboard_arrow_up_rounded : Icons.add_circle_outline_rounded,
                        size: 18,
                        color: AppColors.secondaryNavy,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _showMoreDetails
                            ? (lang.isHindi ? 'कम विवरण दिखाएं ▴' : 'Show Less ▴')
                            : (lang.isHindi ? 'पुराना हिसाब व नोट जोड़ें (वैकल्पिक)' : 'Add Opening Balance & Notes (Optional)'),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.secondaryNavy,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Expanded Optional Fields (Opening Balance & Notes)
              if (_showMoreDetails) ...[
                const SizedBox(height: 8),
                Card(
                  elevation: 0.6,
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.account_balance_wallet_outlined, size: 18, color: AppColors.primaryGold),
                            const SizedBox(width: 8),
                            Text(
                              lang.isHindi ? 'प्रारंभिक शेष (पुराना बकाया हिसाब)' : 'Opening Balance (Khata)',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _openingBalanceController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.currency_rupee, size: 18),
                            labelText: lang.isHindi ? 'पुरानी बकाया राशि (₹)' : 'Opening Amount (₹)',
                            hintText: '0.00',
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.primaryNavy)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _notesController,
                          maxLines: 2,
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.note_alt_outlined, size: 18),
                            labelText: lang.isHindi ? 'टिप्पणी / संदर्भ (Note)' : 'Notes / Reference',
                            hintText: lang.isHindi ? 'उदा. 15 दिन उधारी, दलाल का नाम' : 'e.g. Credit cycle, broker reference',
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.primaryNavy)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // Bottom Primary Save Button
              ElevatedButton.icon(
                onPressed: _isSaving ? null : _saveParty,
                icon: const Icon(Icons.check_circle_rounded, size: 20),
                label: Text(
                  _isSaving
                      ? (lang.isHindi ? 'सहेज रहे हैं...' : 'Saving...')
                      : (isEditing
                          ? (lang.isHindi ? 'संपर्क अपडेट करें' : 'Update Contact')
                          : (lang.isHindi ? 'संपर्क सहेजें (Save Contact)' : 'Save Contact')),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryNavy,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
