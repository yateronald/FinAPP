import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/i18n/app_text.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/responsive.dart';
import '../../core/utils/formatters.dart';
import '../auth/providers/auth_provider.dart';
import '../categories/data/category_model.dart';
import '../categories/providers/categories_provider.dart';

// ============================================================== Models

class ReportSummary {
  final double income, incomeTrend, expenses, expenseTrend, savings, savingsTrend, savingsRate;
  ReportSummary.fromJson(Map<String, dynamic> j)
      : income = asDouble(j['income']),
        incomeTrend = asDouble(j['incomeTrend']),
        expenses = asDouble(j['expenses']),
        expenseTrend = asDouble(j['expenseTrend']),
        savings = asDouble(j['savings']),
        savingsTrend = asDouble(j['savingsTrend']),
        savingsRate = asDouble(j['savingsRate']);
}

class ReportTrendPoint {
  final String label;
  final double income, expenses, savings;
  ReportTrendPoint.fromJson(Map<String, dynamic> j)
      : label = (j['label'] ?? '').toString(),
        income = asDouble(j['income']),
        expenses = asDouble(j['expenses']),
        savings = asDouble(j['savings']);
}

class ReportCategory {
  final String name;
  final double amount;
  final int percentage, count;
  final Color color;
  ReportCategory.fromJson(Map<String, dynamic> j)
      : name = (j['category'] ?? 'Autre').toString(),
        amount = asDouble(j['amount']),
        percentage = asDouble(j['percentage']).round(),
        count = (j['count'] is int) ? j['count'] as int : asDouble(j['count']).round(),
        color = AppColors.hexToColor(j['color'], AppColors.primary);
}

class ReportBudgetItem {
  final String category, status;
  final double budget, spent;
  final int progress;
  final Color color;
  ReportBudgetItem.fromJson(Map<String, dynamic> j)
      : category = (j['category'] ?? '').toString(),
        status = (j['status'] ?? 'ok').toString(),
        budget = asDouble(j['budget']),
        spent = asDouble(j['spent']),
        progress = asDouble(j['progress']).round(),
        color = AppColors.hexToColor(j['color'], AppColors.primary);
}

class LargestExpense {
  final String title;
  final String? category;
  final double amount;
  LargestExpense.fromJson(Map<String, dynamic> j)
      : title = (j['title'] ?? '').toString(),
        category = j['category']?.toString(),
        amount = asDouble(j['amount']);
}

class ReportStats {
  final int txCount, expenseCount, incomeCount, days;
  final double avgExpense, dailyAvgExpense;
  final String? topCategory;
  final LargestExpense? largest;
  ReportStats.fromJson(Map<String, dynamic> j)
      : txCount = _int(j['txCount']),
        expenseCount = _int(j['expenseCount']),
        incomeCount = _int(j['incomeCount']),
        days = _int(j['days']),
        avgExpense = asDouble(j['avgExpense']),
        dailyAvgExpense = asDouble(j['dailyAvgExpense']),
        topCategory = j['topCategory']?.toString(),
        largest = j['largestExpense'] != null
            ? LargestExpense.fromJson(Map<String, dynamic>.from(j['largestExpense']))
            : null;
  static int _int(dynamic v) => v is int ? v : asDouble(v).round();
}

class ReportData {
  final ReportSummary summary;
  final List<ReportTrendPoint> trend;
  final List<ReportCategory> expenseByCategory;
  final List<ReportBudgetItem> budgetItems;
  final int budgetsRespectedPct, budgetsRespected, budgetsTotal;
  final ReportStats stats;

  ReportData({
    required this.summary,
    required this.trend,
    required this.expenseByCategory,
    required this.budgetItems,
    required this.budgetsRespectedPct,
    required this.budgetsRespected,
    required this.budgetsTotal,
    required this.stats,
  });

