import 'package:intl/intl.dart';

class DateFormatter {
  static final DateFormat _ddMmYyyy = DateFormat('dd-MM-yyyy');
  static final DateFormat _ddMmmYyyy = DateFormat('dd MMM yyyy');
  static final DateFormat _dateTimeFormat = DateFormat('dd-MM-yyyy hh:mm a');
  static final DateFormat _monthYearFormat = DateFormat('MMM yyyy');

  /// Formats DateTime to Indian standard DD-MM-YYYY
  static String format(DateTime? date) {
    if (date == null) return '-';
    return _ddMmYyyy.format(date);
  }

  /// Formats DateTime to readable DD MMM YYYY (e.g. 25 Oct 2026)
  static String formatReadable(DateTime? date) {
    if (date == null) return '-';
    return _ddMmmYyyy.format(date);
  }

  /// Formats DateTime with time (e.g. 25-10-2026 09:30 AM)
  static String formatWithTime(DateTime? date) {
    if (date == null) return '-';
    return _dateTimeFormat.format(date);
  }

  /// Formats Month & Year (e.g. Oct 2026)
  static String formatMonthYear(DateTime? date) {
    if (date == null) return '-';
    return _monthYearFormat.format(date);
  }

  /// Parses string in DD-MM-YYYY or ISO-8601 format to DateTime
  static DateTime? parse(String? dateStr) {
    if (dateStr == null || dateStr.trim().isEmpty) return null;
    try {
      if (dateStr.contains('-') && dateStr.length == 10 && dateStr.indexOf('-') == 2) {
        return _ddMmYyyy.parse(dateStr);
      }
      return DateTime.parse(dateStr);
    } catch (_) {
      return null;
    }
  }

  /// ISO 8601 string for SQLite storage
  static String toIso(DateTime date) {
    return date.toIso8601String();
  }

  /// Returns today formatted as DD-MM-YYYY
  static String today() {
    return _ddMmYyyy.format(DateTime.now());
  }

  /// Computes days difference from today (positive = overdue)
  static int daysOverdue(DateTime dueDate) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(dueDate.year, dueDate.month, dueDate.day);
    return today.difference(due).inDays;
  }
}
