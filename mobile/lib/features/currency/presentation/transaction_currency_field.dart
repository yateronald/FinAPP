import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/i18n/app_text.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/form_kit.dart';
import '../data/currency_models.dart';
import '../providers/currency_provider.dart';
import 'currency_picker_sheet.dart';

/// Currency selector for a transaction, with a live "what this becomes" line.
///
/// Only appears once the user picks something other than their base currency,
/// so the common case — everything in one currency — stays a single tap of
/// nothing at all.
///
/// The preview is advisory. The server converts again on save using the same
/// rates, and its answer is the one stored; showing a number here that the
/// client computed itself would eventually disagree with the ledger.
class TransactionCurrencyField extends ConsumerStatefulWidget {
  const TransactionCurrencyField({
    super.key,
    required this.baseCurrency,
    required this.selected,
    required this.amount,
    required this.onChanged,
    this.accent = AppColors.primary,
  });

  /// The user's default currency — what the amount is stored in.
  final String baseCurrency;

  /// Currently chosen currency; equal to [baseCurrency] means no conversion.
  final String selected;

  /// The amount as currently typed, used for the preview.
  final double amount;

  final ValueChanged<String> onChanged;
  final Color accent;

  @override
  ConsumerState<TransactionCurrencyField> createState() =>
      _TransactionCurrencyFieldState();
}

class _TransactionCurrencyFieldState
    extends ConsumerState<TransactionCurrencyField> {
  Conversion? _preview;
  Timer? _debounce;
  bool _loading = false;

  bool get _isForeign =>
      widget.selected.toUpperCase() != widget.baseCurrency.toUpperCase();

  @override
  void didUpdateWidget(TransactionCurrencyField old) {
    super.didUpdateWidget(old);
    if (old.amount != widget.amount || old.selected != widget.selected) {
      _schedulePreview();
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  /// Debounced: the amount field fires on every keystroke, and each one would
  /// otherwise be a round trip.
  void _schedulePreview() {
    _debounce?.cancel();
    if (!_isForeign || widget.amount <= 0) {
      setState(() => _preview = null);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), _loadPreview);
  }

  Future<void> _loadPreview() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final c = await ref.read(currencyRepositoryProvider).convert(
            amount: widget.amount,
            from: widget.selected,
            to: widget.baseCurrency,
          );
      if (mounted) setState(() => _preview = c);
    } catch (_) {
      // A failed preview is not an error the user needs to act on — the save
      // path handles missing rates on its own.
      if (mounted) setState(() => _preview = null);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _age(BuildContext context, int minutes) {
    final t = context.t;
    return minutes >= 60
        ? t.currencyAgeHours(minutes ~/ 60)
        : t.currencyAgeMinutes(minutes);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final status = ref.watch(fxStatusProvider).value;
    final preview = _preview;

    return Padding(
      padding: const EdgeInsets.only(bottom: FormKit.cardGap),
      child: Container(
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(FormKit.cardRadius),
        ),
        child: Column(
          children: [
            InkWell(
              onTap: () async {
                final picked = await showCurrencyPicker(
                  context,
                  selected: widget.selected,
                  title: t.currencyOfTransaction,
                );
                if (picked != null) widget.onChanged(picked);
              },
              borderRadius: BorderRadius.circular(FormKit.cardRadius),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                child: Row(
                  children: [
                    Container(
                      width: FormKit.iconTile,
                      height: FormKit.iconTile,
                      decoration: BoxDecoration(
                        color: widget.accent
                            .withValues(alpha: context.isDark ? 0.20 : 0.11),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(Icons.public_rounded,
                          size: 23, color: widget.accent),
                    ),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(t.currencyOfTransaction,
                              style: const TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 2),
                          Text(
                            widget.selected,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.expand_more_rounded, color: context.muted),
                  ],
                ),
              ),
            ),

            // Everything below is only meaningful for a foreign currency.
            if (_isForeign)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: _PreviewLine(
                  loading: _loading,
                  preview: preview,
                  base: widget.baseCurrency,
                  quality: preview?.quality ?? status?.quality,
                  ageLabel: preview?.ageMinutes != null
                      ? _age(context, preview!.ageMinutes!)
                      : (status?.ageMinutes != null
                          ? _age(context, status!.ageMinutes!)
                          : null),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PreviewLine extends StatelessWidget {
  const _PreviewLine({
    required this.loading,
    required this.preview,
    required this.base,
    required this.quality,
    required this.ageLabel,
  });
  final bool loading;
  final Conversion? preview;
  final String base;
  final FxQuality? quality;
  final String? ageLabel;

  @override
  Widget build(BuildContext context) {
    final t = context.t;

    // No rates at all: say so plainly. The transaction can still be saved.
    if (quality == FxQuality.unavailable) {
      return _Banner(
        icon: Icons.cloud_off_rounded,
        color: AppColors.warning,
        text: t.currencyUnavailableWarning,
      );
    }

    if (loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 10),
        child: SizedBox(
          height: 18,
          width: 18,
          child: CircularProgressIndicator(strokeWidth: 2.2),
        ),
      );
    }

    if (preview == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: context.surfaceAlt,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                t.currencyConvertedTo(Money.format(preview!.amount, base)),
                maxLines: 2,
                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 3),
              Text(
                t.currencyRateLine(preview!.rate.toStringAsFixed(4)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: context.muted),
              ),
            ],
          ),
        ),
        if (quality == FxQuality.stale && ageLabel != null) ...[
          const SizedBox(height: 8),
          _Banner(
            icon: Icons.schedule_rounded,
            color: AppColors.warning,
            text: t.currencyStaleWarning(ageLabel!),
          ),
        ],
      ],
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.icon, required this.color, required this.text});
  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(icon, size: 15, color: color),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text,
              style: TextStyle(fontSize: 11.5, height: 1.35, color: color)),
        ),
      ],
    );
  }
}
