import '../../models/inventory_item.dart';
import '../utils/currency_formatter.dart';

enum PitchStyle {
  wholesaleB2B,     // For Surat traders, shopkeepers, wholesale agents
  boutiqueDesigner, // For fashion designers, boutique owners, tailors
  weddingRush,      // For festive, Diwali, Eid, and wedding season urgency
}

class AiCatalogAssistant {
  /// Generates high-converting marketing pitches tailored for Surat lace business
  static String generateMarketingPitch(
    InventoryItem item, {
    PitchStyle style = PitchStyle.wholesaleB2B,
    bool isHindi = true,
  }) {
    final rate = CurrencyFormatter.format(item.sellingRateRupees);
    final unit = item.unit;
    final code = item.designCode;
    final name = item.itemName;
    final cat = item.category ?? (isHindi ? 'सूरत फैंसी लेस' : 'Surat Fancy Lace');
    final colors = item.colors ?? (isHindi ? 'गोल्डन, सिल्वर व फैंसी शेड्स' : 'Golden, Silver & Fancy Shades');
    final width = item.width ?? (isHindi ? 'मानक पन्ना' : 'Standard');
    final stock = item.currentStock.toStringAsFixed(0);

    if (isHindi) {
      switch (style) {
        case PitchStyle.wholesaleB2B:
          return '''*DM LACE SURAT*
थोक बाज़ार • रिंग रोड, सूरत
----------------------------------------
डिज़ाइन कोड: $code
आइटम: $name
श्रेणी: $cat | पन्ना: $width
रंग उपलब्ध: $colors
होलसेल भाव: $rate / $unit
उपलब्ध स्टॉक: $stock $unit (तुरंत डिस्पैच)
----------------------------------------
ऑल इंडिया पार्सल व ट्रांसपोर्ट सुविधा उपलब्ध
ऑर्डर व थान बुकिंग हेतु WhatsApp पर संपर्क करें!''';

        case PitchStyle.boutiqueDesigner:
          return '''*DM LACE SURAT*
बुटीक कलेक्शन • रिंग रोड, सूरत
----------------------------------------
डिज़ाइन: $name ($code)
वैरायटी: $cat | पन्ना: $width
कलर शेड्स: $colors
उपयोग: लहँगा, साड़ी, गाउन व सूट
बुटीक रेट: $rate / $unit
उपलब्ध स्टॉक: $stock $unit (रोल व कट उपलब्ध)
----------------------------------------
सैम्पल व आर्डर बुकिंग हेतु WhatsApp पर संपर्क करें!''';

        case PitchStyle.weddingRush:
          return '''*DM LACE SURAT*
वेडिंग व फेस्टिव स्पेशल कलेक्शन
----------------------------------------
डिज़ाइन नंबर: $code - $name
वैरायटी: $cat | पन्ना: $width
शेड्स: $colors
स्पेशल भाव: $rate / $unit
सीमित स्टॉक: $stock $unit रेडी
----------------------------------------
तुरंत टोकन देकर अपना स्टॉक सुरक्षित करें!''';
      }
    } else {
      switch (style) {
        case PitchStyle.wholesaleB2B:
          return '''*DM LACE SURAT*
Wholesale Market • Ring Road, Surat
----------------------------------------
Design Code: $code
Item: $name
Category: $cat | Width: $width
Available Colors: $colors
Wholesale Rate: $rate / $unit
Ready Stock: $stock $unit (Immediate Dispatch)
----------------------------------------
All India Parcel & Transport Dispatch Available
Contact on WhatsApp to place orders!''';

        case PitchStyle.boutiqueDesigner:
          return '''*DM LACE SURAT*
Boutique Collection • Ring Road, Surat
----------------------------------------
Design: $name ($code)
Type: $cat | Width: $width
Available Colors: $colors
Application: Lehengas, Sarees, Gowns & Suits
Rate: $rate / $unit
Ready Stock: $stock $unit (Full Rolls & Cuts)
----------------------------------------
Contact on WhatsApp for samples & booking!''';

        case PitchStyle.weddingRush:
          return '''*DM LACE SURAT*
Wedding & Festive Collection
----------------------------------------
Design No: $code - $name
Category: $cat | Width: $width
Colors: $colors
Special Price: $rate / $unit
Available Stock: $stock $unit Ready
----------------------------------------
Confirm booking now on WhatsApp!''';
      }
    }
  }

