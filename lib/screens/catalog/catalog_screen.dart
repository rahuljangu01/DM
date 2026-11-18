import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/localization/language_provider.dart';
import '../../core/services/ai_catalog_assistant.dart';
import '../../core/utils/catalog_pdf_generator.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/share_helper.dart';
import '../../models/inventory_item.dart';
import '../../repositories/inventory_repository.dart';
import '../../services/cloudinary_service.dart';
import '../../services/firebase_sync_service.dart';
import '../inventory/add_edit_item_screen.dart';
import '../../widgets/compact_fab.dart';

enum CatalogViewMode {
  grid,     // 2 columns on mobile, 4-6 on laptop
  feed,     // Showroom detailed cards (1-2 columns)
  lookbook, // Full luxury visual gallery with frosted overlay
}

enum SortOption {
  latest,
  priceLowHigh,
  priceHighLow,
  stockHighLow,
}

class CatalogScreen extends StatefulWidget {
  final String? initialCategory;

  const CatalogScreen({super.key, this.initialCategory});

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> with SingleTickerProviderStateMixin {
  final InventoryRepository _repo = InventoryRepository();
  final ImagePicker _picker = ImagePicker();
  List<InventoryItem> _items = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _selectedCategory = 'All';
  SortOption _sortOption = SortOption.latest;
  final TextEditingController _searchController = TextEditingController();

  CatalogViewMode _viewMode = CatalogViewMode.grid;

  // Multi-select mode state
  bool _isSelectionMode = false;
  final Set<int> _selectedItemIds = {};

  final List<String> _categories = [
    'All',
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
    if (widget.initialCategory != null && widget.initialCategory!.isNotEmpty) {
      _selectedCategory = widget.initialCategory!;
    }
    _loadItems();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadItems() async {
    setState(() => _isLoading = true);
    final allItems = await _repo.getItems();
    if (mounted) {
      setState(() {
        _items = allItems;
        _isLoading = false;
      });
    }
  }

  List<InventoryItem> get _filteredAndSortedItems {
    final list = _items.where((item) {
      // Category filter
      if (_selectedCategory != 'All') {
        final cat = item.category ?? '';
        final name = item.itemName.toLowerCase();
        final selected = _selectedCategory.toLowerCase();
        if (!cat.toLowerCase().contains(selected) && !name.contains(selected)) {
          return false;
        }
      }

      // Search query filter
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchCode = item.designCode.toLowerCase().contains(q);
        final matchName = item.itemName.toLowerCase().contains(q);
        final matchCat = (item.category ?? '').toLowerCase().contains(q);
        final matchColors = (item.colors ?? '').toLowerCase().contains(q);
        if (!matchCode && !matchName && !matchCat && !matchColors) {
          return false;
        }
      }

      return true;
    }).toList();

    switch (_sortOption) {
      case SortOption.priceLowHigh:
        list.sort((a, b) => a.sellingRateRupees.compareTo(b.sellingRateRupees));
        break;
      case SortOption.priceHighLow:
        list.sort((a, b) => b.sellingRateRupees.compareTo(a.sellingRateRupees));
        break;
      case SortOption.stockHighLow:
        list.sort((a, b) => b.currentStock.compareTo(a.currentStock));
        break;
      case SortOption.latest:
        list.sort((a, b) => (b.id ?? 0).compareTo(a.id ?? 0));
        break;
    }

    return list;
  }

  // 1-Tap Single Design WhatsApp Share (Sends image + concise valuable caption)
  void _shareSingleDesign(InventoryItem item, LanguageProvider lang) {
    HapticFeedback.lightImpact();
    final pitch = AiCatalogAssistant.generateMarketingPitch(
      item,
      style: PitchStyle.wholesaleB2B,
      isHindi: lang.isHindi,
    );

    ShareHelper.shareImageWithText(
      imagePath: item.imagePath,
      text: pitch,
      subject: 'DM Lace Surat - ${item.designCode}',
    );
  }

  // Multi-Design WhatsApp Share (Sends all selected photos + concise catalog list)
  void _shareMultipleDesigns(List<InventoryItem> selected, LanguageProvider lang) {
    if (selected.isEmpty) return;
    HapticFeedback.mediumImpact();

    final buffer = StringBuffer();
    if (lang.isHindi) {
      buffer.writeln('*DM LACE SURAT*');
      buffer.writeln('सूरत टेक्सटाइल मार्केट');
      buffer.writeln('----------------------------------------');
      buffer.writeln('लेस कलेक्शन कैटलॉग (${selected.length} डिज़ाइन्स)\n');

      for (int i = 0; i < selected.length; i++) {
        final it = selected[i];
        buffer.writeln('${i + 1}. *${it.designCode}* - ${it.itemName}');
        buffer.writeln('   भाव: ${CurrencyFormatter.format(it.sellingRateRupees)} / ${it.unit}');
        buffer.writeln('   श्रेणी: ${it.category ?? 'लेस'} | पन्ना: ${it.width ?? 'मानक'}');
        if (it.colors != null && it.colors!.isNotEmpty) {
          buffer.writeln('   रंग: ${it.colors}');
        }
        buffer.writeln('   स्टॉक: ${it.currentStock.toStringAsFixed(0)} ${it.unit} उपलब्ध\n');
      }

      buffer.writeln('----------------------------------------');
      buffer.writeln('डायरेक्ट लूम निर्माता • DM Lace Surat');
      buffer.writeln('आर्डर व बुकिंग हेतु WhatsApp पर संपर्क करें।');
    } else {
      buffer.writeln('*DM LACE SURAT*');
      buffer.writeln('Surat Textile Market');
      buffer.writeln('----------------------------------------');
      buffer.writeln('Lace Catalog Collection (${selected.length} Designs)\n');

      for (int i = 0; i < selected.length; i++) {
        final it = selected[i];
        buffer.writeln('${i + 1}. *${it.designCode}* - ${it.itemName}');
        buffer.writeln('   Rate: ${CurrencyFormatter.format(it.sellingRateRupees)} / ${it.unit}');
        buffer.writeln('   Category: ${it.category ?? 'Lace'} | Width: ${it.width ?? 'Standard'}');
        if (it.colors != null && it.colors!.isNotEmpty) {
          buffer.writeln('   Colors: ${it.colors}');
        }
        buffer.writeln('   Stock: ${it.currentStock.toStringAsFixed(0)} ${it.unit} Available\n');
      }

      buffer.writeln('----------------------------------------');
      buffer.writeln('Direct Loom Manufacturer • DM Lace Surat');
      buffer.writeln('Contact on WhatsApp to place orders.');
    }

    final images = selected
        .map((e) => e.imagePath)
        .where((p) => p != null && p.trim().isNotEmpty)
        .cast<String>()
        .toList();

    ShareHelper.shareMultipleImagesWithText(
      imagePaths: images,
      text: buffer.toString(),
      subject: 'DM Lace Surat - Multi-Item Catalog (${selected.length} Designs)',
    );
  }

  // Quick Photo Picker (Directly from Card)
  Future<void> _quickPickPhoto(InventoryItem item) async {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF9C3),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFEAB308)),
                    ),
                    child: const Icon(Icons.add_a_photo_rounded, color: Color(0xFF854D0E), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Update Photo: ${item.designCode}',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.primaryNavy),
                        ),
                        Text(
                          item.itemName,
                          style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.camera_alt_rounded, color: Color(0xFF2563EB)),
                ),
                title: const Text('Capture with Camera', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                subtitle: const Text('Take direct photo of lace roll / sample', style: TextStyle(fontSize: 11)),
                onTap: () async {
                  Navigator.pop(ctx);
                  final picked = await _picker.pickImage(source: ImageSource.camera, maxWidth: 1400, maxHeight: 1400, imageQuality: 88);
                  if (picked != null) {
                    _handleQuickPhotoPicked(item, picked);
                  }
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: const Color(0xFFFDF2F8), borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.photo_library_rounded, color: Color(0xFFDB2777)),
                ),
                title: const Text('Choose from Phone Gallery', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                subtitle: const Text('Pick high quality studio lace photo', style: TextStyle(fontSize: 11)),
                onTap: () async {
                  Navigator.pop(ctx);
                  final picked = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 1400, maxHeight: 1400, imageQuality: 88);
                  if (picked != null) {
                    _handleQuickPhotoPicked(item, picked);
                  }
                },
              ),
              if (item.imagePath != null && item.imagePath!.isNotEmpty) ...[
                const Divider(),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.delete_outline_rounded, color: AppColors.payableRed),
                  ),
                  title: const Text('Remove Photo', style: TextStyle(color: AppColors.payableRed, fontWeight: FontWeight.w800, fontSize: 14)),
                  subtitle: const Text('Revert to Surat lace design motif', style: TextStyle(fontSize: 11)),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await _repo.updateItemImage(item.id!, null, imageBase64: null, imageUrl: null);
                    _loadItems();
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleQuickPhotoPicked(InventoryItem item, XFile picked) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final catalogDir = Directory('${appDir.path}/catalog');
      if (!catalogDir.existsSync()) {
        catalogDir.createSync(recursive: true);
      }
      final fileName = 'lace_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final savedFile = await File(picked.path).copy('${catalogDir.path}/$fileName');
      final bytes = await savedFile.readAsBytes();
      final b64 = base64Encode(bytes);

      await _repo.updateItemImage(item.id!, savedFile.path, imageBase64: b64);
      _loadItems();

      // Background upload to Cloudinary & push to Firebase
      CloudinaryService().uploadImageFile(savedFile, tag: 'catalog_item').then((res) async {
        if (res.success && res.url != null) {
          await _repo.updateItemImage(item.id!, savedFile.path, imageBase64: b64, imageUrl: res.url);
          try {
            final syncService = FirebaseSyncService();
            await syncService.pushSingleRecord(
              collection: 'catalog',
              id: item.id!.toString(),
              data: {
                'id': item.id,
                'design_code': item.designCode,
                'item_name': item.itemName,
                'category': item.category,
                'image_path': savedFile.path,
                'image_base64': b64,
                'image_url': res.url,
                'updated_at': DateTime.now().toIso8601String(),
              },
            );
          } catch (_) {}
          if (mounted) _loadItems();
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  // Delete Single Design with Confirmation
  Future<void> _deleteDesign(InventoryItem item, LanguageProvider lang) async {
    HapticFeedback.vibrate();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFECACA)),
              ),
              child: const Icon(Icons.delete_forever_rounded, color: AppColors.payableRed, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                lang.tr(en: 'Delete Design?', hi: 'डिज़ाइन हटाएं?'),
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              lang.tr(
                en: 'Are you sure you want to remove this design from your catalog?',
                hi: 'क्या आप वाकई इस डिज़ाइन को कैटलॉग से हटाना चाहते हैं?',
              ),
              style: const TextStyle(fontSize: 13.5, color: AppColors.textSecondary, height: 1.4),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(6)),
                    child: Text(item.designCode, style: const TextStyle(color: Color(0xFFFDE047), fontWeight: FontWeight.w900, fontSize: 11)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(item.itemName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              lang.tr(en: 'Cancel', hi: 'रद्द करें'),
              style: const TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w700),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.payableRed,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              lang.tr(en: 'Delete', hi: 'हटाएं'),
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _repo.deleteItem(item.id!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              lang.tr(
                en: '${item.designCode} removed from catalog',
                hi: '${item.designCode} कैटलॉग से हटाया गया',
              ),
            ),
            backgroundColor: AppColors.primaryNavy,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            duration: const Duration(seconds: 2),
          ),
        );
        _loadItems();
      }
    }
  }

  // Bulk Delete Selected Designs
  Future<void> _deleteSelectedDesigns(List<InventoryItem> selected, LanguageProvider lang) async {
    if (selected.isEmpty) return;
    HapticFeedback.vibrate();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.delete_sweep_rounded, color: AppColors.payableRed, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                lang.tr(
                  en: 'Delete ${selected.length} Designs?',
                  hi: '${selected.length} डिज़ाइन हटाएं?',
                ),
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
              ),
            ),
          ],
        ),
        content: Text(
          lang.tr(
            en: 'Are you sure you want to delete these ${selected.length} selected lace designs from your catalog?',
            hi: 'क्या आप वाकई इन ${selected.length} चयनित लेस डिज़ाइनों को कैटलॉग से हटाना चाहते हैं?',
          ),
          style: const TextStyle(fontSize: 13.5, color: AppColors.textSecondary, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(lang.tr(en: 'Cancel', hi: 'रद्द करें'), style: const TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w700)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.payableRed,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(lang.tr(en: 'Delete All', hi: 'सभी हटाएं'), style: const TextStyle(fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final ids = selected.map((e) => e.id!).toList();
      await _repo.deleteItems(ids);
      if (mounted) {
        setState(() {
          _isSelectionMode = false;
          _selectedItemIds.clear();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              lang.tr(
                en: '${ids.length} designs removed from catalog',
                hi: '${ids.length} डिज़ाइन कैटलॉग से हटाए गए',
              ),
            ),
            backgroundColor: AppColors.primaryNavy,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        _loadItems();
      }
    }
  }

  // 🤖 AI Smart Studio Sheet
  void _showAiStudioModal(InventoryItem item, LanguageProvider lang) {
    HapticFeedback.lightImpact();
    PitchStyle currentStyle = PitchStyle.wholesaleB2B;
    final pairings = AiCatalogAssistant.getGarmentPairings(item);
    final insights = AiCatalogAssistant.calculateMarginInsights(item);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final pitchText = AiCatalogAssistant.generateMarketingPitch(
              item,
              style: currentStyle,
              isHindi: lang.isHindi,
            );

            return Container(
              height: MediaQuery.of(context).size.height * 0.88,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
              ),
              child: Column(
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 14, 16, 14),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF060F1E), Color(0xFF132B4F)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFDE047).withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFFD4AF37), width: 1.2),
                          ),
                          child: const Icon(Icons.auto_awesome_rounded, color: Color(0xFFFDE047), size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Text(
                                    'DM LACE AI STUDIO',
                                    style: TextStyle(
                                      color: Color(0xFFFDE047),
                                      fontWeight: FontWeight.w900,
                                      fontSize: 14,
                                      letterSpacing: 1.1,
                                    ),
                                  ),
                                  SizedBox(width: 6),
                                  Text('✨', style: TextStyle(fontSize: 12)),
                                ],
                              ),
                              Text(
                                '${item.designCode} • ${item.itemName}',
                                style: const TextStyle(color: Colors.white70, fontSize: 11),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: Colors.white70),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                  ),

                  // Scrollable Body
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        // Style Switcher Chips
                        const Text(
                          'Select AI Marketing Pitch Target:',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.primaryNavy),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: _buildStyleChip(
                                label: '💼 Wholesale',
                                isSelected: currentStyle == PitchStyle.wholesaleB2B,
                                onTap: () => setSheetState(() => currentStyle = PitchStyle.wholesaleB2B),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: _buildStyleChip(
                                label: '🌸 Boutique',
                                isSelected: currentStyle == PitchStyle.boutiqueDesigner,
                                onTap: () => setSheetState(() => currentStyle = PitchStyle.boutiqueDesigner),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: _buildStyleChip(
                                label: '🔥 Festive Rush',
                                isSelected: currentStyle == PitchStyle.weddingRush,
                                onTap: () => setSheetState(() => currentStyle = PitchStyle.weddingRush),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Generated Pitch Box
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Row(
                                    children: [
                                      Icon(Icons.mark_chat_unread_outlined, size: 16, color: Color(0xFF25D366)),
                                      SizedBox(width: 6),
                                      Text(
                                        'Ready WhatsApp Pitch Preview',
                                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                                      ),
                                    ],
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.copy_rounded, size: 18, color: AppColors.primaryNavy),
                                    tooltip: 'Copy Pitch',
                                    onPressed: () {
                                      Clipboard.setData(ClipboardData(text: pitchText));
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('AI Pitch copied to clipboard!'), duration: Duration(seconds: 1)),
                                      );
                                    },
                                  ),
                                ],
                              ),
                              const Divider(height: 12),
                              Text(
                                pitchText,
                                style: const TextStyle(fontSize: 12, height: 1.45, color: Color(0xFF1E293B)),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Action Buttons: WhatsApp Send
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF25D366),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            elevation: 2,
                          ),
                          onPressed: () {
                            ShareHelper.shareImageWithText(
                              imagePath: item.imagePath,
                              text: pitchText,
                              subject: 'DM Lace Surat - ${item.designCode}',
                            );
                          },
                          icon: const Icon(Icons.chat_rounded, size: 19),
                          label: const Text(
                            'Send AI Pitch Directly on WhatsApp',
                            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13.5),
                          ),
                        ),
                        const SizedBox(height: 18),

                        // AI Garment Pairings
                        const Text(
                          '👗 AI Recommended Garment Styling:',
                          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: AppColors.primaryNavy),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: pairings.map((pair) {
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFFBFDBFE)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.check_circle_rounded, size: 13, color: Color(0xFF2563EB)),
                                  const SizedBox(width: 5),
                                  Text(pair, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF1E40AF))),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 18),

                        // AI Profit & Margin Insights
                        const Text(
                          '📊 AI Profit Margin & Rate Insights:',
                          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: AppColors.primaryNavy),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: _buildInsightCard(
                                title: 'Wholesale Rate',
                                value: '${CurrencyFormatter.format(item.sellingRateRupees)}/${item.unit}',
                                subtitle: 'Your Current Price',
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildInsightCard(
                                title: 'Suggested MRP',
                                value: '₹${insights['suggestedRetailMrp']}',
                                subtitle: 'Boutique Resale',
                                color: const Color(0xFF15803D),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildInsightCard(
                                title: 'Est. Margin',
                                value: '+${insights['marginPercent']}%',
                                subtitle: 'Gross Profit',
                                color: const Color(0xFFD97706),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildStyleChip({required String label, required bool isSelected, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0B1F38) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isSelected ? const Color(0xFFD4AF37) : const Color(0xFFCBD5E1), width: isSelected ? 1.5 : 1),
          boxShadow: isSelected ? [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4)] : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
            color: isSelected ? const Color(0xFFFDE047) : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }

  Widget _buildInsightCard({required String title, required String value, required String subtitle, required Color color}) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 10, color: AppColors.textMuted, fontWeight: FontWeight.w600)),
          const SizedBox(height: 3),
          Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: color)),
          const SizedBox(height: 2),
          Text(subtitle, style: const TextStyle(fontSize: 9, color: AppColors.textMuted)),
        ],
      ),
    );
  }

  // Full Screen Interactive HD Lookbook Photo Viewer
  void _openInteractiveImageViewer(InventoryItem item) {
    HapticFeedback.lightImpact();
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: true,
        pageBuilder: (context, animation, secondaryAnimation) {
          return Scaffold(
            backgroundColor: Colors.black.withValues(alpha: 0.95),
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              iconTheme: const IconThemeData(color: Colors.white),
              title: Text(
                '${item.designCode} • ${item.itemName}',
                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.share_rounded, color: Color(0xFF25D366)),
                  onPressed: () => _shareSingleDesign(item, context.read<LanguageProvider>()),
                ),
              ],
            ),
            body: Center(
              child: Hero(
                tag: 'lace_img_${item.id}',
                child: InteractiveViewer(
                  panEnabled: true,
                  minScale: 0.8,
                  maxScale: 4.0,
                  child: _buildZoomableLaceImage(item),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildZoomableLaceImage(InventoryItem item) {
    if (item.imagePath != null && item.imagePath!.startsWith('assets/')) {
      return Image.asset(item.imagePath!, fit: BoxFit.contain);
    }
    if (item.imagePath != null && item.imagePath!.isNotEmpty && File(item.imagePath!).existsSync()) {
      return Image.file(File(item.imagePath!), fit: BoxFit.contain);
    }
    if (item.imageUrl != null && item.imageUrl!.startsWith('http')) {
      return Image.network(
        item.imageUrl!,
        fit: BoxFit.contain,
        loadingBuilder: (_, child, progress) {
          if (progress == null) return child;
          return const Center(child: CircularProgressIndicator(color: AppColors.primaryGold));
        },
      );
    }
    if (item.imageBase64 != null && item.imageBase64!.isNotEmpty) {
      try {
        return Image.memory(base64Decode(item.imageBase64!), fit: BoxFit.contain);
      } catch (_) {}
    }
    return Container(
      width: 320,
      height: 320,
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF091B33), Color(0xFF1E3A8A)]),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🧵', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 12),
            Text(item.itemName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            Text(item.category ?? 'Surat Lace', style: const TextStyle(color: Color(0xFFFDE047))),
          ],
        ),
      ),
    );
  }

  void _showDesignDetailSheet(InventoryItem item, LanguageProvider lang) {
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 14),

              // Image / Preview in Sheet
              GestureDetector(
                onTap: () => _openInteractiveImageViewer(item),
                child: Container(
                  height: 170,
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFD4AF37), width: 1.5),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14.5),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        _buildDesignImage(item, height: 170, fit: BoxFit.cover),
                        Positioned(
                          bottom: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.65), borderRadius: BorderRadius.circular(8)),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.zoom_in, color: Colors.white, size: 14),
                                SizedBox(width: 4),
                                Text('Tap to Zoom HD', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0B1F38),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      item.designCode,
                      style: const TextStyle(
                        color: Color(0xFFFDE047),
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFA7F3D0)),
                    ),
                    child: Text(
                      '${item.currentStock.toStringAsFixed(0)} ${item.unit} ${lang.tr(en: 'in Godown', hi: 'गोदाम में')}',
                      style: const TextStyle(
                        color: Color(0xFF065F46),
                        fontWeight: FontWeight.w700,
                        fontSize: 11.5,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                item.itemName,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                item.description ?? lang.tr(en: 'Surat Premium Wholesale Lace Design', hi: 'सूरत प्रीमियम होलसेल लेस डिज़ाइन'),
                style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary, height: 1.4),
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildDetailTile(
                      label: lang.tr(en: 'Category', hi: 'श्रेणी'),
                      value: item.category ?? 'Lace Border',
                      icon: Icons.category_outlined,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildDetailTile(
                      label: lang.tr(en: 'Width / Panna', hi: 'पन्ना/चौड़ाई'),
                      value: item.width ?? 'Standard',
                      icon: Icons.straighten_rounded,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildDetailTile(
                      label: lang.tr(en: 'Wholesale Rate', hi: 'होलसेल भाव'),
                      value: '${CurrencyFormatter.format(item.sellingRateRupees)} / ${item.unit}',
                      icon: Icons.currency_rupee_rounded,
                      isBold: true,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildDetailTile(
                      label: lang.tr(en: 'Available Colors', hi: 'उपलब्ध रंग'),
                      value: item.colors ?? 'Gold / Silver',
                      icon: Icons.palette_outlined,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Action Buttons Row (AI Studio, WhatsApp, Edit, Delete)
              Row(
                children: [
                  Expanded(
                    flex: 5,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F172A),
                        foregroundColor: const Color(0xFFFDE047),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xFFD4AF37))),
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        _showAiStudioModal(item, lang);
                      },
                      icon: const Icon(Icons.auto_awesome_rounded, size: 16, color: Color(0xFFFDE047)),
                      label: const Text(
                        'AI Studio',
                        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 6,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF25D366),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        _shareSingleDesign(item, lang);
                      },
                      icon: const Icon(Icons.chat_rounded, size: 16),
                      label: Text(
                        lang.tr(en: 'WhatsApp', hi: 'WhatsApp'),
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primaryNavy,
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                      side: const BorderSide(color: AppColors.primaryNavy),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () async {
                      Navigator.pop(context);
                      final res = await Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => AddEditItemScreen(item: item)),
                      );
                      if (res == true) _loadItems();
                    },
                    child: const Icon(Icons.edit_outlined, size: 18),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _deleteDesign(item, lang);
                    },
                    icon: Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFFECACA)),
                      ),
                      child: const Icon(Icons.delete_outline_rounded, color: AppColors.payableRed, size: 18),
                    ),
                    tooltip: 'Delete Design',
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailTile({
    required String label,
    required String value,
    required IconData icon,
    bool isBold = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 13, color: AppColors.textMuted),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(fontSize: 10, color: AppColors.textMuted, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isBold ? FontWeight.w900 : FontWeight.w700,
              color: isBold ? AppColors.primaryNavy : AppColors.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildDesignImage(InventoryItem item, {double height = 130, double? width, BoxFit fit = BoxFit.cover}) {
    final isAsset = item.imagePath != null && item.imagePath!.startsWith('assets/');
    final isFile = item.imagePath != null && item.imagePath!.isNotEmpty && !isAsset && File(item.imagePath!).existsSync();
    final isNetwork = item.imageUrl != null && item.imageUrl!.startsWith('http');
    final isBase64 = item.imageBase64 != null && item.imageBase64!.isNotEmpty;

    if (isAsset || isFile || isNetwork || isBase64) {
      return Stack(
        fit: StackFit.passthrough,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: isFile
                ? Image.file(
                    File(item.imagePath!),
                    height: height,
                    width: width ?? double.infinity,
                    fit: fit,
                    cacheWidth: 500,
                    errorBuilder: (context, error, stackTrace) => _buildPlaceholderMotif(item, height: height, width: width),
                  )
                : isNetwork
                    ? Image.network(
                        item.imageUrl!,
                        height: height,
                        width: width ?? double.infinity,
                        fit: fit,
                        loadingBuilder: (_, child, progress) {
                          if (progress == null) return child;
                          return SizedBox(
                            height: height,
                            width: width ?? double.infinity,
                            child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) => _buildPlaceholderMotif(item, height: height, width: width),
                      )
                    : isBase64
                        ? Image.memory(
                            base64Decode(item.imageBase64!),
                            height: height,
                            width: width ?? double.infinity,
                            fit: fit,
                            errorBuilder: (context, error, stackTrace) => _buildPlaceholderMotif(item, height: height, width: width),
                          )
                        : Image.asset(
                            item.imagePath!,
                            height: height,
                            width: width ?? double.infinity,
                            fit: fit,
                            errorBuilder: (context, error, stackTrace) => _buildPlaceholderMotif(item, height: height, width: width),
                          ),
          ),
          Positioned(
            top: 6,
            right: 6,
            child: GestureDetector(
              onTap: () => _quickPickPhoto(item),
              child: Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.65),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.camera_alt, color: Colors.white, size: 12),
              ),
            ),
          ),
        ],
      );
    }
    return _buildPlaceholderMotif(item, height: height, width: width);
  }

  Widget _buildPlaceholderMotif(InventoryItem item, {double height = 130, double? width}) {
    return Container(
      height: height,
      width: width ?? double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF091B33), Color(0xFF1E3A8A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Stack(
        children: [
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.texture_rounded, size: 30, color: Color(0xFFD4AF37)),
                const SizedBox(height: 3),
                Text(
                  item.category ?? 'Surat Lace',
                  style: const TextStyle(
                    color: Color(0xFFCBD5E1),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 6,
            right: 6,
            child: GestureDetector(
              onTap: () => _quickPickPhoto(item),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFD4AF37), width: 0.8),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_a_photo_outlined, size: 10, color: Color(0xFFFDE047)),
                    SizedBox(width: 4),
                    Text('Photo', style: TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 1. Grid View (2 per row on mobile, 4-6 on laptop) with Staggered Fade-in Animation
  Widget _buildGridView(List<InventoryItem> items, LanguageProvider lang, BoxConstraints constraints) {
    final width = constraints.maxWidth;
    final int crossAxisCount = width < 650
        ? 2
        : width < 950
            ? 3
            : width < 1250
                ? 4
                : 5;

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 80),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: width < 650 ? 0.77 : 0.84,
      ),
      itemCount: items.length,
      itemBuilder: (context, idx) {
        final item = items[idx];
        final isChecked = _selectedItemIds.contains(item.id);

        return TweenAnimationBuilder<double>(
          duration: Duration(milliseconds: 200 + (idx % 8 * 40)),
          tween: Tween(begin: 0.0, end: 1.0),
          builder: (context, animValue, child) {
            return Opacity(
              opacity: animValue,
              child: Transform.translate(
                offset: Offset(0, 15 * (1 - animValue)),
                child: child,
              ),
            );
          },
          child: Card(
            color: Colors.white,
            elevation: 2,
            margin: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: isChecked ? AppColors.primaryNavy : const Color(0xFFE2E8F0),
                width: isChecked ? 2 : 0.9,
              ),
            ),
            child: InkWell(
              onTap: () {
                if (_isSelectionMode) {
                  setState(() {
                    if (isChecked) {
                      _selectedItemIds.remove(item.id);
                    } else {
                      _selectedItemIds.add(item.id!);
                    }
                  });
                } else {
                  _showDesignDetailSheet(item, lang);
                }
              },
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Image with Badges
                    Stack(
                      children: [
                        _buildDesignImage(item, height: width < 650 ? 115 : 130),
                        if (_isSelectionMode)
                          Positioned(
                            top: 4,
                            left: 4,
                            child: Container(
                              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6)),
                              child: Checkbox(
                                value: isChecked,
                                activeColor: AppColors.primaryNavy,
                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                visualDensity: VisualDensity.compact,
                                onChanged: (val) {
                                  setState(() {
                                    if (val == true) {
                                      _selectedItemIds.add(item.id!);
                                    } else {
                                      _selectedItemIds.remove(item.id);
                                    }
                                  });
                                },
                              ),
                            ),
                          )
                        else
                          Positioned(
                            top: 6,
                            left: 6,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0B1F38).withValues(alpha: 0.92),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFFD4AF37), width: 0.8),
                              ),
                              child: Text(
                                item.designCode,
                                style: const TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFFFDE047),
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ),
                          ),
                        Positioned(
                          bottom: 6,
                          left: 6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFECFDF5).withValues(alpha: 0.92),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '${item.currentStock.toStringAsFixed(0)} ${item.unit}',
                              style: const TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF065F46),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    // Item Name
                    Text(
                      item.itemName,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),

                    // Width & Category
                    Text(
                      '${item.category ?? 'Lace'} • ${item.width ?? 'Std'}',
                      style: const TextStyle(fontSize: 10, color: AppColors.textMuted, fontWeight: FontWeight.w500),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),

                    // Rate & Actions Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            '${CurrencyFormatter.format(item.sellingRateRupees)}/${item.unit}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              color: AppColors.primaryNavy,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (!_isSelectionMode) ...[
                          // AI Button
                          GestureDetector(
                            onTap: () => _showAiStudioModal(item, lang),
                            child: Container(
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0F172A).withValues(alpha: 0.08),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.auto_awesome_rounded, size: 14, color: Color(0xFFD97706)),
                            ),
                          ),
                          const SizedBox(width: 4),
                          // WhatsApp Button
                          GestureDetector(
                            onTap: () => _shareSingleDesign(item, lang),
                            child: Container(
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                color: const Color(0xFF25D366).withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.share_rounded, size: 14, color: Color(0xFF25D366)),
                            ),
                          ),
                          const SizedBox(width: 4),
                          // Delete Button
                          GestureDetector(
                            onTap: () => _deleteDesign(item, lang),
                            child: Container(
                              padding: const EdgeInsets.all(5),
                              decoration: const BoxDecoration(
                                color: Color(0xFFFEF2F2),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.delete_outline_rounded, size: 14, color: AppColors.payableRed),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // 2. Feed View (Showroom Cards)
  Widget _buildFeedView(List<InventoryItem> items, LanguageProvider lang, BoxConstraints constraints) {
    final isDesktop = constraints.maxWidth >= 850;

    if (isDesktop) {
      return GridView.builder(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 80),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 10,
          childAspectRatio: 2.5,
        ),
        itemCount: items.length,
        itemBuilder: (context, idx) => _buildFeedItemCard(items[idx], lang),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 80),
      itemCount: items.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, idx) => _buildFeedItemCard(items[idx], lang),
    );
  }

  Widget _buildFeedItemCard(InventoryItem item, LanguageProvider lang) {
    final isChecked = _selectedItemIds.contains(item.id);

    return Card(
      color: Colors.white,
      elevation: 2,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isChecked ? AppColors.primaryNavy : const Color(0xFFE2E8F0),
          width: isChecked ? 2 : 0.8,
        ),
      ),
      child: InkWell(
        onTap: () {
          if (_isSelectionMode) {
            setState(() {
              if (isChecked) {
                _selectedItemIds.remove(item.id);
              } else {
                _selectedItemIds.add(item.id!);
              }
            });
          } else {
            _showDesignDetailSheet(item, lang);
          }
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_isSelectionMode)
                Checkbox(
                  value: isChecked,
                  activeColor: AppColors.primaryNavy,
                  onChanged: (val) {
                    setState(() {
                      if (val == true) {
                        _selectedItemIds.add(item.id!);
                      } else {
                        _selectedItemIds.remove(item.id);
                      }
                    });
                  },
                )
              else
                SizedBox(
                  width: 82,
                  height: 82,
                  child: _buildDesignImage(item, height: 82, width: 82),
                ),
              const SizedBox(width: 10),

              // Specs
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFBFDBFE)),
                          ),
                          child: Text(
                            item.designCode,
                            style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF1D4ED8)),
                          ),
                        ),
                        if (item.category != null) ...[
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              '• ${item.category}',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textMuted),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.itemName,
                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Text(
                          '${CurrencyFormatter.format(item.sellingRateRupees)} / ${item.unit}',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: AppColors.primaryNavy),
                        ),
                        if (item.width != null) ...[
                          const SizedBox(width: 6),
                          Text('(${item.width})', style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                        ],
                      ],
                    ),
                    if (item.colors != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        item.colors!,
                        style: const TextStyle(fontSize: 10.5, color: AppColors.textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),

              // Action buttons
              if (!_isSelectionMode)
                Column(
                  children: [
                    IconButton(
                      icon: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A).withValues(alpha: 0.08),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.auto_awesome_rounded, size: 16, color: Color(0xFFD97706)),
                      ),
                      onPressed: () => _showAiStudioModal(item, lang),
                      tooltip: 'AI Studio',
                    ),
                    IconButton(
                      icon: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF25D366).withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.share_rounded, size: 16, color: Color(0xFF25D366)),
                      ),
                      onPressed: () => _shareSingleDesign(item, lang),
                      tooltip: 'Share on WhatsApp',
                    ),
                    IconButton(
                      icon: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: Color(0xFFFEF2F2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.delete_outline_rounded, size: 16, color: AppColors.payableRed),
                      ),
                      onPressed: () => _deleteDesign(item, lang),
                      tooltip: 'Delete Design',
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  // 3. Lookbook View (High-End Showcase / Visual Gallery)
  Widget _buildLookbookView(List<InventoryItem> items, LanguageProvider lang, BoxConstraints constraints) {
    final width = constraints.maxWidth;
    final int crossAxisCount = width < 750 ? 1 : width < 1150 ? 2 : 3;

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 80),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        childAspectRatio: width < 750 ? 1.32 : 1.25,
      ),
      itemCount: items.length,
      itemBuilder: (context, idx) {
        final item = items[idx];
        final isChecked = _selectedItemIds.contains(item.id);

        return Card(
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: isChecked ? const Color(0xFFFDE047) : const Color(0xFFCBD5E1),
              width: isChecked ? 2.5 : 0.8,
            ),
          ),
          elevation: 4,
          child: InkWell(
            onTap: () {
              if (_isSelectionMode) {
                setState(() {
                  if (isChecked) {
                    _selectedItemIds.remove(item.id);
                  } else {
                    _selectedItemIds.add(item.id!);
                  }
                });
              } else {
                _showDesignDetailSheet(item, lang);
              }
            },
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Background Image / Motif
                _buildDesignImage(item, height: double.infinity, fit: BoxFit.cover),

                // Top Vignette Header
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.black.withValues(alpha: 0.75), Colors.transparent],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F172A).withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFFDE047), width: 1.2),
                          ),
                          child: Text(
                            item.designCode,
                            style: const TextStyle(
                              color: Color(0xFFFDE047),
                              fontWeight: FontWeight.w900,
                              fontSize: 12.5,
                            ),
                          ),
                        ),
                        if (_isSelectionMode)
                          Checkbox(
                            value: isChecked,
                            activeColor: const Color(0xFFFDE047),
                            checkColor: Colors.black,
                            onChanged: (val) {
                              setState(() {
                                if (val == true) {
                                  _selectedItemIds.add(item.id!);
                                } else {
                                  _selectedItemIds.remove(item.id);
                                }
                              });
                            },
                          )
                        else
                          Row(
                            children: [
                              GestureDetector(
                                onTap: () => _showAiStudioModal(item, lang),
                                child: Container(
                                  padding: const EdgeInsets.all(7),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.55),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: const Color(0xFFFDE047), width: 1),
                                  ),
                                  child: const Icon(Icons.auto_awesome_rounded, size: 15, color: Color(0xFFFDE047)),
                                ),
                              ),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () => _quickPickPhoto(item),
                                child: Container(
                                  padding: const EdgeInsets.all(7),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.55),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.camera_alt_outlined, size: 16, color: Colors.white),
                                ),
                              ),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () => _deleteDesign(item, lang),
                                child: Container(
                                  padding: const EdgeInsets.all(7),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.55),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.delete_outline_rounded, size: 16, color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),

                // Bottom Frosted Information Bar
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.black.withValues(alpha: 0.88), Colors.black.withValues(alpha: 0.96)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.itemName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Text(
                              item.category ?? 'Surat Wholesale Lace',
                              style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 11),
                            ),
                            if (item.colors != null) ...[
                              const Text(' • ', style: TextStyle(color: Colors.white70)),
                              Flexible(
                                child: Text(
                                  item.colors!,
                                  style: const TextStyle(color: Color(0xFFFDE047), fontSize: 11, fontWeight: FontWeight.w700),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${CurrencyFormatter.format(item.sellingRateRupees)} / ${item.unit}',
                              style: const TextStyle(
                                color: Color(0xFFFDE047),
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF25D366),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                visualDensity: VisualDensity.compact,
                              ),
                              onPressed: () => _shareSingleDesign(item, lang),
                              icon: const Icon(Icons.chat_rounded, size: 15),
                              label: Text(
                                lang.tr(en: 'WhatsApp', hi: 'शेयर'),
                                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final items = _filteredAndSortedItems;
    final selectedItems = _items.where((it) => _selectedItemIds.contains(it.id)).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        title: Text(lang.tr(en: 'Lace Catalog', hi: 'लेस कैटलॉग')),
        actions: [
          // Sort Dropdown
          PopupMenuButton<SortOption>(
            icon: const Icon(Icons.sort_rounded, color: AppColors.goldLight),
            tooltip: 'Sort Designs',
            onSelected: (opt) => setState(() => _sortOption = opt),
            itemBuilder: (context) => [
              const PopupMenuItem(value: SortOption.latest, child: Text('Latest Added')),
              const PopupMenuItem(value: SortOption.priceLowHigh, child: Text('Price: Low to High')),
              const PopupMenuItem(value: SortOption.priceHighLow, child: Text('Price: High to Low')),
              const PopupMenuItem(value: SortOption.stockHighLow, child: Text('Stock: High to Low')),
            ],
          ),

          if (!_isSelectionMode)
            TextButton.icon(
              onPressed: () {
                HapticFeedback.lightImpact();
                setState(() {
                  _isSelectionMode = true;
                  _selectedItemIds.clear();
                });
              },
              icon: const Icon(Icons.checklist_rounded, color: AppColors.goldLight, size: 18),
              label: Text(
                lang.tr(en: 'Select', hi: 'चुनें'),
                style: const TextStyle(color: AppColors.goldLight, fontWeight: FontWeight.w700, fontSize: 12),
              ),
            )
          else ...[
            TextButton(
              onPressed: () {
                setState(() {
                  if (_selectedItemIds.length == items.length) {
                    _selectedItemIds.clear();
                  } else {
                    _selectedItemIds.addAll(items.map((e) => e.id!));
                  }
                });
              },
              child: Text(
                _selectedItemIds.length == items.length
                    ? lang.tr(en: 'Clear All', hi: 'हटाएं')
                    : lang.tr(en: 'Select All', hi: 'सभी चुनें'),
                style: const TextStyle(color: AppColors.goldLight, fontWeight: FontWeight.w700, fontSize: 12),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close_rounded, color: Colors.white),
              onPressed: () {
                setState(() {
                  _isSelectionMode = false;
                  _selectedItemIds.clear();
                });
              },
            ),
          ],
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1350),
              child: Column(
                children: [
                  // Search & View Toggle Header
                  Container(
                    color: Colors.white,
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                    child: Column(
                      children: [
                        // Search bar & Animated View Switcher Row
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppColors.borderLight),
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                                child: Row(
                                  children: [
                                    const Icon(Icons.search_rounded, color: AppColors.primaryNavy, size: 19),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: TextField(
                                        controller: _searchController,
                                        decoration: InputDecoration(
                                          hintText: lang.tr(
                                            en: 'Search design code, name, color...',
                                            hi: 'कोड, नाम या रंग खोजें...',
                                          ),
                                          hintStyle: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                                          border: InputBorder.none,
                                          isDense: true,
                                          contentPadding: const EdgeInsets.symmetric(vertical: 8),
                                        ),
                                        onChanged: (val) => setState(() => _searchQuery = val.trim()),
                                      ),
                                    ),
                                    if (_searchQuery.isNotEmpty)
                                      GestureDetector(
                                        onTap: () {
                                          _searchController.clear();
                                          setState(() => _searchQuery = '');
                                        },
                                        child: const Icon(Icons.close_rounded, size: 16, color: AppColors.textMuted),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),

                            // 3-Way Animated View Switcher (Grid / Feed / Lookbook)
                            Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.borderLight),
                              ),
                              padding: const EdgeInsets.all(2.5),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _buildViewModeButton(
                                    mode: CatalogViewMode.grid,
                                    icon: Icons.grid_view_rounded,
                                    tooltip: 'Grid (2 per row)',
                                  ),
                                  _buildViewModeButton(
                                    mode: CatalogViewMode.feed,
                                    icon: Icons.view_agenda_rounded,
                                    tooltip: 'Cards View',
                                  ),
                                  _buildViewModeButton(
                                    mode: CatalogViewMode.lookbook,
                                    icon: Icons.photo_library_outlined,
                                    tooltip: 'Lookbook Gallery',
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Categories Horizontal Filter
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: _categories.map((cat) {
                              final isSelected = _selectedCategory == cat;
                              return Padding(
                                padding: const EdgeInsets.only(right: 6.0),
                                child: ChoiceChip(
                                  label: Text(
                                    cat,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                      color: isSelected ? Colors.white : AppColors.textSecondary,
                                    ),
                                  ),
                                  selected: isSelected,
                                  selectedColor: AppColors.primaryNavy,
                                  backgroundColor: const Color(0xFFF8FAFC),
                                  side: BorderSide(
                                    color: isSelected ? AppColors.primaryNavy : AppColors.borderLight,
                                  ),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  showCheckmark: false,
                                  onSelected: (selected) {
                                    if (selected) setState(() => _selectedCategory = cat);
                                  },
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // View Content with Animated Transition
                  Expanded(
                    child: _isLoading
                        ? const Center(child: CircularProgressIndicator(color: AppColors.primaryNavy))
                        : items.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.inventory_2_outlined, size: 54, color: Color(0xFFCBD5E1)),
                                    const SizedBox(height: 10),
                                    Text(
                                      lang.tr(en: 'No Lace Designs Found', hi: 'कोई लेस डिज़ाइन नहीं मिला'),
                                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      lang.tr(en: 'Try clearing filters or add a new design', hi: 'फ़िल्टर बदलें या नया डिज़ाइन जोड़ें'),
                                      style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                                    ),
                                  ],
                                ),
                              )
                            : AnimatedSwitcher(
                                duration: const Duration(milliseconds: 250),
                                child: _viewMode == CatalogViewMode.grid
                                    ? _buildGridView(items, lang, constraints)
                                    : _viewMode == CatalogViewMode.feed
                                        ? _buildFeedView(items, lang, constraints)
                                        : _buildLookbookView(items, lang, constraints),
                              ),
                  ),
                ],
              ),
            ),
          );
        },
      ),

      // Multi-Select Actions (WhatsApp Share, PDF, Delete)
      bottomNavigationBar: _isSelectionMode && selectedItems.isNotEmpty
          ? Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -3),
                  ),
                ],
                border: const Border(top: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: SafeArea(
                top: false,
                child: Row(
                  children: [
                    // Delete Selected
                    IconButton(
                      onPressed: () => _deleteSelectedDesigns(selectedItems, lang),
                      icon: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFFECACA)),
                        ),
                        child: const Icon(Icons.delete_outline_rounded, color: AppColors.payableRed, size: 20),
                      ),
                      tooltip: 'Delete Selected',
                    ),
                    const SizedBox(width: 8),

                    // WhatsApp Share
                    Expanded(
                      flex: 6,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF25D366),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () => _shareMultipleDesigns(selectedItems, lang),
                        icon: const Icon(Icons.chat_rounded, size: 18),
                        label: Text(
                          lang.tr(
                            en: 'Share ${selectedItems.length} on WhatsApp',
                            hi: '${selectedItems.length} WhatsApp पर भेजें',
                          ),
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // PDF Export
                    Expanded(
                      flex: 3,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0B1F38),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () => CatalogPdfGenerator.shareCatalogPdf(
                          items: selectedItems,
                          title: 'DM Lace Surat Selected Catalog (${selectedItems.length} Designs)',
                        ),
                        icon: const Icon(Icons.picture_as_pdf_rounded, size: 16),
                        label: const Text('PDF', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : null,

      floatingActionButton: !_isSelectionMode
          ? CompactFab(
              heroTag: 'fab_catalog',
              icon: Icons.add_rounded,
              label: lang.tr(en: 'New Design', hi: 'नया डिज़ाइन'),
              onTap: () async {
                final res = await Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AddEditItemScreen()),
                );
                if (res == true) _loadItems();
              },
            )
          : null,
    );
  }

  Widget _buildViewModeButton({
    required CatalogViewMode mode,
    required IconData icon,
    required String tooltip,
  }) {
    final isSelected = _viewMode == mode;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _viewMode = mode);
        },
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primaryNavy : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: isSelected ? [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 4)] : null,
          ),
          child: Icon(
            icon,
            size: 18,
            color: isSelected ? const Color(0xFFFDE047) : AppColors.textMuted,
          ),
        ),
      ),
    );
  }
}
