import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';
import '../../../core/i18n/app_text.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/category_icons.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/amount_text.dart';
import '../../ai/presentation/ai_analytics_widget.dart';
import '../../auth/providers/auth_provider.dart';
import '../../reports/reports_feature.dart';
import '../../shell/shell_providers.dart';
import '../../transactions/presentation/period_picker.dart';
import '../../transactions/providers/finance_filters.dart';
import '../data/dashboard_models.dart';
import '../providers/dashboard_provider.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(dashboardProvider);
    final user = ref.watch(authProvider).user;
    final currency = user?.currency ?? 'XOF';
    final period = ref.watch(dashboardPeriodProvider);
    final prevMonth = Dates.monthFull(period.from.month - 1);

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async => ref.refresh(dashboardProvider.future),
        child: async.when(
          loading: () => const _DashboardSkeleton(),
          error: (e, _) =>
              _ErrorView(message: e.toString(), onRetry: () => ref.refresh(dashboardProvider)),
          data: (data) => ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 110),
            children: [
              _Greeting(name: user?.displayName ?? ''),
              const SizedBox(height: 16),
              _PeriodBar(month: period.label, label: context.t.overview),
              const SizedBox(height: 18),
              _SummaryGrid(
                summary: data.summary,
                trend: data.trend,
                currency: currency,
                prevMonth: prevMonth,
              ),
              const SizedBox(height: 26),
              if (data.budgets.isNotEmpty) ...[
                _SectionHeader(
                  context.t.budgetAlerts,
                  actionLabel: context.t.seeAll,
                  onAction: () => ref.read(shellIndexProvider.notifier).set(2),
                ),
                const SizedBox(height: 12),
                _BudgetStrip(budgets: data.budgets, currency: currency),
                const SizedBox(height: 26),
              ],
              if (data.expenseDistribution.isNotEmpty) ...[
                _DistributionCard(
                  slices: data.expenseDistribution,
                  currency: currency,
                  onDetail: () => ref.read(shellIndexProvider.notifier).set(1),
                ),
                const SizedBox(height: 18),
              ],
              if (data.trend.length > 1) ...[
                _IncomeVsExpensesCard(
                  points: data.trend,
                  onReport: () => Navigator.of(context)
                      .push(MaterialPageRoute(builder: (_) => const ReportsScreen())),
                ),
                const SizedBox(height: 26),
              ],
              RealAiAnalyticsWidget(date: period.from),
              const SizedBox(height: 26),
              _SectionHeader(
                context.t.recentTransactions,
                actionLabel: context.t.seeAll,
                onAction: () => ref.read(shellIndexProvider.notifier).set(1),
              ),
              const SizedBox(height: 4),
              ...data.recent.take(5).map((t) => _TxTile(t: t, currency: currency)),
            ],
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------- Header

class _Greeting extends StatelessWidget {
  final String name;
  const _Greeting({required this.name});
  @override
  Widget build(BuildContext context) {
    final first = name.isEmpty ? '' : name.split(' ').first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(context.t.greeting(first),
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
        const SizedBox(height: 2),
        Text(context.t.dashSubtitle, style: TextStyle(color: context.muted)),
      ],
    );
  }
}

class _PeriodBar extends ConsumerWidget {
  final String month;
  final String label;
  const _PeriodBar({required this.month, required this.label});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => showPeriodPicker(context, ref, targetProvider: dashboardPeriodProvider),
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: context.colors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: context.borderColor),
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_today_rounded, size: 15, color: context.muted),
                  const SizedBox(width: 8),
                  Text(month, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                  const SizedBox(width: 4),
                  Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: context.muted),
                ],
              ),
            ),
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            gradient: AppColors.brandGradient,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              const Icon(Icons.visibility_rounded, size: 15, color: Colors.white),
              const SizedBox(width: 8),
              Text(label,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
            ],
          ),
        ),
      ],
    );
  }
}

// ------------------------------------------------------- Summary grid

