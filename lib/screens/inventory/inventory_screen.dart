import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/localization/language_provider.dart';
import '../../core/utils/currency_formatter.dart';
import '../../models/inventory_item.dart';
import '../../repositories/inventory_repository.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/compact_fab.dart';
import 'add_edit_item_screen.dart';

class InventoryScreen extends StatefulWidget {
  final InventoryRepository? repository;

  const InventoryScreen({super.key, this.repository});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  late InventoryRepository _repo;
  List<InventoryItem> _items = [];
  bool _isLoading = true;
  bool _onlyLowStock = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? InventoryRepository();
    _loadItems();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadItems() async {
    setState(() => _isLoading = true);
    final list = await _repo.getItems(
      searchQuery: _searchQuery,
      onlyLowStock: _onlyLowStock,
    );
    if (mounted) {
      setState(() {
        _items = list;
        _isLoading = false;
      });
    }
  }

  Future<void> _showStockAdjustmentDialog(InventoryItem item) async {
    final qtyController = TextEditingController(text: item.currentStock.toStringAsFixed(1));
    final reasonController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Adjust Stock: ${item.designCode}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(item.itemName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 12),
            TextField(
              controller: qtyController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Correct Stock (${item.unit})',
                isDense: true,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason for Adjustment',
                hintText: 'e.g. Physical stock count check, damaged roll',
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryNavy),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Save Adjustment'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final newQty = double.tryParse(qtyController.text) ?? item.currentStock;
      await _repo.adjustStock(
        itemId: item.id!,
        adjustedQty: newQty,
        reason: reasonController.text.trim().isEmpty ? 'Manual Stock Count' : reasonController.text.trim(),
      );
      _loadItems();
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: Text(lang.tr(en: 'Lace Inventory', hi: 'स्टॉक इन्वेंटरी')),
        actions: [
          IconButton(
            icon: Icon(
              _onlyLowStock ? Icons.warning : Icons.warning_amber_outlined,
              color: _onlyLowStock ? AppColors.warningOrange : AppColors.goldLight,
            ),
            tooltip: lang.tr(en: 'Filter Low Stock', hi: 'कम स्टॉक देखें'),
            onPressed: () {
              setState(() => _onlyLowStock = !_onlyLowStock);
              _loadItems();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            color: AppColors.surfaceWhite,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search lace design code or name...',
                prefixIcon: const Icon(Icons.search, size: 20),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                          _loadItems();
                        },
                      )
                    : null,
              ),
              onChanged: (val) {
                setState(() => _searchQuery = val);
                _loadItems();
              },
            ),
          ),

          // Inventory List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primaryGold))
                : _items.isEmpty
                    ? EmptyState(
                        icon: Icons.inventory_2_outlined,
                        title: 'No Inventory Items',
                        message: _searchQuery.isNotEmpty
                            ? 'No lace items matching "$_searchQuery".'
                            : 'Add your lace designs to track roll and meter stock automatically.',
                      )
                    : RefreshIndicator(
                        color: AppColors.primaryGold,
                        onRefresh: _loadItems,
                        child: ListView.separated(
                          padding: const EdgeInsets.all(12),
                          itemCount: _items.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 8),
                          itemBuilder: (context, idx) {
                            final item = _items[idx];
                            return _buildInventoryCard(item);
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: CompactFab(
        heroTag: 'fab_inventory',
        icon: Icons.add_rounded,
        label: lang.tr(en: 'New Design', hi: 'नया डिज़ाइन'),
        onTap: () => _navigateToAddItem(),
      ),
    );
  }

  Widget _buildInventoryCard(InventoryItem item) {
    return Card(
      color: AppColors.surfaceWhite,
      child: InkWell(
        onTap: () => _showStockAdjustmentDialog(item),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primaryNavy.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      item.designCode,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.primaryNavy),
                    ),
                  ),
                  if (item.isLowStock)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFFCA5A5)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.warning_amber_rounded, size: 14, color: AppColors.payableRed),
                          SizedBox(width: 4),
                          Text('LOW STOCK', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.payableRed)),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                item.itemName,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Selling Rate', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                      Text(
                        '${CurrencyFormatter.format(item.sellingRateRupees)} / ${item.unit}',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primaryNavy),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text('Current Stock', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                      Text(
                        '${item.currentStock.toStringAsFixed(1)} ${item.unit}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: item.isLowStock ? AppColors.payableRed : AppColors.successGreen,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _navigateToAddItem() async {
    final res = await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AddEditItemScreen()),
    );
    if (res == true) _loadItems();
  }
}
