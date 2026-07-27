import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/i18n/app_text.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/ai_models.dart';
import '../providers/ai_providers.dart';

class ForecastPanel extends ConsumerWidget {
  const ForecastPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(forecastProvider);
    final horizon = ref.watch(forecastHorizonProvider);
    final currency = ref.watch(authProvider).user?.currency ?? 'XOF';

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(e.toString(), textAlign: TextAlign.center),
        ),
      ),
      data: (f) => RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async => ref.refresh(forecastProvider.future),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
          children: [
            _HorizonSelector(
              current: horizon,
              onSelect: (h) => ref.read(forecastHorizonProvider.notifier).set(h),
            ),
            const SizedBox(height: 16),
            _ModelBadges(f: f),
            const SizedBox(height: 16),
            _OverviewGrid(o: f.overview, currency: currency),
            const SizedBox(height: 20),
            if (f.cashflow.isNotEmpty) ...[
              _CashflowCard(points: f.cashflow, currency: currency),
              const SizedBox(height: 20),
            ],
            if (f.alerts.isNotEmpty) ...[
              _Title(context.t.alerts),
              const SizedBox(height: 10),
              ...f.alerts.map((a) => _AlertCard(a: a)),
              const SizedBox(height: 12),
            ],
            if (f.objectives.isNotEmpty) ...[
              _Title(context.t.objectives),
              const SizedBox(height: 10),
              ...f.objectives.map((o) => _ObjectiveCard(o: o, currency: currency)),
              const SizedBox(height: 12),
            ],
            if (f.suggestions.isNotEmpty) ...[
              _Title(context.t.suggestions),
              const SizedBox(height: 10),
              ...f.suggestions.map((s) => _SuggestionCard(s: s)),
            ],
          ],
        ),
      ),
    );
  }
}

class _HorizonSelector extends StatelessWidget {
  final int current;
  final ValueChanged<int> onSelect;
  const _HorizonSelector({required this.current, required this.onSelect});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: context.surfaceAlt,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [30, 60, 90].map((h) {
          final sel = h == current;
          return Expanded(
            child: GestureDetector(
              onTap: () => onSelect(h),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: sel ? context.colors.surface : Colors.transparent,
                  borderRadius: BorderRadius.circular(11),
                  boxShadow: sel
                      ? [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 6)]
                      : null,
                ),
                child: Text('$h ${context.t.days}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: sel ? AppColors.primary : context.muted)),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _ModelBadges extends StatelessWidget {
  final ForecastData f;
  const _ModelBadges({required this.f});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.psychology_rounded, color: AppColors.primary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(context.t.forecastModels,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                const SizedBox(height: 2),
                Text(
                  '${context.t.income} : ${f.incomeModel.label} · ${context.t.expenses} : ${f.expenseModel.label}',
                  style: TextStyle(color: context.muted, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OverviewGrid extends StatelessWidget {
  final ForecastOverview o;
  final String currency;
  const _OverviewGrid({required this.o, required this.currency});
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(children: [
          Expanded(
              child: _stat(context, context.t.projectedIncome, o.projectedIncome, o.incomeTrend,
                  AppColors.success, currency)),
          const SizedBox(width: 12),
          Expanded(
              child: _stat(context, context.t.projectedExpenses, o.projectedExpenses,
                  o.expenseTrend, AppColors.danger, currency, downGood: true)),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
              child: _stat(context, context.t.projectedSavings, o.projectedSavings, o.savingsTrend,
                  AppColors.info, currency)),
          const SizedBox(width: 12),
          Expanded(
              child: _stat(context, context.t.projectedBalance, o.projectedBalance, null,
                  AppColors.primary, currency)),
        ]),
      ],
    );
  }

  Widget _stat(BuildContext context, String label, double value, double? trend, Color color,
      String currency,
      {bool downGood = false}) {
    final good = trend == null ? true : (downGood ? trend <= 0 : trend >= 0);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: context.muted, fontSize: 12.5)),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(Money.format(value, currency),
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color)),
          ),
          if (trend != null) ...[
            const SizedBox(height: 4),
            Text(trend == 0 ? '— ${context.t.stable}' : percentLabel(trend),
                style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: trend == 0 ? context.muted : (good ? AppColors.success : AppColors.danger))),
          ],
        ],
      ),
    );
  }
}

class _CashflowCard extends StatelessWidget {
  final List<CashPoint> points;
  final String currency;
  const _CashflowCard({required this.points, required this.currency});

  @override
  Widget build(BuildContext context) {
    final actualSpots = <FlSpot>[];
    final forecastSpots = <FlSpot>[];
    for (var i = 0; i < points.length; i++) {
      final p = points[i];
      if (p.actual != null) actualSpots.add(FlSpot(i.toDouble(), p.actual!));
      if (p.forecast != null) forecastSpots.add(FlSpot(i.toDouble(), p.forecast!));
    }
    // Bridge the actual and forecast lines at the junction.
    if (actualSpots.isNotEmpty && forecastSpots.isNotEmpty) {
      forecastSpots.insert(0, actualSpots.last);
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 18, 16, 12),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: context.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Text(context.t.cashflow,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const SizedBox(width: 8),
              _legend(context, AppColors.primary, context.t.real, false),
              const SizedBox(width: 14),
              _legend(context, AppColors.warning, context.t.forecastWord, true),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 180,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: null,
                  getDrawingHorizontalLine: (_) =>
                      FlLine(color: context.borderColor, strokeWidth: 1),
                ),
                titlesData: const FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                lineTouchData: const LineTouchData(enabled: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: actualSpots,
                    isCurved: true,
                    color: AppColors.primary,
                    barWidth: 3,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                        show: true, color: AppColors.primary.withValues(alpha: 0.08)),
                  ),
                  LineChartBarData(
                    spots: forecastSpots,
                    isCurved: true,
                    color: AppColors.warning,
                    barWidth: 3,
                    dashArray: [6, 4],
                    dotData: const FlDotData(show: false),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _legend(BuildContext context, Color color, String label, bool dashed) {
    return Row(
      children: [
        Container(width: 16, height: 3, color: color),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(color: context.muted, fontSize: 12)),
      ],
    );
  }
}

