import 'package:flutter/services.dart';

/// Everything an amount field needs to accept decimals correctly.
///
/// Amounts are stored as `Decimal(14, 2)`, so two decimal places is the real
/// contract — this enforces it at the keyboard rather than letting the database
/// silently round a third digit away.
///
/// Both `.` and `,` are accepted as the separator. A French keyboard puts a
/// comma on the decimal key, and the app's own display uses a comma in French,
/// so refusing it means the number the user reads back cannot be retyped.
class MoneyInput {
  MoneyInput._();

  /// Digits, one separator, at most two decimals.
  static const int decimals = 2;

  static List<TextInputFormatter> get formatters =>
      const [_DecimalAmountFormatter(decimals)];

  static const TextInputType keyboard =
      TextInputType.numberWithOptions(decimal: true);

  /// Parses what the user typed, accepting either separator and ignoring the
  /// group spacing our own formatter produces elsewhere.
  ///
  /// Returns null when there is no number, so callers can tell "empty" from
  /// "zero" — the difference between an untouched field and a deliberate 0.
  static double? tryParse(String? raw) {
    if (raw == null) return null;
    // Non-breaking and narrow no-break spaces come from NumberFormat's French
    // grouping; a plain replaceAll(' ') would miss them.
    var s = raw.replaceAll(RegExp(r'[\s  ]'), '').replaceAll(',', '.');
    if (s.isEmpty) return null;
    // Keep the last separator only, so a pasted "1.234.56" still resolves.
    final lastDot = s.lastIndexOf('.');
    if (lastDot >= 0) {
      s = s.substring(0, lastDot).replaceAll('.', '') + s.substring(lastDot);
    }
    final value = double.tryParse(s);
    if (value == null || value.isNaN || value.isInfinite) return null;
    return value;
  }

  /// [tryParse] with a default, for the many call sites that treat a blank
  /// field as zero.
  static double parseOr(String? raw, [double fallback = 0]) =>
      tryParse(raw) ?? fallback;

  /// Rounds to the stored precision. Applied before sending so the client and
  /// the database agree on the value — otherwise 10.005 is saved as 10.01 and
  /// the app keeps showing 10.005 until the next refresh.
  static double round(double value) {
    final factor = 100.0; // 10^decimals
    return (value * factor).roundToDouble() / factor;
  }

  /// Plain text for prefilling an edit field: no grouping (it would have to be
  /// stripped again on save) and no trailing ".00" on a whole amount.
  ///
  /// Uses '.' so the result always round-trips through [tryParse] regardless of
  /// the active locale.
  static String forEditing(num? value) {
    if (value == null) return '';
    final rounded = round(value.toDouble());
    if (rounded == rounded.roundToDouble()) return rounded.toStringAsFixed(0);
    return rounded
        .toStringAsFixed(decimals)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }
}

/// Allows digits and a single decimal separator, capped at [decimals] places.
///
/// Written as a formatter rather than a validator so the field simply cannot
/// hold an impossible amount — by the time the user presses save there is
/// nothing left to reject.
class _DecimalAmountFormatter extends TextInputFormatter {
  const _DecimalAmountFormatter(this.decimals);
  final int decimals;

  static bool _isDigit(String ch) {
    final c = ch.codeUnitAt(0);
    return c >= 0x30 && c <= 0x39;
  }

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    if (text.isEmpty) return newValue;

    // Whichever separator the user pressed becomes *the* separator; a second
    // one is dropped rather than replacing the first, so the caret does not
    // jump around mid-typing.
    final buffer = StringBuffer();
    var seenSeparator = false;
    var decimalsSoFar = 0;
    var removed = 0;

    for (final ch in text.split('')) {
      if (ch == '.' || ch == ',') {
        if (seenSeparator) {
          removed++;
          continue;
        }
        seenSeparator = true;
        buffer.write(ch);
        continue;
      }
      if (_isDigit(ch)) {
        if (seenSeparator) {
          if (decimalsSoFar >= decimals) {
            removed++;
            continue;
          }
          decimalsSoFar++;
        }
        buffer.write(ch);
        continue;
      }
      removed++; // anything else: letters, symbols, a stray minus
    }

    if (removed == 0) return newValue;
    final out = buffer.toString();
    // Keep the caret where the user left it, minus whatever was dropped ahead
    // of it. Without this it snaps to the end on every rejected keystroke.
    final offset = (newValue.selection.baseOffset - removed).clamp(0, out.length);
    return TextEditingValue(
      text: out,
      selection: TextSelection.collapsed(offset: offset),
    );
  }
}