  factory ReportData.fromJson(Map<String, dynamic> j) {
    final budgets = Map<String, dynamic>.from(j['budgets'] ?? {});
    return ReportData(
      summary: ReportSummary.fromJson(Map<String, dynamic>.from(j['summary'] ?? {})),
      trend: ((j['trend'] ?? []) as List)
          .map((e) => ReportTrendPoint.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      expenseByCategory: ((j['expenseByCategory'] ?? []) as List)
          .map((e) => ReportCategory.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      budgetItems: ((budgets['items'] ?? []) as List)
          .map((e) => ReportBudgetItem.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      budgetsRespectedPct: ReportStats._int(budgets['respectedPct']),
      budgetsRespected: ReportStats._int(budgets['respectedCount']),
      budgetsTotal: ReportStats._int(budgets['totalCount']),
      stats: ReportStats.fromJson(Map<String, dynamic>.from(j['stats'] ?? {})),
    );
  }

  bool get isEmpty => summary.income == 0 && summary.expenses == 0;
}

// ============================================================ Providers

class ReportFilter {
  final String period; // weekly | monthly | yearly | custom
  final DateTime? from, to;
  final String? categoryId, categoryName;
  const ReportFilter({
    this.period = 'monthly',
    this.from,
    this.to,
    this.categoryId,
    this.categoryName,
  });
}

class ReportFilterNotifier extends Notifier<ReportFilter> {
  @override
  ReportFilter build() => const ReportFilter();

  void setPeriod(String period) => state = ReportFilter(
        period: period,
        categoryId: state.categoryId,
        categoryName: state.categoryName,
      );

  void setCustom(DateTime from, DateTime to) => state = ReportFilter(
        period: 'custom',
        from: from,
        to: to,
        categoryId: state.categoryId,
        categoryName: state.categoryName,
      );

  void setCategory(String? id, String? name) => state = ReportFilter(
        period: state.period,
        from: state.from,
        to: state.to,
        categoryId: id,
        categoryName: name,
      );
}

final reportFilterProvider =
    NotifierProvider<ReportFilterNotifier, ReportFilter>(ReportFilterNotifier.new);

String _d(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

final reportProvider = FutureProvider.autoDispose<ReportData>((ref) async {
  final f = ref.watch(reportFilterProvider);
  final query = <String, dynamic>{'period': f.period};
  if (f.period == 'custom' && f.from != null && f.to != null) {
    query['from'] = _d(f.from!);
    query['to'] = _d(f.to!);
  }
  if (f.categoryId != null) query['categoryId'] = f.categoryId;
  final data = await ApiClient.instance.get('/reports/overview', query: query);
  return ReportData.fromJson(Map<String, dynamic>.from(data));
});

// ============================================================== Screen

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(reportProvider);
    final currency = ref.watch(authProvider).user?.currency ?? 'XOF';

    return Scaffold(
      appBar: AppBar(title: Text(context.t.reports)),
      body: ResponsiveCenter(
        child: Column(
        children: [
          const _FilterBar(),
          Expanded(
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
              error: (e, _) => _ErrorState(onRetry: () => ref.invalidate(reportProvider)),
              data: (r) => RefreshIndicator(
                color: AppColors.primary,
                onRefresh: () async => ref.refresh(reportProvider.future),
                child: r.isEmpty
                    ? _EmptyState()
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
                        children: [
                          _SummaryGrid(s: r.summary, currency: currency),
                          const SizedBox(height: 18),
                          _StatsCard(stats: r.stats, currency: currency),
                          if (r.trend.length > 1) ...[
                            const SizedBox(height: 18),
                            _TrendChart(points: r.trend),
                          ],
                          if (r.expenseByCategory.isNotEmpty) ...[
                            const SizedBox(height: 18),
                            _CategoryCard(cats: r.expenseByCategory, currency: currency),
                          ],
                          if (r.budgetItems.isNotEmpty) ...[
                            const SizedBox(height: 18),
                            _BudgetCard(
                              items: r.budgetItems,
                              pct: r.budgetsRespectedPct,
                              respected: r.budgetsRespected,
                              total: r.budgetsTotal,
                              currency: currency,
                            ),
                          ],
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }
}

// ============================================================ Filter bar

class _FilterBar extends ConsumerWidget {
  const _FilterBar();

  Future<void> _pickRange(BuildContext context, WidgetRef ref, ReportFilter f) async {
    final now = DateTime.now();
    final initial = (f.from != null && f.to != null)
        ? DateTimeRange(start: f.from!, end: f.to!.subtract(const Duration(days: 1)))
        : DateTimeRange(start: DateTime(now.year, now.month, 1), end: now);
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1, 12, 31),
      initialDateRange: initial,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(colorScheme: Theme.of(ctx).colorScheme.copyWith(primary: AppColors.primary)),
        child: child!,
      ),
    );
    if (picked != null) {
      final from = DateTime(picked.start.year, picked.start.month, picked.start.day);
      // Make `to` exclusive (start of the day after the picked end).
      final to = DateTime(picked.end.year, picked.end.month, picked.end.day).add(const Duration(days: 1));
      ref.read(reportFilterProvider.notifier).setCustom(from, to);
    }
  }

  void _pickCategory(BuildContext context, WidgetRef ref) {
    final cats = ref.read(categoriesProvider).value ?? [];
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _CategorySheet(categories: cats),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final f = ref.watch(reportFilterProvider);
    final options = [
      ('weekly', t.reportWeek),
      ('monthly', t.reportMonth),
      ('yearly', t.reportYear),
      ('custom', t.reportCustom),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 6),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(color: context.surfaceAlt, borderRadius: BorderRadius.circular(14)),
            child: Row(
              children: options.map((o) {
                final sel = o.$1 == f.period;
                return Expanded(
                  child: GestureDetector(
                    onTap: () {
                      if (o.$1 == 'custom') {
                        _pickRange(context, ref, f);
                      } else {
                        ref.read(reportFilterProvider.notifier).setPeriod(o.$1);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      decoration: BoxDecoration(
                        color: sel ? context.colors.surface : Colors.transparent,
                        borderRadius: BorderRadius.circular(11),
                        boxShadow: sel
                            ? [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 6)]
                            : null,
                      ),
                      child: Text(o.$2,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: sel ? AppColors.primary : context.muted)),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              if (f.period == 'custom' && f.from != null && f.to != null)
                Expanded(
                  child: _pill(
                    context,
                    Icons.calendar_today_rounded,
                    '${_d(f.from!)} → ${_d(f.to!.subtract(const Duration(days: 1)))}',
                    onTap: () => _pickRange(context, ref, f),
                  ),
                )
              else
                const Spacer(),
              const SizedBox(width: 8),
              _pill(
                context,
                Icons.category_rounded,
                f.categoryName ?? t.reportAllCategories,
                onTap: () => _pickCategory(context, ref),
                active: f.categoryName != null,
                onClear: f.categoryName != null
                    ? () => ref.read(reportFilterProvider.notifier).setCategory(null, null)
                    : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _pill(BuildContext context, IconData icon, String label,
      {required VoidCallback onTap, bool active = false, VoidCallback? onClear}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: active ? AppColors.primary.withValues(alpha: 0.1) : context.colors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? AppColors.primary : context.borderColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: active ? AppColors.primary : context.muted),
            const SizedBox(width: 6),
            Flexible(
              child: Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: active ? AppColors.primary : context.colors.onSurface)),
            ),
            if (onClear != null) ...[
              const SizedBox(width: 4),
              GestureDetector(
                onTap: onClear,
                child: const Icon(Icons.close_rounded, size: 14, color: AppColors.primary),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CategorySheet extends ConsumerWidget {
  final List<Category> categories;
  const _CategorySheet({required this.categories});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    return Container(
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(color: context.borderColor, borderRadius: BorderRadius.circular(4)),
          ),
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.select_all_rounded, color: AppColors.primary),
            title: Text(t.reportAllCategories, style: const TextStyle(fontWeight: FontWeight.w600)),
            onTap: () {
              ref.read(reportFilterProvider.notifier).setCategory(null, null);
              Navigator.pop(context);
            },
          ),
          Divider(height: 1, color: context.borderColor),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: categories
                  .where((c) => !c.isArchived)
                  .map((c) => ListTile(
                        leading: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: c.color.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.circle, size: 12, color: c.color),
                        ),
                        title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(c.isIncome ? t.income : t.expenses,
                            style: TextStyle(color: context.muted, fontSize: 12)),
                        onTap: () {
                          ref.read(reportFilterProvider.notifier).setCategory(c.id, c.name);
                          Navigator.pop(context);
                        },
                      ))
                  .toList(),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ============================================================ Summary grid

class _SummaryGrid extends StatelessWidget {
  final ReportSummary s;
  final String currency;
  const _SummaryGrid({required this.s, required this.currency});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Row(children: [
        Expanded(child: _stat(context, context.t.income, s.income, s.incomeTrend, AppColors.success, currency)),
        const SizedBox(width: 12),
        Expanded(
            child: _stat(context, context.t.expenses, s.expenses, s.expenseTrend, AppColors.danger, currency,
                downGood: true)),
      ]),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: _stat(context, context.t.savings, s.savings, s.savingsTrend, AppColors.info, currency)),
        const SizedBox(width: 12),
        Expanded(child: _rate(context, s.savingsRate)),
      ]),
    ]);
  }

  Widget _stat(BuildContext c, String label, double v, double trend, Color color, String cur,
      {bool downGood = false}) {
    final good = downGood ? trend <= 0 : trend >= 0;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: c.muted, fontSize: 12.5)),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(Money.format(v, cur),
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color)),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(trend == 0 ? Icons.remove_rounded : (trend > 0 ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded),
                  size: 12,
                  color: trend == 0 ? c.muted : (good ? AppColors.success : AppColors.danger)),
              const SizedBox(width: 2),
              Text(trend == 0 ? 'stable' : percentLabel(trend),
                  style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: trend == 0 ? c.muted : (good ? AppColors.success : AppColors.danger))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _rate(BuildContext c, double rate) => Container(
        padding: const EdgeInsets.all(14),
        decoration:
            BoxDecoration(gradient: AppColors.brandGradient, borderRadius: BorderRadius.circular(18)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(c.t.savingsRate, style: const TextStyle(color: Colors.white70, fontSize: 12.5)),
            const SizedBox(height: 6),
            Text('${rate.toStringAsFixed(1)}%',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white)),
          ],
        ),
      );
}

// ============================================================ Key figures

class _StatsCard extends StatelessWidget {
  final ReportStats stats;
  final String currency;
  const _StatsCard({required this.stats, required this.currency});

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t.reportKeyFigures, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 14),
          Row(children: [
            _mini(context, Icons.receipt_long_rounded, '${stats.txCount}', t.reportTransactionsStat),
            _sep(context),
            _mini(context, Icons.payments_rounded, Money.compact(stats.avgExpense), t.reportAvgExpense),
          ]),
          const SizedBox(height: 14),
          Row(children: [
            _mini(context, Icons.calendar_view_day_rounded, Money.compact(stats.dailyAvgExpense), t.reportDailyAvg),
            _sep(context),
            _mini(
              context,
              Icons.trending_up_rounded,
              stats.largest != null ? Money.compact(stats.largest!.amount) : '—',
              stats.largest?.title ?? t.reportLargest,
            ),
          ]),
        ],
      ),
    );
  }

  Widget _sep(BuildContext c) => Container(width: 1, height: 34, color: c.borderColor);

  Widget _mini(BuildContext c, IconData icon, String value, String label) => Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, size: 17, color: AppColors.primary),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                    Text(label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: c.muted, fontSize: 10.5)),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}

