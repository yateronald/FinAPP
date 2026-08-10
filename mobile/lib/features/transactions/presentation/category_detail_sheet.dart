import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/i18n/app_text.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/responsive.dart';
import '../../../core/utils/category_icons.dart';
import '../../../core/utils/formatters.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/transaction_models.dart';
import '../data/transaction_repository.dart';
import '../providers/finance_filters.dart';
import '../providers/transactions_provider.dart';
import 'add_transaction_sheet.dart';

/// Every transaction of one category over the selected period.
///
/// The filtering is done by the API, not here: the request carries the
/// category and the date window, and the server answers only with rows the
/// bearer token owns. Pulling everything and filtering on the device would
/// hand each client far more data than the screen needs.
Future<void> showCategoryDetailSheet(
  BuildContext context, {
  required TxType type,
  required String categoryId,
  required String categoryName,
  required Color color,
  required String? icon,
  required FinancePeriod period,
  required double periodTotal,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _CategoryDetailSheet(
      type: type,
      categoryId: categoryId,
      categoryName: categoryName,
      color: color,
      icon: icon,
      period: period,
      periodTotal: periodTotal,
    ),
  );
}

class _CategoryDetailSheet extends ConsumerStatefulWidget {
  const _CategoryDetailSheet({
    required this.type,
    required this.categoryId,
    required this.categoryName,
    required this.color,
    required this.icon,
    required this.period,
    required this.periodTotal,
  });

  final TxType type;
  final String categoryId, categoryName;
  final Color color;
  final String? icon;
  final FinancePeriod period;

  /// Whole-period total for this type, used for the share badge.
  final double periodTotal;

  @override
  ConsumerState<_CategoryDetailSheet> createState() => _CategoryDetailSheetState();
}

class _CategoryDetailSheetState extends ConsumerState<_CategoryDetailSheet> {
  static const _pageSize = 25;

  final _items = <Transaction>[];
  final _scroll = ScrollController();

