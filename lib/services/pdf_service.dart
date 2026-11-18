import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../core/utils/currency_formatter.dart';
import '../core/utils/date_formatter.dart';
import '../core/utils/share_helper.dart';
import '../models/document.dart';
import 'upi_qr_service.dart';

class PdfService {
  /// Builds the complete PDF document model
  static Future<pw.Document> generateDocument(BusinessDocument doc) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'DM LACE SURAT',
                        style: pw.TextStyle(
                          fontSize: 22,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColor.fromHex('#0A192F'),
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'Ring Road Textile Market, Surat, Gujarat',
                        style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                      ),
                      pw.Text(
                        'Specialists in Zari Borders, Crochet, Sequence Gota & Designer Laces',
                        style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
                      ),
                    ],
                  ),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: pw.BoxDecoration(
                      color: PdfColor.fromHex('#F4F6F9'),
                      border: pw.Border.all(color: PdfColor.fromHex('#D4AF37')),
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          doc.isChallan
                              ? 'DELIVERY CHALLAN'
                              : (doc.isKacchaBill ? 'KACCHA BILL / MEMO' : 'TAX INVOICE'),
                          style: pw.TextStyle(
                            fontSize: 12,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColor.fromHex('#0A192F'),
                          ),
                        ),
                        pw.Text(
                          doc.docNumber,
                          style: pw.TextStyle(
                            fontSize: 14,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColor.fromHex('#B45309'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              pw.Divider(thickness: 1.5, color: PdfColor.fromHex('#D4AF37')),
              pw.SizedBox(height: 10),

              // Party & Date Details
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Billed To (पार्टी):', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        doc.partyName ?? 'Customer #${doc.partyId}',
                        style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('Date: ${DateFormatter.format(DateFormatter.parse(doc.docDate))}', style: const pw.TextStyle(fontSize: 10)),
                      if (doc.dueDate != null)
                        pw.Text('Due Date: ${DateFormatter.format(DateFormatter.parse(doc.dueDate))}', style: const pw.TextStyle(fontSize: 10, color: PdfColors.red800)),
                      pw.Text('Payment Status: ${doc.paymentStatus.toUpperCase()}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 16),

              // Line Items Table
              pw.TableHelper.fromTextArray(
                context: context,
                border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                headerStyle: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                headerDecoration: pw.BoxDecoration(color: PdfColor.fromHex('#0A192F')),
                cellStyle: const pw.TextStyle(fontSize: 9),
                cellAlignment: pw.Alignment.centerLeft,
                headers: <String>['#', 'Lace Item / Design', 'Qty', 'Unit', 'Rate (₹)', 'Total (₹)'],
                data: doc.items.asMap().entries.map((entry) {
                  final idx = entry.key + 1;
                  final it = entry.value;
                  return [
                    idx.toString(),
                    it.itemName,
                    it.quantity.toStringAsFixed(1),
                    it.unit,
                    CurrencyFormatter.format(it.rateRupees, includeSymbol: false),
                    CurrencyFormatter.format(it.lineTotalRupees, includeSymbol: false),
                  ];
                }).toList(),
              ),
              pw.SizedBox(height: 16),

              // Totals Breakdown
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        if (doc.isKacchaBill)
                          pw.Text(
                            '* Internal business cash memo. Not an official GST tax invoice.',
                            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                          ),
                        if (doc.notes != null)
                          pw.Text('Notes: ${doc.notes}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey800)),
                      ],
                    ),
                  ),
                  pw.Container(
                    width: 200,
                    padding: const pw.EdgeInsets.all(8),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey300),
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                    ),
                    child: pw.Column(
                      children: [
                        _buildPdfSummaryRow('Subtotal', CurrencyFormatter.format(doc.subtotalRupees)),
                        if (doc.discountPaise > 0)
                          _buildPdfSummaryRow('Discount', '- ${CurrencyFormatter.format(doc.discountRupees)}'),
                        if (doc.taxPaise > 0)
                          _buildPdfSummaryRow('Tax', CurrencyFormatter.format(doc.taxRupees)),
                        pw.Divider(thickness: 0.5),
                        _buildPdfSummaryRow('Grand Total', CurrencyFormatter.format(doc.grandTotalRupees), isBold: true),
                        _buildPdfSummaryRow('Paid Amount', CurrencyFormatter.format(doc.paidAmountRupees)),
                        pw.Divider(thickness: 0.5),
                        _buildPdfSummaryRow('Balance Due', CurrencyFormatter.format(doc.remainingBalanceRupees), isBold: true),
                      ],
                    ),
                  ),
                ],
              ),
              pw.Spacer(),

              // Signatures
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Receiver\'s Signature / Stamp', style: const pw.TextStyle(fontSize: 9)),
                  pw.Text('For DM LACE SURAT (Authorized Signatory)', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                ],
              ),
              pw.SizedBox(height: 8),
            ],
          );
        },
      ),
    );

    return pdf;
  }

  /// Print or preview PDF document
  static Future<void> printDocument(BusinessDocument doc) async {
    final pdf = await generateDocument(doc);
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: '${doc.docNumber}.pdf',
    );
  }

  /// Save PDF to device cache and return File
  static Future<File> generatePdfFile(BusinessDocument doc) async {
    final pdf = await generateDocument(doc);
    final tempDir = await getTemporaryDirectory();
    final safeName = doc.docNumber.replaceAll('/', '_').replaceAll('\\', '_');
    final file = File('${tempDir.path}/$safeName.pdf');
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  /// Share PDF directly with WhatsApp or system share sheet along with valuable summary
  static Future<void> shareDocumentPdf(BusinessDocument doc, {String? text}) async {
    try {
      final file = await generatePdfFile(doc);
      await ShareHelper.shareImageWithText(
        imagePath: file.path,
        text: text ?? 'DM Lace Surat - Bill #${doc.docNumber}',
        subject: 'Bill ${doc.docNumber}',
      );
    } catch (_) {
      if (text != null) {
        await ShareHelper.shareText(text, subject: 'Bill ${doc.docNumber}');
      }
    }
  }

  /// Builds complete PDF ledger statement for a party
  static Future<pw.Document> generatePartyLedgerPdf({
    required String partyName,
    String? partyPhone,
    String? partyAddress,
    required double currentBalanceRupees,
    required List<Map<String, dynamic>> ledgerEntries,
    String upiId = 'dmlace@upi',
  }) async {
    if (upiId == 'dmlace@upi') {
      try {
        final primary = await UpiQrService.getPrimaryAccount();
        upiId = primary.upiId;
      } catch (_) {}
    }
    final pdf = pw.Document();
    final isReceivable = currentBalanceRupees >= 0;
    final upiUrl = 'upi://pay?pa=$upiId&pn=${Uri.encodeComponent("DM LACE SURAT")}&am=${currentBalanceRupees.abs().toStringAsFixed(2)}&cu=INR&tn=${Uri.encodeComponent("Ledger Payment - $partyName")}';

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (pw.Context context) {
          return [
            // Header
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'DM LACE SURAT',
                      style: pw.TextStyle(
                        fontSize: 22,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColor.fromHex('#0A192F'),
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      'Ring Road Textile Market, Surat, Gujarat',
                      style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                    ),
                    pw.Text(
                      'Lace, Border, Crochet & Sequence Embroidery',
                      style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
                    ),
                  ],
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('#F4F6F9'),
                    border: pw.Border.all(color: PdfColor.fromHex('#D4AF37')),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'PARTY STATEMENT',
                        style: pw.TextStyle(
                          fontSize: 11,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColor.fromHex('#0A192F'),
                        ),
                      ),
                      pw.Text(
                        DateFormatter.today(),
                        style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColor.fromHex('#B45309'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            pw.Divider(thickness: 1.5, color: PdfColor.fromHex('#D4AF37')),
            pw.SizedBox(height: 8),

            // Party Info & Balance Card
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Party Details (पार्टी विवरण):', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                    pw.Text(
                      partyName,
                      style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
                    ),
                    if (partyPhone != null && partyPhone.isNotEmpty)
                      pw.Text('Phone: $partyPhone', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey800)),
                    if (partyAddress != null && partyAddress.isNotEmpty)
                      pw.Text('Market: $partyAddress', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                  ],
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: pw.BoxDecoration(
                    color: isReceivable ? PdfColor.fromHex('#DCFCE7') : PdfColor.fromHex('#FEE2E2'),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        isReceivable ? 'NET DUE (लेना बाकी)' : 'NET CREDIT (जमा)',
                        style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                          color: isReceivable ? PdfColor.fromHex('#166534') : PdfColor.fromHex('#991B1B'),
                        ),
                      ),
                      pw.Text(
                        CurrencyFormatter.format(currentBalanceRupees.abs()),
                        style: pw.TextStyle(
                          fontSize: 15,
                          fontWeight: pw.FontWeight.bold,
                          color: isReceivable ? PdfColor.fromHex('#15803D') : PdfColor.fromHex('#B91C1C'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 14),

            // Ledger Entries Table
            pw.TableHelper.fromTextArray(
              context: context,
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
              headerDecoration: pw.BoxDecoration(color: PdfColor.fromHex('#0A192F')),
              cellStyle: const pw.TextStyle(fontSize: 8.5),
              cellAlignment: pw.Alignment.centerLeft,
              headers: <String>['Date', 'Particulars / Detail', 'Debit (+)', 'Credit (-)', 'Balance (₹)'],
              data: ledgerEntries.map((e) {
                final debitPaise = e['debit_paise'] as int? ?? 0;
                final creditPaise = e['credit_paise'] as int? ?? 0;
                final runningPaise = e['running_balance_paise'] as int? ?? 0;
                final dateStr = e['date'] as String? ?? '';
                final desc = e['description'] as String? ?? '';

                return [
                  DateFormatter.format(DateFormatter.parse(dateStr)),
                  desc,
                  debitPaise > 0 ? CurrencyFormatter.formatPaise(debitPaise, showDecimals: false) : '-',
                  creditPaise > 0 ? CurrencyFormatter.formatPaise(creditPaise, showDecimals: false) : '-',
                  CurrencyFormatter.formatPaise(runningPaise, showDecimals: false),
                ];
              }).toList(),
            ),
            pw.SizedBox(height: 16),

            // Bottom Section: UPI QR Code & Signatures
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                if (isReceivable && currentBalanceRupees > 0)
                  pw.Row(
                    children: [
                      pw.BarcodeWidget(
                        barcode: pw.Barcode.qrCode(),
                        data: upiUrl,
                        width: 65,
                        height: 65,
                      ),
                      pw.SizedBox(width: 8),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('Scan to Pay via UPI', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                          pw.Text('GPay • PhonePe • Paytm', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                          pw.Text('UPI ID: $upiId', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                        ],
                      ),
                    ],
                  )
                else
                  pw.Text('* Thank you for your continued business.', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.SizedBox(height: 30),
                    pw.Text('For DM LACE SURAT', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                    pw.Text('Authorized Signatory', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                  ],
                ),
              ],
            ),
          ];
        },
      ),
    );

    return pdf;
  }

  /// Share Party Ledger Statement PDF directly via WhatsApp or System Share
  static Future<void> sharePartyLedgerPdf({
    required String partyName,
    String? partyPhone,
    String? partyAddress,
    required double currentBalanceRupees,
    required List<Map<String, dynamic>> ledgerEntries,
    String upiId = 'dmlace@upi',
  }) async {
    try {
      if (upiId == 'dmlace@upi') {
        try {
          final primary = await UpiQrService.getPrimaryAccount();
          upiId = primary.upiId;
        } catch (_) {}
      }
      final pdf = await generatePartyLedgerPdf(
        partyName: partyName,
        partyPhone: partyPhone,
        partyAddress: partyAddress,
        currentBalanceRupees: currentBalanceRupees,
        ledgerEntries: ledgerEntries,
        upiId: upiId,
      );
      final tempDir = await getTemporaryDirectory();
      final safeName = partyName.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
      final file = File('${tempDir.path}/Ledger_$safeName.pdf');
      await file.writeAsBytes(await pdf.save());

      final isReceivable = currentBalanceRupees >= 0;
      final text = '''
🧵 *DM LACE SURAT • खाता बही विवरण*
👤 *पार्टी:* $partyName
💰 *${isReceivable ? "बकाया (लेना)" : "जमा (देना)"}:* ₹ ${CurrencyFormatter.format(currentBalanceRupees.abs())}
📅 *दिनांक:* ${DateFormatter.today()}
🙏 कृपया संलग्न PDF खाता विवरण देखें।
''';

      await ShareHelper.shareImageWithText(
        imagePath: file.path,
        text: text,
        subject: '$partyName - खाता विवरण',
      );
    } catch (_) {
      // Fallback
    }
  }

  static pw.Widget _buildPdfSummaryRow(String label, String value, {bool isBold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(fontSize: 9, fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(fontSize: 9, fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal),
          ),
        ],
      ),
    );
  }
}