  /// AI Garment Pairings & Recommendations
  static List<String> getGarmentPairings(InventoryItem item) {
    final cat = (item.category ?? '').toLowerCase();
    final name = item.itemName.toLowerCase();

    if (cat.contains('gota') || name.contains('gota')) {
      return [
        'Rajasthani Poshaak & Rajputi Chundadi',
        'Bridal Lehenga Gher & Kali Work',
        'Festive Georgette & Bandhani Sarees',
        'Traditional Kurti Sleeves & Daman Border',
      ];
    } else if (cat.contains('sequence') || name.contains('sequin')) {
      return [
        'Cocktail & Reception Evening Gowns',
        'Bollywood Style Net & Organza Sarees',
        'Glamour Velvet Blouse Necklines',
        'Partywear Dupatta 4-Side Framing',
      ];
    } else if (cat.contains('crochet') || cat.contains('cotton') || name.contains('cotton')) {
      return [
        'Pure Cotton & Linen Summer Kurtas',
        'Chanderi Silk Dupatta Edging',
        'Pakistani Style Lawn Suits',
        'Boutique Sleeves & Pant Hemlines',
      ];
    } else if (cat.contains('velvet') || name.contains('velvet')) {
      return [
        'Heavy Winter Bridal Velvet Shawls',
        'Royal Sherwani Collar & Cuffs',
        'Raw Silk Bridal Lehenga Borders',
        'Embroidered Blouse Border Panels',
      ];
    } else {
      return [
        'Heavy Silk & Banarasi Sarees',
        'Bridal Dupatta Borders (4-Side Patti)',
        'Traditional Anarkali Suit Bottoms',
        'Festive Koti / Jacket Borders',
      ];
    }
  }

  /// AI Margin & Profit Calculation Insights
  static Map<String, dynamic> calculateMarginInsights(InventoryItem item) {
    final purchase = item.purchaseRateRupees;
    final selling = item.sellingRateRupees;
    final profitPerUnit = selling - purchase;
    final marginPercent = purchase > 0 ? ((profitPerUnit / purchase) * 100) : 35.0;
    final rollStock = (item.currentStock / (item.unit == 'roll' ? 1 : 9.0)).floor();
    final inventoryValue = item.currentStock * selling;

    return {
      'profitPerUnit': profitPerUnit > 0 ? profitPerUnit : 15.0,
      'marginPercent': marginPercent.clamp(10.0, 150.0).toStringAsFixed(1),
      'suggestedRetailMrp': (selling * 1.5).toStringAsFixed(0),
      'wholesaleBundleDiscountRate': (selling * 0.92).toStringAsFixed(1),
      'rollsEquivalent': rollStock > 0 ? rollStock : 1,
      'totalAssetValue': inventoryValue,
    };
  }

  /// AI Auto-Generated Design Code
  static String generateSmartDesignCode(String category) {
    final prefix = switch (category) {
      'Zari Border' => 'ZARI',
      'Gota Patti' => 'GOTA',
      'Sequence Work' => 'SEQ',
      'Cotton Crochet' => 'COT',
      'Latkan & Dori' => 'LAT',
      'Velvet & Net' => 'VEL',
      'Dupatta Border' => 'DUP',
      _ => 'DM',
    };
    final num = DateTime.now().millisecondsSinceEpoch % 900 + 100;
    return '$prefix-$num';
  }
}
