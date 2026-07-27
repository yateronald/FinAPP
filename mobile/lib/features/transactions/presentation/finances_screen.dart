import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/i18n/app_text.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/category_icons.dart';
import '../../../core/utils/formatters.dart';
import '../../ai/presentation/ai_analytics_widget.dart';
import '../../auth/providers/auth_provider.dart';
import '../../categories/providers/categories_provider.dart';
import '../../dashboard/data/dashboard_models.dart' show CategorySlice;
import '../../dashboard/providers/dashboard_provider.dart';
import '../data/overview_models.dart';
import '../data/transaction_models.dart';
import '../providers/finance_filters.dart';
import '../providers/transactions_provider.dart';
import 'add_transaction_sheet.dart';
import 'period_picker.dart';

class FinancesScreen extends ConsumerStatefulWidget {
  const FinancesScreen({super.key});
  @override
  ConsumerState<FinancesScreen> createState() => _FinancesScreenState();
}

class _FinancesScreenState extends ConsumerState<FinancesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    // Rebuild so the category filter bar follows the visible tab.
    _tab.addListener(_onTabChanged);
  }

  void _onTabChanged() {
    if (!_tab.indexIsChanging && mounted) setState(() {});
  }

  @override
  void dispose() {
    _tab.removeListener(_onTabChanged);
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final period = ref.watch(financePeriodProvider);
    return Column(
      children: [
        // Tabs
        Container(
          margin: const EdgeInsets.fromLTRB(20, 4, 20, 10),
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: context.surfaceAlt,
            borderRadius: BorderRadius.circular(16),
          ),
          child: TabBar(
            controller: _tab,
            dividerColor: Colors.transparent,
            indicatorSize: TabBarIndicatorSize.tab,
            indicator: BoxDecoration(
              color: context.colors.surface,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 6)],
            ),
            labelColor: AppColors.primary,
            unselectedLabelColor: context.muted,
            labelStyle: const TextStyle(fontWeight: FontWeight.w700),
            tabs: [Tab(text: context.t.expensesTab), Tab(text: context.t.incomeTab)],
          ),
        ),
        // Period filter + search
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Row(
            children: [
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => showPeriodPicker(context, ref),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: context.colors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: context.borderColor),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today_rounded, size: 16, color: context.muted),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(period.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                        ),
                        Icon(Icons.expand_more_rounded, size: 20, color: context.muted),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              _SearchButton(),
            ],
          ),
        ),
        // While typing, suggest matching categories; otherwise show the filter
        // chips. Applies to the tab currently in view.
        Builder(builder: (context) {
          final type = _tab.index == 0 ? TxType.expense : TxType.income;
          final query = ref.watch(txSearchProvider).trim();
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: query.isEmpty
                ? _CategoryFilterBar(type: type)
                : _CategorySuggestions(type: type, query: query),
          );
        }),
        Expanded(
          child: TabBarView(
            controller: _tab,
            children: const [
              _FinanceTab(type: TxType.expense),
              _FinanceTab(type: TxType.income),
            ],
          ),
        ),
      ],
    );
  }
}

class _SearchButton extends ConsumerStatefulWidget {
  @override
  ConsumerState<_SearchButton> createState() => _SearchButtonState();
}

class _SearchButtonState extends ConsumerState<_SearchButton> {
  bool _open = false;
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_open) {
      return Expanded(
        flex: 3,
        child: TextField(
          controller: _ctrl,
          autofocus: true,
          onChanged: (v) => ref.read(txSearchProvider.notifier).set(v),
          decoration: InputDecoration(
            hintText: context.t.search,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            prefixIcon: const Icon(Icons.search_rounded, size: 20),
            suffixIcon: IconButton(
              icon: const Icon(Icons.close_rounded, size: 20),
              onPressed: () {
                _ctrl.clear();
                ref.read(txSearchProvider.notifier).set('');
                setState(() => _open = false);
              },
            ),
          ),
        ),
      );
    }
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => setState(() => _open = true),
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.borderColor),
        ),
        child: Icon(Icons.search_rounded, color: context.muted),
      ),
    );
  }
}

