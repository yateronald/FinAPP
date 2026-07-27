import 'package:intl/intl.dart';

/// Parses a JSON value into a double. Handles num and Prisma Decimal (String).
double asDouble(dynamic v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? 0.0;
  return 0.0;
}

class Money {
  static String format(num amount, [String currency = 'XOF']) {
    final formatted = NumberFormat.decimalPattern(dateLocale).format(amount.round());
    final symbol = currency == 'XOF' ? 'FCFA' : currency;
    return '$formatted $symbol';
  }

  /// Grouped digits without a currency symbol, e.g. "421 500".
  static String number(num amount) =>
      NumberFormat.decimalPattern(dateLocale).format(amount.round());

  static String compact(num amount) {
    if (amount.abs() >= 1000000) {
      return '${(amount / 1000000).toStringAsFixed(amount.abs() >= 10000000 ? 0 : 1)}M';
    }
    if (amount.abs() >= 1000) return '${(amount / 1000).round()}K';
    return amount.round().toString();
  }
}

/// Active locale for date formatting; kept in sync with the UI language.
String dateLocale = 'fr';

class Dates {
  static String short(DateTime d) => DateFormat('d MMM y', dateLocale).format(d);

  /// Date + time, e.g. "25 juil. 2026 à 15:04" / "25 Jul 2026 at 15:04".
  static String shortWithTime(DateTime d) {
    final date = DateFormat('d MMM y', dateLocale).format(d);
    final time = DateFormat('HH:mm', dateLocale).format(d);
    return '$date ${dateLocale.startsWith('fr') ? 'à' : 'at'} $time';
  }

  /// Relative label for recent items ("Il y a 5 min"), falling back to the
  /// absolute date+time for anything older than a day.
  static String relative(DateTime d) {
    final diff = DateTime.now().difference(d);
    final fr = dateLocale.startsWith('fr');
    if (diff.inMinutes < 1) return fr ? "À l'instant" : 'Just now';
    if (diff.inMinutes < 60) {
      return fr ? 'Il y a ${diff.inMinutes} min' : '${diff.inMinutes} min ago';
    }
    if (diff.inHours < 24) {
      return fr ? 'Il y a ${diff.inHours} h' : '${diff.inHours} h ago';
    }
    return shortWithTime(d);
  }
  static String monthYear(DateTime d) {
    final s = DateFormat('MMMM y', dateLocale).format(d);
    return s[0].toUpperCase() + s.substring(1);
  }

  static String monthShort(int month) {
    final s = DateFormat('MMM', dateLocale).format(DateTime(2020, month));
    return s[0].toUpperCase() + s.substring(1);
  }

  /// Full month name (handles 0/13 wraparound), capitalized. E.g. 6 → "Juin".
  static String monthFull(int month) {
    final normalized = DateTime(2020, month);
    final s = DateFormat('MMMM', dateLocale).format(normalized);
    return s[0].toUpperCase() + s.substring(1);
  }

  static String iso(DateTime d) => DateFormat('yyyy-MM-dd').format(d);
}

String percentLabel(num v) {
  final sign = v > 0 ? '+' : '';
  return '$sign$v%';
}