class _SummaryGrid extends StatelessWidget {
  final DashboardSummary summary;
  final List<TrendPoint> trend;
  final String currency;
  final String prevMonth;
  const _SummaryGrid({
    required this.summary,
    required this.trend,
    required this.currency,
    required this.prevMonth,
  });

  @override
  Widget build(BuildContext context) {
    final incomeSpark = trend.map((p) => p.income).toList();
    final expenseSpark = trend.map((p) => p.expenses).toList();
    final savingsSpark = trend.map((p) => p.income - p.expenses).toList();
    final rateSpark =
        trend.map((p) => p.income > 0 ? (p.income - p.expenses) / p.income * 100 : 0.0).toList();

    return Column(
      children: [
        Row(children: [
          Expanded(
            child: _StatCard(
              label: context.t.income,
              value: summary.income,
              trend: summary.hasComparison ? summary.incomeTrend : null,
              spark: incomeSpark,
              icon: Icons.arrow_outward_rounded,
              color: AppColors.success,
              currency: currency,
              prevMonth: prevMonth,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: _StatCard(
              label: context.t.expenses,
              value: summary.expenses,
              trend: summary.hasComparison ? summary.expenseTrend : null,
              spark: expenseSpark,
              icon: Icons.south_east_rounded,
              color: AppColors.danger,
              currency: currency,
              prevMonth: prevMonth,
              downIsGood: true,
            ),
          ),
        ]),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(
            child: _StatCard(
              label: context.t.netSavings,
              value: summary.savings,
              trend: summary.hasComparison ? summary.savingsTrend : null,
              spark: savingsSpark,
              icon: Icons.savings_rounded,
              color: AppColors.info,
              currency: currency,
              prevMonth: prevMonth,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: _ScoreCard(
              rate: summary.savingsRate,
              rateTrend: summary.hasComparison ? summary.rateTrend : null,
              spark: rateSpark,
              prevMonth: prevMonth,
            ),
          ),
        ]),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final double value;
  final double? trend;
  final List<double> spark;
  final IconData icon;
  final Color color;
  final String currency;
  final String prevMonth;
  final bool downIsGood;
  const _StatCard({
    required this.label,
    required this.value,
    required this.trend,
    required this.spark,
    required this.icon,
    required this.color,
    required this.currency,
    required this.prevMonth,
    this.downIsGood = false,
  });

  @override
  Widget build(BuildContext context) {
    final good = trend == null ? true : (downIsGood ? trend! <= 0 : trend! >= 0);
    final trendColor = trend == 0 ? context.muted : (good ? AppColors.success : AppColors.danger);
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: color, size: 19),
          ),
          const SizedBox(height: 12),
          Text(label, style: TextStyle(color: context.muted, fontSize: 12.5)),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: AmountText(
                amount: value,
                currency: currency,
                style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (trend != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: trendColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        trend == 0
                            ? Icons.remove_rounded
                            : (trend! < 0
                                ? Icons.arrow_downward_rounded
                                : Icons.arrow_upward_rounded),
                        size: 11,
                        color: trendColor,
                      ),
                      const SizedBox(width: 1),
                      Text('${trend!.abs().round()}%',
                          style: TextStyle(
                              color: trendColor, fontSize: 11, fontWeight: FontWeight.w800)),
                    ],
                  ),
                )
              else
                const Spacer(),
              if (spark.length > 1) ...[
                const SizedBox(width: 6),
                Expanded(child: SizedBox(height: 22, child: _Sparkline(values: spark, color: color))),
              ],
            ],
          ),
          if (trend != null) ...[
            const SizedBox(height: 4),
            Text(context.t.vsMonth(prevMonth),
                style: TextStyle(color: context.muted, fontSize: 10)),
          ],
        ],
      ),
    ).animate().fadeIn(duration: 250.ms).slideY(begin: 0.08, end: 0);
  }
}

