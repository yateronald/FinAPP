import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/i18n/app_text.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/responsive.dart';
import '../data/currency_models.dart';
import '../providers/currency_provider.dart';

/// Picks a currency from the full catalogue. Resolves the chosen code, or null.
///
/// [convertibleOnly] is used when picking a *base* currency: everything is
/// expressed in it, so choosing one the rate feed cannot price would leave the
/// account unable to convert anything. For a single transaction the constraint
/// is relaxed — an unconvertible currency is still recorded honestly.
Future<String?> showCurrencyPicker(
  BuildContext context, {
  String? selected,
  bool convertibleOnly = false,
  String? title,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _CurrencyPickerSheet(
      selected: selected,
      convertibleOnly: convertibleOnly,
      title: title,
    ),
  );
}

class _CurrencyPickerSheet extends ConsumerStatefulWidget {
  const _CurrencyPickerSheet({
    this.selected,
    required this.convertibleOnly,
    this.title,
  });
  final String? selected;
  final bool convertibleOnly;
  final String? title;

  @override
  ConsumerState<_CurrencyPickerSheet> createState() => _CurrencyPickerSheetState();
}

class _CurrencyPickerSheetState extends ConsumerState<_CurrencyPickerSheet> {
  final _search = TextEditingController();
  String _term = '';

  /// Shown first, before the alphabetical list. These cover the overwhelming
  /// majority of users, and scrolling to XOF past 150 others is a poor
  /// experience on the one screen everybody sees at sign-up.
  static const _common = ['XOF', 'XAF', 'EUR', 'USD', 'GBP', 'NGN', 'GHS', 'MAD'];

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<CurrencyInfo> _filter(List<CurrencyInfo> all) {
    final t = _term.trim().toLowerCase();
    final base = widget.convertibleOnly
        ? all.where((c) => c.convertible || c.code == widget.selected).toList()
        : all;
    if (t.isEmpty) return base;
    return base
        .where((c) =>
            c.code.toLowerCase().contains(t) || c.name.toLowerCase().contains(t))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final media = MediaQuery.of(context);
    final async = ref.watch(currenciesProvider);

    return Container(
      constraints: BoxConstraints(maxHeight: media.size.height * 0.9),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: context.borderColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title ?? t.currencyPickTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close_rounded, size: 22, color: context.muted),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: TextField(
                controller: _search,
                autofocus: false,
                onChanged: (v) => setState(() => _term = v),
                decoration: InputDecoration(
                  hintText: t.currencySearchHint,
                  prefixIcon: Icon(Icons.search_rounded, size: 20, color: context.muted),
                  filled: true,
                  fillColor: context.surfaceAlt,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            Flexible(
              child: async.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => Padding(
                  padding: const EdgeInsets.all(28),
                  child: Text(e.toString(),
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12.5, color: context.muted)),
                ),
                data: (all) {
                  final list = _filter(all);
                  if (list.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(t.noData,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: context.muted)),
                    );
                  }
                  final common = _term.isEmpty
                      ? list.where((c) => _common.contains(c.code)).toList()
                      : const <CurrencyInfo>[];
                  final rest = _term.isEmpty
                      ? list.where((c) => !_common.contains(c.code)).toList()
                      : list;

                  return ResponsiveCenter(
                    maxWidth: 620,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
                      children: [
                        if (common.isNotEmpty) ...[
                          _SectionLabel(text: t.currencyCommon),
                          ...common.map((c) => _Row(
                                currency: c,
                                selected: c.code == widget.selected,
                                onTap: () => Navigator.pop(context, c.code),
                              )),
                          const SizedBox(height: 6),
                          _SectionLabel(text: t.currencyAll),
                        ],
                        ...rest.map((c) => _Row(
                              currency: c,
                              selected: c.code == widget.selected,
                              onTap: () => Navigator.pop(context, c.code),
                            )),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
        child: Text(
          text.toUpperCase(),
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.6,
            color: context.muted,
          ),
        ),
      );
}

class _Row extends StatelessWidget {
  const _Row({
    required this.currency,
    required this.selected,
    required this.onTap,
  });
  final CurrencyInfo currency;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: context.isDark ? 0.18 : 0.07)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppColors.primary : Colors.transparent,
            width: 1.4,
          ),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 46,
              child: Text(
                currency.code,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: selected ? AppColors.primary : null,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(currency.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13.5)),
                  // Said plainly rather than hidden: the currency is real, we
                  // simply have no rate for it yet.
                  if (!currency.convertible)
                    Text(t.currencyNoRate,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 10.5, color: AppColors.warning)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (currency.symbol != null)
              Text(currency.symbol!,
                  style: TextStyle(fontSize: 12.5, color: context.muted)),
            if (selected) ...[
              const SizedBox(width: 8),
              const Icon(Icons.check_circle_rounded,
                  size: 19, color: AppColors.primary),
            ],
          ],
        ),
      ),
    );
  }
}
