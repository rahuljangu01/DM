import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/database/database_helper.dart';
import '../../core/database/database_tables.dart';
import '../../core/localization/language_provider.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';
import '../../core/utils/share_helper.dart';
import '../../models/document.dart';
import '../../repositories/document_repository.dart';
import '../../services/cloudinary_service.dart';
import '../../services/firebase_sync_service.dart';
import '../../services/pdf_service.dart';
import '../../widgets/confirmation_dialog.dart';
import '../../widgets/interactive_slip_viewer.dart';
import '../../widgets/upi_qr_dialog.dart';
import '../transactions/payment_entry_screen.dart';

class BillDetailScreen extends StatefulWidget {
  final int documentId;
  final DocumentRepository? repository;

  const BillDetailScreen({super.key, required this.documentId, this.repository});

  @override
  State<BillDetailScreen> createState() => _BillDetailScreenState();
}

class _BillDetailScreenState extends State<BillDetailScreen> {
  late DocumentRepository _repo;
  BusinessDocument? _doc;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? DocumentRepository();
    _loadDoc();
  }

  Future<void> _loadDoc() async {
    setState(() => _isLoading = true);
    final doc = await _repo.getDocumentById(widget.documentId);
    if (mounted) {
      setState(() {
        _doc = doc;
        _isLoading = false;
      });
    }
  }

  String _getValuableBillText(LanguageProvider lang) {
    if (_doc == null) return '';
    final date = DateFormatter.format(DateFormatter.parse(_doc!.docDate));
    final party = _doc!.partyName ?? (lang.isHindi ? "ग्राहक" : "Customer");
    final buffer = StringBuffer();
    final headerType = _doc!.isChallan
        ? (lang.isHindi ? "डिलीवरी चालान" : "Delivery Challan")
        : (lang.isHindi ? "बिल पर्ची" : "Invoice Bill");

    buffer.writeln('*DM LACE SURAT*');
    buffer.writeln(lang.isHindi ? 'सूरत टेक्सटाइल मार्केट' : 'Surat Textile Market');
    buffer.writeln('----------------------------------------');
    buffer.writeln(headerType);
    buffer.writeln('${lang.isHindi ? "नंबर:" : "No:"} ${_doc!.docNumber}');
    buffer.writeln('${lang.isHindi ? "तारीख:" : "Date:"} $date');
    buffer.writeln('${lang.isHindi ? "पार्टी:" : "Party:"} $party');
    buffer.writeln('----------------------------------------');
    buffer.writeln(lang.isHindi ? 'माल विवरण:' : 'Items:');
    for (int i = 0; i < _doc!.items.length; i++) {
      final it = _doc!.items[i];
      buffer.writeln('${i + 1}. *${it.itemName}*');
      buffer.writeln('   ${it.quantity} ${it.unit} × ₹${it.rateRupees.toStringAsFixed(2)} = ₹${it.lineTotalRupees.toStringAsFixed(2)}');
    }
    buffer.writeln('----------------------------------------');
    buffer.writeln('${lang.isHindi ? "कुल रकम:" : "Total Amount:"} ${CurrencyFormatter.format(_doc!.grandTotalRupees)}');
    if (_doc!.paidAmountPaise > 0) {
      buffer.writeln('${lang.isHindi ? "जमा रकम:" : "Advance Paid:"} ${CurrencyFormatter.format(_doc!.paidAmountRupees)}');
    }
    if (_doc!.remainingBalancePaise > 0) {
      buffer.writeln('${lang.isHindi ? "बाकी रकम:" : "Balance Due:"} ${CurrencyFormatter.format(_doc!.remainingBalanceRupees)}');
    } else {
      buffer.writeln(lang.isHindi ? 'स्थिति: पूर्ण भुगतान (PAID)' : 'Status: FULLY PAID');
    }
    buffer.writeln('----------------------------------------');
    buffer.writeln(lang.isHindi ? 'धन्यवाद! • DM Lace Surat' : 'Thank You! • DM Lace Surat');
    return buffer.toString();
  }

  void _shareInvoice(LanguageProvider lang) {
    if (_doc == null) return;
    final textSummary = _getValuableBillText(lang);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF25D366).withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.share_rounded, color: Color(0xFF25D366), size: 20),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Share ${_doc!.docNumber}',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.primaryNavy),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Option 1: Share Official PDF Document
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                ),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.picture_as_pdf_rounded, color: Color(0xFF2563EB)),
                ),
                title: const Text(
                  'Share Official PDF Bill (Document)',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
                ),
                subtitle: const Text(
                  'Attaches printable PDF Invoice with market header & caption',
                  style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                ),
                trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.primaryNavy),
                onTap: () {
                  Navigator.pop(ctx);
                  PdfService.shareDocumentPdf(_doc!, text: textSummary);
                },
              ),
              const SizedBox(height: 10),

              // Option 2: Share Quick Clean Text
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                ),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.chat_rounded, color: Color(0xFF16A34A)),
                ),
                title: const Text(
                  'Share Quick Text Bill Summary',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
                ),
                subtitle: const Text(
                  'Clean formatted text message for instant WhatsApp reading',
                  style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                ),
                trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.primaryNavy),
                onTap: () {
                  Navigator.pop(ctx);
                  ShareHelper.shareText(textSummary, subject: 'Bill ${_doc!.docNumber}');
                },
              ),
              if (_doc!.remainingBalanceRupees > 0) ...[
                const SizedBox(height: 10),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: Color(0xFFD4AF37)),
                  ),
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF9C3),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.qr_code_2_rounded, color: Color(0xFFB45309)),
                  ),
                  title: Text(
                    Provider.of<LanguageProvider>(context, listen: false).tr(
                      en: '⚡ Collect Payment (UPI QR)',
                      hi: '⚡ तुरंत पेमेंट लें (UPI QR Code)',
                    ),
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
                  ),
                  subtitle: Text(
                    Provider.of<LanguageProvider>(context, listen: false).tr(
                      en: 'Instant payment via GPay • PhonePe • Paytm QR',
                      hi: 'GPay • PhonePe • Paytm QR कोड से तुरंत भुगतान',
                    ),
                    style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.primaryNavy),
                  onTap: () {
                    Navigator.pop(ctx);
                    UpiQrDialog.show(
                      context,
                      partyName: _doc!.partyName ?? 'Customer',
                      amountRupees: _doc!.remainingBalanceRupees,
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _attachPhoto(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: source, imageQuality: 70, maxWidth: 1080);
      if (picked == null) return;
      final appDir = await getApplicationDocumentsDirectory();
      final slipsDir = Directory('${appDir.path}/slips');
      if (!slipsDir.existsSync()) {
        slipsDir.createSync(recursive: true);
      }
      final fileName = 'slip_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final saved = await File(picked.path).copy('${slipsDir.path}/$fileName');
      final bytes = await saved.readAsBytes();
      final b64 = base64Encode(bytes);

      // Cloudinary cloud upload (direct HTTPS link for Firebase)
      String? uploadedUrl;
      try {
        final res = await CloudinaryService().uploadImageFile(saved, tag: 'bill_slip');
        if (res.success && res.url != null) {
          uploadedUrl = res.url;
        }
      } catch (_) {}

      final db = await DatabaseHelper.instance.database;
      final updateData = <String, dynamic>{
        'image_path': saved.path,
        'image_base64': b64,
      };
      if (uploadedUrl != null && uploadedUrl.isNotEmpty) {
        updateData['image_url'] = uploadedUrl;
      }
      await db.update(
        DatabaseTables.tableDocuments,
        updateData,
        where: 'id = ?',
        whereArgs: [_doc!.id],
      );

      // Instant push to Firebase Cloud Database so it's always safely backed up
      try {
        final syncService = FirebaseSyncService();
        final cloudMap = Map<String, dynamic>.from(_doc!.toMap());
        cloudMap['id'] = _doc!.id;
        cloudMap['image_path'] = saved.path;
        cloudMap['image_base64'] = b64;
        if (uploadedUrl != null && uploadedUrl.isNotEmpty) {
          cloudMap['image_url'] = uploadedUrl;
        }
        cloudMap['items_json'] = jsonEncode(_doc!.items.map((i) => i.toMap()).toList());

        await syncService.pushSingleRecord(
          collection: 'bills',
          id: _doc!.id.toString(),
          data: cloudMap,
        );
        if (_doc!.isChallan) {
          await syncService.pushSingleRecord(
            collection: 'challans',
            id: _doc!.id.toString(),
            data: cloudMap,
          );
        }
      } catch (_) {}

      _loadDoc();
      if (mounted) {
        final lang = Provider.of<LanguageProvider>(context, listen: false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(lang.tr(
              en: '✅ Slip photo saved and synced to cloud!',
              hi: '✅ चालान फोटो सुरक्षित हो गई और क्लाउड डेटाबेस में भी अपलोड हो गई!',
            )),
            backgroundColor: const Color(0xFF0F172A),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final lang = Provider.of<LanguageProvider>(context, listen: false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(lang.tr(
              en: 'Error attaching photo: $e',
              hi: 'फोटो जोड़ने में त्रुटि: $e',
            )),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showAttachPhotoSheet() {
    final lang = Provider.of<LanguageProvider>(context, listen: false);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                lang.tr(en: 'Attach Bill / Challan Photo', hi: 'पर्ची / चालान की फोटो जोड़ें'),
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
              const SizedBox(height: 14),
              ListTile(
                leading: const Icon(Icons.camera_alt_rounded, color: AppColors.primaryNavy),
                title: Text(
                  lang.tr(en: 'Take Photo (Camera)', hi: 'कैमरा से फोटो खींचें'),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _attachPhoto(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_rounded, color: AppColors.primaryGold),
                title: Text(
                  lang.tr(en: 'Choose from Gallery', hi: 'गैलरी से चुनें'),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _attachPhoto(ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _cancelBill() async {
    final confirm = await ConfirmationDialog.show(
      context: context,
      title: 'Cancel Document',
      message: 'Are you sure you want to cancel ${_doc!.docNumber}? This will reverse balances and inventory stock movements.',
      confirmText: 'Cancel Bill',
      isDestructive: true,
    );

    if (confirm == true) {
      await _repo.cancelDocument(widget.documentId, 'Cancelled by user from app');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Document cancelled successfully')),
        );
        _loadDoc();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text(lang.tr(en: 'Document Details', hi: 'दस्तावेज़ विवरण'))),
        body: const Center(child: CircularProgressIndicator(color: AppColors.primaryGold)),
      );
    }

    if (_doc == null) {
      return Scaffold(
        appBar: AppBar(title: Text(lang.tr(en: 'Document Details', hi: 'दस्तावेज़ विवरण'))),
        body: Center(child: Text(lang.tr(en: 'Document not found', hi: 'दस्तावेज़ नहीं मिला'))),
      );
    }

    final isPaid = _doc!.remainingBalancePaise == 0;

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: Text(_doc!.docNumber),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined, color: AppColors.goldLight),
            onPressed: () => _shareInvoice(lang),
            tooltip: lang.tr(en: 'Share Bill', hi: 'बिल शेयर करें'),
          ),
          if (!_doc!.isCancelled)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: AppColors.goldLight),
              onSelected: (val) {
                if (val == 'cancel') _cancelBill();
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'cancel',
                  child: Row(
                    children: [
                      const Icon(Icons.cancel_outlined, color: AppColors.payableRed, size: 18),
                      const SizedBox(width: 8),
                      Text(lang.tr(en: 'Cancel Bill', hi: 'बिल रद्द करें'), style: const TextStyle(color: AppColors.payableRed)),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          // Cancelled Banner if cancelled
          if (_doc!.isCancelled) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.payableRed.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.payableRed),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning, color: AppColors.payableRed),
                  SizedBox(width: 8),
                  Text('DOCUMENT CANCELLED', style: TextStyle(color: AppColors.payableRed, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // PhonePe Receipt Hero Card
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                // Icon (Paid = Green check, Due = Amber clock)
                CircleAvatar(
                  radius: 22,
                  backgroundColor: isPaid ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
                  child: Icon(
                    isPaid ? Icons.check_circle_rounded : Icons.pending_rounded,
                    color: isPaid ? const Color(0xFF16A34A) : const Color(0xFFD97706),
                    size: 26,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _doc!.partyName ?? 'Party #${_doc!.partyId}',
                  style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  CurrencyFormatter.format(_doc!.grandTotalRupees),
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                ),
                const SizedBox(height: 6),
                // Status Pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: _doc!.isCancelled
                        ? Colors.red.shade50
                        : (isPaid ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2)),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _doc!.isCancelled
                        ? (lang.isHindi ? 'रद्द' : 'Cancelled')
                        : (isPaid
                            ? (lang.isHindi ? 'पूर्ण भुगतान (चुकता)' : 'Fully Paid')
                            : (lang.isHindi
                                ? 'बाकी: ${CurrencyFormatter.format(_doc!.remainingBalanceRupees)}'
                                : 'Due: ${CurrencyFormatter.format(_doc!.remainingBalanceRupees)}')),
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: _doc!.isCancelled
                          ? Colors.red
                          : (isPaid ? const Color(0xFF15803D) : const Color(0xFFDC2626)),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                const SizedBox(height: 12),
                // Key metadata in PhonePe receipt style
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(lang.isHindi ? 'बिल नंबर' : 'Bill No', style: const TextStyle(color: Color(0xFF64748B), fontSize: 12.5)),
                    Text(_doc!.docNumber, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(lang.isHindi ? 'तारीख' : 'Date', style: const TextStyle(color: Color(0xFF64748B), fontSize: 12.5)),
                    Text(DateFormatter.format(DateFormatter.parse(_doc!.docDate)), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(lang.isHindi ? 'प्रकार' : 'Type', style: const TextStyle(color: Color(0xFF64748B), fontSize: 12.5)),
                    Text(
                      _doc!.isChallan
                          ? (lang.isHindi ? 'डिलीवरी चालान' : 'Delivery Challan')
                          : (_doc!.isPurchase
                              ? (lang.isHindi ? 'खरीद बिल' : 'Purchase Bill')
                              : (lang.isHindi ? 'बिक्री बिल' : 'Sales Bill')),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Attached Paper Slip Photo Section
          if (_doc!.hasImage || (_doc!.imageBase64 != null && _doc!.imageBase64!.isNotEmpty)) ...[
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        lang.isHindi ? 'पर्ची फोटो' : 'Slip Photo',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF0F172A)),
                      ),
                      InkWell(
                        onTap: () => InteractiveSlipViewer.show(
                          context,
                          imagePath: _doc!.imagePath,
                          imageUrl: _doc!.imageUrl,
                          imageBase64: _doc!.imageBase64,
                          title: '${_doc!.docNumber} • ${_doc!.partyName ?? ""}',
                        ),
                        child: Text(
                          lang.isHindi ? 'बड़ा देखें' : 'View Full',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0284C7)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () => InteractiveSlipViewer.show(
                      context,
                      imagePath: _doc!.imagePath,
                      imageUrl: _doc!.imageUrl,
                      imageBase64: _doc!.imageBase64,
                      title: '${_doc!.docNumber} • ${_doc!.partyName ?? ""}',
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          if (_doc!.imagePath != null && File(_doc!.imagePath!).existsSync())
                            Image.file(File(_doc!.imagePath!), height: 180, width: double.infinity, fit: BoxFit.cover)
                          else if (_doc!.imageBase64 != null && _doc!.imageBase64!.isNotEmpty)
                            Image.memory(base64Decode(_doc!.imageBase64!), height: 180, width: double.infinity, fit: BoxFit.cover)
                          else if (_doc!.imageUrl != null && _doc!.imageUrl!.isNotEmpty)
                            Image.network(_doc!.imageUrl!, height: 180, width: double.infinity, fit: BoxFit.cover),
                          Container(
                            margin: const EdgeInsets.all(6),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(6)),
                            child: const Icon(Icons.zoom_in_rounded, size: 14, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF475569),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      visualDensity: VisualDensity.compact,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: _showAttachPhotoSheet,
                    icon: const Icon(Icons.camera_alt_rounded, size: 14),
                    label: Text(lang.isHindi ? 'फोटो बदलें' : 'Change Photo', style: const TextStyle(fontSize: 11.5)),
                  ),
                ],
              ),
            ),
          ] else ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primaryNavy,
                side: const BorderSide(color: Color(0xFFCBD5E1)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
              onPressed: _showAttachPhotoSheet,
              icon: const Icon(Icons.camera_alt_rounded, size: 16),
              label: Text(
                lang.isHindi ? 'पर्ची की फोटो जोड़ें' : 'Attach Slip Photo',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ],
          if (_doc!.items.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              lang.isHindi ? 'माल विवरण' : 'Items',
              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
            ),
            const SizedBox(height: 6),
            Card(
              elevation: 0.6,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xFFE2E8F0))),
              color: Colors.white,
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _doc!.items.length,
                separatorBuilder: (context, index) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                itemBuilder: (context, idx) {
                  final it = _doc!.items[idx];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(it.itemName, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                              const SizedBox(height: 2),
                              Text(
                                '${it.quantity} ${it.unit} × ${CurrencyFormatter.format(it.rateRupees)}',
                                style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          CurrencyFormatter.format(it.lineTotalRupees),
                          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
          const SizedBox(height: 12),
          Card(
            elevation: 0.6,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xFFE2E8F0))),
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  _buildSummaryRow(lang.isHindi ? 'कुल माल' : 'Subtotal', CurrencyFormatter.format(_doc!.subtotalRupees)),
                  if (_doc!.discountPaise > 0) ...[
                    const SizedBox(height: 6),
                    _buildSummaryRow(lang.isHindi ? 'छूट' : 'Discount', '- ${CurrencyFormatter.format(_doc!.discountRupees)}', color: const Color(0xFF16A34A)),
                  ],
                  if (_doc!.taxPaise > 0) ...[
                    const SizedBox(height: 6),
                    _buildSummaryRow(lang.isHindi ? 'जीएसटी टैक्स' : 'GST Tax', CurrencyFormatter.format(_doc!.taxRupees)),
                  ],
                  const Divider(height: 16, color: Color(0xFFF1F5F9)),
                  _buildSummaryRow(lang.isHindi ? 'कुल बिल' : 'Grand Total', CurrencyFormatter.format(_doc!.grandTotalRupees), isBold: true),
                  if (_doc!.paidAmountPaise > 0) ...[
                    const SizedBox(height: 6),
                    _buildSummaryRow(lang.isHindi ? 'जमा रकम' : 'Paid Amount', CurrencyFormatter.format(_doc!.paidAmountRupees), color: const Color(0xFF16A34A)),
                  ],
                  const Divider(height: 16, color: Color(0xFFF1F5F9)),
                  _buildSummaryRow(
                    lang.isHindi ? 'बाकी रकम' : 'Balance Due',
                    CurrencyFormatter.format(_doc!.remainingBalanceRupees),
                    isBold: true,
                    color: _doc!.remainingBalancePaise > 0 ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Clean Dual Share Row (WhatsApp & PDF)
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.chat_rounded, size: 16),
                  label: Text(lang.isHindi ? 'व्हाट्सएप शेयर' : 'WhatsApp Share'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF16A34A),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  onPressed: () {
                    final textSummary = _getValuableBillText(lang);
                    ShareHelper.shareText(textSummary, subject: 'Bill ${_doc!.docNumber}');
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.picture_as_pdf_rounded, size: 16),
                  label: Text(lang.isHindi ? 'PDF बिल' : 'PDF Invoice'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primaryNavy,
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  onPressed: () {
                    final textSummary = _getValuableBillText(lang);
                    PdfService.shareDocumentPdf(_doc!, text: textSummary);
                  },
                ),
              ),
            ],
          ),
          if (_doc!.remainingBalancePaise > 0 && !_doc!.isCancelled) ...[
            const SizedBox(height: 10),
            ElevatedButton.icon(
              icon: const Icon(Icons.payment_rounded, size: 16),
              label: Text(
                _doc!.isPurchase
                    ? (lang.isHindi ? 'भुगतान दर्ज करें' : 'Record Payment')
                    : (lang.isHindi ? 'पेमेंट लें / QR कोड' : 'Collect Payment / QR'),
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryNavy,
                foregroundColor: AppColors.primaryGold,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 13),
              ),
              onPressed: () async {
                final res = await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => PaymentEntryScreen(
                      initialPartyId: _doc!.partyId,
                      initialTxType: _doc!.isPurchase ? 'supplier_payment' : 'customer_receipt',
                      initialRelatedDocId: _doc!.id,
                      initialAmountRupees: _doc!.remainingBalanceRupees,
                    ),
                  ),
                );
                if (res == true) _loadDoc();
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isBold = false, Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isBold ? 14 : 13,
            fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
            color: color ?? AppColors.textSecondary,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isBold ? 16 : 14,
            fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
            color: color ?? AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