class _ScoreCard extends StatelessWidget {
  final double rate;
  final double? rateTrend;
  final List<double> spark;
  final String prevMonth;
  const _ScoreCard({
    required this.rate,
    required this.rateTrend,
    required this.spark,
    required this.prevMonth,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        gradient: AppColors.brandGradient,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Icon(Icons.percent_rounded, color: Colors.white, size: 19),
          ),
          const SizedBox(height: 12),
          Text(context.t.savingsRate, style: const TextStyle(color: Colors.white70, fontSize: 12.5)),
          const SizedBox(height: 3),
          Text('${rate.toStringAsFixed(1)}%',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white)),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (rateTrend != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                          rateTrend! >= 0
                              ? Icons.arrow_upward_rounded
                              : Icons.arrow_downward_rounded,
                          size: 11,
                          color: Colors.white),
                      const SizedBox(width: 1),
                      Text('${rateTrend!.abs().toStringAsFixed(1)}pt',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
                    ],
                  ),
                )
              else
                const Spacer(),
              if (spark.length > 1) ...[
                const SizedBox(width: 6),
                Expanded(
                    child: SizedBox(
                        height: 22, child: _Sparkline(values: spark, color: Colors.white))),
              ],
            ],
          ),
          if (rateTrend != null) ...[
            const SizedBox(height: 4),
            Text(context.t.vsMonth(prevMonth),
                style: const TextStyle(color: Colors.white60, fontSize: 10)),
          ],
        ],
      ),
    ).animate().fadeIn(duration: 250.ms).slideY(begin: 0.08, end: 0);
  }
}

class _Sparkline extends StatelessWidget {
  final List<double> values;
  final Color color;
  const _Sparkline({required this.values, required this.color});
  @override
  Widget build(BuildContext context) {
    final spots = [
      for (var i = 0; i < values.length; i++) FlSpot(i.toDouble(), values[i]),
    ];
    final minY = values.reduce((a, b) => a < b ? a : b);
    final maxY = values.reduce((a, b) => a > b ? a : b);
    return LineChart(
      LineChartData(
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
            barWidth: 2,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(show: true, color: color.withValues(alpha: 0.18)),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------- Section header

class _SectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  const _SectionHeader(this.title, {this.actionLabel, this.onAction});
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        if (actionLabel != null)
          GestureDetector(
            onTap: onAction,
            child: Text(actionLabel!,
                style: const TextStyle(
                    color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 13)),
          ),
      ],
    );
  }
}

// ------------------------------------------------------ Budget strip

class _BudgetStrip extends StatelessWidget {
  final List<BudgetStatus> budgets;
  final String currency;
  const _BudgetStrip({required this.budgets, required this.currency});
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 150,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: budgets.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, i) => _BudgetCard(b: budgets[i], currency: currency),
      ),
    );
  }
}