// ============================================================ Trend chart

class _TrendChart extends StatelessWidget {
  final List<ReportTrendPoint> points;
  const _TrendChart({required this.points});

  @override
  Widget build(BuildContext context) {
    final maxV =
        points.expand((p) => [p.income, p.expenses]).fold<double>(0, (m, v) => v > m ? v : m);
    // Show at most ~7 x-axis labels evenly spaced so it stays readable.
    final step = (points.length / 7).ceil().clamp(1, points.length);
    final barW = points.length > 14 ? 4.0 : (points.length > 8 ? 6.0 : 8.0);

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 18, 14, 12),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: context.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 6),
            child: Text(context.t.incomeVsExpenses,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 180,
            child: BarChart(
              BarChartData(
                maxY: maxV * 1.2,
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                barTouchData: BarTouchData(enabled: false),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 24,
                      getTitlesWidget: (v, _) {
                        final i = v.toInt();
                        if (i < 0 || i >= points.length || i % step != 0) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(points[i].label,
                              style: TextStyle(color: context.muted, fontSize: 9.5)),
                        );
                      },
                    ),
                  ),
                ),
                barGroups: [
                  for (var i = 0; i < points.length; i++)
                    BarChartGroupData(x: i, barsSpace: 2, barRods: [
                      BarChartRodData(
                          toY: points[i].income,
                          color: AppColors.success,
                          width: barW,
                          borderRadius: BorderRadius.circular(2)),
                      BarChartRodData(
                          toY: points[i].expenses,
                          color: AppColors.danger,
                          width: barW,
                          borderRadius: BorderRadius.circular(2)),
                    ]),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _dot(context, AppColors.success, context.t.income),
              const SizedBox(width: 16),
              _dot(context, AppColors.danger, context.t.expenses),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dot(BuildContext c, Color color, String label) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(color: c.muted, fontSize: 12)),
      ]);
}