  int _page = 1;
  int _totalCount = 0;
  double _total = 0;
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _load();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_hasMore || _loadingMore) return;
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 280) {
      _load(more: true);
    }
  }

  Future<void> _load({bool more = false}) async {
    setState(() {
      if (more) {
        _loadingMore = true;
      } else {
        _loading = true;
        _error = null;
      }
    });
    try {
      final page = await ref.read(transactionRepositoryProvider).list(
            widget.type,
            page: more ? _page + 1 : 1,
            limit: _pageSize,
            categoryId: widget.categoryId,
            from: widget.period.from,
            to: widget.period.lastDay,
          );
      if (!mounted) return;
      setState(() {
        if (more) {
          _page += 1;
          _items.addAll(page.items);
        } else {
          _page = 1;
          _items
            ..clear()
            ..addAll(page.items);
          _total = page.totalAmount;
          _totalCount = page.total;
        }
        _hasMore = _items.length < page.total;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadingMore = false;
        });
      }
    }
  }

  /// Groups by calendar day, newest first — the order the API already returns.
  Map<DateTime, List<Transaction>> get _byDay {
    final map = <DateTime, List<Transaction>>{};
    for (final t in _items) {
      final key = DateTime(t.date.year, t.date.month, t.date.day);
      map.putIfAbsent(key, () => []).add(t);
    }
    return map;
  }

  String _dayLabel(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final diff = today.difference(d).inDays;
    if (diff == 0) return context.t.catDetailToday;
    if (diff == 1) return context.t.catDetailYesterday;
    return Dates.short(d);
  }

  @override
  Widget build(BuildContext context) {
    final currency = ref.watch(authProvider).user?.currency ?? 'XOF';
    final share = widget.periodTotal > 0
        ? ((_total / widget.periodTotal) * 100).round()
        : 0;

    final screenH = MediaQuery.sizeOf(context).height;
    // A short screen needs more of itself to show anything useful; a tall one
    // does not have to fill the whole display to feel complete.
    final initial = screenH < 700 ? 0.92 : (screenH > 900 ? 0.78 : 0.85);

    return DraggableScrollableSheet(
      initialChildSize: initial,
      minChildSize: 0.5,
      maxChildSize: 0.96,
      expand: false,
      builder: (context, sheetScroll) {
        return Container(
          decoration: BoxDecoration(
            color: context.isDark ? AppColors.darkBg : AppColors.lightBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          // Capped and centred: on a tablet a full-width list of short rows
          // reads as an empty page with text stuck to the edges.
          child: ResponsiveCenter(
            maxWidth: 660,
            child: Column(
            children: [
              _Header(
                name: widget.categoryName,
                icon: widget.icon,
                color: widget.color,
                periodLabel: widget.period.label,
                total: _total,
                count: _totalCount,
                share: share,
                currency: currency,
                loading: _loading,
                items: _items,
              ),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                        ? _Message(icon: Icons.cloud_off_rounded, text: _error!)
                        : _items.isEmpty
                            ? _Message(
                                icon: Icons.receipt_long_rounded,
                                text: context.t.catDetailEmpty,
                              )
                            : _buildList(currency, sheetScroll),
              ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildList(String currency, ScrollController sheetScroll) {
    final groups = _byDay;
    final days = groups.keys.toList();

    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (_hasMore &&
            !_loadingMore &&
            n.metrics.pixels >= n.metrics.maxScrollExtent - 280) {
          _load(more: true);
        }
        return false;
      },
      child: ListView.builder(
        controller: sheetScroll,
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
        itemCount: days.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, i) {
          if (i >= days.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.2),
                ),
              ),
            );
          }
          final day = days[i];
          final rows = groups[day]!;
          final dayTotal = rows.fold<double>(0, (s, t) => s + t.amount);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(4, i == 0 ? 8 : 18, 4, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _dayLabel(day),
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: context.muted,
                        ),
                      ),
                    ),
                    Text(
                      Money.format(dayTotal, ref.read(authProvider).user?.currency ?? 'XOF'),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: context.muted,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: context.colors.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: context.borderColor),
                ),
                child: Column(
                  children: [
                    for (var k = 0; k < rows.length; k++) ...[
                      if (k > 0)
                        Divider(
                          height: 1,
                          indent: 16,
                          endIndent: 16,
                          color: context.borderColor,
                        ),
                      _Row(
                        tx: rows[k],
                        color: widget.color,
                        currency: currency,
                        onTap: () async {
                          final saved = await showTransactionSheet(
                            context,
                            type: widget.type,
                            existing: rows[k],
                          );
                          if (saved == true) _load();
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────── header

class _Header extends StatelessWidget {
  const _Header({
    required this.name,
    required this.icon,
    required this.color,
    required this.periodLabel,
    required this.total,
    required this.count,
    required this.share,
    required this.currency,
    required this.loading,
    required this.items,
  });

  final String name, periodLabel, currency;
  final String? icon;
  final Color color;
  final double total;
  final int count, share;
  final bool loading;
  final List<Transaction> items;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final average = items.isEmpty ? 0.0 : total / count.clamp(1, count);
    final largest =
        items.isEmpty ? 0.0 : items.map((e) => e.amount).reduce((a, b) => a > b ? a : b);

    final compact = context.useCompactLayout;
    final pad = compact ? 16.0 : 20.0;

    return Container(
      padding: EdgeInsets.fromLTRB(pad, 10, pad, compact ? 16 : 20),
      decoration: BoxDecoration(
        // A wash of the category's own colour: the sheet should feel like an
        // extension of the card that opened it.
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.alphaBlend(
              color.withValues(alpha: context.isDark ? 0.22 : 0.14),
              context.colors.surface,
            ),
            context.isDark ? AppColors.darkBg : AppColors.lightBg,
          ],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: context.borderColor,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Container(
                width: compact ? 44 : 52,
                height: compact ? 44 : 52,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(compact ? 14 : 16),
                ),
                child: Icon(categoryIcon(icon), color: color, size: compact ? 21 : 25),
              ),
              SizedBox(width: compact ? 11 : 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: compact ? 17 : 19,
                          fontWeight: FontWeight.w800,
                          height: 1.2),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      periodLabel,
                      style: TextStyle(fontSize: 12.5, color: context.muted),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Icon(Icons.close_rounded, size: 20, color: context.muted),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (loading)
            const SizedBox(height: 64)
          else
            Row(
              children: [
                Expanded(
                  flex: 5,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t.catDetailTotal,
                          style: TextStyle(fontSize: 11.5, color: context.muted)),
                      const SizedBox(height: 3),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          Money.format(total, currency),
                          style: TextStyle(
                            fontSize: compact ? 22 : 26,
                            fontWeight: FontWeight.w800,
                            color: color,
                            height: 1.1,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _Chip(label: t.catDetailCount(count), color: color),
                          if (share > 0)
                            _Chip(label: t.catDetailShare(share), color: color),
                        ],
                      ),
                    ],
                  ),
                ),
                if (!compact) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 4,
                    child: Column(
                      children: [
                        _Stat(
                            label: t.catDetailAverage,
                            value: Money.compact(average),
                            color: color),
                        const SizedBox(height: 8),
                        _Stat(
                            label: t.catDetailLargest,
                            value: Money.compact(largest),
                            color: color),
                      ],
                    ),
                  ),
                ],
              ],
            ).animate().fadeIn(duration: 260.ms),
          if (!loading && compact) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _Stat(
                      label: t.catDetailAverage,
                      value: Money.compact(average),
                      color: color),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _Stat(
                      label: t.catDetailLargest,
                      value: Money.compact(largest),
                      color: color),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.color});
  final String label, value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: context.borderColor),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: context.muted)),
          Text(value,
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────────── row

class _Row extends StatelessWidget {
  const _Row({
    required this.tx,
    required this.color,
    required this.currency,
    required this.onTap,
  });

  final Transaction tx;
  final Color color;
  final String currency;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasNote = (tx.description ?? '').trim().isNotEmpty;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      tx.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700, height: 1.25),
                    ),
                    if (hasNote) ...[
                      const SizedBox(height: 2),
                      Text(
                        tx.description!.trim(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11.5, color: context.muted),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    Money.format(tx.amount, currency),
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    Dates.hourMinute(tx.date),
                    style: TextStyle(fontSize: 10.5, color: context.muted),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: context.muted),
            const SizedBox(height: 14),
            Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, height: 1.5, color: context.muted),
            ),
          ],
        ),
      ),
    );
  }
}
