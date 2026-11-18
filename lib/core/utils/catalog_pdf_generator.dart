import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/inventory_item.dart';
import 'currency_formatter.dart';
import 'date_formatter.dart';

class CatalogPdfGenerator {
  static Future<File> generateCatalogPdf({
    required List<InventoryItem> items,
    String? title,
  }) async {
    final pdf = pw.Document();
    final today = DateFormatter.today();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
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
                          color: PdfColor.fromHex('#0B1F38'),
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'WHOLESALE LACE & EMBROIDERY CATALOG',
                        style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColor.fromHex('#D4AF37'),
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'Date: $today',
                        style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
                      ),
                      pw.Text(
                        'Ring Road, Surat Textile Market Hub',
                        style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
                      ),
                    ],
                  ),
                ],
              ),
              pw.Divider(thickness: 1.5, color: PdfColor.fromHex('#D4AF37')),
              pw.SizedBox(height: 8),
            ],
          );
        },
        footer: (context) {
          return pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(top: 10),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'DM Lace Surat • Direct Manufacturer & Wholesaler',
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                ),
                pw.Text(
                  'Page ${context.pageNumber} of ${context.pagesCount}',
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                ),
              ],
            ),
          );
        },
        build: (context) {
          return [
            pw.Text(
              title ?? 'Lace Designs Catalog (${items.length} Items)',
              style: pw.TextStyle(
                fontSize: 13,
                fontWeight: pw.FontWeight.bold,
                color: PdfColor.fromHex('#0B1F38'),
              ),
            ),
            pw.SizedBox(height: 10),
            pw.TableHelper.fromTextArray(
              headers: ['Code', 'Design Name & Details', 'Category', 'Width', 'Colors', 'Wholesale Rate'],
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
                fontSize: 9.5,
              ),
              headerDecoration: pw.BoxDecoration(color: PdfColor.fromHex('#0B1F38')),
              cellAlignment: pw.Alignment.centerLeft,
              cellStyle: const pw.TextStyle(fontSize: 9),
              cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 7),
              data: items.map((item) {
                return [
                  item.designCode,
                  item.itemName,
                  item.category ?? 'Lace',
                  item.width ?? '-',
                  item.colors ?? 'Standard',
                  '${CurrencyFormatter.format(item.sellingRateRupees)} / ${item.unit}',
                ];
              }).toList(),
            ),
            pw.SizedBox(height: 16),
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromHex('#F1F5F9'),
                borderRadius: pw.BorderRadius.circular(6),
                border: pw.Border.all(color: PdfColor.fromHex('#CBD5E1')),
              ),
              child: pw.Row(
                children: [
                  pw.Expanded(
                    child: pw.Text(
                      'Terms: Rates quoted above are wholesale ex-godown Surat. Special discounts available for bulk roll/bale orders. Contact us on WhatsApp for live sample videos & current dispatch availability.',
                      style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey800),
                    ),
                  ),
                ],
              ),
            ),
          ];
        },
      ),
    );

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/DM_Lace_Catalog_${DateTime.now().millisecondsSinceEpoch}.pdf');
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  static Future<void> shareCatalogPdf({
    required List<InventoryItem> items,
    String? title,
  }) async {
    try {
      final file = await generateCatalogPdf(items: items, title: title);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: '🧵 DM LACE SURAT - Digital Product Catalog (${items.length} Designs)\nRing Road, Surat Textile Market Hub',
          subject: 'DM Lace Surat - Lace Catalog Brochure',
        ),
      );
    } catch (_) {
      // Fallback
    }
  }
}