class _FinanceTab extends ConsumerWidget {
  final TxType type;
  const _FinanceTab({required this.type});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overviewAsync = ref.watch(financeOverviewProvider(type));
    final listAsync = ref.watch(transactionsProvider(type));
    final period = ref.watch(financePeriodProvider);
    final currency = ref.watch(authProvider).user?.currency ?? 'XOF';
    final accent = type.isIncome ? AppColors.success : AppColors.danger;

    // Map categoryId → icon slug for the distribution cards.
    final cats = ref.watch(categoriesProvider).value ?? [];
    final Map<String, String?> iconOf = {for (final c in cats) c.id: c.icon};

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () async {
        ref.invalidate(financeOverviewProvider(type));
        return ref.refresh(transactionsProvider(type).future);
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 120),
        children: [
          overviewAsync.when(
            loading: () => const _CardSkeleton(height: 150),
            error: (e, _) => const SizedBox.shrink(),
            data: (o) => _TotalCard(overview: o, accent: accent, currency: currency),
          ),
          const SizedBox(height: 16),
          RealAiAnalyticsWidget(date: period.from, scope: type.isIncome ? 'INCOME' : 'EXPENSE'),
          const SizedBox(height: 16),
          overviewAsync.maybeWhen(
            data: (o) => o.distribution.isEmpty
                ? const SizedBox.shrink()
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _CategoryStrip(slices: o.distribution, iconOf: iconOf, currency: currency),
                      const SizedBox(height: 20),
                      _DistributionDonut(slices: o.distribution, currency: currency),
                      const SizedBox(height: 16),
                      _SecondaryRow(overview: o, currency: currency, period: period),
                      const SizedBox(height: 20),
                      _AnalysisSection(overview: o, currency: currency, type: type),
                      const SizedBox(height: 8),
                    ],
                  ),
            orElse: () => const SizedBox.shrink(),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(context.t.transactions,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              listAsync.maybeWhen(
                data: (p) => Text(context.t.opsCount(p.total),
                    style: TextStyle(color: context.muted, fontSize: 12.5)),
                orElse: () => const SizedBox.shrink(),
              ),
            ],
          ),
          const SizedBox(height: 4),
          listAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.only(top: 40),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.only(top: 24),
              child: Center(child: Text(e.toString())),
            ),
            data: (page) => page.items.isEmpty
                ? _EmptyState(type: type)
                : Column(
                    children: page.items
                        .map((t) => _SwipeableTile(tx: t, currency: currency))
                        .toList(),
                  ),
          ),
        ],
      ),
    );
  }
}

// -------------------------------------------------------- Total card

class _TotalCard extends StatelessWidget {
  final FinanceOverview overview;
  final Color accent;
  final String currency;
  const _TotalCard({required this.overview, required this.accent, required this.currency});

  @override
  Widget build(BuildContext context) {
    final trend = overview.totalTrend;
    // For expenses, a drop is good; for income, a rise is good.
    final good = overview.type.isIncome ? trend >= 0 : trend <= 0;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: accent.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(overview.type.isIncome ? context.t.totalIncome : context.t.totalExpenses,
                    style: TextStyle(color: context.muted, fontSize: 13)),
                const SizedBox(height: 6),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(Money.number(overview.total),
                          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
                      const SizedBox(width: 4),
                      Text(currency == 'XOF' ? 'FCFA' : currency,
                          style: TextStyle(
                              color: context.muted, fontSize: 13, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _TrendPill(trend: trend, good: good),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(context.t.vsPrevPeriod,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: context.muted, fontSize: 11.5)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (overview.trendValues.length > 1) ...[
            const SizedBox(width: 8),
            SizedBox(
              width: 92,
              height: 56,
              child: _Sparkline(values: overview.trendValues, color: accent),
            ),
          ],
        ],
      ),
    );
  }
}

/// Compact colored badge showing a trend arrow + percentage. Never overflows.
class _TrendPill extends StatelessWidget {
  final double trend;
  final bool good;
  const _TrendPill({required this.trend, required this.good});
  @override
  Widget build(BuildContext context) {
    final neutral = trend == 0;
    final color = neutral ? context.muted : (good ? AppColors.success : AppColors.danger);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            neutral
                ? Icons.remove_rounded
                : (trend < 0 ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded),
            size: 13,
            color: color,
          ),
          const SizedBox(width: 2),
          Text('${trend.abs().round()}%',
              style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 12.5)),
        ],
      ),
    );
  }
}

