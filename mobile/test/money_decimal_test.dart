import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fintrack/core/utils/formatters.dart';
import 'package:fintrack/core/utils/money_input.dart';

/// Amounts are stored as Decimal(14, 2). These pin the two halves that were
/// broken: the keyboard refusing a separator, and the display rounding away
/// whatever did get stored.
void main() {
  group('parsing what the user typed', () {
    test('accepts a dot', () => expect(MoneyInput.tryParse('2000.21'), 2000.21));
    test('accepts a comma — the French decimal key',
        () => expect(MoneyInput.tryParse('2000,21'), 2000.21));
    test('ignores grouping spaces from our own formatter', () {
      expect(MoneyInput.tryParse('2 000,21'), 2000.21);
      expect(MoneyInput.tryParse('2 000,21'), 2000.21); // non-breaking
      expect(MoneyInput.tryParse('2 000,21'), 2000.21); // narrow no-break
    });
    test('resolves a pasted fully-grouped number',
        () => expect(MoneyInput.tryParse('1.234.56'), 1234.56));
    test('blank is null, not zero — an untouched field is not a deliberate 0', () {
      expect(MoneyInput.tryParse(''), isNull);
      expect(MoneyInput.tryParse(null), isNull);
      expect(MoneyInput.tryParse('abc'), isNull);
    });
    test('zero is a real value', () => expect(MoneyInput.tryParse('0'), 0));
  });

  group('rounding to the stored precision', () {
    test('keeps two decimals', () => expect(MoneyInput.round(2000.21), 2000.21));
    test('rounds a third away', () => expect(MoneyInput.round(10.005), 10.01));
    test('leaves whole amounts alone', () => expect(MoneyInput.round(2000), 2000));
  });

  group('prefilling an edit field', () {
    test('a whole amount has no trailing zeros',
        () => expect(MoneyInput.forEditing(2000), '2000'));
    test('a decimal amount keeps its cents',
        () => expect(MoneyInput.forEditing(2000.21), '2000.21'));
    test('a single decimal is not padded',
        () => expect(MoneyInput.forEditing(2000.5), '2000.5'));
    test('null is empty', () => expect(MoneyInput.forEditing(null), ''));
    test('round-trips back through the parser', () {
      for (final v in [2000.21, 2000.5, 2000.0, 0.05, 999999.99]) {
        expect(MoneyInput.tryParse(MoneyInput.forEditing(v)), v, reason: '$v');
      }
    });
  });

  group('display no longer rounds decimals away', () {
    setUp(() => dateLocale = 'fr');

    test('cents survive formatting', () {
      expect(Money.format(2000.21), contains('21'));
      expect(Money.number(2000.21), contains('21'));
    });
    test('whole amounts stay clean — no ",00" noise', () {
      expect(Money.number(2000), isNot(contains(',00')));
      expect(Money.number(2000), isNot(contains('.00')));
    });
    test('the currency symbol is still appended',
        () => expect(Money.format(2000.21), endsWith('FCFA')));
    test('compact keeps cents below 1000, drops them above', () {
      expect(Money.compact(12.34), contains('34'));
      expect(Money.compact(2500), '3K');
    });
  });

  group('the field cannot hold an impossible amount', () {
    // The formatter is the guard: by the time save runs there is nothing left
    // to reject, which is why none of these need a validator.
    TextEditingValue v(String s) =>
        TextEditingValue(text: s, selection: TextSelection.collapsed(offset: s.length));
    String apply(String previous, String next) {
      final f = MoneyInput.formatters.first;
      return f.formatEditUpdate(v(previous), v(next)).text;
    }

    test('a decimal passes through', () => expect(apply('2000.2', '2000.21'), '2000.21'));
    test('a comma passes through', () => expect(apply('2000,2', '2000,21'), '2000,21'));
    test('a third decimal is refused',
        () => expect(apply('2000.21', '2000.219'), '2000.21'));
    test('a second separator is refused',
        () => expect(apply('2000.21', '2000.21.'), '2000.21'));
    test('a comma after a dot is refused',
        () => expect(apply('2000.21', '2000.21,'), '2000.21'));
    test('letters and symbols are refused',
        () => expect(apply('2000', '2000a-!'), '2000'));
    test('digits before the separator are unlimited',
        () => expect(apply('123456789', '1234567890'), '1234567890'));
  });
}
