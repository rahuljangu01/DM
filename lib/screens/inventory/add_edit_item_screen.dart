import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/localization/language_provider.dart';
import '../../core/utils/currency_formatter.dart';
import '../../models/inventory_item.dart';
import '../../repositories/inventory_repository.dart';
import '../../services/cloudinary_service.dart';
import '../../services/firebase_sync_service.dart';

class AddEditItemScreen extends StatefulWidget {
  final InventoryItem? item;
  final InventoryRepository? repository;

  const AddEditItemScreen({super.key, this.item, this.repository});

  @override
  State<AddEditItemScreen> createState() => _AddEditItemScreenState();
}

class _AddEditItemScreenState extends State<AddEditItemScreen> {
  final _formKey = GlobalKey<FormState>();
  late InventoryRepository _repo;

  late TextEditingController _codeController;
  late TextEditingController _nameController;
  late TextEditingController _openingQtyController;
  late TextEditingController _purchaseRateController;
  late TextEditingController _sellingRateController;
  late TextEditingController _alertQtyController;
  late TextEditingController _widthController;
  late TextEditingController _colorsController;
  late TextEditingController _descriptionController;

  String _unit = 'meter';
  String _category = 'Zari Border';
  String? _imagePath;
  String? _imageBase64;
  String? _imageUrl;
  bool _isSaving = false;
  final ImagePicker _picker = ImagePicker();

  final List<String> _categories = [
    'Zari Border',
    'Gota Patti',
    'Sequence Work',
    'Cotton Crochet',
    'Latkan & Dori',
    'Velvet & Net',
    'Dupatta Border',
    'Fancy Lace',
  ];

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? InventoryRepository();
    final it = widget.item;

    _codeController = TextEditingController(text: it?.designCode ?? '');
    _nameController = TextEditingController(text: it?.itemName ?? '');
    _openingQtyController = TextEditingController(text: it?.openingQuantity.toString() ?? '100');
    _purchaseRateController = TextEditingController(text: it != null ? it.purchaseRateRupees.toString() : '0');
    _sellingRateController = TextEditingController(text: it != null ? it.sellingRateRupees.toString() : '0');
    _alertQtyController = TextEditingController(text: it?.lowStockWarningQty.toString() ?? '50');
    _widthController = TextEditingController(text: it?.width ?? '2 Inch');
    _colorsController = TextEditingController(text: it?.colors ?? 'Gold / Silver');
    _descriptionController = TextEditingController(text: it?.description ?? '');

    if (it != null) {
      _unit = it.unit;
      if (it.category != null && it.category!.isNotEmpty) {
        if (_categories.contains(it.category)) {
          _category = it.category!;
        } else {
          _categories.insert(0, it.category!);
          _category = it.category!;
        }
      }
      _imagePath = it.imagePath;
      _imageBase64 = it.imageBase64;
      _imageUrl = it.imageUrl;
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    _openingQtyController.dispose();
    _purchaseRateController.dispose();
    _sellingRateController.dispose();
    _alertQtyController.dispose();
    _widthController.dispose();
    _colorsController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1400,
        maxHeight: 1400,
        imageQuality: 88,
      );
      if (picked != null) {
        final appDir = await getApplicationDocumentsDirectory();
        final catalogDir = Directory('${appDir.path}/catalog');
        if (!catalogDir.existsSync()) {
          catalogDir.createSync(recursive: true);
        }
        final fileName = 'lace_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final savedFile = await File(picked.path).copy('${catalogDir.path}/$fileName');
        final bytes = await savedFile.readAsBytes();
        final b64 = base64Encode(bytes);

        setState(() {
          _imagePath = savedFile.path;
          _imageBase64 = b64;
        });

        // Background upload to Cloudinary for direct link
        CloudinaryService().uploadImageFile(savedFile, tag: 'catalog_item').then((res) {
          if (res.success && res.url != null && mounted) {
            setState(() {
              _imageUrl = res.url;
            });
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not access image: $e')),
        );
      }
    }
  }

