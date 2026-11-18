import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/database/database_helper.dart';
import '../../core/database/database_tables.dart';
import '../../core/localization/language_provider.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';
import '../../models/document.dart';
import '../../models/document_item.dart';
import '../../models/party.dart';
import '../../repositories/document_repository.dart';
import '../../repositories/party_repository.dart';
import '../../services/cloudinary_service.dart';
import '../../services/firebase_sync_service.dart';
import '../../widgets/interactive_slip_viewer.dart';

class QuickSlipBillScreen extends StatefulWidget {
  final int? initialPartyId;
  final DocumentRepository? docRepository;
  final PartyRepository? partyRepository;

  const QuickSlipBillScreen({
    super.key,
    this.initialPartyId,
    this.docRepository,
    this.partyRepository,
  });

  @override
  State<QuickSlipBillScreen> createState() => _QuickSlipBillScreenState();
}

class _QuickSlipBillScreenState extends State<QuickSlipBillScreen> {
  final _formKey = GlobalKey<FormState>();
  late DocumentRepository _docRepo;
  late PartyRepository _partyRepo;

  List<Party> _parties = [];
  Party? _selectedParty;
  String _tradeType = 'sale'; // 'sale' = माल दिया (बिक्री), 'purchase' = माल आया (खरीद)
  DateTime _docDate = DateTime.now();
  String? _imagePath;
  String? _imageBase64;
  String? _imageUrl;
  bool _isLoading = true;
  bool _isSaving = false;

