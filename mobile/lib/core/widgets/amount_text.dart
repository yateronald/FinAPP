import 'package:flutter/material.dart';
import '../utils/formatters.dart';

/// An amount that shows the most information the available width allows.
///
/// The decision is made from measured width rather than from the value, which
/// matters because "large" depends entirely on the currency: 1 000 USD is a
/// month's rent, 1 000 XOF is a coffee, 1 000 JPY is a sandwich. A fixed
/// threshold that suits one is wrong for the others, so there isn't one here.
///
/// It tries, in order of how much it tells the reader:
///   1. `1 200 000 FCFA`   — full, with currency
///   2. `1 200 000`        — full, currency dropped
///   3. `1,2 M FCFA`       — abbreviated, with currency
///   4. `1,2 M`            — abbreviated, bare
///
/// and renders the first that fits. On a wide hero card that is the exact
/// figure; in a cramped table cell it is the abbreviation. Same number, same
/// widget, no per-screen decisions.
///
/// Whenever it falls back to an abbreviation it becomes tappable, revealing the
/// exact amount. That is not a nicety: a finance app must never make a number
/// impossible to read, so abbreviation is only ever allowed to be the *default*
/// view, never the only one.
class AmountText extends StatelessWidget {
  const AmountText({
    super.key,
    required this.amount,
    this.currency = 'XOF',
    this.style,
    this.textAlign,
    this.showCurrency = true,
    this.maxLines = 1,
  });

  final num amount;
  final String currency;
  final TextStyle? style;
  final TextAlign? textAlign;

  /// When false the currency is never shown — for columns that carry it in the
  /// header, where repeating it on every row is noise.
  final bool showCurrency;

  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final effective = style ?? DefaultTextStyle.of(context).style;
    final scaler = MediaQuery.textScalerOf(context);

    final full = Money.format(amount, currency);
    final fullBare = Money.number(amount);
    final short = Money.compactWith(amount, currency);
    final shortBare = Money.compact(amount);

    // Most informative first; the first that fits wins.
    final candidates = showCurrency
        ? <String>[full, fullBare, short, shortBare]
        : <String>[fullBare, shortBare];

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        var chosen = candidates.last;

        // Unbounded width (a Row without Expanded, a horizontal scroll view)
        // means nothing is squeezing us, so show everything.
        if (maxWidth.isFinite) {
          for (final candidate in candidates) {
            if (_fits(candidate, effective, scaler, maxWidth)) {
              chosen = candidate;
              break;
            }
          }
        } else {
          chosen = candidates.first;
        }

        final text = Text(
          chosen,
          maxLines: maxLines,
          overflow: TextOverflow.ellipsis,
          textAlign: textAlign,
          style: style,
        );

        // Exact already on screen — nothing to reveal.
        if (chosen == full || chosen == fullBare) return text;

        return Tooltip(
          message: full,
          // Tap rather than long-press: the affordance has to be discoverable,
          // and nobody long-presses a number to see if something happens.
          triggerMode: TooltipTriggerMode.tap,
          preferBelow: false,
          showDuration: const Duration(seconds: 3),
          child: text,
        );
      },
    );
  }

  static bool _fits(
    String text,
    TextStyle style,
    TextScaler scaler,
    double maxWidth,
  ) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      maxLines: 1,
      textScaler: scaler,
      textDirection: TextDirection.ltr,
    )..layout();
    return painter.width <= maxWidth;
  }
}