// ============================================================ Category card

class _CategoryCard extends StatelessWidget {
  final List<ReportCategory> cats;
  final String currency;
  const _CategoryCard({required this.cats, required this.currency});

  @override
  Widget build(BuildContext context) {
    final total = cats.fold<double>(0, (s, e) => s + e.amount);
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
          Text(context.t.spendingByCategory,
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
                      centerSpaceRadius: 38,
                      sections: cats
                          .take(6)
                          .map((s) => PieChartSectionData(
                              value: s.amount, color: s.color, radius: 20, showTitle: false))
                          .toList(),
                    )),
                    Text(Money.compact(total),
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  children: cats.take(5).map((s) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
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
                                style: TextStyle(color: context.muted, fontSize: 13))),
                        Text('${s.percentage}%',
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                      ]),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Divider(height: 20),
          ...cats.take(6).map((s) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: [
                    Expanded(
                      child: Text('${s.name} · ${s.count}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    ),
                    Text(Money.format(s.amount, currency),
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}

// ============================================================ Budget card

class _BudgetCard extends StatelessWidget {
  final List<ReportBudgetItem> items;
  final int pct, respected, total;
  final String currency;
  const _BudgetCard(
      {required this.items,
      required this.pct,
      required this.respected,
      required this.total,
      required this.currency});

  Color _statusColor(String status) => switch (status) {
        'exceeded' => AppColors.danger,
        'warning' => AppColors.warning,
        _ => AppColors.success,
      };

  @override
  Widget build(BuildContext context) {
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
          Row(
            children: [
              Expanded(
                child: Text(context.t.reportBudgetTracking,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20)),
                child: Text(context.t.budgetsKept(respected, total),
                    style: const TextStyle(
                        color: AppColors.success, fontWeight: FontWeight.w700, fontSize: 11.5)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...items.map((b) {
            final color = _statusColor(b.status);
            final frac = (b.progress / 100).clamp(0.0, 1.0);
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(b.category,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                      ),
                      Text('${Money.compact(b.spent)} / ${Money.compact(b.budget)}',
                          style: TextStyle(color: context.muted, fontSize: 12)),
                      const SizedBox(width: 8),
                      Text('${b.progress}%',
                          style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 12.5)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Stack(
                      children: [
                        Container(height: 8, color: context.surfaceAlt),
                        FractionallySizedBox(
                          widthFactor: frac,
                          child: Container(height: 8, color: color),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ============================================================ States

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const SizedBox(height: 120),
        Icon(Icons.bar_chart_rounded, size: 56, color: context.muted),
        const SizedBox(height: 16),
        Center(
          child: Text(context.t.reportNoData,
              style: TextStyle(color: context.muted, fontSize: 14, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorState({required this.onRetry});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline_rounded, color: AppColors.danger, size: 40),
          const SizedBox(height: 12),
          Text(context.t.reportNoData, style: TextStyle(color: context.muted)),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: Text(context.t.retry),
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
          ),
        ],
      ),
    );
  }
}
