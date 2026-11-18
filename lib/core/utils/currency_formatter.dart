import 'package:intl/intl.dart';

class CurrencyFormatter {
  static final NumberFormat _indianFormatWithDecimals = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹ ',
    decimalDigits: 2,
  );

  static final NumberFormat _indianFormatWithoutDecimals = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹ ',
    decimalDigits: 0,
  );

  /// Converts rupees to integer paise to eliminate floating point errors in DB storage
  static int rupeesToPaise(double rupees) {
    return (rupees * 100).round();
  }

  /// Converts paise back to rupees
  static double paiseToRupees(int paise) {
    return paise / 100.0;
  }

  /// Formats double amount into Indian currency format (e.g., ₹ 1,50,000.00)
  static String format(double amount, {bool showDecimals = true, bool includeSymbol = true}) {
    String formatted = showDecimals
        ? _indianFormatWithDecimals.format(amount)
        : _indianFormatWithoutDecimals.format(amount);
    
    if (!includeSymbol) {
      return formatted.replaceFirst('₹ ', '').replaceFirst('₹', '').trim();
    }
    return formatted;
  }

  /// Formats integer paise into Indian currency format
  static String formatPaise(int paise, {bool showDecimals = true, bool includeSymbol = true}) {
    return format(paiseToRupees(paise), showDecimals: showDecimals, includeSymbol: includeSymbol);
  }

  /// Compact representation for dashboard cards (e.g. ₹ 4.5L, ₹ 1.2Cr)
  static String formatCompact(double amount) {
    if (amount.abs() >= 10000000) {
      return '₹ ${(amount / 10000000).toStringAsFixed(2)} Cr';
    } else if (amount.abs() >= 100000) {
      return '₹ ${(amount / 100000).toStringAsFixed(2)} L';
    } else if (amount.abs() >= 1000) {
      return '₹ ${(amount / 1000).toStringAsFixed(1)} k';
    }
    return format(amount, showDecimals: false);
  }

  /// Formats amount and respects privacy mode
  static String formatWithPrivacy(double amount, {bool isPrivacyMode = false, bool showDecimals = true}) {
    if (isPrivacyMode) {
      return '₹ ••••••';
    }
    return format(amount, showDecimals: showDecimals);
  }

  static String formatPaiseWithPrivacy(int paise, {bool isPrivacyMode = false, bool showDecimals = true}) {
    if (isPrivacyMode) {
      return '₹ ••••••';
    }
    return formatPaise(paise, showDecimals: showDecimals);
  }

  /// Parses text input safely to double
  static double parseDouble(String text) {
    if (text.isEmpty) return 0.0;
    final cleaned = text.replaceAll(',', '').replaceAll('₹', '').trim();
    return double.tryParse(cleaned) ?? 0.0;
  }
}
