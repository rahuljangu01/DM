import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/localization/language_provider.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';
import '../../core/utils/share_helper.dart';
import '../../models/document.dart';
import '../../repositories/document_repository.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/compact_fab.dart';
import '../../widgets/interactive_slip_viewer.dart';
import '../transactions/payment_entry_screen.dart';
import 'create_edit_bill_screen.dart';
import 'bill_detail_screen.dart';
import 'quick_slip_bill_screen.dart';

class BillsListScreen extends StatefulWidget {
  final DocumentRepository? repository;

  const BillsListScreen({super.key, this.repository});

  @override
  State<BillsListScreen> createState() => _BillsListScreenState();
}

class _BillsListScreenState extends State<BillsListScreen> with SingleTickerProviderStateMixin {
  late DocumentRepository _repo;
  late TabController _tabController;
  List<BusinessDocument> _documents = [];
  bool _isLoading = true;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  // Metrics for Sales & Purchase Dashboard
  double _totalSalesRupees = 0.0;
  double _totalPurchaseRupees = 0.0;
  double _unpaidBalanceRupees = 0.0;
  int _allCount = 0;
  int _outwardCount = 0;
  int _inwardCount = 0;
  int _unpaidCount = 0;

  // 4 Simple & Clear Tabs: All, Outward (Sales), Inward (Purchases), Unpaid
  final List<String> _types = ['all', 'outward', 'inward', 'unpaid'];

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? DocumentRepository();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        _loadDocuments();
      }
    });
    _loadDocuments();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadDocuments() async {
    setState(() => _isLoading = true);
    final selectedType = _types[_tabController.index];

    final allDocs = await _repo.getDocuments(docType: 'all');
    double totalSales = 0.0;
    double totalPurchase = 0.0;
    double unpaidBal = 0.0;
    int outward = 0;
    int inward = 0;
    int unpaid = 0;

    for (final d in allDocs) {
      if (d.tradeType == 'purchase' || d.docType == 'purchase_bill') {
        inward++;
        totalPurchase += d.grandTotalRupees;
      } else {
        outward++;
        totalSales += d.grandTotalRupees;
      }
      if (d.remainingBalancePaise > 0) {
        unpaid++;
        unpaidBal += d.remainingBalanceRupees;
      }
    }

    // Filter documents for current tab view
    List<BusinessDocument> filtered;
    if (selectedType == 'unpaid') {
      filtered = allDocs.where((d) => d.remainingBalancePaise > 0).toList();
    } else if (selectedType == 'outward') {
      filtered = allDocs.where((d) => d.tradeType != 'purchase' && d.docType != 'purchase_bill').toList();
    } else if (selectedType == 'inward') {
      filtered = allDocs.where((d) => d.tradeType == 'purchase' || d.docType == 'purchase_bill').toList();
    } else {
      filtered = allDocs;
    }

    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      filtered = filtered.where((d) {
        final matchDocNum = d.docNumber.toLowerCase().contains(q);
        final matchParty = d.partyName != null && d.partyName!.toLowerCase().contains(q);
        final matchNotes = d.notes != null && d.notes!.toLowerCase().contains(q);
        final matchAmt = d.grandTotalRupees.toString().contains(q);
        return matchDocNum || matchParty || matchNotes || matchAmt;
      }).toList();
    }

    if (mounted) {
      setState(() {
        _documents = filtered;
        _totalSalesRupees = totalSales;
        _totalPurchaseRupees = totalPurchase;
        _unpaidBalanceRupees = unpaidBal;
        _allCount = allDocs.length;
        _outwardCount = outward;
        _inwardCount = inward;
        _unpaidCount = unpaid;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        title: Text(
          lang.isHindi ? 'बिल व चालान' : 'Bills & Challans',
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
        ),
        actions: [
          IconButton(
            tooltip: lang.isHindi ? 'फास्ट पर्ची फोटो' : 'Quick Slip Camera',
            icon: const Icon(Icons.camera_alt_rounded, color: AppColors.primaryGold),
            onPressed: () => _navigateToQuickSlip(),
          ),
          IconButton(
            tooltip: lang.isHindi ? 'रिफ्रेश' : 'Refresh',
            icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
            onPressed: _loadDocuments,
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            children: [
              // 1. Simple 3-Card KPI Header (माल दिया, माल आया, कुल बाकी)
              _buildSalesDashboardHeader(lang),

              // 2. Tactile Segmented Filter Pills
              _buildSegmentedFilterPills(lang),

              // 3. Clean Search Bar
              Container(
                color: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: lang.isHindi
                        ? 'पार्टी का नाम या चालान नंबर खोजें...'
                        : 'Search party name or slip #...',
                    prefixIcon: const Icon(Icons.search, size: 20, color: Color(0xFF64748B)),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.primaryNavy)),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                              _loadDocuments();
                            },
                          )
                        : null,
                  ),
                  onChanged: (val) {
                    setState(() => _searchQuery = val);
                    _loadDocuments();
                  },
                ),
              ),

              // 4. Documents List
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(color: AppColors.primaryGold))
                    : _documents.isEmpty
                        ? EmptyState(
                            icon: Icons.receipt_long_rounded,
                            title: lang.isHindi ? 'कोई चालान या बिल नहीं मिला' : 'No Records Found',
                            message: _searchQuery.isNotEmpty
                                ? (lang.isHindi
                                    ? '"$_searchQuery" से मिलता कोई चालान नहीं मिला।'
                                    : 'No documents matching "$_searchQuery".')
                                : (lang.isHindi
                                    ? 'कागज़ की पर्ची की फोटो खींचें या नया बिल बनाएं।'
                                    : 'Capture a slip photo or create a new bill.'),
                          )
                        : RefreshIndicator(
                            color: AppColors.primaryGold,
                            onRefresh: _loadDocuments,
                            child: ListView.separated(
                              padding: const EdgeInsets.all(12),
                              itemCount: _documents.length,
                              separatorBuilder: (context, index) => const SizedBox(height: 8),
                              itemBuilder: (context, index) {
                                final doc = _documents[index];
                                return _buildDocumentCard(doc, lang);
                              },
                            ),
                          ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: CompactFab(
        heroTag: 'fab_bills',
        icon: Icons.add_rounded,
        label: lang.isHindi ? 'नया चालान / बिल' : 'New Bill / Slip',
        onTap: () => _showCreateDocumentSheet(lang),
      ),
    );
  }

  void _showCreateDocumentSheet(LanguageProvider lang) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text(
                lang.isHindi ? 'नया चालान या बिल' : 'New Bill or Challan',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.primaryNavy),
              ),
              const SizedBox(height: 14),

              // Option 1: Fast Photo Slip
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFFEF3C7),
                    child: Icon(Icons.camera_alt_rounded, color: Color(0xFFB45309)),
                  ),
                  title: Text(
                    lang.isHindi ? 'पर्ची फोटो चालान' : 'Photo Slip Challan',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: Text(
                    lang.isHindi ? 'कागज़ की पर्ची की फोटो से तुरंत बनाएं' : 'Quick entry from slip photo',
                    style: const TextStyle(fontSize: 11.5),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                  onTap: () {
                    Navigator.pop(ctx);
                    _navigateToQuickSlip();
                  },
                ),
              ),

              const SizedBox(height: 10),

              // Option 2: Detailed Bill
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFE0F2FE),
                    child: Icon(Icons.receipt_long_rounded, color: Color(0xFF0369A1)),
                  ),
                  title: Text(
                    lang.isHindi ? 'नया कच्चा बिल' : 'Detailed Bill',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: Text(
                    lang.isHindi ? 'आइटम व दर अनुसार बिल बनाएं' : 'Item-wise bill entry',
                    style: const TextStyle(fontSize: 11.5),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                  onTap: () {
                    Navigator.pop(ctx);
                    _navigateToCreateBill();
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 1. Simple 3-Metric KPI Header (बिक्री, खरीद, बाकी)
  Widget _buildSalesDashboardHeader(LanguageProvider lang) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.primaryNavy,
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      child: Row(
        children: [
          Expanded(
            child: _buildMetricTile(
              title: lang.isHindi ? 'बिक्री' : 'Sales',
              value: CurrencyFormatter.format(_totalSalesRupees),
              badge: '$_outwardCount',
              icon: Icons.trending_up_rounded,
              color: AppColors.primaryGold,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _buildMetricTile(
              title: lang.isHindi ? 'खरीद' : 'Purchases',
              value: CurrencyFormatter.format(_totalPurchaseRupees),
              badge: '$_inwardCount',
              icon: Icons.inventory_2_rounded,
              color: const Color(0xFF38BDF8),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _buildMetricTile(
              title: lang.isHindi ? 'कुल बाकी' : 'Total Dues',
              value: CurrencyFormatter.format(_unpaidBalanceRupees),
              badge: '$_unpaidCount',
              icon: Icons.pending_actions_rounded,
              color: const Color(0xFFFCA5A5),
            ),
          ),
        ],
      ),
    );
  }

  /// 2. Tactile Segmented Filter Pills
  Widget _buildSegmentedFilterPills(LanguageProvider lang) {
    final tabs = [
      {'label': lang.isHindi ? 'सभी' : 'All', 'count': _allCount, 'color': AppColors.primaryGold},
      {'label': lang.isHindi ? 'बिक्री' : 'Sales', 'count': _outwardCount, 'color': const Color(0xFF4ADE80)},
      {'label': lang.isHindi ? 'खरीद' : 'Purchases', 'count': _inwardCount, 'color': const Color(0xFF38BDF8)},
      {'label': lang.isHindi ? 'बाकी' : 'Dues', 'count': _unpaidCount, 'color': const Color(0xFFF87171)},
    ];

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        padding: const EdgeInsets.all(4),
        child: Row(
          children: List.generate(tabs.length, (idx) {
            final isSelected = _tabController.index == idx;
            final item = tabs[idx];
            return Expanded(
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  setState(() => _tabController.index = idx);
                  _loadDocuments();
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    gradient: isSelected
                        ? const LinearGradient(
                            colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                          )
                        : null,
                    color: isSelected ? null : Colors.transparent,
                    borderRadius: BorderRadius.circular(9),
                    border: isSelected
                        ? Border.all(color: (item['color'] as Color).withValues(alpha: 0.8), width: 1.2)
                        : null,
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.15),
                              blurRadius: 5,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          '${item['label']}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                            color: isSelected ? (item['color'] as Color) : const Color(0xFF64748B),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? (item['color'] as Color).withValues(alpha: 0.25)
                              : const Color(0xFFE2E8F0),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${item['count']}',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            color: isSelected ? (item['color'] as Color) : const Color(0xFF475569),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildMetricTile({
    required String title,
    required String value,
    required String badge,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 9.5,
                    color: Colors.white.withValues(alpha: 0.8),
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentCard(BusinessDocument doc, LanguageProvider lang) {
    final isChallan = doc.docType == 'challan';
    final isPurchase = doc.isPurchase;
    final hasSlipPhoto = doc.hasImage || (doc.imageBase64 != null && doc.imageBase64!.isNotEmpty);

    return Card(
      elevation: 0.8,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      color: Colors.white,
      child: InkWell(
        onTap: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => BillDetailScreen(documentId: doc.id!)),
          );
          _loadDocuments();
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Row: Party Name on Left, Amount on Right (PhonePe style)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Photo thumbnail or directional icon
                  if (hasSlipPhoto)
                    GestureDetector(
                      onTap: () => InteractiveSlipViewer.show(
                        context,
                        imagePath: doc.imagePath,
                        imageBase64: doc.imageBase64,
                        title: '${doc.docNumber} • ${doc.partyName ?? ""}',
                      ),
                      child: Container(
                        width: 44,
                        height: 44,
                        margin: const EdgeInsets.only(right: 10),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFD4AF37), width: 1),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(7),
                          child: Stack(
                            alignment: Alignment.bottomRight,
                            children: [
                              if (doc.imagePath != null && File(doc.imagePath!).existsSync())
                                Image.file(File(doc.imagePath!), width: 44, height: 44, fit: BoxFit.cover)
                              else if (doc.imageBase64 != null && doc.imageBase64!.isNotEmpty)
                                Image.memory(base64Decode(doc.imageBase64!), width: 44, height: 44, fit: BoxFit.cover)
                              else
                                const Center(child: Icon(Icons.receipt_rounded, size: 20, color: Color(0xFF94A3B8))),
                              Container(
                                padding: const EdgeInsets.all(2),
                                color: Colors.black54,
                                child: const Icon(Icons.zoom_in_rounded, size: 9, color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  else
                    Container(
                      width: 40,
                      height: 40,
                      margin: const EdgeInsets.only(right: 10),
                      decoration: BoxDecoration(
                        color: (isPurchase ? const Color(0xFF0284C7) : (isChallan ? const Color(0xFFD97706) : AppColors.primaryNavy)).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        isPurchase
                            ? Icons.arrow_downward_rounded
                            : (isChallan ? Icons.local_shipping_rounded : Icons.receipt_long_rounded),
                        size: 20,
                        color: isPurchase
                            ? const Color(0xFF0284C7)
                            : (isChallan ? const Color(0xFFD97706) : AppColors.primaryNavy),
                      ),
                    ),
                  // Party Name & Doc Details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          doc.partyName ?? 'Party #${doc.partyId}',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Text(
                              doc.docNumber,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                            ),
                            const Text(' • ', style: TextStyle(color: Color(0xFF94A3B8))),
                            Text(
                              DateFormatter.format(DateFormatter.parse(doc.docDate)),
                              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Amount & Status (Right side)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        CurrencyFormatter.format(doc.grandTotalRupees),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 3),
                      if (doc.isCancelled)
                        Text(
                          lang.isHindi ? 'रद्द' : 'Cancelled',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.red),
                        )
                      else if (doc.remainingBalancePaise > 0)
                        Text(
                          lang.isHindi
                              ? 'बाकी: ${CurrencyFormatter.format(doc.remainingBalanceRupees)}'
                              : 'Due: ${CurrencyFormatter.format(doc.remainingBalanceRupees)}',
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFDC2626),
                          ),
                        )
                      else
                        Text(
                          lang.isHindi ? 'चुकता' : 'Paid',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF16A34A),
                          ),
                        ),
                    ],
                  ),
                ],
              ),

              // Bottom Clean Action Row (WhatsApp Share & Collect/Pay)
              const SizedBox(height: 8),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isPurchase ? const Color(0xFFE0F2FE) : const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          isPurchase
                              ? (lang.isHindi ? 'खरीद' : 'Inward')
                              : (isChallan ? (lang.isHindi ? 'चालान' : 'Challan') : (lang.isHindi ? 'बिक्री' : 'Sale')),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: isPurchase ? const Color(0xFF0369A1) : const Color(0xFF15803D),
                          ),
                        ),
                      ),
                      if (hasSlipPhoto) ...[
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: () => InteractiveSlipViewer.show(
                            context,
                            imagePath: doc.imagePath,
                            imageBase64: doc.imageBase64,
                            title: '${doc.docNumber} • ${doc.partyName ?? ""}',
                          ),
                          child: Text(
                            lang.isHindi ? 'पर्ची देखें' : 'View Slip',
                            style: const TextStyle(fontSize: 11, color: Color(0xFF0284C7), fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ],
                  ),
                  Row(
                    children: [
                      InkWell(
                        onTap: () => _shareDoc(doc, lang),
                        borderRadius: BorderRadius.circular(6),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          child: Row(
                            children: [
                              const Icon(Icons.share_rounded, size: 13, color: Color(0xFF16A34A)),
                              const SizedBox(width: 4),
                              Text(
                                lang.isHindi ? 'शेयर' : 'Share',
                                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF16A34A)),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (doc.remainingBalancePaise > 0 && !doc.isCancelled) ...[
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: () async {
                            await Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => PaymentEntryScreen(
                                  initialPartyId: doc.partyId,
                                  initialRelatedDocId: doc.id,
                                  initialTxType: isPurchase ? 'supplier_payment' : 'customer_receipt',
                                  initialAmountRupees: doc.remainingBalanceRupees,
                                ),
                              ),
                            );
                            _loadDocuments();
                          },
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFFBFDBFE)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.payment_rounded, size: 12, color: Color(0xFF2563EB)),
                                const SizedBox(width: 4),
                                Text(
                                  isPurchase
                                      ? (lang.isHindi ? 'भुगतान दें' : 'Pay')
                                      : (lang.isHindi ? 'पेमेंट लें' : 'Collect'),
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF2563EB)),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
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

  void _shareDoc(BusinessDocument doc, LanguageProvider lang) {
    final textSummary = lang.isHindi
        ? '*DM LACE SURAT*\n'
            '----------------------------------------\n'
            'बिल / चालान: ${doc.docNumber}\n'
            'तारीख: ${DateFormatter.format(DateFormatter.parse(doc.docDate))}\n'
            'पार्टी: ${doc.partyName ?? "ग्राहक"}\n'
            '----------------------------------------\n'
            'कुल रकम: ${CurrencyFormatter.format(doc.grandTotalRupees)}\n'
            'जमा: ${CurrencyFormatter.format(doc.paidAmountRupees)}\n'
            'बाकी: ${CurrencyFormatter.format(doc.remainingBalanceRupees)}\n'
            '----------------------------------------\n'
            'धन्यवाद! • DM Lace Surat'
        : '*DM LACE SURAT*\n'
            '----------------------------------------\n'
            'Bill / Challan: ${doc.docNumber}\n'
            'Date: ${DateFormatter.format(DateFormatter.parse(doc.docDate))}\n'
            'Party: ${doc.partyName ?? "Customer"}\n'
            '----------------------------------------\n'
            'Total: ${CurrencyFormatter.format(doc.grandTotalRupees)}\n'
            'Paid: ${CurrencyFormatter.format(doc.paidAmountRupees)}\n'
            'Balance: ${CurrencyFormatter.format(doc.remainingBalanceRupees)}\n'
            '----------------------------------------\n'
            'Thank You! • DM Lace Surat';
    ShareHelper.shareText(textSummary, subject: 'Bill ${doc.docNumber}');
  }

  Future<void> _navigateToQuickSlip() async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const QuickSlipBillScreen()),
    );
    if (result == true) {
      _loadDocuments();
    }
  }

  Future<void> _navigateToCreateBill() async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const CreateEditBillScreen()),
    );
    if (result == true) {
      _loadDocuments();
    }
  }
}
