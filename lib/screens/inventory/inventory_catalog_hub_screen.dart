import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/localization/language_provider.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/share_helper.dart';
import '../../models/inventory_item.dart';
import '../../repositories/inventory_repository.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/compact_fab.dart';
import 'add_edit_item_screen.dart';

class InventoryCatalogHubScreen extends StatefulWidget {
  final InventoryRepository? repository;

  const InventoryCatalogHubScreen({super.key, this.repository});

  @override
  State<InventoryCatalogHubScreen> createState() => _InventoryCatalogHubScreenState();
}

class _InventoryCatalogHubScreenState extends State<InventoryCatalogHubScreen>
    with SingleTickerProviderStateMixin {
  late InventoryRepository _repo;
  late TabController _moduleTabController;

  List<InventoryItem> _items = [];
  bool _isLoading = true;
  String _searchQuery = '';
  bool _onlyLowStock = false;
  final TextEditingController _searchController = TextEditingController();

  // Category filter for Catalog lookbook tab
  String _selectedCategory = 'All';
  final List<String> _categories = [
    'All',
    'Zari Border',
    'Gota Patti',
    'Sequence Work',
    'Cotton Crochet',
    'Velvet & Net',
    'Fancy Lace',
  ];

  Map<String, dynamic> _summaryStats = {
    'totalItems': 0,
    'totalQuantity': 0.0,
    'totalValuationRupees': 0.0,
    'lowStockCount': 0,
  };

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? InventoryRepository();
    _moduleTabController = TabController(length: 2, vsync: this);
    _moduleTabController.addListener(() {
      if (!_moduleTabController.indexIsChanging) {
        setState(() {});
      }
    });

    _loadData();
  }

  @override
  void dispose() {
    _moduleTabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final items = await _repo.getItems(
      searchQuery: _searchQuery,
      onlyLowStock: _onlyLowStock,
    );
    final stats = await _repo.getInventorySummaryStats();

    if (mounted) {
      setState(() {
        _items = items;
        _summaryStats = stats;
        _isLoading = false;
      });
    }
  }

  List<InventoryItem> get _catalogItems {
    if (_selectedCategory == 'All') return _items;
    return _items.where((i) {
      final cat = i.category?.toLowerCase() ?? '';
      final name = i.itemName.toLowerCase();
      final target = _selectedCategory.toLowerCase();
      return cat.contains(target) || name.contains(target);
    }).toList();
  }

  Future<void> _showStockAdjustmentDialog(InventoryItem item) async {
    final qtyController = TextEditingController(text: item.currentStock.toStringAsFixed(1));
    final reasonController = TextEditingController();

    final lang = Provider.of<LanguageProvider>(context, listen: false);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${lang.tr(en: "Stock Adjustment", hi: "स्टॉक सुधार")}: ${item.designCode}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(item.itemName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
            const SizedBox(height: 12),
            TextField(
              controller: qtyController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: '${lang.tr(en: "Physical Stock Count", hi: "वास्तविक स्टॉक संख्या")} (${item.unit})',
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: reasonController,
              decoration: InputDecoration(
                labelText: lang.tr(en: 'Reason for Adjustment', hi: 'सुधार का कारण'),
                hintText: lang.tr(en: 'e.g. Physical count variance, damaged roll', hi: 'उदा. भौतिक गिनती में कम/ज्यादा, डैमेज थान'),
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(lang.tr(en: 'Cancel', hi: 'रद्द करें')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryNavy),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(lang.tr(en: 'Save', hi: 'सहेजें')),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final newQty = double.tryParse(qtyController.text) ?? item.currentStock;
      await _repo.adjustStock(
        itemId: item.id!,
        adjustedQty: newQty,
        reason: reasonController.text.trim().isEmpty ? 'Manual physical count' : reasonController.text.trim(),
      );
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          lang.isHindi ? 'स्टॉक व कैटलॉग' : 'Stock & Catalog',
          style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.5),
        ),
        bottom: TabBar(
          controller: _moduleTabController,
          indicatorColor: AppColors.primaryGold,
          labelColor: AppColors.goldLight,
          unselectedLabelColor: Colors.white70,
          indicatorWeight: 3.2,
          tabs: [
            Tab(
              icon: const Icon(Icons.inventory_2_rounded, size: 18),
              text: lang.isHindi ? 'गोदाम स्टॉक' : 'Godown Stock',
            ),
            Tab(
              icon: const Icon(Icons.photo_library_rounded, size: 18),
              text: lang.isHindi ? 'फ़ोटो कैटलॉग' : 'Catalog',
            ),
          ],
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            children: [
              // 1. Stock & Catalog KPI Dashboard Header
              _buildStockKpiDashboard(lang),

              // 2. Tab Content
              Expanded(
                child: TabBarView(
                  controller: _moduleTabController,
                  children: [
                    _buildGodownStockTab(lang),
                    _buildCatalogShowroomTab(lang),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: CompactFab(
        heroTag: 'fab_add_item_stock',
        icon: Icons.add_rounded,
        label: lang.isHindi ? 'नया थान / डिज़ाइन' : 'Add Lace Item',
        onTap: () async {
          final res = await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const AddEditItemScreen()),
          );
          if (res == true) _loadData();
        },
      ),
    );
  }

  // Stock KPI Dashboard Header
  Widget _buildStockKpiDashboard(LanguageProvider lang) {
    final val = (_summaryStats['totalValuationRupees'] as num?)?.toDouble() ?? 0.0;
    final qty = (_summaryStats['totalQuantity'] as num?)?.toDouble() ?? 0.0;
    final low = _summaryStats['lowStockCount'] ?? 0;
    final itemsCount = _summaryStats['totalItems'] ?? 0;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.primaryNavy,
        border: Border(
          bottom: BorderSide(
            color: const Color(0xFFD4AF37).withValues(alpha: 0.35),
            width: 1,
          ),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Row(
        children: [
          // 1. Stock Valuation
          Expanded(
            child: _buildKpiBox(
              title: lang.isHindi ? 'स्टॉक मूल्यांकन' : 'Valuation',
              value: CurrencyFormatter.format(val),
              icon: Icons.monetization_on_rounded,
              accentColor: const Color(0xFFFDE047), // Gold
            ),
          ),
          const SizedBox(width: 8),

          // 2. Total Thans
          Expanded(
            child: _buildKpiBox(
              title: lang.isHindi ? 'कुल थान / रोल' : 'Total Units',
              value: qty.toStringAsFixed(0),
              icon: Icons.inventory_rounded,
              accentColor: const Color(0xFF38BDF8), // Blue
            ),
          ),
          const SizedBox(width: 8),

          // 3. Low stock & Designs
          Expanded(
            child: _buildKpiBox(
              title: lang.isHindi ? 'डिज़ाइन / लो-स्टॉक' : 'Designs / Low',
              value: '$itemsCount / $low',
              icon: Icons.warning_amber_rounded,
              accentColor: low > 0 ? const Color(0xFFF87171) : const Color(0xFF4ADE80),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiBox({
    required String title,
    required String value,
    required IconData icon,
    required Color accentColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accentColor.withValues(alpha: 0.35), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, size: 12, color: accentColor),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFCBD5E1),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w900,
                color: accentColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // TAB 1: Godown Stock & Adjustments
  Widget _buildGodownStockTab(LanguageProvider lang) {
    return Column(
      children: [
        // Search & Filter
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: lang.isHindi
                        ? 'डिज़ाइन कोड या लेस का नाम खोजें...'
                        : 'Search by design code or lace name...',
                    prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary, size: 20),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                              _loadData();
                            },
                          )
                        : null,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.borderLight),
                    ),
                  ),
                  onChanged: (val) {
                    setState(() => _searchQuery = val);
                    _loadData();
                  },
                ),
              ),
              const SizedBox(width: 8),
              FilterChip(
                label: Text(
                  lang.isHindi ? '⚠️ लो-स्टॉक' : '⚠️ Low Stock',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: _onlyLowStock ? FontWeight.w800 : FontWeight.w600,
                    color: _onlyLowStock ? Colors.white : AppColors.payableRed,
                  ),
                ),
                selected: _onlyLowStock,
                selectedColor: AppColors.payableRed,
                backgroundColor: const Color(0xFFFEE2E2),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                showCheckmark: false,
                onSelected: (val) {
                  setState(() => _onlyLowStock = val);
                  _loadData();
                },
              ),
            ],
          ),
        ),

        // Items List
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: AppColors.primaryGold))
              : _items.isEmpty
                  ? EmptyState(
                      icon: Icons.inventory_2_outlined,
                      title: lang.isHindi ? 'कोई स्टॉक आइटम नहीं मिला' : 'No Items Found',
                      message: lang.isHindi
                          ? 'गोदाम में नया लेस थान या रोल जोड़ने के लिए नीचे दिए बटन पर टैप करें।'
                          : 'Tap below to add your first lace stock item.',
                      buttonText: lang.isHindi ? 'नया थान जोड़ें' : 'Add Stock Item',
                      onButtonPressed: () async {
                        final res = await Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const AddEditItemScreen()),
                        );
                        if (res == true) _loadData();
                      },
                    )
                  : RefreshIndicator(
                      color: AppColors.primaryGold,
                      onRefresh: _loadData,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(10),
                        itemCount: _items.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 6),
                        itemBuilder: (context, index) {
                          final item = _items[index];
                          return _buildStockCard(item, lang);
                        },
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _buildStockCard(InventoryItem item, LanguageProvider lang) {
    final isLowStock = item.isLowStock;

    return Card(
      elevation: 0.6,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isLowStock ? AppColors.payableRed.withValues(alpha: 0.45) : AppColors.borderLight,
        ),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Lace Image Thumbnail or Icon
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: const Color(0xFFF1F5F9),
                border: Border.all(color: AppColors.borderLight),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: item.imagePath != null && item.imagePath!.isNotEmpty
                    ? Image.file(
                        File(item.imagePath!),
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => const Icon(Icons.image_outlined, size: 24, color: AppColors.textMuted),
                      )
                    : const Icon(Icons.inventory_2_outlined, size: 24, color: AppColors.textMuted),
              ),
            ),
            const SizedBox(width: 12),

            // Item Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: AppColors.primaryNavy.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          item.designCode,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: AppColors.primaryNavy,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          item.itemName,
                          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Text(
                        '${lang.tr(en: "Rate:", hi: "दर:")} ${CurrencyFormatter.format(item.saleRateRupees)}/${item.unit}',
                        style: const TextStyle(fontSize: 11.5, color: Color(0xFF15803D), fontWeight: FontWeight.w700),
                      ),
                      if (item.category != null && item.category!.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Text(
                          '• ${item.category}',
                          style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            // Stock Count & Action Buttons
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${item.currentStock.toStringAsFixed(1)} ${item.unit}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: isLowStock ? AppColors.payableRed : AppColors.primaryNavy,
                      ),
                    ),
                    if (isLowStock) ...[
                      const SizedBox(width: 4),
                      const Icon(Icons.warning_amber_rounded, size: 14, color: AppColors.payableRed),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Stock Adjustment Icon
                    IconButton.filledTonal(
                      icon: const Icon(Icons.tune_rounded, size: 14),
                      style: IconButton.styleFrom(
                        backgroundColor: const Color(0xFFF1F5F9),
                        foregroundColor: AppColors.primaryNavy,
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.all(5),
                      ),
                      tooltip: lang.tr(en: 'Adjust Stock', hi: 'स्टॉक सुधार'),
                      onPressed: () => _showStockAdjustmentDialog(item),
                    ),
                    const SizedBox(width: 4),
                    // Edit Item Icon
                    IconButton.filledTonal(
                      icon: const Icon(Icons.edit_rounded, size: 14),
                      style: IconButton.styleFrom(
                        backgroundColor: const Color(0xFFEFF6FF),
                        foregroundColor: const Color(0xFF2563EB),
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.all(5),
                      ),
                      tooltip: lang.tr(en: 'Edit Design', hi: 'एडिट करें'),
                      onPressed: () async {
                        final res = await Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => AddEditItemScreen(item: item)),
                        );
                        if (res == true) _loadData();
                      },
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // TAB 2: Showroom Lookbook & Catalog
  Widget _buildCatalogShowroomTab(LanguageProvider lang) {
    final catalogList = _catalogItems;

    return Column(
      children: [
        // Category Filter Chips
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: SingleChildScrollView(
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
                    backgroundColor: const Color(0xFFF1F5F9),
                    showCheckmark: false,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => _selectedCategory = cat);
                      }
                    },
                  ),
                );
              }).toList(),
            ),
          ),
        ),

        // Grid of Lace Photos & Cards
        Expanded(
          child: catalogList.isEmpty
              ? EmptyState(
                  icon: Icons.photo_library_outlined,
                  title: lang.isHindi ? 'कोई डिज़ाइन नहीं मिला' : 'No Designs Found',
                  message: lang.isHindi
                      ? 'इस श्रेणी में कोई लेस डिज़ाइन उपलब्ध नहीं है।'
                      : 'No lace designs available in this category.',
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 0.82,
                  ),
                  itemCount: catalogList.length,
                  itemBuilder: (context, idx) {
                    final item = catalogList[idx];
                    return _buildCatalogCard(item, lang);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildCatalogCard(InventoryItem item, LanguageProvider lang) {
    return Card(
      elevation: 0.8,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.borderLight),
      ),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image Box
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                item.imagePath != null && item.imagePath!.isNotEmpty
                    ? Image.file(
                        File(item.imagePath!),
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: const Color(0xFFF1F5F9),
                          child: const Icon(Icons.image_outlined, size: 36, color: AppColors.textMuted),
                        ),
                      )
                    : Container(
                        color: const Color(0xFFF1F5F9),
                        child: const Icon(Icons.style_rounded, size: 36, color: AppColors.textMuted),
                      ),
                // Design Code Badge
                Positioned(
                  top: 6,
                  left: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.75),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      item.designCode,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: AppColors.goldLight,
                      ),
                    ),
                  ),
                ),
                // Stock Badge
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: item.isLowStock
                          ? AppColors.payableRed.withValues(alpha: 0.9)
                          : const Color(0xFF15803D).withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${item.currentStock.toStringAsFixed(0)} ${item.unit}',
                      style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Details Box
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.itemName,
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      CurrencyFormatter.format(item.saleRateRupees),
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Color(0xFF15803D)),
                    ),
                    // WhatsApp share lace item
                    InkWell(
                      onTap: () {
                        ShareHelper.shareText(
                          '🧵 *DM LACE SURAT • Design Lookbook*\n'
                          '📍 Surat Textile Market\n'
                          '━━━━━━━━━━━━━━━━━━━━\n'
                          '🎨 *Design:* ${item.designCode} (${item.itemName})\n'
                          '💰 *Rate:* ${CurrencyFormatter.format(item.saleRateRupees)} per ${item.unit}\n'
                          '🏷️ *Category:* ${item.category ?? "Fancy Lace"}\n'
                          '━━━━━━━━━━━━━━━━━━━━\n'
                          '📲 DM LACE SURAT',
                          subject: 'Lace Design ${item.designCode}',
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(Icons.share_rounded, size: 13, color: Color(0xFF15803D)),
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
  }
}