  void _showImagePickerOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Select Lace Design Photo',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.primaryNavy),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.camera_alt_rounded, color: Color(0xFF2563EB)),
                  ),
                  title: const Text('Take Photo with Camera', style: TextStyle(fontWeight: FontWeight.w700)),
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(ImageSource.camera);
                  },
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFDF2F8),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.photo_library_rounded, color: Color(0xFFDB2777)),
                  ),
                  title: const Text('Choose from Gallery', style: TextStyle(fontWeight: FontWeight.w700)),
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(ImageSource.gallery);
                  },
                ),
                if (_imagePath != null)
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.delete_outline_rounded, color: AppColors.payableRed),
                    ),
                    title: const Text('Remove Photo', style: TextStyle(color: AppColors.payableRed, fontWeight: FontWeight.w700)),
                    onTap: () {
                      Navigator.pop(context);
                      setState(() {
                        _imagePath = null;
                        _imageBase64 = null;
                        _imageUrl = null;
                      });
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final openingQty = double.tryParse(_openingQtyController.text) ?? 0.0;
      final pRateRupees = CurrencyFormatter.parseDouble(_purchaseRateController.text);
      final sRateRupees = CurrencyFormatter.parseDouble(_sellingRateController.text);
      final alertQty = double.tryParse(_alertQtyController.text) ?? 50.0;

      // Ensure Cloudinary upload is attempted if not done yet
      if (_imageUrl == null && _imagePath != null && File(_imagePath!).existsSync()) {
        try {
          final res = await CloudinaryService().uploadImageFile(File(_imagePath!), tag: 'catalog_item');
          if (res.success && res.url != null) {
            _imageUrl = res.url;
          }
        } catch (_) {}
      }

      int itemId;
      if (widget.item == null) {
        final newItem = InventoryItem(
          designCode: _codeController.text.trim().toUpperCase(),
          itemName: _nameController.text.trim(),
          unit: _unit,
          openingQuantity: openingQty,
          purchaseRatePaise: CurrencyFormatter.rupeesToPaise(pRateRupees),
          sellingRatePaise: CurrencyFormatter.rupeesToPaise(sRateRupees),
          lowStockWarningQty: alertQty,
          category: _category,
          width: _widthController.text.trim().isEmpty ? null : _widthController.text.trim(),
          colors: _colorsController.text.trim().isEmpty ? null : _colorsController.text.trim(),
          imagePath: _imagePath,
          imageBase64: _imageBase64,
          imageUrl: _imageUrl,
          description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
        );
        itemId = await _repo.insertItem(newItem);
      } else {
        final updated = widget.item!.copyWith(
          designCode: _codeController.text.trim().toUpperCase(),
          itemName: _nameController.text.trim(),
          unit: _unit,
          purchaseRatePaise: CurrencyFormatter.rupeesToPaise(pRateRupees),
          sellingRatePaise: CurrencyFormatter.rupeesToPaise(sRateRupees),
          lowStockWarningQty: alertQty,
          category: _category,
          width: _widthController.text.trim().isEmpty ? null : _widthController.text.trim(),
          colors: _colorsController.text.trim().isEmpty ? null : _colorsController.text.trim(),
          imagePath: _imagePath,
          imageBase64: _imageBase64,
          imageUrl: _imageUrl,
          description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
        );
        await _repo.updateItem(updated);
        itemId = widget.item!.id!;
      }

      // Real-time push to Firebase catalog collection
      try {
        final syncService = FirebaseSyncService();
        final catalogMap = <String, dynamic>{
          'id': itemId,
          'design_code': _codeController.text.trim().toUpperCase(),
          'item_name': _nameController.text.trim(),
          'category': _category,
          'width': _widthController.text.trim(),
          'colors': _colorsController.text.trim(),
          'unit': _unit,
          'selling_rate_paise': CurrencyFormatter.rupeesToPaise(sRateRupees),
          'purchase_rate_paise': CurrencyFormatter.rupeesToPaise(pRateRupees),
          'current_stock': widget.item != null ? widget.item!.currentStock : openingQty,
          'image_path': _imagePath,
          'image_base64': _imageBase64,
          'image_url': _imageUrl,
          'updated_at': DateTime.now().toIso8601String(),
        };
        await syncService.pushSingleRecord(
          collection: 'catalog',
          id: itemId.toString(),
          data: catalogMap,
        );
        syncService.triggerAutoSync();
      } catch (_) {}

      if (mounted) {
        final lang = Provider.of<LanguageProvider>(context, listen: false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(lang.tr(en: '✅ Lace design saved successfully!', hi: '✅ लेस डिज़ाइन व फोटो सुरक्षित सेव हो गई!')),
            backgroundColor: AppColors.primaryNavy,
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.payableRed),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: Text(widget.item == null ? 'Add Lace Design' : 'Edit Lace Design'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 750),
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Image Picker Container
                GestureDetector(
                  onTap: _showImagePickerOptions,
                  child: Container(
                    height: 180,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFD4AF37), width: 1.2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: (_imagePath != null && File(_imagePath!).existsSync()) ||
                            (_imageUrl != null && _imageUrl!.startsWith('http')) ||
                            (_imageBase64 != null && _imageBase64!.isNotEmpty) ||
                            (_imagePath != null && _imagePath!.startsWith('assets/'))
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(15),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                if (_imagePath != null && File(_imagePath!).existsSync())
                                  Image.file(
                                    File(_imagePath!),
                                    fit: BoxFit.cover,
                                  )
                                else if (_imageUrl != null && _imageUrl!.startsWith('http'))
                                  Image.network(
                                    _imageUrl!,
                                    fit: BoxFit.cover,
                                    loadingBuilder: (_, child, progress) {
                                      if (progress == null) return child;
                                      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
                                    },
                                    errorBuilder: (context, error, stackTrace) => const Center(child: Icon(Icons.broken_image_rounded, size: 40, color: Colors.grey)),
                                  )
                                else if (_imageBase64 != null && _imageBase64!.isNotEmpty)
                                  Image.memory(
                                    base64Decode(_imageBase64!),
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) => const Center(child: Icon(Icons.broken_image_rounded, size: 40, color: Colors.grey)),
                                  )
                                else if (_imagePath != null && _imagePath!.startsWith('assets/'))
                                  Image.asset(
                                    _imagePath!,
                                    fit: BoxFit.cover,
                                  ),
                                Positioned(
                                  top: 10,
                                  right: 10,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.65),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.camera_alt, color: Colors.white, size: 14),
                                        SizedBox(width: 4),
                                        Text('Change Photo', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEF9C3),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: const Color(0xFFEAB308), width: 1.5),
                                ),
                                child: const Icon(Icons.add_a_photo_rounded, size: 36, color: Color(0xFF854D0E)),
                              ),
                              const SizedBox(height: 10),
                              const Text(
                                'Tap to Add Custom Lace Photo',
                                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.primaryNavy),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Camera or Gallery • Looks gorgeous in Client Catalog & WhatsApp',
                                style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                              ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 16),

                // Design Code & Name
                Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: TextFormField(
                        controller: _codeController,
                        decoration: const InputDecoration(
                          labelText: 'Design Code *',
                          hintText: 'e.g. ZARI-105',
                          prefixIcon: Icon(Icons.qr_code, color: AppColors.primaryNavy),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 5,
                      child: DropdownButtonFormField<String>(
                        initialValue: _category,
                        decoration: const InputDecoration(
                          labelText: 'Lace Category',
                          prefixIcon: Icon(Icons.category_outlined, color: AppColors.primaryNavy),
                        ),
                        items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c, overflow: TextOverflow.ellipsis))).toList(),
                        onChanged: (v) => setState(() => _category = v!),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Item Name & Description *',
                    hintText: 'e.g. 2-Inch Golden Cutwork Zari Lace Border',
                    prefixIcon: Icon(Icons.style_outlined, color: AppColors.primaryNavy),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter item name' : null,
                ),
                const SizedBox(height: 14),

                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _widthController,
                        decoration: const InputDecoration(
                          labelText: 'Width / Panna',
                          hintText: 'e.g. 2 Inch, 9 Mtr',
                          prefixIcon: Icon(Icons.straighten, color: AppColors.primaryNavy),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _colorsController,
                        decoration: const InputDecoration(
                          labelText: 'Available Colors',
                          hintText: 'e.g. Gold, Silver, Rani',
                          prefixIcon: Icon(Icons.palette_outlined, color: AppColors.primaryNavy),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                DropdownButtonFormField<String>(
                  initialValue: _unit,
                  decoration: InputDecoration(
                    labelText: Provider.of<LanguageProvider>(context, listen: false).tr(en: 'Unit of Measurement', hi: 'इकाई (Unit)'),
                    prefixIcon: const Icon(Icons.straighten, color: AppColors.primaryNavy),
                  ),
                  items: [
                    DropdownMenuItem(value: 'meter', child: Text(Provider.of<LanguageProvider>(context, listen: false).tr(en: 'Meter', hi: 'मीटर (Meter)'))),
                    DropdownMenuItem(value: 'roll', child: Text(Provider.of<LanguageProvider>(context, listen: false).tr(en: 'Roll / Than', hi: 'रोल / थान (Roll)'))),
                    DropdownMenuItem(value: 'piece', child: Text(Provider.of<LanguageProvider>(context, listen: false).tr(en: 'Piece / Nag', hi: 'नग / पीस (Piece)'))),
                    DropdownMenuItem(value: 'kg', child: Text(Provider.of<LanguageProvider>(context, listen: false).tr(en: 'Kg', hi: 'किलो (Kg)'))),
                    DropdownMenuItem(value: 'yard', child: Text(Provider.of<LanguageProvider>(context, listen: false).tr(en: 'Yard', hi: 'गज (Yard)'))),
                  ],
                  onChanged: (v) => setState(() => _unit = v!),
                ),
                const SizedBox(height: 14),

                if (widget.item == null) ...[
                  TextFormField(
                    controller: _openingQtyController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Initial Opening Stock ($_unit)',
                      hintText: '100',
                      prefixIcon: const Icon(Icons.inventory, color: AppColors.primaryNavy),
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _purchaseRateController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Purchase Rate (₹)',
                          hintText: '0.00',
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _sellingRateController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Selling Rate (₹)',
                          hintText: '0.00',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                TextFormField(
                  controller: _alertQtyController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Low Stock Alert Threshold ($_unit)',
                    hintText: '50',
                    prefixIcon: const Icon(Icons.warning_amber_rounded, color: AppColors.warningOrange),
                  ),
                ),
                const SizedBox(height: 14),

                TextFormField(
                  controller: _descriptionController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Additional Notes / Fabric Details',
                    hintText: 'e.g. Surat direct loom production, wholesale quality',
                    prefixIcon: Icon(Icons.notes_rounded, color: AppColors.primaryNavy),
                  ),
                ),
                const SizedBox(height: 24),

                ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryNavy,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isSaving
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text(widget.item == null ? 'Save Lace Design' : 'Update Lace Design', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
