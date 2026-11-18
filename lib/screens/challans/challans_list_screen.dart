import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/localization/language_provider.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';
import '../../models/document.dart';
import '../../repositories/document_repository.dart';
import '../../widgets/badge_chip.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/compact_fab.dart';
import '../../widgets/interactive_slip_viewer.dart';
import '../bills/bill_detail_screen.dart';
import 'create_edit_challan_screen.dart';
import 'convert_challan_dialog.dart';

class ChallansListScreen extends StatefulWidget {
  final DocumentRepository? repository;

  const ChallansListScreen({super.key, this.repository});

  @override
  State<ChallansListScreen> createState() => _ChallansListScreenState();
}

class _ChallansListScreenState extends State<ChallansListScreen> {
  late DocumentRepository _repo;
  List<BusinessDocument> _challans = [];
  bool _isLoading = true;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? DocumentRepository();
    _loadChallans();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadChallans() async {
    setState(() => _isLoading = true);
    final list = await _repo.getDocuments(
      docType: 'challan',
      searchQuery: _searchQuery,
    );
    if (mounted) {
      setState(() {
        _challans = list;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: Text(lang.isHindi ? 'डिलीवरी चालान' : 'Delivery Challans'),
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
                hintText: 'Search challan # or customer...',
                prefixIcon: const Icon(Icons.search, size: 20),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                          _loadChallans();
                        },
                      )
                    : null,
              ),
              onChanged: (val) {
                setState(() => _searchQuery = val);
                _loadChallans();
              },
            ),
          ),

          // Challan List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primaryGold))
                : _challans.isEmpty
                    ? EmptyState(
                        icon: Icons.local_shipping_outlined,
                        title: 'No Delivery Challans Found',
                        message: _searchQuery.isNotEmpty
                            ? 'No challans matched "$_searchQuery".'
                            : 'Dispatch lace material with delivery challans for approval before invoicing.',
                      )
                    : RefreshIndicator(
                        color: AppColors.primaryGold,
                        onRefresh: _loadChallans,
                        child: ListView.separated(
                          padding: const EdgeInsets.all(12),
                          itemCount: _challans.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final doc = _challans[index];
                            return _buildChallanCard(doc, lang);
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: CompactFab(
        heroTag: 'fab_challans',
        icon: Icons.add_rounded,
        label: lang.isHindi ? 'नया चालान' : 'New Challan',
        onTap: () => _navigateToCreateChallan(),
      ),
    );
  }

  Widget _buildChallanCard(BusinessDocument doc, LanguageProvider lang) {
    final isConverted = doc.notes != null && doc.notes!.contains('Converted to');
    final hasSlipPhoto = doc.hasImage || (doc.imageBase64 != null && doc.imageBase64!.isNotEmpty);

    return Card(
      color: AppColors.surfaceWhite,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => BillDetailScreen(documentId: doc.id!)),
          );
          _loadChallans();
        },
        child: Padding(
          padding: const EdgeInsets.all(14.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(
                        doc.docNumber,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppColors.secondaryNavy,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const BadgeChip(label: 'CHALLAN', type: BadgeType.challan),
                      if (hasSlipPhoto) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFFCD34D)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.photo_camera_rounded, size: 11, color: Color(0xFFB45309)),
                              const SizedBox(width: 3),
                              Text(
                                lang.tr(en: 'With Photo', hi: 'फोटो सहित'),
                                style: const TextStyle(color: Color(0xFF92400E), fontSize: 10, fontWeight: FontWeight.w800),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                  BadgeChip(
                    label: isConverted ? 'CONVERTED TO BILL' : 'DISPATCHED',
                    type: isConverted ? BadgeType.paid : BadgeType.partial,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Photo thumbnail if attached
                  if (hasSlipPhoto) ...[
                    GestureDetector(
                      onTap: () => InteractiveSlipViewer.show(
                        context,
                        imagePath: doc.imagePath,
                        imageBase64: doc.imageBase64,
                        title: '${doc.docNumber} • ${doc.partyName ?? ""}',
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          width: 52,
                          height: 52,
                          color: const Color(0xFFF1F5F9),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              if (doc.imagePath != null && File(doc.imagePath!).existsSync())
                                Image.file(File(doc.imagePath!), fit: BoxFit.cover)
                              else if (doc.imagePath != null && doc.imagePath!.startsWith('assets/'))
                                Image.asset(doc.imagePath!, fit: BoxFit.cover)
                              else if (doc.imageBase64 != null && doc.imageBase64!.isNotEmpty)
                                Image.memory(base64Decode(doc.imageBase64!), fit: BoxFit.cover)
                              else
                                const Icon(Icons.receipt_rounded, color: Color(0xFF94A3B8)),
                              Positioned(
                                bottom: 2,
                                right: 2,
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: BoxDecoration(
                                    color: Colors.black87,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Icon(Icons.zoom_in, size: 10, color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          doc.partyName ?? 'Party #${doc.partyId}',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Dispatch Date: ${DateFormatter.format(DateFormatter.parse(doc.docDate))}',
                          style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    CurrencyFormatter.format(doc.grandTotalRupees),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.primaryNavy),
                  ),
                ],
              ),
              const Divider(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF0F172A),
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: const Icon(Icons.visibility_outlined, size: 15, color: Color(0xFF0284C7)),
                    label: Text(lang.isHindi ? 'विवरण' : 'Details', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF0284C7))),
                    onPressed: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => BillDetailScreen(documentId: doc.id!)),
                      );
                      _loadChallans();
                    },
                  ),
                  if (!isConverted)
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primaryNavy,
                        side: const BorderSide(color: AppColors.primaryNavy),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      ),
                      icon: const Icon(Icons.receipt_long, size: 15),
                      label: Text(lang.isHindi ? 'बिल बनाएं' : 'Convert to Bill', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
                      onPressed: () async {
                        final newBillId = await ConvertChallanDialog.show(
                          context: context,
                          challan: doc,
                          repository: _repo,
                        );
                        if (newBillId != null) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Challan successfully converted to Bill and ledger updated!')),
                            );
                          }
                          _loadChallans();
                        }
                      },
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _navigateToCreateChallan() async {
    final res = await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const CreateEditChallanScreen()),
    );
    if (res == true) {
      _loadChallans();
    }
  }
}