class _BudgetCard extends StatelessWidget {
  final BudgetStatus b;
  final String currency;
  const _BudgetCard({required this.b, required this.currency});
  @override
  Widget build(BuildContext context) {
    final (barColor, label, badgeBg) = switch (b.status) {
      'exceeded' => (AppColors.danger, 'Dépassé', AppColors.danger),
      'danger' => (AppColors.danger, 'Critique', AppColors.danger),
      'warning' => (AppColors.warning, 'Attention', AppColors.warning),
      _ => (AppColors.success, 'En bonne voie', AppColors.success),
    };
    return Container(
      width: 210,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                    color: b.color.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(10)),
                child: Icon(categoryIcon(b.icon), color: b.color, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(b.categoryName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                    Text('${b.progress.round()}%',
                        style: TextStyle(
                            color: barColor, fontWeight: FontWeight.w800, fontSize: 14)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: (b.progress / 100).clamp(0, 1),
              minHeight: 7,
              backgroundColor: context.surfaceAlt,
              valueColor: AlwaysStoppedAnimation(barColor),
            ),
          ),
          const SizedBox(height: 10),
          Text('${Money.format(b.spent, currency)} / ${Money.format(b.budget, currency)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: context.muted, fontSize: 11.5)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
            decoration: BoxDecoration(
              color: badgeBg.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(label,
                style: TextStyle(color: badgeBg, fontSize: 11, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------- Distribution

class _DistributionCard extends StatelessWidget {
  final List<CategorySlice> slices;
  final String currency;
  final VoidCallback onDetail;
  const _DistributionCard(
      {required this.slices, required this.currency, required this.onDetail});
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
          Text(context.t.spendingByCategory,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          Row(
            children: [
              SizedBox(
                width: 128,
                height: 128,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    PieChart(PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 42,
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
                        Text('${s.percentage.round()}%',
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                      ]),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Divider(height: 20),
          _CardAction(label: context.t.viewDetail, onTap: onDetail),
        ],
      ),
    );
  }
}

// ------------------------------------------------- Income vs expenses

class _IncomeVsExpensesCard extends StatelessWidget {
  final List<TrendPoint> points;
  final VoidCallback onReport;
  const _IncomeVsExpensesCard({required this.points, required this.onReport});
  @override
  Widget build(BuildContext context) {
    final maxV = points
        .expand((p) => [p.income, p.expenses])
        .fold<double>(0, (m, v) => v > m ? v : m);
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
            padding: const EdgeInsets.only(left: 4),
            child: Row(
              children: [
                Text(context.t.incomeVsExpenses,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                const Spacer(),
                _legendDot(context, AppColors.success, context.t.income),
                const SizedBox(width: 10),
                _legendDot(context, AppColors.danger, context.t.expenses),
              ],
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 160,
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
                      getTitlesWidget: (v, _) {
                        final i = v.toInt();
                        if (i < 0 || i >= points.length) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(points[i].shortLabel,
                              style: TextStyle(color: context.muted, fontSize: 10)),
                        );
                      },
                    ),
                  ),
                ),
                barGroups: [
                  for (var i = 0; i < points.length; i++)
                    BarChartGroupData(x: i, barsSpace: 3, barRods: [
                      BarChartRodData(
                          toY: points[i].income,
                          color: AppColors.success,
                          width: 7,
                          borderRadius: BorderRadius.circular(3)),
                      BarChartRodData(
                          toY: points[i].expenses,
                          color: AppColors.danger,
                          width: 7,
                          borderRadius: BorderRadius.circular(3)),
                    ]),
                ],
              ),
            ),
          ),
          const Divider(height: 20),
          _CardAction(label: context.t.viewReport, onTap: onReport),
        ],
      ),
    );
  }

  Widget _legendDot(BuildContext c, Color color, String label) => Row(children: [
        Container(
            width: 9, height: 9, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(color: c.muted, fontSize: 11)),
      ]);
}

class _CardAction extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _CardAction({required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label,
                style: const TextStyle(
                    color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 13.5)),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_forward_rounded, size: 16, color: AppColors.primary),
          ],
        ),
      ),
    );
  }
}

// -------------------------------------------------------- Insights IA

class _InsightsSection extends StatelessWidget {
  final DashboardData data;
  final String currency;
  final String prevMonth;
  const _InsightsSection({required this.data, required this.currency, required this.prevMonth});

  List<_Insight> _build(AppText t) {
    final out = <_Insight>[];
    final s = data.summary;

    // 1) Savings vs last month.
    if (s.hasComparison && s.savingsTrend != 0) {
      final up = s.savingsTrend > 0;
      final pct = s.savingsTrend.abs().round();
      out.add(_Insight(
        icon: up ? Icons.trending_up_rounded : Icons.trending_down_rounded,
        color: up ? AppColors.success : AppColors.danger,
        text: up ? t.savedMore(pct, prevMonth) : t.savingsDropped(pct, prevMonth),
        emphasis: '$pct%',
      ));
    }

    // 2) Worst budget (already sorted by progress desc from the backend).
    if (data.budgets.isNotEmpty) {
      final b = data.budgets.first;
      if (b.status == 'exceeded') {
        final amt = Money.format(b.remaining.abs(), currency);
        out.add(_Insight(
          icon: Icons.warning_amber_rounded,
          color: AppColors.danger,
          text: t.budgetExceeded(b.categoryName, amt),
          emphasis: amt,
        ));
      } else if (b.status == 'warning' || b.status == 'danger') {
        final amt = Money.format(b.remaining, currency);
        out.add(_Insight(
          icon: Icons.warning_amber_rounded,
          color: AppColors.warning,
          text: t.budgetNearLimit(b.categoryName, amt),
          emphasis: amt,
        ));
      }
    }

    // 3) Savings tip from the biggest expense category.
    if (data.expenseDistribution.isNotEmpty) {
      final top = data.expenseDistribution.first;
      final amt = Money.format(top.amount * 0.15, currency);
      out.add(_Insight(
        icon: Icons.lightbulb_outline_rounded,
        color: AppColors.primary,
        text: t.savingTip(top.name, amt),
        emphasis: amt,
      ));
    }
    return out.take(3).toList();
  }