class _AlertCard extends StatelessWidget {
  final ForecastAlert a;
  const _AlertCard({required this.a});
  @override
  Widget build(BuildContext context) {
    final color = a.isWarning ? AppColors.warning : AppColors.success;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(a.isWarning ? Icons.warning_amber_rounded : Icons.check_circle_rounded,
              color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(a.title, style: const TextStyle(fontWeight: FontWeight.w700, height: 1.3)),
                if (a.detail.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(a.detail, style: TextStyle(color: context.muted, fontSize: 12.5)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ObjectiveCard extends StatelessWidget {
  final ForecastObjective o;
  final String currency;
  const _ObjectiveCard({required this.o, required this.currency});
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.borderColor),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                  child: Text(o.name,
                      style: const TextStyle(fontWeight: FontWeight.w700))),
              Text('${o.percentage}%',
                  style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.primary)),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: (o.percentage / 100).clamp(0, 1),
              minHeight: 7,
              backgroundColor: context.surfaceAlt,
              valueColor: const AlwaysStoppedAnimation(AppColors.primary),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${Money.format(o.current, currency)} / ${Money.format(o.target, currency)}',
                  style: TextStyle(color: context.muted, fontSize: 12.5)),
              if (o.etaDate != null)
                Text('≈ ${o.etaDate}', style: TextStyle(color: context.muted, fontSize: 12.5)),
            ],
          ),
        ],
      ),
    );
  }
}

class _SuggestionCard extends StatelessWidget {
  final ForecastSuggestion s;
  const _SuggestionCard({required this.s});
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.borderColor),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => showSuggestionAiSheet(context, s.text),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.lightbulb_outline_rounded, color: AppColors.warning, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.text,
                          style: const TextStyle(fontWeight: FontWeight.w600, height: 1.35)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(s.cta.isNotEmpty ? s.cta : context.t.seeSuggestions,
                              style: const TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700)),
                          const SizedBox(width: 3),
                          const Icon(Icons.auto_awesome_rounded,
                              color: AppColors.primary, size: 13),
                        ],
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: context.muted, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Opens a sheet that asks the AI to expand a forecast suggestion into concrete,
/// personalised advice based on the user's real data.
void showSuggestionAiSheet(BuildContext context, String suggestion) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _SuggestionAiSheet(suggestion: suggestion),
  );
}

class _SuggestionAiSheet extends ConsumerStatefulWidget {
  final String suggestion;
  const _SuggestionAiSheet({required this.suggestion});
  @override
  ConsumerState<_SuggestionAiSheet> createState() => _SuggestionAiSheetState();
}

class _SuggestionAiSheetState extends ConsumerState<_SuggestionAiSheet> {
  String _reply = '';
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _ask();
  }

  Future<void> _ask() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    final fr = context.t.isFr;
    final prompt = fr
        ? 'À partir de cette prévision sur mes finances : "${widget.suggestion}"\n\n'
            'Donne-moi un plan concret et chiffré pour y arriver, basé sur mes données réelles : '
            'les postes précis à ajuster, combien économiser sur chacun, et en combien de temps. '
            'Sois court et actionnable.'
        : 'Based on this forecast about my finances: "${widget.suggestion}"\n\n'
            'Give me a concrete, quantified plan to achieve it using my real data: '
            'which categories to adjust, how much to save on each, and in what timeframe. '
            'Keep it short and actionable.';
    try {
      final (reply, _) = await ref.read(aiRepositoryProvider).chat(prompt, const []);
      if (!mounted) return;
      setState(() {
        _reply = reply;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollController) => Container(
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: context.borderColor, borderRadius: BorderRadius.circular(4)),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                      gradient: AppColors.brandGradient,
                      borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 17),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(t.aiSuggestionTitle,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.warning.withValues(alpha: 0.25)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.lightbulb_outline_rounded,
                      color: AppColors.warning, size: 17),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(widget.suggestion,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: _loading
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const CircularProgressIndicator(color: AppColors.primary),
                        const SizedBox(height: 14),
                        Text(t.aiThinking,
                            style: TextStyle(color: context.muted, fontSize: 13)),
                      ],
                    )
                  : _failed
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline_rounded,
                                color: AppColors.danger, size: 34),
                            const SizedBox(height: 10),
                            Text(t.saveFailed, style: TextStyle(color: context.muted)),
                            const SizedBox(height: 12),
                            FilledButton.icon(
                              onPressed: _ask,
                              icon: const Icon(Icons.refresh_rounded, size: 16),
                              label: Text(t.retry),
                              style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
                            ),
                          ],
                        )
                      : ListView(
                          controller: scrollController,
                          children: [
                            MarkdownBody(
                              data: _reply,
                              selectable: true,
                              styleSheet: MarkdownStyleSheet.fromTheme(context.theme).copyWith(
                                p: context.theme.textTheme.bodyMedium?.copyWith(height: 1.5),
                                tableBorder:
                                    TableBorder.all(color: context.borderColor, width: 1),
                                tableCellsPadding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 5),
                              ),
                            ),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Title extends StatelessWidget {
  final String text;
  const _Title(this.text);
  @override
  Widget build(BuildContext context) =>
      Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700));
}
