import 'package:intl/intl.dart';

/// Parses a JSON value into a double. Handles num and Prisma Decimal (String).
double asDouble(dynamic v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? 0.0;
  return 0.0;
}

class Money {
  /// Amounts are stored as Decimal(14, 2), so anything shown has to be able to
  /// carry two decimals — rounding here used to hide the cents the user had
  /// just typed, which made decimal entry look broken even when it saved fine.
  ///
  /// Whole amounts stay clean: 2000 reads "2 000", not "2 000,00". Most
  /// amounts in XOF are whole, and padding every one of them with ",00" is
  /// noise that makes the few real decimals harder to spot.
  static bool _isWhole(num amount) => amount == amount.roundToDouble();

  static String _grouped(num amount) {
    final pattern = _isWhole(amount) ? '#,##0' : '#,##0.00';
    return NumberFormat(pattern, dateLocale).format(amount);
  }

  static String format(num amount, [String currency = 'XOF']) {
    final symbol = currency == 'XOF' ? 'FCFA' : currency;
    return '${_grouped(amount)} $symbol';
  }

  /// Grouped digits without a currency symbol, e.g. "421 500" or "421 500,21".
  static String number(num amount) => _grouped(amount);

  /// Short form for dense rows and chart labels.
  ///
  /// Prefer [AmountText] over calling this directly: it only abbreviates when
  /// the full number genuinely does not fit, which is almost always the better
  /// answer. This is the fallback for places with no width to measure, such as
  /// chart axis labels.
  ///
  /// Below [_compactFloor] the full number is returned. Abbreviating small
  /// amounts loses more than it saves — a 2 500 FCFA lunch rendered as "3k" is
  /// both rounded and harder to read than "2 500".
  static String compact(num amount) {
    final abs = amount.abs();
    if (abs < _compactFloor) return _grouped(amount);

    // Largest tier first, so the shortest representation is found directly.
    final tiers = _tiers;
    for (var i = 0; i < tiers.length; i++) {
      final (threshold, suffix) = tiers[i];
      if (abs < threshold) continue;

      var text = _scaleTo(amount, threshold);
      // Rounding can push a value up into the next tier: 999 500 scales to
      // 999.5, which renders as "1000" and must become "1 M", not "1000 k".
      // Tiers are ordered largest first, so promoting means stepping back.
      if (double.parse(text).abs() >= 1000 && i > 0) {
        final promoted = tiers[i - 1];
        text = _scaleTo(amount, promoted.$1);
        return '${_decimalSeparator(text)} ${promoted.$2}';
      }
      return '${_decimalSeparator(text)} $suffix';
    }
    return _grouped(amount);
  }

  /// One decimal below ten units ("1,2 M"), none above ("12 M") — past ten the
  /// decimal is noise rather than information.
  static String _scaleTo(num amount, double threshold) {
    final scaled = amount / threshold;
    var text =
        scaled.abs() < 10 ? scaled.toStringAsFixed(1) : scaled.toStringAsFixed(0);
    if (text.endsWith('.0')) text = text.substring(0, text.length - 2);
    return text;
  }

  static String _decimalSeparator(String text) =>
      _fr ? text.replaceAll('.', ',') : text;

  /// Ordered largest first so the loop picks the shortest representation.
  static const List<(double, String)> _tiersEn = [
    (1e12, 'T'),
    (1e9, 'B'),
    (1e6, 'M'),
    (1e3, 'k'),
  ];

  /// French uses "Md" for milliard; "B" would read as billion = 10¹².
  static const List<(double, String)> _tiersFr = [
    (1e12, 'Bn'),
    (1e9, 'Md'),
    (1e6, 'M'),
    (1e3, 'k'),
  ];

  static bool get _fr => dateLocale.startsWith('fr');
  static List<(double, String)> get _tiers => _fr ? _tiersFr : _tiersEn;

  /// Below this, the full number is short enough to be worth showing.
  static const double _compactFloor = 10000;

  /// The compact form with its currency, e.g. "1,2 M FCFA".
  static String compactWith(num amount, [String currency = 'XOF']) {
    final symbol = currency == 'XOF' ? 'FCFA' : currency;
    return '${compact(amount)} $symbol';
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

  /// Clock time only, e.g. "07:00".
  static String hourMinute(DateTime d) =>
      DateFormat('HH:mm', dateLocale).format(d);

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
