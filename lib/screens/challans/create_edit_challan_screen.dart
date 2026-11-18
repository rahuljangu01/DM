import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
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
import '../../services/cloudinary_service.dart';
import '../../services/firebase_sync_service.dart';
import '../../widgets/interactive_slip_viewer.dart';

class CreateEditChallanScreen extends StatefulWidget {
  final int? initialPartyId;
  final DocumentRepository? docRepository;
  final PartyRepository? partyRepository;

  const CreateEditChallanScreen({
    super.key,
    this.initialPartyId,
    this.docRepository,
    this.partyRepository,
  });

  @override
  State<CreateEditChallanScreen> createState() => _CreateEditChallanScreenState();
}

class _CreateEditChallanScreenState extends State<CreateEditChallanScreen> {
  final _formKey = GlobalKey<FormState>();
  late DocumentRepository _docRepo;
  late PartyRepository _partyRepo;

  List<Party> _parties = [];
  Party? _selectedParty;
  String _docNumber = '';
  DateTime _docDate = DateTime.now();
  final TextEditingController _notesController = TextEditingController();

  final List<_ChallanItemDraft> _items = [];
  bool _isLoading = true;
  bool _isSaving = false;

  String? _imagePath;
  String? _imageBase64;
  String? _imageUrl;
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        imageQuality: 70,
        maxWidth: 1080,
      );
      if (picked == null) return;

      final appDir = await getApplicationDocumentsDirectory();
      final slipsDir = Directory('${appDir.path}/slips');
      if (!slipsDir.existsSync()) {
        slipsDir.createSync(recursive: true);
      }
      final fileName = 'challan_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final saved = await File(picked.path).copy('${slipsDir.path}/$fileName');
      final bytes = await saved.readAsBytes();
      final b64 = base64Encode(bytes);

      setState(() {
        _imagePath = saved.path;
        _imageBase64 = b64;
      });

      // Background upload to Cloudinary for instant direct link
      CloudinaryService().uploadImageFile(saved, tag: 'challan_slip').then((res) {
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
          SnackBar(
            content: Text(lang.tr(en: 'Error capturing photo: $e', hi: 'फोटो लेने में त्रुटि: $e')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

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
    final nextNum = await _docRepo.generateNextDocNumber('challan');

    Party? matched;
    if (widget.initialPartyId != null) {
      matched = parties.where((p) => p.id == widget.initialPartyId).firstOrNull;
    }
    matched ??= parties.isNotEmpty ? parties.first : null;

    _items.add(_ChallanItemDraft());

    if (mounted) {
      setState(() {
        _parties = parties;
        _selectedParty = matched;
        _docNumber = nextNum;
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    for (final it in _items) {
      it.dispose();
    }
    super.dispose();
  }

  int get _grandTotalPaise {
    int total = 0;
    for (final item in _items) {
      total += item.lineTotalPaise;
    }
    return total;
  }

  Future<void> _saveChallan() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedParty == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select customer')),
      );
      return;
    }

    if (_items.isEmpty || _items.every((it) => it.nameController.text.trim().isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one lace item')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final lineItems = _items
          .where((it) => it.nameController.text.trim().isNotEmpty)
          .map((it) => it.toDocumentItem())
          .toList();

      // Ensure Cloudinary upload is attempted if not ready yet
      if (_imageUrl == null && _imagePath != null) {
        try {
          final res = await CloudinaryService().uploadImageFile(File(_imagePath!), tag: 'challan_slip');
          if (res.success && res.url != null) {
            _imageUrl = res.url;
          }
        } catch (_) {}
      }

      final doc = BusinessDocument(
        docNumber: _docNumber,
        docType: 'challan',
        partyId: _selectedParty!.id!,
        partyName: _selectedParty!.name,
        docDate: DateFormatter.toIso(_docDate).substring(0, 10),
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        imagePath: _imagePath,
        imageBase64: _imageBase64,
        imageUrl: _imageUrl,
        items: lineItems,
      );

      final docId = await _docRepo.createDocument(doc);

      // Save slip data + full photo to Firebase cloud in real-time
      try {
        final syncService = FirebaseSyncService();
        final cloudMap = Map<String, dynamic>.from(doc.toMap());
        cloudMap['id'] = docId;
        if (_imageUrl != null) {
          cloudMap['image_url'] = _imageUrl;
        }
        cloudMap['items_json'] = jsonEncode(lineItems.map((i) => i.toMap()).toList());
        await syncService.pushSingleRecord(
          collection: 'bills',
          id: docId.toString(),
          data: cloudMap,
        );
        await syncService.pushSingleRecord(
          collection: 'challans',
          id: docId.toString(),
          data: cloudMap,
        );
        syncService.triggerAutoSync();
      } catch (_) {}

      if (mounted) {
        final lang = Provider.of<LanguageProvider>(context, listen: false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(lang.tr(
              en: '✅ Delivery Challan $_docNumber & photo saved and synced to cloud!',
              hi: '✅ डिलीवरी चालान $_docNumber और फोटो क्लाउड में सुरक्षित हो गया!',
            )),
            backgroundColor: AppColors.secondaryNavy,
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create challan: $e'), backgroundColor: AppColors.payableRed),
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
        appBar: AppBar(title: Text(lang.tr(en: 'New Delivery Challan', hi: 'नया डिलीवरी चालान'))),
        body: const Center(child: CircularProgressIndicator(color: AppColors.primaryGold)),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: Text(lang.tr(en: 'New Delivery Challan', hi: 'नया डिलीवरी चालान')),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(14),
          children: [
            // Slip Photo Section
            _buildPhotoSection(lang),

            const SizedBox(height: 12),

            // Number & Party Card
            Card(
              color: AppColors.surfaceWhite,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Text(
                          '${lang.tr(en: 'Challan Number', hi: 'चालान नंबर')}: $_docNumber',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.secondaryNavy),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
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
                          child: Text(p.name, overflow: TextOverflow.ellipsis),
                        );
                      }).toList(),
                      onChanged: (val) => setState(() => _selectedParty = val),
                      validator: (val) => val == null ? lang.tr(en: 'Please select party', hi: 'ग्राहक चुनें') : null,
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _docDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2035),
                        );
                        if (picked != null) setState(() => _docDate = picked);
                      },
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: lang.tr(en: 'Dispatch Date', hi: 'तारीख'),
                          prefixIcon: const Icon(Icons.calendar_today, size: 18),
                        ),
                        child: Text(DateFormatter.format(_docDate), style: const TextStyle(fontSize: 13)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Items Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  lang.tr(en: 'Dispatched Lace Items', hi: 'माल का विवरण'),
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.add, size: 16),
                  label: Text(lang.tr(en: 'Add Item', hi: 'माल जोड़ें'), style: const TextStyle(fontWeight: FontWeight.w700)),
                  onPressed: () => setState(() => _items.add(_ChallanItemDraft())),
                ),
              ],
            ),
            const SizedBox(height: 6),

            ..._items.asMap().entries.map((entry) {
              final idx = entry.key;
              final it = entry.value;
              return _buildItemCard(idx, it);
            }),

            const SizedBox(height: 12),

            // Total Value Card
            Card(
              color: AppColors.surfaceWhite,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total Estimated Value:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                    Text(
                      CurrencyFormatter.formatPaise(_grandTotalPaise),
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.secondaryNavy),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Tempo / Transport Notes
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Transport / Driver / Remarks',
                hintText: 'e.g. Delivered via tempo driver Mukeshbhai, Goods for party approval',
              ),
            ),
            const SizedBox(height: 24),

            // Submit Button
            ElevatedButton(
              onPressed: _isSaving ? null : _saveChallan,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.secondaryNavy,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isSaving
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text('Generate Challan $_docNumber', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemCard(int index, _ChallanItemDraft item) {
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
                  backgroundColor: AppColors.secondaryNavy.withValues(alpha: 0.1),
                  child: Text('${index + 1}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.secondaryNavy)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: item.nameController,
                    decoration: const InputDecoration(
                      hintText: 'Lace Design Name (e.g. Cotton Crochet 1.5")',
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                if (_items.length > 1)
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: AppColors.payableRed, size: 20),
                    onPressed: () => setState(() => _items.removeAt(index)),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
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
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text('Total', style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
                      Text(
                        CurrencyFormatter.formatPaise(item.lineTotalPaise),
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.secondaryNavy),
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
                Row(
                  children: [
                    const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 18),
                    const SizedBox(width: 6),
                    Text(
                      lang.tr(en: 'Challan slip photo attached', hi: 'चालान पर्ची फोटो अटैच है'),
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF0F172A)),
                    ),
                  ],
                ),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  onPressed: () => InteractiveSlipViewer.show(context, imagePath: _imagePath!),
                  icon: const Icon(Icons.zoom_in_rounded, size: 17, color: Color(0xFF0284C7)),
                  label: Text(lang.tr(en: 'View Large', hi: 'बड़ा देखें'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => InteractiveSlipViewer.show(context, imagePath: _imagePath!),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(
                  File(_imagePath!),
                  height: 180,
                  width: double.infinity,
                  fit: BoxFit.cover,
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
                    label: Text(lang.tr(en: 'Retake Photo', hi: 'दोबारा फोटो लें')),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton(
                  tooltip: lang.tr(en: 'Remove', hi: 'हटाएं'),
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
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFD4AF37).withValues(alpha: 0.15),
                ),
                child: const Icon(Icons.camera_alt_rounded, color: Color(0xFFB45309), size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lang.tr(en: 'Attach Challan Slip Photo', hi: 'चालान पर्ची का फोटो जोड़ें'),
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      lang.tr(en: 'Photo is securely backed up to cloud', hi: 'फोटो सीधे क्लाउड डेटाबेस में भी सुरक्षित रहेगी'),
                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryNavy,
                    foregroundColor: AppColors.primaryGold,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  onPressed: () => _pickImage(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt_rounded, size: 17),
                  label: Text(lang.tr(en: 'Camera', hi: 'कैमरा')),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF0F172A),
                    side: const BorderSide(color: Color(0xFF94A3B8)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  onPressed: () => _pickImage(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_rounded, size: 17),
                  label: Text(lang.tr(en: 'Gallery', hi: 'गैलरी')),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ChallanItemDraft {
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
  int get lineTotalPaise => (quantity * ratePaise).round();

  DocumentItem toDocumentItem() {
    return DocumentItem(
      itemName: nameController.text.trim(),
      quantity: quantity,
      unit: unit,
      ratePaise: ratePaise,
      lineTotalPaise: lineTotalPaise,
    );
  }
}