  @override
  Widget build(BuildContext context) {
    final insights = _build(context.t);
    if (insights.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.auto_awesome_rounded, size: 18, color: AppColors.primary),
            const SizedBox(width: 8),
            Text(context.t.aiInsights,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          ],
        ),
        const SizedBox(height: 12),
        ...insights.map((i) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _InsightCard(insight: i),
            )),
      ],
    );
  }
}

class _Insight {
  final IconData icon;
  final Color color;
  final String text;
  final String emphasis; // substring of `text` to highlight
  _Insight({required this.icon, required this.color, required this.text, required this.emphasis});
}

class _InsightCard extends StatelessWidget {
  final _Insight insight;
  const _InsightCard({required this.insight});
  @override
  Widget build(BuildContext context) {
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
                color: insight.color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(11)),
            child: Icon(insight.icon, color: insight.color, size: 19),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text.rich(
              _highlight(insight.text, insight.emphasis, insight.color, context),
            ),
          ),
        ],
      ),
    );
  }

  /// Splits `text` around the first occurrence of `emphasis` and bolds it.
  TextSpan _highlight(String text, String emphasis, Color color, BuildContext context) {
    final base = TextStyle(height: 1.4, color: context.colors.onSurface, fontSize: 13.5);
    final idx = emphasis.isEmpty ? -1 : text.indexOf(emphasis);
    if (idx < 0) return TextSpan(text: text, style: base);
    return TextSpan(style: base, children: [
      TextSpan(text: text.substring(0, idx)),
      TextSpan(
          text: emphasis, style: TextStyle(fontWeight: FontWeight.w800, color: color)),
      TextSpan(text: text.substring(idx + emphasis.length)),
    ]);
  }
}

// -------------------------------------------------------- Transactions

class _TxTile extends StatelessWidget {
  final RecentTx t;
  final String currency;
  const _TxTile({required this.t, required this.currency});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: t.color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(categoryIcon(t.icon), color: t.color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                Text('${t.category} · ${Dates.short(t.date)}',
                    style: TextStyle(color: context.muted, fontSize: 12)),
              ],
            ),
          ),
          Text(
            '${t.isIncome ? '+' : '-'}${Money.format(t.amount, currency)}',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: t.isIncome ? AppColors.success : context.colors.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

// -------------------------------------------------------- Loading/error

class _DashboardSkeleton extends StatelessWidget {
  const _DashboardSkeleton();
  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: context.surfaceAlt,
      highlightColor: context.colors.surface,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _box(160, 28),
          const SizedBox(height: 20),
          Row(children: [_box(null, 128, e: true), const SizedBox(width: 14), _box(null, 128, e: true)]),
          const SizedBox(height: 14),
          Row(children: [_box(null, 128, e: true), const SizedBox(width: 14), _box(null, 128, e: true)]),
          const SizedBox(height: 24),
          _box(null, 150, e: true),
          const SizedBox(height: 20),
          _box(null, 200, e: true),
        ],
      ),
    );
  }

  Widget _box(double? w, double h, {bool e = false}) {
    final child = Container(
      width: w,
      height: h,
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
    );
    return e ? Expanded(child: child) : child;
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});
  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const SizedBox(height: 120),
        Icon(Icons.cloud_off_rounded, size: 56, color: context.muted),
        const SizedBox(height: 16),
        Center(child: Text(message, textAlign: TextAlign.center)),
        const SizedBox(height: 16),
        Center(child: FilledButton(onPressed: onRetry, child: Text(context.t.retry))),
      ],
    );
  }
}