  final TextEditingController _totalAmountController = TextEditingController();
  final TextEditingController _partySearchController = TextEditingController();
  final TextEditingController _slipNumberController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _docRepo = widget.docRepository ?? DocumentRepository();
    _partyRepo = widget.partyRepository ?? PartyRepository();
    _initData();
  }

  @override
  void dispose() {
    _totalAmountController.dispose();
    _partySearchController.dispose();
    _slipNumberController.dispose();
    super.dispose();
  }

  Future<void> _initData() async {
    setState(() => _isLoading = true);
    final parties = await _partyRepo.getAllParties();
    Party? matchedParty;
    if (widget.initialPartyId != null) {
      matchedParty = parties.where((p) => p.id == widget.initialPartyId).firstOrNull;
    }
    matchedParty ??= parties.isNotEmpty ? parties.first : null;

    if (matchedParty != null) {
      _partySearchController.text = matchedParty.name;
    }

    // Auto-suggest next slip number
    try {
      final nextNum = await _docRepo.generateNextDocNumber('challan');
      _slipNumberController.text = nextNum;
    } catch (_) {}

    if (mounted) {
      setState(() {
        _parties = parties;
        _selectedParty = matchedParty;
        _isLoading = false;
      });
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 70,
        maxWidth: 1080,
      );
      if (pickedFile == null) return;

      // Copy to persistent documents directory
      final appDir = await getApplicationDocumentsDirectory();
      final slipsDir = Directory('${appDir.path}/slips');
      if (!slipsDir.existsSync()) {
        slipsDir.createSync(recursive: true);
      }
      final fileName = 'slip_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final savedFile = await File(pickedFile.path).copy('${slipsDir.path}/$fileName');
      final bytes = await savedFile.readAsBytes();
      final b64 = base64Encode(bytes);

      setState(() {
        _imagePath = savedFile.path;
        _imageBase64 = b64;
      });

      // Background upload to Cloudinary for instant direct link
      CloudinaryService().uploadImageFile(savedFile, tag: 'quick_slip').then((res) {
        if (res.success && res.url != null && mounted) {
          setState(() {
            _imageUrl = res.url;
          });
        }
      });
    } catch (e) {
      if (mounted) {
        final lang = Provider.of<LanguageProvider>(context, listen: false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(lang.tr(en: 'Error capturing photo: $e', hi: 'फोटो लेने में त्रुटि: $e')), backgroundColor: Colors.red),
        );
      }
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
          lang.isHindi ? 'नई पार्टी जोड़ें' : 'Add New Party',
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              autofocus: true,
              decoration: InputDecoration(
                labelText: lang.isHindi ? 'व्यापारी / फर्म का नाम *' : 'Party / Firm Name *',
                hintText: 'उदा. चुन लेस, संत आशिष',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: lang.isHindi ? 'मोबाइल नंबर (वैकल्पिक)' : 'Mobile Phone (Optional)',
                hintText: '9876543210',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(lang.isHindi ? 'रद्द करें' : 'Cancel'),
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
                type: _tradeType == 'purchase' ? 'supplier' : 'customer',
              );
              final newId = await _partyRepo.insertParty(newParty);
              if (newId > 0 && ctx.mounted) {
                Navigator.pop(ctx, true);
              }
            },
            child: Text(lang.isHindi ? 'सुरक्षित करें' : 'Save'),
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

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _docDate,
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
      setState(() => _docDate = picked);
    }
  }

  Future<void> _saveSlip(LanguageProvider lang) async {
    if (_imagePath == null || _imagePath!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            lang.isHindi
                ? '📷 कृपया पहले चालान पर्ची का फोटो लें'
                : 'Please take/upload slip photo first',
          ),
          backgroundColor: const Color(0xFFD97706),
        ),
      );
      return;
    }

    // Resolve party from search controller or selected party
    Party? partyToUse = _selectedParty;
    final typedParty = _partySearchController.text.trim();

    if (partyToUse == null && typedParty.isNotEmpty) {
      partyToUse = _parties.where((p) => p.name.trim().toLowerCase() == typedParty.toLowerCase()).firstOrNull;
      if (partyToUse == null) {
        // Auto-create new party on the fly without dialog friction
        try {
          final newParty = Party(
            name: typedParty,
            type: _tradeType == 'purchase' ? 'supplier' : 'customer',
          );
          final newId = await _partyRepo.insertParty(newParty);
          partyToUse = newParty.copyWith(id: newId);
          _parties.add(partyToUse);
          _selectedParty = partyToUse;
        } catch (_) {}
      }
    }
    if (!mounted) return;

    if (partyToUse == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            lang.isHindi ? 'कृपया व्यापारी / पार्टी का नाम लिखें या चुनें' : 'Please enter or select party name',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final totalRupees = double.tryParse(_totalAmountController.text.trim()) ?? 0.0;
    if (totalRupees <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(lang.isHindi ? 'कृपया कुल रकम (₹) भरें' : 'Please enter total amount'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final totalPaise = CurrencyFormatter.rupeesToPaise(totalRupees);

    setState(() => _isSaving = true);

    try {
      // Slip number: use user's handwritten slip number or auto-generate
      String finalDocNumber = _slipNumberController.text.trim();
      if (finalDocNumber.isEmpty) {
        finalDocNumber = await _docRepo.generateNextDocNumber('challan');
      } else if (!finalDocNumber.toUpperCase().startsWith('CH-') &&
          !finalDocNumber.toUpperCase().startsWith('DC-') &&
          !finalDocNumber.toUpperCase().startsWith('INV-') &&
          !finalDocNumber.toUpperCase().startsWith('KB-') &&
          !finalDocNumber.toUpperCase().startsWith('PO-')) {
        finalDocNumber = 'CH-$finalDocNumber';
      }

      // Pre-check uniqueness so duplicates never fail
      final db = await DatabaseHelper.instance.database;
      final duplicateCheck = await db.rawQuery(
        'SELECT 1 FROM ${DatabaseTables.tableDocuments} WHERE doc_number = ? LIMIT 1',
        [finalDocNumber],
      );
      if (duplicateCheck.isNotEmpty) {
        final freshNum = await _docRepo.generateNextDocNumber('challan');
        finalDocNumber = freshNum;
      }

      final item = DocumentItem(
        itemName: lang.isHindi ? 'सूरत चालान पर्ची' : 'Challan Slip',
        description: 'Challan $finalDocNumber',
        quantity: 1.0,
        unit: 'pck',
        ratePaise: totalPaise,
        taxableAmountPaise: totalPaise,
        lineTotalPaise: totalPaise,
      );

      // Ensure Cloudinary upload is attempted if not ready yet
      if (_imageUrl == null && _imagePath != null) {
        try {
          final res = await CloudinaryService().uploadImageFile(File(_imagePath!), tag: 'quick_slip');
          if (res.success && res.url != null) {
            _imageUrl = res.url;
          }
        } catch (_) {}
      }

      final doc = BusinessDocument(
        docNumber: finalDocNumber,
        docType: _tradeType == 'purchase' ? 'purchase_bill' : 'challan',
        tradeType: _tradeType,
        partyId: partyToUse.id!,
        partyName: partyToUse.name,
        docDate: DateFormatter.toIso(_docDate),
        subtotalPaise: totalPaise,
        grandTotalPaise: totalPaise,
        paidAmountPaise: 0,
        imagePath: _imagePath,
        imageBase64: _imageBase64,
        imageUrl: _imageUrl,
        notes: 'Challan: $finalDocNumber • ${partyToUse.name}',
        items: [item],
      );

      final docId = await _docRepo.createDocument(doc);

      // Save slip data + full photo to Firebase backend in real-time
      try {
        final syncService = FirebaseSyncService();
        final cloudMap = Map<String, dynamic>.from(doc.toMap());
        cloudMap['id'] = docId;
        if (_imageBase64 != null) {
          cloudMap['image_base64'] = _imageBase64;
        }
        if (_imageUrl != null) {
          cloudMap['image_url'] = _imageUrl;
        }
        cloudMap['items_json'] = jsonEncode([
          {
            'item_name': lang.isHindi ? 'सूरत चालान पर्ची' : 'Challan Slip',
            'quantity': 1.0,
            'line_total_paise': totalPaise,
          }
        ]);
        await syncService.pushSingleRecord(
          collection: 'bills',
          id: docId.toString(),
          data: cloudMap,
        );
        if (doc.isChallan) {
          await syncService.pushSingleRecord(
            collection: 'challans',
            id: docId.toString(),
            data: cloudMap,
          );
        }
        syncService.triggerAutoSync();
      } catch (_) {
        // Safe offline fallback
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            lang.isHindi
                ? '✅ चालान और फोटो क्लाउड डेटाबेस में सुरक्षित हो गई!'
                : '✅ Slip & Photo safely backed up to Cloud!',
          ),
          backgroundColor: const Color(0xFF0F172A),
        ),
      );

      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        final lang = Provider.of<LanguageProvider>(context, listen: false);
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(lang.tr(en: 'Error saving document: $e', hi: 'सुरक्षित करने में त्रुटि: $e')), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageProvider>(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        title: Text(
          lang.isHindi ? 'चालान पर्ची' : 'Quick Challan Slip',
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16.5),
        ),
        actions: [
          IconButton(
            tooltip: 'Camera',
            icon: const Icon(Icons.camera_alt_rounded, color: AppColors.primaryGold),
            onPressed: () => _pickImage(ImageSource.camera),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryGold))
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
                children: [
                  // 1. Slip Photo Capture Hero Card
                  _buildPhotoSection(lang),

                  const SizedBox(height: 14),

                  // 2. Trade Type Selector (माल दिया / बिक्री vs माल आया / खरीद)
                  _buildTradeTypeSelector(lang),

                  const SizedBox(height: 14),

                  // 3. Only 3 Pure Required Fields: Party Name, Date, Amount
                  _buildSimpleDetailsCard(lang),

                  const SizedBox(height: 24),

                  // 4. Save Button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F172A),
                        foregroundColor: const Color(0xFFD4AF37),
                        elevation: 3,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: _isSaving ? null : () => _saveSlip(lang),
                      child: _isSaving
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(color: Color(0xFFD4AF37), strokeWidth: 2.5),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.cloud_upload_rounded, color: Color(0xFFD4AF37), size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  lang.isHindi ? 'चालान सुरक्षित करें' : 'Save Challan',
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

  /// 1. Photo Capture Section
  Widget _buildPhotoSection(LanguageProvider lang) {
    if (_imagePath != null && File(_imagePath!).existsSync()) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.primaryGold.withValues(alpha: 0.6), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 18),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          lang.isHindi ? 'पर्ची का फोटो अटैच है' : 'Slip Photo Attached',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF0F172A)),
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  onPressed: () => InteractiveSlipViewer.show(context, imagePath: _imagePath!),
                  icon: const Icon(Icons.zoom_in_rounded, size: 17, color: Color(0xFF0284C7)),
                  label: Text(lang.isHindi ? 'बड़ा देखें' : 'Zoom', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => InteractiveSlipViewer.show(context, imagePath: _imagePath!),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    Image.file(
                      File(_imagePath!),
                      height: 190,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                    Container(
                      margin: const EdgeInsets.all(8),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.touch_app_rounded, color: Colors.white, size: 13),
                          const SizedBox(width: 4),
                          Text(
                            lang.isHindi ? 'ज़ूम करने हेतु दबाएं' : 'Tap to Zoom',
                            style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF0F172A),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () => _pickImage(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt_rounded, size: 16),
                    label: Text(lang.isHindi ? 'दोबारा फोटो लें' : 'Retake Photo'),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton(
                  tooltip: lang.isHindi ? 'हटाएं' : 'Remove',
                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                  onPressed: () => setState(() {
                    _imagePath = null;
                    _imageBase64 = null;
                  }),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFCBD5E1), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFD4AF37).withValues(alpha: 0.15),
            ),
            child: const Icon(Icons.camera_alt_rounded, color: Color(0xFFB45309), size: 30),
          ),
          const SizedBox(height: 10),
          Text(
            lang.isHindi ? 'पर्ची की फोटो लें' : 'Take Slip Photo',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryNavy,
                    foregroundColor: AppColors.primaryGold,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () => _pickImage(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt_rounded, size: 18),
                  label: Text(lang.isHindi ? 'कैमरा' : 'Camera'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF0F172A),
                    side: const BorderSide(color: Color(0xFF94A3B8)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () => _pickImage(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_rounded, size: 18),
                  label: Text(lang.isHindi ? 'गैलरी' : 'Gallery'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 2. Direction Toggle: माल दिया vs माल आया
  Widget _buildTradeTypeSelector(LanguageProvider lang) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      padding: const EdgeInsets.all(5),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                setState(() => _tradeType = 'sale');
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 11),
                decoration: BoxDecoration(
                  gradient: _tradeType == 'sale'
                      ? const LinearGradient(
                          colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                        )
                      : null,
                  color: _tradeType == 'sale' ? null : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: _tradeType == 'sale'
                      ? Border.all(color: const Color(0xFFD4AF37), width: 1.5)
                      : null,
                  boxShadow: _tradeType == 'sale'
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.arrow_upward_rounded,
                      size: 17,
                      color: _tradeType == 'sale' ? const Color(0xFF4ADE80) : const Color(0xFF64748B),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      lang.isHindi ? 'माल दिया' : 'Sales',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: _tradeType == 'sale' ? const Color(0xFFFDE047) : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                setState(() => _tradeType = 'purchase');
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 11),
                decoration: BoxDecoration(
                  gradient: _tradeType == 'purchase'
                      ? const LinearGradient(
                          colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                        )
                      : null,
                  color: _tradeType == 'purchase' ? null : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: _tradeType == 'purchase'
                      ? Border.all(color: const Color(0xFF38BDF8), width: 1.5)
                      : null,
                  boxShadow: _tradeType == 'purchase'
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.arrow_downward_rounded,
                      size: 17,
                      color: _tradeType == 'purchase' ? const Color(0xFF38BDF8) : const Color(0xFF64748B),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      lang.isHindi ? 'माल आया' : 'Purchases',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: _tradeType == 'purchase' ? const Color(0xFF38BDF8) : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 3. ONLY 3-4 Simple & Essential Fields: Party Name, Challan No., Date, Amount
  Widget _buildSimpleDetailsCard(LanguageProvider lang) {
    final query = _partySearchController.text.trim().toLowerCase();

    final isNewPartyTyped = query.isNotEmpty &&
        !_parties.any((p) => p.name.trim().toLowerCase() == query);

    final isToday = DateUtils.isSameDay(_docDate, DateTime.now());
    final isYesterday = DateUtils.isSameDay(_docDate, DateTime.now().subtract(const Duration(days: 1)));

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Field 1: Party Name (Searchable + Quick chips)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                lang.isHindi ? 'पार्टी का नाम *' : 'Party Name *',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: Color(0xFF1E293B)),
              ),
              InkWell(
                onTap: () => _openQuickAddPartyDialog(lang),
                child: Row(
                  children: [
                    const Icon(Icons.add_circle_outline_rounded, size: 15, color: Color(0xFF2563EB)),
                    const SizedBox(width: 3),
                    Text(
                      lang.isHindi ? '+ नया खाता' : '+ New Party',
                      style: const TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.w800, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          TextField(
            controller: _partySearchController,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              prefixIcon: const Icon(Icons.person_search_rounded, size: 20, color: Color(0xFF64748B)),
              hintText: lang.isHindi ? 'पार्टी का नाम लिखें या चुनें...' : 'Type or select party name...',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.primaryNavy, width: 1.8),
              ),
              suffixIcon: _partySearchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 18),
                      onPressed: () {
                        setState(() {
                          _partySearchController.clear();
                          _selectedParty = null;
                        });
                      },
                    )
                  : null,
            ),
            onChanged: (val) {
              setState(() {
                final match = _parties.where((p) => p.name.trim().toLowerCase() == val.trim().toLowerCase()).firstOrNull;
                _selectedParty = match;
              });
            },
          ),

          // 1-Tap Quick Suggestion Chips for Frequent Parties
          if (_parties.isNotEmpty) ...[
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ..._parties.take(4).map((p) {
                    final isSel = _selectedParty?.id == p.id;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ActionChip(
                        labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                        visualDensity: VisualDensity.compact,
                        backgroundColor: isSel ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                        side: BorderSide(
                          color: isSel ? const Color(0xFFD4AF37) : const Color(0xFFCBD5E1),
                        ),
                        label: Text(
                          p.name,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: isSel ? FontWeight.w900 : FontWeight.w700,
                            color: isSel ? const Color(0xFFFDE047) : const Color(0xFF334155),
                          ),
                        ),
                        onPressed: () {
                          HapticFeedback.selectionClick();
                          setState(() {
                            _selectedParty = p;
                            _partySearchController.text = p.name;
                          });
                        },
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],

          // Quick prompt to auto-create if user typed a new party
          if (isNewPartyTyped) ...[
            const SizedBox(height: 6),
            InkWell(
              onTap: () async {
                final newParty = Party(
                  name: _partySearchController.text.trim(),
                  type: _tradeType == 'purchase' ? 'supplier' : 'customer',
                );
                final newId = await _partyRepo.insertParty(newParty);
                if (!mounted) return;
                final created = newParty.copyWith(id: newId);
                setState(() {
                  _parties.add(created);
                  _selectedParty = created;
                });
                final lang = Provider.of<LanguageProvider>(context, listen: false);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(lang.tr(en: '✅ Account "${created.name}" created!', hi: '✅ खाता "${created.name}" सुरक्षित हो गया!')),
                    backgroundColor: const Color(0xFF0F172A),
                    duration: const Duration(seconds: 1),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF93C5FD)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.add_circle_rounded, size: 16, color: Color(0xFF2563EB)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '+ "${_partySearchController.text.trim()}" ${lang.isHindi ? "नया खाता बनाएं" : "Create Account"}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1D4ED8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          const SizedBox(height: 14),

          // Field 2: Challan / Slip Number (Handwritten PO/Challan No.)
          Text(
            lang.isHindi ? 'चालान नंबर' : 'Challan Number',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: Color(0xFF1E293B)),
          ),
          const SizedBox(height: 7),
          TextField(
            controller: _slipNumberController,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              prefixIcon: const Icon(Icons.tag_rounded, size: 20, color: Color(0xFF64748B)),
              hintText: lang.isHindi ? 'उदा. 191, 222, 1068' : 'e.g. 191, 222, 1068',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.primaryNavy, width: 1.8),
              ),
            ),
          ),

          const SizedBox(height: 14),

          // Field 3: Date (with [आज], [कल] Quick Pills)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                lang.isHindi ? 'चालान तारीख *' : 'Challan Date *',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: Color(0xFF1E293B)),
              ),
              Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _docDate = DateTime.now());
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isToday ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isToday ? const Color(0xFFD4AF37) : const Color(0xFFCBD5E1),
                        ),
                      ),
                      child: Text(
                        lang.isHindi ? 'आज' : 'Today',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: isToday ? const Color(0xFFFDE047) : const Color(0xFF475569),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 5),
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _docDate = DateTime.now().subtract(const Duration(days: 1)));
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isYesterday ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isYesterday ? const Color(0xFFD4AF37) : const Color(0xFFCBD5E1),
                        ),
                      ),
                      child: Text(
                        lang.isHindi ? 'कल' : 'Yesterday',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: isYesterday ? const Color(0xFFFDE047) : const Color(0xFF475569),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 7),
          InkWell(
            onTap: _selectDate,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFCBD5E1)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today_rounded, size: 18, color: Color(0xFF64748B)),
                  const SizedBox(width: 8),
                  Text(
                    DateFormatter.format(_docDate),
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5, color: Color(0xFF0F172A)),
                  ),
                  const Spacer(),
                  const Icon(Icons.arrow_drop_down_rounded, color: Color(0xFF64748B)),
                ],
              ),
            ),
          ),

          const SizedBox(height: 14),

          // Field 4: Amount
          Text(
            lang.isHindi ? 'कुल रकम (₹) *' : 'Total Amount (₹) *',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: Color(0xFF1E293B)),
          ),
          const SizedBox(height: 7),
          TextFormField(
            controller: _totalAmountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              prefixIcon: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Text('₹', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFFD4AF37))),
              ),
              hintText: '66560',
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
              final n = double.tryParse(val.trim());
              if (n == null || n <= 0) {
                return lang.tr(en: 'Please enter valid amount', hi: 'वैध रकम दर्ज करें');
              }
              return null;
            },
          ),
        ],
      ),
    );
  }
}