class _Sparkline extends StatelessWidget {
  final List<double> values;
  final Color color;
  const _Sparkline({required this.values, required this.color});
  @override
  Widget build(BuildContext context) {
    final spots = [for (var i = 0; i < values.length; i++) FlSpot(i.toDouble(), values[i])];
    final minY = values.reduce((a, b) => a < b ? a : b);
    final maxY = values.reduce((a, b) => a > b ? a : b);
    return LineChart(LineChartData(
      minY: minY,
      maxY: maxY == minY ? maxY + 1 : maxY,
      gridData: const FlGridData(show: false),
      titlesData: const FlTitlesData(show: false),
      borderData: FlBorderData(show: false),
      lineTouchData: const LineTouchData(enabled: false),
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          isCurved: true,
          color: color,
          barWidth: 2.5,
          dotData: FlDotData(
            show: true,
            checkToShowDot: (spot, _) => spot.x == values.length - 1,
            getDotPainter: (s, _, __, ___) =>
                FlDotCirclePainter(radius: 3, color: color, strokeWidth: 0),
          ),
          belowBarData: BarAreaData(show: true, color: color.withValues(alpha: 0.15)),
        ),
      ],
    ));
  }
}

// ----------------------------------------------------- Category strip

class _CategoryStrip extends StatelessWidget {
  final List<CategorySlice> slices;
  final Map<String, String?> iconOf;
  final String currency;
  const _CategoryStrip({required this.slices, required this.iconOf, required this.currency});
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 138,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        itemCount: slices.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, i) {
          final s = slices[i];
          return Container(
            width: 138,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: context.colors.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: context.borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                          color: s.color.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(12)),
                      child: Icon(categoryIcon(iconOf[s.categoryId]), color: s.color, size: 19),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: s.color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text('${s.percentage.round()}%',
                          style: TextStyle(
                              color: s.color, fontWeight: FontWeight.w800, fontSize: 11.5)),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: context.muted, fontSize: 12.5)),
                    const SizedBox(height: 3),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(Money.format(s.amount, currency),
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// --------------------------------------------------------- Donut

class _DistributionDonut extends StatelessWidget {
  final List<CategorySlice> slices;
  final String currency;
  const _DistributionDonut({required this.slices, required this.currency});
  @override
  Widget build(BuildContext context) {
    final total = slices.fold<double>(0, (s, e) => s + e.amount);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: context.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.t.distributionByCategory,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          Row(
            children: [
              SizedBox(
                width: 120,
                height: 120,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    PieChart(PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 40,
                      sections: slices
                          .take(6)
                          .map((s) => PieChartSectionData(
                              value: s.amount, color: s.color, radius: 20, showTitle: false))
                          .toList(),
                    )),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(Money.compact(total),
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                        Text('FCFA', style: TextStyle(color: context.muted, fontSize: 10)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  children: slices.take(5).map((s) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(children: [
                        Container(
                            width: 9,
                            height: 9,
                            decoration: BoxDecoration(color: s.color, shape: BoxShape.circle)),
                        const SizedBox(width: 8),
                        Expanded(
                            child: Text(s.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: context.muted, fontSize: 12.5))),
                        Text('${s.percentage.round()}%',
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
                      ]),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------ Secondary row

class _SecondaryRow extends StatelessWidget {
  final FinanceOverview overview;
  final String currency;
  final FinancePeriod period;
  const _SecondaryRow(
      {required this.overview, required this.currency, required this.period});

  @override
  Widget build(BuildContext context) {
    final avgCard = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(overview.type.isIncome ? context.t.avgPerMonth : context.t.avgPerDay,
              style: TextStyle(color: context.muted, fontSize: 12.5)),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(Money.format(overview.secondaryValue, currency),
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );

    if (!period.isCurrentMonth) return avgCard;

    // Days remaining in the current month.
    final now = DateTime.now();
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final remaining = daysInMonth - now.day;
    return Row(
      children: [
        Expanded(child: avgCard),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.colors.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: context.borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(context.t.daysLeft, style: TextStyle(color: context.muted, fontSize: 12.5)),
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Icon(Icons.calendar_month_rounded, size: 18, color: AppColors.primary),
                    const SizedBox(width: 6),
                    Text('$remaining',
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                    const SizedBox(width: 4),
                    Text(context.t.days, style: TextStyle(color: context.muted, fontSize: 12.5)),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: now.day / daysInMonth,
                    minHeight: 5,
                    backgroundColor: context.surfaceAlt,
                    valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// -------------------------------------------------------- Analysis

class _AnalysisSection extends StatelessWidget {
  final FinanceOverview overview;
  final String currency;
  final TxType type;
  const _AnalysisSection(
      {required this.overview, required this.currency, required this.type});

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final o = overview;
    final items = <Widget>[];
    final down = o.totalTrend <= 0;
    final pct = o.totalTrend.abs().round();
    // 1) Trend vs previous period.
    final trendText = type.isIncome
        ? (down ? t.incomeDown(pct) : t.incomeUp(pct))
        : (down ? t.spendLess(pct) : t.spendMore(pct));
    items.add(_analysis(
      context,
      icon: down ? Icons.trending_down_rounded : Icons.trending_up_rounded,
      color: (type.isIncome ? !down : down) ? AppColors.success : AppColors.danger,
      text: trendText,
      emphasis: '$pct%',
    ));
    // 2) Top category weight.
    if (o.topCategory != null) {
      items.add(_analysis(
        context,
        icon: Icons.pie_chart_outline_rounded,
        color: AppColors.warning,
        text: t.categoryWeight(
            o.topCategory!.name, o.topCategory!.percentage.round(), type.isIncome),
        emphasis: '${o.topCategory!.percentage.round()}%',
      ));
    }
    // 3) Savings tip (expenses) / diversification (income).
    if (o.topCategory != null) {
      final amt = Money.format(o.topCategory!.amount * 0.15, currency);
      items.add(_analysis(
        context,
        icon: Icons.lightbulb_outline_rounded,
        color: AppColors.primary,
        text: type.isIncome
            ? t.diversifyTip(o.topCategory!.name)
            : t.savingTip(o.topCategory!.name, amt),
        emphasis: type.isIncome ? '' : amt,
      ));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const Icon(Icons.auto_awesome_rounded, size: 18, color: AppColors.primary),
          const SizedBox(width: 8),
          Text(type.isIncome ? t.incomeAnalysis : t.expenseAnalysis,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 12),
        ...items.map((w) => Padding(padding: const EdgeInsets.only(bottom: 10), child: w)),
      ],
    );
  }

  Widget _analysis(BuildContext context,
      {required IconData icon,
      required Color color,
      required String text,
      required String emphasis}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(11)),
            child: Icon(icon, color: color, size: 19),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text.rich(_highlight(text, emphasis, color, context))),
        ],
      ),
    );
  }

  TextSpan _highlight(String text, String emphasis, Color color, BuildContext context) {
    final base = TextStyle(height: 1.4, color: context.colors.onSurface, fontSize: 13.5);
    final idx = emphasis.isEmpty ? -1 : text.indexOf(emphasis);
    if (idx < 0) return TextSpan(text: text, style: base);
    return TextSpan(style: base, children: [
      TextSpan(text: text.substring(0, idx)),
      TextSpan(text: emphasis, style: TextStyle(fontWeight: FontWeight.w800, color: color)),
      TextSpan(text: text.substring(idx + emphasis.length)),
    ]);
  }
}

// ---------------------------------------------------- Transaction tile

class _SwipeableTile extends ConsumerWidget {
  final Transaction tx;
  final String currency;
  const _SwipeableTile({required this.tx, required this.currency});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Dismissible(
      key: ValueKey(tx.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(color: AppColors.danger, borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.delete_rounded, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        return await showDialog<bool>(
              context: context,
              builder: (_) => AlertDialog(
                title: Text(context.t.deleteQuestion),
                content: Text(context.t.deleteBody(tx.title)),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: Text(context.t.cancel)),
                  FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
                    onPressed: () => Navigator.pop(context, true),
                    child: Text(context.t.delete),
                  ),
                ],
              ),
            ) ??
            false;
      },
      onDismissed: (_) async {
        try {
          await ref.read(transactionRepositoryProvider).remove(tx.type, tx.id);
          ref.invalidate(transactionsProvider(tx.type));
          ref.invalidate(financeOverviewProvider(tx.type));
          ref.invalidate(dashboardProvider);
        } catch (_) {}
      },
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => showTransactionSheet(context, type: tx.type, existing: tx),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: tx.categoryColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(categoryIcon(tx.categoryIcon), color: tx.categoryColor, size: 21),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tx.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    Text('${tx.categoryName} · ${Dates.short(tx.date)}',
                        style: TextStyle(color: context.muted, fontSize: 12)),
                  ],
                ),
              ),
              Text(
                '${tx.type.isIncome ? '+' : '-'}${Money.format(tx.amount, currency)}',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: tx.type.isIncome ? AppColors.success : context.colors.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final TxType type;
  const _EmptyState({required this.type});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 30),
      child: Column(
        children: [
          Icon(type.isIncome ? Icons.trending_up_rounded : Icons.receipt_long_rounded,
              size: 52, color: context.muted),
          const SizedBox(height: 14),
          Text(
              context.t.noneForPeriod(
                  type.isIncome ? context.t.incomeWord : context.t.expenseWord),
              style: TextStyle(color: context.muted)),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => showTransactionSheet(context, type: type),
            icon: const Icon(Icons.add_rounded),
            label: Text(type.isIncome ? context.t.addIncome() : context.t.addExpense()),
          ),
        ],
      ),
    );
  }
}

