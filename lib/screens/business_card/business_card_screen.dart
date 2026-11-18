import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'package:qr/qr.dart';
import '../../core/constants/app_colors.dart';
import '../../core/database/database_helper.dart';
import '../../core/database/database_tables.dart';
import '../../core/localization/language_provider.dart';
import '../../core/security/auth_service.dart';
import '../../core/utils/share_helper.dart';

enum CardThemeType {
  royalGold,
  emeraldLuxe,
  platinumOnyx,
  rubyImperial,
}

class _ThemePalette {
  final List<Color> gradient;
  final Color borderColor;
  final Color primaryColor;
  final Color accentColor;
  final Color subtextColor;
  final Color glowColor;
  final String icon;

  const _ThemePalette({
    required this.gradient,
    required this.borderColor,
    required this.primaryColor,
    required this.accentColor,
    required this.subtextColor,
    required this.glowColor,
    required this.icon,
  });
}

class BusinessCardScreen extends StatefulWidget {
  const BusinessCardScreen({super.key});

  @override
  State<BusinessCardScreen> createState() => _BusinessCardScreenState();
}

class _BusinessCardScreenState extends State<BusinessCardScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _flipController;
  late Animation<double> _flipAnimation;
  bool _isFront = true;
  CardThemeType _selectedTheme = CardThemeType.royalGold;

  // Editable Business Card Details (Auto-populated with actual user & shop data)
  String _firmName = 'DM LACE SURAT';
  String _tagline = 'Direct Loom Manufacturer & Wholesale Supplier';
  String _ownerName = 'D.M. Lace Surat';
  String _phone = '+91 98765 43210';
  String _email = 'contact@dmlacesurat.com';
  String _address = 'Ring Road, Millennium Textile Market, Surat, Gujarat - 395002';
  String _gstin = '24AAACD1234M1Z5';
  String _products = 'Fancy Saree Borders • Zari Laces • Gota Patti • Sequence Trims';

  @override
  void initState() {
    super.initState();
    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _flipAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _flipController, curve: Curves.easeInOutCubic),
    );
    _loadSavedDetails();
  }

  @override
  void dispose() {
    _flipController.dispose();
    super.dispose();
  }

  _ThemePalette _getThemeColors(CardThemeType theme) {
    switch (theme) {
      case CardThemeType.royalGold:
        return const _ThemePalette(
          gradient: [
            Color(0xFF030712),
            Color(0xFF071426),
            Color(0xFF0E274A),
            Color(0xFF040A14),
          ],
          borderColor: Color(0xFFD4AF37),
          primaryColor: Color(0xFFFDE047),
          accentColor: Color(0xFFD4AF37),
          subtextColor: Color(0xFF93C5FD),
          glowColor: Color(0xFFD4AF37),
          icon: '👑',
        );
      case CardThemeType.emeraldLuxe:
        return const _ThemePalette(
          gradient: [
            Color(0xFF021E17),
            Color(0xFF063A2D),
            Color(0xFF0B5345),
            Color(0xFF021B15),
          ],
          borderColor: Color(0xFFD4AF37),
          primaryColor: Color(0xFFFDE047),
          accentColor: Color(0xFF10B981),
          subtextColor: Color(0xFF6EE7B7),
          glowColor: Color(0xFF10B981),
          icon: '🌿',
        );
      case CardThemeType.platinumOnyx:
        return const _ThemePalette(
          gradient: [
            Color(0xFF090D16),
            Color(0xFF111827),
            Color(0xFF1E293B),
            Color(0xFF0A0E17),
          ],
          borderColor: Color(0xFFE2E8F0),
          primaryColor: Color(0xFFF8FAFC),
          accentColor: Color(0xFF38BDF8),
          subtextColor: Color(0xFF94A3B8),
          glowColor: Color(0xFF38BDF8),
          icon: '💎',
        );
      case CardThemeType.rubyImperial:
        return const _ThemePalette(
          gradient: [
            Color(0xFF1F0404),
            Color(0xFF3B0707),
            Color(0xFF581010),
            Color(0xFF1A0303),
          ],
          borderColor: Color(0xFFF59E0B),
          primaryColor: Color(0xFFFDE047),
          accentColor: Color(0xFFEF4444),
          subtextColor: Color(0xFFFCA5A5),
          glowColor: Color(0xFFEF4444),
          icon: '🍷',
        );
    }
  }

  Future<void> _loadSavedDetails() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final rows = await db.query(DatabaseTables.tableAppSettings);
      final map = {for (final r in rows) r['setting_key'] as String: r['setting_value'] as String};
      final user = await AuthService.getCurrentUser();

      if (mounted) {
        setState(() {
          // 1. Owner Name: Prioritize user's actual registered name
          if (map.containsKey('biz_card_owner') && map['biz_card_owner']!.trim().isNotEmpty) {
            _ownerName = map['biz_card_owner']!.trim();
          } else if (user != null && user['name'] != null && (user['name'] as String).trim().isNotEmpty) {
            _ownerName = (user['name'] as String).trim();
          }

          // 2. Firm Name: Prioritize shop_name
          if (map.containsKey('biz_card_firm') && map['biz_card_firm']!.trim().isNotEmpty) {
            _firmName = map['biz_card_firm']!.trim();
          } else if (user != null && user['shop_name'] != null && (user['shop_name'] as String).trim().isNotEmpty) {
            _firmName = (user['shop_name'] as String).trim();
          } else if (map.containsKey('shop_name') && map['shop_name']!.trim().isNotEmpty) {
            _firmName = map['shop_name']!.trim();
          }

          // 3. Email: Prioritize registered login email
          if (map.containsKey('biz_card_email') && map['biz_card_email']!.trim().isNotEmpty) {
            _email = map['biz_card_email']!.trim();
          } else if (user != null && user['email'] != null && (user['email'] as String).trim().isNotEmpty) {
            _email = (user['email'] as String).trim();
          }

          // 4. Phone
          if (map.containsKey('biz_card_phone') && map['biz_card_phone']!.trim().isNotEmpty) {
            _phone = map['biz_card_phone']!.trim();
          } else if (user != null && user['phone'] != null && (user['phone'] as String).trim().isNotEmpty) {
            _phone = (user['phone'] as String).trim();
          } else if (map.containsKey('shop_phone') && map['shop_phone']!.trim().isNotEmpty) {
            _phone = map['shop_phone']!.trim();
          }

          // 5. Address
          if (map.containsKey('biz_card_address') && map['biz_card_address']!.trim().isNotEmpty) {
            _address = map['biz_card_address']!.trim();
          } else if (map.containsKey('shop_address') && map['shop_address']!.trim().isNotEmpty) {
            _address = map['shop_address']!.trim();
          } else if (map.containsKey('market_address') && map['market_address']!.trim().isNotEmpty) {
            _address = map['market_address']!.trim();
          }

          // 6. GSTIN
          if (map.containsKey('biz_card_gstin') && map['biz_card_gstin']!.trim().isNotEmpty) {
            _gstin = map['biz_card_gstin']!.trim();
          } else if (map.containsKey('shop_gstin') && map['shop_gstin']!.trim().isNotEmpty) {
            _gstin = map['shop_gstin']!.trim();
          }

          // 7. Tagline & Products
          if (map.containsKey('biz_card_tagline') && map['biz_card_tagline']!.trim().isNotEmpty) {
            _tagline = map['biz_card_tagline']!.trim();
          }
          if (map.containsKey('biz_card_products') && map['biz_card_products']!.trim().isNotEmpty) {
            _products = map['biz_card_products']!.trim();
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _saveDetail(String key, String value) async {
    try {
      final db = await DatabaseHelper.instance.database;
      await db.rawInsert('''
        INSERT OR REPLACE INTO ${DatabaseTables.tableAppSettings} (setting_key, setting_value)
        VALUES (?, ?)
      ''', [key, value]);
    } catch (_) {}
  }

  void _toggleFlip() {
    if (_isFront) {
      _flipController.forward();
    } else {
      _flipController.reverse();
    }
    setState(() => _isFront = !_isFront);
  }

  void _shareViaWhatsApp(LanguageProvider lang) {
    final cleanPhone = _phone.replaceAll(RegExp(r'[^0-9]'), '');
    final waLink = 'https://wa.me/$cleanPhone';

    final text = lang.isHindi
        ? '''
👑 *$_firmName* 👑
$_tagline
सूरत टेक्सटाइल मार्केट • डायरेक्ट लूम
----------------------------------------
🪡 हमारी विशेषताएं (Specialties):
$_products
----------------------------------------
👤 संचालक / प्रोप्राइटर: $_ownerName
📞 फ़ोन / WhatsApp: $_phone
📍 पता: $_address
🏢 GSTIN: $_gstin
✉️ ईमेल: $_email
----------------------------------------
💬 WhatsApp पर जुड़ें: $waLink
----------------------------------------
✨ $_firmName • 100% क्वालिटी व ज़री गारंटी
'''
        : '''
👑 *$_firmName* 👑
$_tagline
Surat Textile Market • Direct Factory Loom
----------------------------------------
🪡 Our Specialties:
$_products
----------------------------------------
👤 Proprietor: $_ownerName
📞 Phone / WhatsApp: $_phone
📍 Address: $_address
🏢 GSTIN: $_gstin
✉️ Email: $_email
----------------------------------------
💬 Chat on WhatsApp: $waLink
----------------------------------------
✨ $_firmName • 100% Quality & Metallic Fastness Guaranteed
''';

    ShareHelper.shareText(
      text,
      subject: '$_firmName - Digital Business Card',
    );
  }

  Future<void> _printOrExportPdf(LanguageProvider lang) async {
    // Show modal to choose print theme
    final isDark = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.print_rounded, color: Color(0xFFFDE047), size: 22),
                const SizedBox(width: 10),
                Text(
                  lang.tr(en: 'Choose Print Style', hi: 'प्रिंट स्टाइल चुनें'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              lang.tr(
                en: 'Includes Front Side, Back Side & A4 Cut Sheet',
                hi: 'कार्ड का अगला भाग, पिछला भाग और A4 कट शीट दोनों शामिल हैं',
              ),
              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
            ),
            const SizedBox(height: 16),
            ListTile(
              onTap: () => Navigator.pop(ctx, true),
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF040A14),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFD4AF37), width: 1.2),
                ),
                child: const Icon(Icons.stars_rounded, color: Color(0xFFFDE047), size: 22),
              ),
              title: Text(
                lang.tr(en: '👑 Royal Obsidian & Gold (Screen Match)', hi: '👑 रॉयल ऑब्सिडियन व गोल्ड (स्क्रीन जैसा VIP लुक)'),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13.5),
              ),
              subtitle: Text(
                lang.tr(en: 'Deep royal background with luxury gold trim', hi: 'डीप रॉयल नेवी बैकग्राउंड व 24K गोल्ड बॉर्डर'),
                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
              ),
              trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFFFDE047)),
            ),
            const Divider(color: Color(0x33FFFFFF)),
            ListTile(
              onTap: () => Navigator.pop(ctx, false),
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFD4AF37), width: 1.2),
                ),
                child: const Icon(Icons.print_outlined, color: Color(0xFF0F172A), size: 22),
              ),
              title: Text(
                lang.tr(en: '📄 Crisp White & Gold (Ink-Saver)', hi: '📄 क्लासिक व्हाइट व गोल्ड (कम इंक प्रिंट)'),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13.5),
              ),
              subtitle: Text(
                lang.tr(en: 'Crisp white paper background with gold & navy borders', hi: 'सफेद पेपर प्रिंट के लिए बेस्ट, कम स्याही खर्च'),
                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
              ),
              trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFFFDE047)),
            ),
          ],
        ),
      ),
    );

    if (isDark == null) return;
    await _renderAndPrintPdf(isDarkTheme: isDark, lang: lang);
  }

  Future<void> _renderAndPrintPdf({required bool isDarkTheme, required LanguageProvider lang}) async {
    pw.MemoryImage? logoImage;
    try {
      final ByteData logoData = await rootBundle.load('assets/images/dm_lace_logo.png');
      logoImage = pw.MemoryImage(logoData.buffer.asUint8List());
    } catch (_) {}

    final cleanPhone = _phone.replaceAll(RegExp(r'[^0-9]'), '');
    final waLink = 'https://wa.me/$cleanPhone';

    final doc = pw.Document();

    // Page 1: Front Side (3.5" x 2.0")
    doc.addPage(
      pw.Page(
        pageFormat: const PdfPageFormat(
          3.5 * PdfPageFormat.inch,
          2.0 * PdfPageFormat.inch,
          marginAll: 0.08 * PdfPageFormat.inch,
        ),
        build: (pw.Context ctx) {
          return _buildPdfCardContent(
            isFront: true,
            isDarkTheme: isDarkTheme,
            logoImage: logoImage,
            waLink: waLink,
          );
        },
      ),
    );

    // Page 2: Back Side (3.5" x 2.0")
    doc.addPage(
      pw.Page(
        pageFormat: const PdfPageFormat(
          3.5 * PdfPageFormat.inch,
          2.0 * PdfPageFormat.inch,
          marginAll: 0.08 * PdfPageFormat.inch,
        ),
        build: (pw.Context ctx) {
          return _buildPdfCardContent(
            isFront: false,
            isDarkTheme: isDarkTheme,
            logoImage: logoImage,
            waLink: waLink,
          );
        },
      ),
    );

    // Page 3: Full A4 Print Sheet with Cut Marks (Front & Back Side by Side)
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context ctx) {
          final goldColor = PdfColor.fromHex('#D4AF37');
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Text(
                'DM LACE SURAT • VISITING CARD PRINT SHEET',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColor.fromHex('#0B1F38'),
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'Cut along border lines for standard 3.5" x 2.0" visiting card size.',
                style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
              ),
              pw.SizedBox(height: 24),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.center,
                children: [
                  pw.Column(
                    children: [
                      pw.Text(
                        'FRONT SIDE (अगला भाग)',
                        style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: goldColor),
                      ),
                      pw.SizedBox(height: 6),
                      pw.Container(
                        width: 3.5 * PdfPageFormat.inch,
                        height: 2.0 * PdfPageFormat.inch,
                        child: _buildPdfCardContent(
                          isFront: true,
                          isDarkTheme: isDarkTheme,
                          logoImage: logoImage,
                          waLink: waLink,
                        ),
                      ),
                    ],
                  ),
                  pw.SizedBox(width: 24),
                  pw.Column(
                    children: [
                      pw.Text(
                        'BACK SIDE (पिछला भाग)',
                        style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: goldColor),
                      ),
                      pw.SizedBox(height: 6),
                      pw.Container(
                        width: 3.5 * PdfPageFormat.inch,
                        height: 2.0 * PdfPageFormat.inch,
                        child: _buildPdfCardContent(
                          isFront: false,
                          isDarkTheme: isDarkTheme,
                          logoImage: logoImage,
                          waLink: waLink,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 32),
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#F8FAFC'),
                  borderRadius: pw.BorderRadius.circular(8),
                  border: pw.Border.all(color: PdfColors.grey400, width: 0.8),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Printing Instructions / प्रिंट निर्देश:', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 3),
                    pw.Text('1. Use 300 GSM Matte or Glossy Art Card paper for best durability.', style: const pw.TextStyle(fontSize: 8)),
                    pw.Text('2. Set printer scale to "100% / Actual Size" (do not select "Fit to Printable Area").', style: const pw.TextStyle(fontSize: 8)),
                    pw.Text('3. Cut along the gold outer border lines with a paper cutter.', style: const pw.TextStyle(fontSize: 8)),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => doc.save(),
      name: 'DM_Lace_Surat_Business_Card',
    );
  }

  pw.Widget _buildPdfBulletItem(String title, String desc, PdfColor textColor, PdfColor goldColor) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('• ', style: pw.TextStyle(color: goldColor, fontSize: 6.5, fontWeight: pw.FontWeight.bold)),
        pw.Expanded(
          child: pw.RichText(
            text: pw.TextSpan(
              children: [
                pw.TextSpan(
                  text: '$title: ',
                  style: pw.TextStyle(
                    fontSize: 5.4,
                    fontWeight: pw.FontWeight.bold,
                    color: goldColor,
                  ),
                ),
                pw.TextSpan(
                  text: desc,
                  style: pw.TextStyle(
                    fontSize: 4.8,
                    color: textColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  pw.Widget _buildPdfCardContent({
    required bool isFront,
    required bool isDarkTheme,
    pw.MemoryImage? logoImage,
    required String waLink,
  }) {
    final cardBgColor = isDarkTheme ? PdfColor.fromHex('#040B17') : PdfColors.white;
    final cardBorderColor = PdfColor.fromHex('#D4AF37');
    final titleColor = isDarkTheme ? PdfColor.fromHex('#FDE047') : PdfColor.fromHex('#0B1F38');
    final textColor = isDarkTheme ? PdfColor.fromHex('#E2E8F0') : PdfColor.fromHex('#1E293B');
    final subtextColor = isDarkTheme ? PdfColor.fromHex('#93C5FD') : PdfColor.fromHex('#0284C7');
    final goldColor = PdfColor.fromHex('#D4AF37');

    if (isFront) {
      return pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: pw.BoxDecoration(
          color: cardBgColor,
          borderRadius: pw.BorderRadius.circular(6),
          border: pw.Border.all(color: cardBorderColor, width: 1.4),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            // Top Mantra & GSTIN Bar
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'SHREE GANESHAY NAMAH',
                  style: pw.TextStyle(
                    fontSize: 5.5,
                    fontWeight: pw.FontWeight.bold,
                    color: goldColor,
                    letterSpacing: 0.5,
                  ),
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: pw.BoxDecoration(
                    color: isDarkTheme ? PdfColor.fromHex('#1E293B') : PdfColor.fromHex('#F1F5F9'),
                    borderRadius: pw.BorderRadius.circular(3),
                    border: pw.Border.all(color: goldColor, width: 0.5),
                  ),
                  child: pw.Text(
                    'GSTIN: $_gstin',
                    style: pw.TextStyle(
                      fontSize: 5.5,
                      fontWeight: pw.FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                ),
                pw.Text(
                  'SHUBH LABH',
                  style: pw.TextStyle(
                    fontSize: 5.5,
                    fontWeight: pw.FontWeight.bold,
                    color: goldColor,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),

            // Center: Logo + Firm Name & Specialty
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                if (logoImage != null)
                  pw.Container(
                    width: 32,
                    height: 32,
                    decoration: pw.BoxDecoration(
                      shape: pw.BoxShape.circle,
                      border: pw.Border.all(color: goldColor, width: 1.2),
                    ),
                    child: pw.ClipOval(
                      child: pw.Image(logoImage, fit: pw.BoxFit.contain),
                    ),
                  ),
                pw.SizedBox(width: 8),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        _firmName,
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                          color: titleColor,
                          letterSpacing: 1.2,
                        ),
                      ),
                      pw.Text(
                        _tagline,
                        style: pw.TextStyle(
                          fontSize: 5.8,
                          fontWeight: pw.FontWeight.bold,
                          color: subtextColor,
                        ),
                      ),
                      pw.Text(
                        _products,
                        style: pw.TextStyle(
                          fontSize: 5.2,
                          color: textColor,
                        ),
                        maxLines: 1,
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Specular Hairline Divider
            pw.Container(
              height: 0.8,
              decoration: pw.BoxDecoration(
                color: goldColor,
              ),
            ),

            // Bottom: Contact Details & QR Code
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Proprietor: $_ownerName',
                        style: pw.TextStyle(
                          fontSize: 5.8,
                          fontWeight: pw.FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      pw.Text(
                        'Phone / WhatsApp: $_phone',
                        style: pw.TextStyle(
                          fontSize: 6.2,
                          fontWeight: pw.FontWeight.bold,
                          color: goldColor,
                        ),
                      ),
                      pw.Text(
                        'Address: $_address',
                        style: pw.TextStyle(fontSize: 5.0, color: textColor),
                        maxLines: 1,
                      ),
                      pw.Text(
                        'Email: $_email',
                        style: pw.TextStyle(fontSize: 5.0, color: subtextColor),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(width: 6),
                pw.Column(
                  children: [
                    pw.Container(
                      width: 32,
                      height: 32,
                      padding: const pw.EdgeInsets.all(2),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.white,
                        borderRadius: pw.BorderRadius.circular(4),
                        border: pw.Border.all(color: goldColor, width: 0.8),
                      ),
                      child: pw.BarcodeWidget(
                        barcode: pw.Barcode.qrCode(),
                        data: waLink,
                        color: PdfColors.black,
                        backgroundColor: PdfColors.white,
                      ),
                    ),
                    pw.SizedBox(height: 1),
                    pw.Text(
                      'SCAN TO CHAT',
                      style: pw.TextStyle(
                        fontSize: 4.5,
                        fontWeight: pw.FontWeight.bold,
                        color: goldColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      );
    } else {
      // Back side
      return pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: pw.BoxDecoration(
          color: cardBgColor,
          borderRadius: pw.BorderRadius.circular(6),
          border: pw.Border.all(color: cardBorderColor, width: 1.4),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            // Top Header
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'WHY CHOOSE DM LACE SURAT?',
                  style: pw.TextStyle(
                    fontSize: 7.2,
                    fontWeight: pw.FontWeight.bold,
                    color: goldColor,
                    letterSpacing: 0.8,
                  ),
                ),
                pw.Text(
                  'SURAT LACE HUB',
                  style: pw.TextStyle(
                    fontSize: 5.5,
                    fontWeight: pw.FontWeight.bold,
                    color: subtextColor,
                  ),
                ),
              ],
            ),
            pw.Container(height: 0.6, color: goldColor),

            // 4 Quality Guarantees
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _buildPdfBulletItem('DIRECT LOOM RATES', 'Direct factory loom rates without middleman brokerage.', textColor, goldColor),
                pw.SizedBox(height: 2),
                _buildPdfBulletItem('ALL-INDIA DAILY PARCEL', 'Fast daily transport parcel dispatch across all states.', textColor, goldColor),
                pw.SizedBox(height: 2),
                _buildPdfBulletItem('100% ZARI & COLOR FASTNESS', 'Guaranteed non-tarnish high-tensile metallic thread.', textColor, goldColor),
                pw.SizedBox(height: 2),
                _buildPdfBulletItem('CUSTOM ORDERS & JOBWORK', 'Bulk custom development on sample order basis.', textColor, goldColor),
              ],
            ),

            // Bottom Payment & Address Strip
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: pw.BoxDecoration(
                color: isDarkTheme ? PdfColor.fromHex('#0E223D') : PdfColor.fromHex('#F1F5F9'),
                borderRadius: pw.BorderRadius.circular(4),
                border: pw.Border.all(color: goldColor, width: 0.6),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Payment: Cash • Bank RTGS/NEFT • UPI • Cheque',
                    style: pw.TextStyle(fontSize: 5.0, fontWeight: pw.FontWeight.bold, color: textColor),
                  ),
                  pw.Text(
                    'Ring Road, Surat, Gujarat - 395002',
                    style: pw.TextStyle(fontSize: 5.0, color: subtextColor),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
  }

  void _openEditDialog(LanguageProvider lang) {
    final firmCtrl = TextEditingController(text: _firmName);
    final ownerCtrl = TextEditingController(text: _ownerName);
    final phoneCtrl = TextEditingController(text: _phone);
    final emailCtrl = TextEditingController(text: _email);
    final addrCtrl = TextEditingController(text: _address);
    final gstinCtrl = TextEditingController(text: _gstin);
    final taglineCtrl = TextEditingController(text: _tagline);
    final productsCtrl = TextEditingController(text: _products);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
            left: 16,
            right: 16,
            top: 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      lang.tr(en: 'Edit Business Card Info', hi: 'विज़िटिंग कार्ड जानकारी बदलें'),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.primaryNavy),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const Divider(),
                const SizedBox(height: 8),
                _buildEditField(lang.tr(en: 'Firm / Shop Name', hi: 'दुकान / फर्म का नाम'), firmCtrl),
                const SizedBox(height: 10),
                _buildEditField(lang.tr(en: 'Proprietor Name', hi: 'मालिक का नाम'), ownerCtrl),
                const SizedBox(height: 10),
                _buildEditField(lang.tr(en: 'Phone / WhatsApp', hi: 'फ़ोन / WhatsApp'), phoneCtrl, isPhone: true),
                const SizedBox(height: 10),
                _buildEditField(lang.tr(en: 'Email', hi: 'ईमेल'), emailCtrl),
                const SizedBox(height: 10),
                _buildEditField(lang.tr(en: 'Tagline', hi: 'टैगलाइन'), taglineCtrl),
                const SizedBox(height: 10),
                _buildEditField(lang.tr(en: 'Specialties / Products', hi: 'विशेष उत्पाद / लेस प्रकार'), productsCtrl, maxLines: 2),
                const SizedBox(height: 10),
                _buildEditField(lang.tr(en: 'GSTIN', hi: 'जीएसटी नंबर'), gstinCtrl),
                const SizedBox(height: 10),
                _buildEditField(lang.tr(en: 'Address', hi: 'सूरत दुकान का पता'), addrCtrl, maxLines: 2),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      setState(() {
                        _firmName = firmCtrl.text.trim().isEmpty ? 'DM LACE SURAT' : firmCtrl.text.trim();
                        _ownerName = ownerCtrl.text.trim();
                        _phone = phoneCtrl.text.trim();
                        _email = emailCtrl.text.trim();
                        _tagline = taglineCtrl.text.trim();
                        _products = productsCtrl.text.trim();
                        _gstin = gstinCtrl.text.trim();
                        _address = addrCtrl.text.trim();
                      });
                      _saveDetail('biz_card_firm', _firmName);
                      _saveDetail('biz_card_owner', _ownerName);
                      _saveDetail('biz_card_phone', _phone);
                      _saveDetail('biz_card_email', _email);
                      _saveDetail('biz_card_tagline', _tagline);
                      _saveDetail('biz_card_products', _products);
                      _saveDetail('biz_card_gstin', _gstin);
                      _saveDetail('biz_card_address', _address);
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(lang.tr(en: 'Business Card updated!', hi: 'विज़िटिंग कार्ड अपडेट हो गया!')),
                          backgroundColor: AppColors.successGreen,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryNavy,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      lang.tr(en: 'Save & Update Card', hi: 'सेव करें'),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15),
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

  void _copyDetailsToClipboard(LanguageProvider lang) {
    HapticFeedback.lightImpact();
    final cleanPhone = _phone.replaceAll(RegExp(r'[^0-9]'), '');
    final waLink = 'https://wa.me/$cleanPhone';
    final text = '''
👑 *$_firmName* 👑
$_tagline
सूरत टेक्सटाइल मार्केट • डायरेक्ट लूम
----------------------------------------
🪡 विशेष उत्पाद:
$_products
----------------------------------------
👤 संचालक: $_ownerName
📞 फ़ोन: $_phone
📍 पता: $_address
🏢 GSTIN: $_gstin
✉️ ईमेल: $_email
💬 WhatsApp: $waLink
----------------------------------------
✨ $_firmName • 100% क्वालिटी गारंटी
''';
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          lang.isHindi ? 'विज़िटिंग कार्ड विवरण कॉपी हो गया!' : 'Business Card details copied!',
        ),
        backgroundColor: const Color(0xFF0F172A),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _buildEditField(String label, TextEditingController ctrl, {bool isPhone = false, int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF475569))),
        const SizedBox(height: 4),
        TextField(
          controller: ctrl,
          maxLines: maxLines,
          keyboardType: isPhone ? TextInputType.phone : TextInputType.text,
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final isDesktop = MediaQuery.of(context).size.width >= 700;

    return Scaffold(
      backgroundColor: const Color(0xFF030712),
      appBar: AppBar(
        backgroundColor: const Color(0xFF040A14),
        elevation: 0,
        title: Text(
          lang.tr(en: 'Digital Business Card', hi: '👑 डिजिटल विज़िटिंग कार्ड'),
          style: const TextStyle(color: AppColors.goldLight, fontWeight: FontWeight.w800, fontSize: 16.5),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy_rounded, color: AppColors.goldLight, size: 20),
            tooltip: lang.tr(en: 'Copy Details', hi: 'विवरण कॉपी करें'),
            onPressed: () => _copyDetailsToClipboard(lang),
          ),
          IconButton(
            icon: const Icon(Icons.edit_note_rounded, color: AppColors.goldLight, size: 22),
            tooltip: lang.tr(en: 'Edit Details', hi: 'जानकारी बदलें'),
            onPressed: () => _openEditDialog(lang),
          ),
          IconButton(
            icon: const Icon(Icons.print_rounded, color: AppColors.goldLight, size: 22),
            tooltip: lang.tr(en: 'Print Card', hi: 'प्रिंट करें'),
            onPressed: () => _printOrExportPdf(lang),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: isDesktop ? 60 : 16,
          vertical: 18,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 580),
            child: Column(
              children: [
                // 1. Top Flip Prompt Pill
                InkWell(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    _toggleFlip();
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD4AF37).withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFD4AF37).withValues(alpha: 0.45)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.sync_rounded, color: Color(0xFFFDE047), size: 16),
                        const SizedBox(width: 6),
                        Text(
                          lang.tr(
                            en: _isFront ? 'Tap to flip (View Back Side) ➔' : 'Tap to flip (View Front Side) ➔',
                            hi: _isFront ? 'कार्ड पलटने के लिए टैप करें (Back Side) ➔' : 'सामने का भाग देखने के लिए टैप करें ➔',
                          ),
                          style: const TextStyle(
                            color: Color(0xFFFDE047),
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // 2. 3D Flippable Business Card
                GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    _toggleFlip();
                  },
                  child: AnimatedBuilder(
                    animation: _flipAnimation,
                    builder: (context, child) {
                      final angle = _flipAnimation.value * math.pi;
                      final isUnder = angle > (math.pi / 2);

                      return Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.identity()
                          ..setEntry(3, 2, 0.001)
                          ..rotateY(angle),
                        child: isUnder
                            ? Transform(
                                alignment: Alignment.center,
                                transform: Matrix4.identity()..rotateY(math.pi),
                                child: _buildBackCard(lang),
                              )
                            : _buildFrontCard(lang),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 18),

                // 3. Live Card Themes Bar
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0C192E),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF1E293B)),
                  ),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildThemeChip(CardThemeType.royalGold, '👑 Royal Gold', const Color(0xFFD4AF37)),
                        const SizedBox(width: 6),
                        _buildThemeChip(CardThemeType.emeraldLuxe, '🌿 Emerald Luxe', const Color(0xFF10B981)),
                        const SizedBox(width: 6),
                        _buildThemeChip(CardThemeType.platinumOnyx, '💎 Platinum Onyx', const Color(0xFF38BDF8)),
                        const SizedBox(width: 6),
                        _buildThemeChip(CardThemeType.rubyImperial, '🍷 Ruby Imperial', const Color(0xFFF59E0B)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                // 4. Primary Action Buttons (WhatsApp Share + Print PDF)
                Row(
                  children: [
                    // WhatsApp Share Button
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _shareViaWhatsApp(lang),
                        icon: const Icon(Icons.chat_rounded, color: Colors.white, size: 18),
                        label: Text(
                          lang.tr(en: 'WhatsApp Share', hi: 'WhatsApp शेयर'),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF25D366),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 3,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Print Card Button
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _printOrExportPdf(lang),
                        icon: const Icon(Icons.print_rounded, color: Colors.white, size: 18),
                        label: Text(
                          lang.tr(en: 'Print / PDF', hi: 'प्रिंट / PDF'),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1E3A8A),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 3,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // 5. Secondary Action Buttons (Flip, Edit, Copy)
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          HapticFeedback.selectionClick();
                          _toggleFlip();
                        },
                        icon: const Icon(Icons.flip_camera_android_rounded, color: Color(0xFFFDE047), size: 17),
                        label: Text(
                          lang.tr(en: 'Flip Card', hi: 'कार्ड पलटें'),
                          style: const TextStyle(color: Color(0xFFFDE047), fontWeight: FontWeight.w800, fontSize: 13),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFFD4AF37), width: 1.1),
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _openEditDialog(lang),
                        icon: const Icon(Icons.edit_rounded, color: Colors.white70, size: 17),
                        label: Text(
                          lang.tr(en: 'Edit Info', hi: 'जानकारी बदलें'),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.white24, width: 1.1),
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _copyDetailsToClipboard(lang),
                        icon: const Icon(Icons.copy_all_rounded, color: Color(0xFF38BDF8), size: 17),
                        label: Text(
                          lang.tr(en: 'Copy', hi: 'कॉपी करें'),
                          style: const TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.w700, fontSize: 13),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF0284C7), width: 1.1),
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildThemeChip(CardThemeType theme, String label, Color accent) {
    final isSelected = _selectedTheme == theme;
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _selectedTheme = theme);
      },
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5.5),
        decoration: BoxDecoration(
          color: isSelected ? accent.withValues(alpha: 0.24) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? accent : Colors.transparent,
            width: 1.1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFF94A3B8),
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // FRONT OF BUSINESS CARD (LUXURY FINISH)
  // ===========================================================================
  Widget _buildFrontCard(LanguageProvider lang) {
    final themeColors = _getThemeColors(_selectedTheme);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: themeColors.gradient,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: themeColors.borderColor, width: 1.8),
        boxShadow: [
          BoxShadow(
            color: themeColors.glowColor.withValues(alpha: 0.35),
            blurRadius: 22,
            spreadRadius: 2,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.65),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Holographic Diagonal Gloss Sheen
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: LinearGradient(
                    begin: const Alignment(-1.2, -1.2),
                    end: const Alignment(1.2, 1.2),
                    stops: const [0.0, 0.45, 0.50, 0.55, 1.0],
                    colors: [
                      Colors.transparent,
                      Colors.transparent,
                      Colors.white.withValues(alpha: 0.08),
                      Colors.white.withValues(alpha: 0.03),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Inner Golden Inset Border
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                margin: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: themeColors.accentColor.withValues(alpha: 0.35),
                    width: 0.8,
                  ),
                ),
              ),
            ),
          ),

          // Main Card Content
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // 1. Sanskrit Mantra Header & Dynamic GSTIN
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '॥ श्री गणेशाय नमः ॥',
                      style: TextStyle(
                        color: themeColors.accentColor,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: themeColors.accentColor.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: themeColors.accentColor.withValues(alpha: 0.45), width: 0.8),
                      ),
                      child: Text(
                        'GSTIN: ${_gstin.isNotEmpty ? _gstin : '24AAACD1234M1Z5'}',
                        style: const TextStyle(
                          color: Color(0xFFFFFBEB),
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      '॥ शुभ लाभ ॥',
                      style: TextStyle(
                        color: themeColors.accentColor,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // 2. Brand Emblem + Firm Name + Tagline + Products
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Royal 3D Circular Logo Emblem
                    Container(
                      width: 62,
                      height: 62,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF040A14),
                        border: Border.all(color: themeColors.accentColor, width: 1.8),
                        boxShadow: [
                          BoxShadow(
                            color: themeColors.glowColor.withValues(alpha: 0.4),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: Padding(
                          padding: const EdgeInsets.all(3.0),
                          child: Image.asset(
                            'assets/images/dm_lace_logo.png',
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) => Icon(
                              Icons.workspace_premium_rounded,
                              color: themeColors.primaryColor,
                              size: 32,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _firmName,
                            style: TextStyle(
                              color: themeColors.primaryColor,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.4,
                              fontFamily: 'serif',
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _tagline,
                            style: TextStyle(
                              color: themeColors.subtextColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.4,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _products,
                            style: const TextStyle(
                              color: Color(0xFFCBD5E1),
                              fontSize: 9.5,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // 3. Hairline Divider with Royal Emblem Accent
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 1,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.transparent,
                              themeColors.accentColor.withValues(alpha: 0.6),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(themeColors.icon, style: const TextStyle(fontSize: 12)),
                    ),
                    Expanded(
                      child: Container(
                        height: 1,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              themeColors.accentColor.withValues(alpha: 0.6),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // 4. Contact Details & Live Interactive QR Code
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildContactItem(
                            icon: Icons.person_rounded,
                            text: _ownerName,
                            color: const Color(0xFFF1F5F9),
                            badge: 'Owner',
                          ),
                          const SizedBox(height: 5),
                          _buildContactItem(
                            icon: Icons.phone_rounded,
                            text: _phone,
                            color: themeColors.primaryColor,
                            isPhone: true,
                          ),
                          const SizedBox(height: 5),
                          _buildContactItem(
                            icon: Icons.location_on_rounded,
                            text: _address,
                            color: const Color(0xFFCBD5E1),
                          ),
                          const SizedBox(height: 5),
                          _buildContactItem(
                            icon: Icons.email_rounded,
                            text: _email,
                            color: const Color(0xFF94A3B8),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 70,
                          height: 70,
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: themeColors.accentColor, width: 1.5),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.3),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                          child: CustomPaint(
                            painter: _QrPainter(
                              data: 'https://wa.me/${_phone.replaceAll(RegExp(r'[^0-9]'), '')}?text=${Uri.encodeComponent('Namaste $_firmName, I am contacting you via your Digital Business Card.')}',
                            ),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: themeColors.accentColor.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'SCAN TO CHAT',
                            style: TextStyle(
                              color: themeColors.primaryColor,
                              fontSize: 8,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ),
                      ],
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

  // ===========================================================================
  // BACK OF BUSINESS CARD (MANUFACTURING GUARANTEES)
  // ===========================================================================
  Widget _buildBackCard(LanguageProvider lang) {
    final themeColors = _getThemeColors(_selectedTheme);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: themeColors.gradient,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: themeColors.borderColor, width: 1.8),
        boxShadow: [
          BoxShadow(
            color: themeColors.glowColor.withValues(alpha: 0.35),
            blurRadius: 22,
            spreadRadius: 2,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.65),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Holographic Sheen
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: LinearGradient(
                    begin: const Alignment(-1.2, -1.2),
                    end: const Alignment(1.2, 1.2),
                    stops: const [0.0, 0.45, 0.50, 0.55, 1.0],
                    colors: [
                      Colors.transparent,
                      Colors.transparent,
                      Colors.white.withValues(alpha: 0.08),
                      Colors.white.withValues(alpha: 0.03),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Inset Border
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                margin: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: themeColors.accentColor.withValues(alpha: 0.35),
                    width: 0.8,
                  ),
                ),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      lang.tr(
                        en: 'WHY CHOOSE ${_firmName.toUpperCase()}?',
                        hi: '${_firmName.toUpperCase()} क्यों चुनें?',
                      ),
                      style: TextStyle(
                        color: themeColors.primaryColor,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.0,
                      ),
                    ),
                    Text(themeColors.icon, style: const TextStyle(fontSize: 15)),
                  ],
                ),
                const SizedBox(height: 10),

                // 4 Manufacturing Guarantees
                _buildGuaranteeRow(
                  themeColors: themeColors,
                  icon: Icons.precision_manufacturing_rounded,
                  title: lang.tr(en: 'Direct Loom Rates', hi: 'करघा रेट (No Brokerage)'),
                  subtitle: lang.tr(en: 'Direct factory loom pricing without middlemen.', hi: 'बिचौलियों के बिना सीधे लूम की फैक्ट्री दरें।'),
                ),
                const SizedBox(height: 7),
                _buildGuaranteeRow(
                  themeColors: themeColors,
                  icon: Icons.local_shipping_rounded,
                  title: lang.tr(en: 'All-India Daily Parcel', hi: 'अखिल भारतीय डिलीवरी'),
                  subtitle: lang.tr(en: 'Daily transport parcel dispatch from Surat.', hi: 'सूरत से सभी राज्यों में तेज़ ट्रांसपोर्ट बुकिंग।'),
                ),
                const SizedBox(height: 7),
                _buildGuaranteeRow(
                  themeColors: themeColors,
                  icon: Icons.verified_rounded,
                  title: lang.tr(en: '100% Zari & Color Fastness', hi: '100% ज़री व रंग गारंटी'),
                  subtitle: lang.tr(en: 'Guaranteed non-tarnish high-tensile metallic thread.', hi: 'बिना काला पड़े लम्बी चमक एवं पक्के रंग।'),
                ),
                const SizedBox(height: 7),
                _buildGuaranteeRow(
                  themeColors: themeColors,
                  icon: Icons.design_services_rounded,
                  title: lang.tr(en: 'Custom Orders & Jobwork', hi: 'कस्टम डिज़ाइन ऑर्डर'),
                  subtitle: lang.tr(en: 'Bulk custom development as per sample request.', hi: 'मांग के अनुसार नया डिज़ाइन तैयार करने की सुविधा।'),
                ),
                const SizedBox(height: 12),

                // Payment Strip
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: themeColors.accentColor.withValues(alpha: 0.35)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.account_balance_rounded, size: 16, color: Color(0xFF38BDF8)),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                lang.tr(en: 'Bank / UPI Payment Accepted', hi: 'बैंक व UPI पेमेंट स्वीकार्य'),
                                style: const TextStyle(color: Color(0xFFFFFBEB), fontSize: 11, fontWeight: FontWeight.w800),
                              ),
                              Text(
                                'GPay / PhonePe / RTGS / NEFT / Cheque / Cash',
                                style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 9.5),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const Icon(Icons.check_circle_rounded, size: 16, color: Color(0xFF4ADE80)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactItem({
    required IconData icon,
    required String text,
    required Color color,
    String? badge,
    bool isPhone = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 13, color: isPhone ? const Color(0xFFFDE047) : const Color(0xFF94A3B8)),
        const SizedBox(width: 6),
        Expanded(
          child: Row(
            children: [
              Flexible(
                child: Text(
                  text,
                  style: TextStyle(
                    color: color,
                    fontSize: 10.5,
                    fontWeight: isPhone ? FontWeight.w800 : FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (badge != null) ...[
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0284C7).withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.5), width: 0.5),
                  ),
                  child: Text(
                    badge,
                    style: const TextStyle(color: Color(0xFFBAE6FD), fontSize: 8.5, fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGuaranteeRow({
    required _ThemePalette themeColors,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: themeColors.accentColor.withValues(alpha: 0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 13, color: themeColors.primaryColor),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(color: Color(0xFFFFFBEB), fontSize: 11, fontWeight: FontWeight.w800),
              ),
              Text(
                subtitle,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.65), fontSize: 9.5),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// Lightweight Dynamic QR Canvas Painter
class _QrPainter extends CustomPainter {
  final String data;
  _QrPainter({required this.data});

  @override
  void paint(Canvas canvas, Size size) {
    try {
      QrCode? qrCode;
      for (int v = 1; v <= 10; v++) {
        try {
          qrCode = QrCode(v, QrErrorCorrectLevel.M)..addData(data);
          break;
        } catch (_) {}
      }
      qrCode ??= (QrCode(4, QrErrorCorrectLevel.L)..addData(data));

      final qrImage = QrImage(qrCode);
      final moduleCount = qrImage.moduleCount;
      final pixelSize = size.width / moduleCount;

      final paint = Paint()..color = const Color(0xFF040A14);

      for (int x = 0; x < moduleCount; x++) {
        for (int y = 0; y < moduleCount; y++) {
          if (qrImage.isDark(y, x)) {
            canvas.drawRect(
              Rect.fromLTWH(x * pixelSize, y * pixelSize, pixelSize, pixelSize),
              paint,
            );
          }
        }
      }
    } catch (_) {
      // Fallback box with QR icon
      final paint = Paint()..color = const Color(0xFF040A14);
      canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