class _CardSkeleton extends StatelessWidget {
  final double height;
  const _CardSkeleton({required this.height});
  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: context.surfaceAlt,
        borderRadius: BorderRadius.circular(22),
      ),
    );
  }
}

/// Horizontal category filter for the Finances tabs. "Toutes" clears the
/// filter; picking a category refetches both the overview and the list.
class _CategoryFilterBar extends ConsumerWidget {
  final TxType type;
  const _CategoryFilterBar({required this.type});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoriesByTypeProvider(type.categoryType));
    final selected = ref.watch(financeCategoryProvider(type.categoryType));
    if (categories.isEmpty) return const SizedBox.shrink();
    final notifier = ref.read(financeCategoryProvider(type.categoryType).notifier);

    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          // "All categories" = the default, cleared state.
          _chip(
            context,
            label: selected.isEmpty
                ? context.t.reportAllCategories
                : '${context.t.clearFilter} (${selected.length})',
            color: AppColors.primary,
            selected: selected.isEmpty,
            onTap: notifier.clear,
            icon: selected.isEmpty ? Icons.filter_list_rounded : Icons.filter_alt_off_rounded,
          ),
          for (final c in categories)
            _chip(
              context,
              label: c.name,
              color: c.color,
              selected: selected.contains(c.id),
              // Multi-select: tap to add, tap again to remove.
              onTap: () => notifier.toggle(c.id),
              icon: categoryIcon(c.icon),
              showCheck: selected.contains(c.id),
            ),
        ],
      ),
    );
  }

  Widget _chip(
    BuildContext context, {
    required String label,
    required Color color,
    required bool selected,
    required VoidCallback onTap,
    required IconData icon,
    bool showCheck = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? color.withValues(alpha: 0.14) : context.colors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? color : context.borderColor,
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(showCheck ? Icons.check_rounded : icon,
                  size: 15, color: selected ? color : context.muted),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  color: selected ? color : context.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Category suggestions shown while the user types in the search field.
/// Tapping one applies the category filter and clears the text query, so
/// searching a category name actually filters (instead of matching titles).
class _CategorySuggestions extends ConsumerWidget {
  final TxType type;
  final String query;
  const _CategorySuggestions({required this.type, required this.query});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final q = query.toLowerCase();
    final matches = ref
        .watch(categoriesByTypeProvider(type.categoryType))
        .where((c) => c.name.toLowerCase().contains(q))
        .toList();
    if (matches.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 6),
          child: Text(context.t.category.toUpperCase(),
              style: TextStyle(
                  color: context.muted,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6)),
        ),
        SizedBox(
          height: 36,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (final c in matches)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () {
                      // Add to the multi-select filter and drop the text query.
                      ref
                          .read(financeCategoryProvider(type.categoryType).notifier)
                          .add(c.id);
                      ref.read(txSearchProvider.notifier).set('');
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: c.color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: c.color.withValues(alpha: 0.55)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(categoryIcon(c.icon), size: 15, color: c.color),
                          const SizedBox(width: 6),
                          Text(c.name,
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: c.color)),
                          const SizedBox(width: 4),
                          Icon(Icons.filter_alt_rounded, size: 13, color: c.color),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
