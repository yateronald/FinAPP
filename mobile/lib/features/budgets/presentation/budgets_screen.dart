import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/i18n/app_text.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/category_icons.dart';
import '../../../core/utils/formatters.dart';
import '../../ai/presentation/ai_analytics_widget.dart';
import '../../auth/providers/auth_provider.dart';
import '../../dashboard/data/dashboard_models.dart';
import '../data/budget_models.dart';
import '../providers/budgets_provider.dart';
import 'set_budget_sheet.dart';

/// Budgets for one month, in two independent layers:
///
///  1. the **overall cap** — one number for the whole month, that every
///     expense counts against;
///  2. the **category budgets** — caps per category, whose sum is a coverage
///     figure and never the month's budget.
///
/// Keeping them apart is the point: a user can sit inside every category cap
/// and still blow through the month.
class BudgetsScreen extends ConsumerWidget {
  const BudgetsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final async = ref.watch(budgetOverviewProvider);
    final month = ref.watch(budgetMonthProvider);
    final currency = ref.watch(authProvider).user?.currency ?? 'XOF';

    return Column(
      children: [
        _MonthSwitcher(month: month, ref: ref),
        Expanded(
          child: async.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text(e.toString())),
            data: (data) => RefreshIndicator(
              color: AppColors.primary,
              onRefresh: () async {
                ref.invalidate(budgetOverviewProvider);
                await ref.read(budgetOverviewProvider.future);
              },
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 120),
                children: [
                  // ── 1. The month as a whole ──────────────────────────
                  _SectionTitle(
                    title: t.budgetOverallTitle,
                    subtitle: t.budgetOverallSubtitle,
                  ),
                  const SizedBox(height: 10),
                  if (data.overall == null)
                    const _OverallEmptyCard()
                  else
                    _OverallBudgetCard(
                      overall: data.overall!,
                      currency: currency,
                      month: month,
                    ),

                  const SizedBox(height: 24),
                  RealAiAnalyticsWidget(date: month, scope: 'BUDGET'),

                  // ── 2. Category caps ─────────────────────────────────
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(t.byCategory,
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w700)),
                      ),
                      _AddChip(
                        onTap: () => showSetBudgetSheet(context,
                            kind: BudgetKind.category),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (data.categories.isEmpty)
                    const _CategoriesEmpty()
                  else ...[
                    _CoverageCard(totals: data.totals, currency: currency),
                    const SizedBox(height: 14),
                    ...data.categories.asMap().entries.map((e) => _BudgetCard(
                          b: e.value,
                          currency: currency,
                          index: e.key,
                          month: month,
                        )),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.subtitle});
  final String title, subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 3),
        Text(subtitle,
            style: TextStyle(fontSize: 12, height: 1.35, color: context.muted)),
      ],
    );
  }
}

// ══════════════════════════════════════════════ overall (month-wide) budget

class _OverallBudgetCard extends ConsumerWidget {
  const _OverallBudgetCard({
    required this.overall,
    required this.currency,
    required this.month,
  });

  final OverallBudgetStatus overall;
  final String currency;
  final DateTime month;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final over = overall.isOver;
    final progress = overall.budget > 0 ? overall.spent / overall.budget : 0.0;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: over
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFDC2626), Color(0xFF9F1239)],
              )
            : AppColors.heroGradient,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: (over ? AppColors.danger : AppColors.primary)
                .withValues(alpha: 0.30),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(Dates.monthYear(month),
                  style: const TextStyle(
                      color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
              const Spacer(),
              if (overall.isRepeating)
                _Pill(icon: Icons.repeat_rounded, label: t.budgetRepeatingBadge),
              const SizedBox(width: 6),
              _OverallMenu(overall: overall, month: month),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _Ring(progress: progress, over: over),
              const SizedBox(width: 22),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(Money.format(overall.spent, currency),
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w800)),
                    ),
                    Text('${t.onOf} ${Money.format(overall.budget, currency)}',
                        style: const TextStyle(color: Colors.white70, fontSize: 13)),
                    const SizedBox(height: 12),
                    _Pill(
                      icon: over
                          ? Icons.warning_amber_rounded
                          : Icons.account_balance_wallet_rounded,
                      label: over
                          ? t.overLabel(
                              Money.format(overall.remaining.abs(), currency))
                          : t.remainingLabel(
                              Money.format(overall.remaining, currency)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          // Pace: being under the cap on the 28th means something very
          // different from being under it on the 3rd.
          if (overall.expectedProgress != null) ...[
            const SizedBox(height: 16),
            Divider(color: Colors.white.withValues(alpha: 0.18), height: 1),
            const SizedBox(height: 12),
            _PaceRow(overall: overall, currency: currency),
          ],
          if (overall.uncategorisedSpend > 0) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.visibility_off_rounded,
                    size: 14, color: Colors.white.withValues(alpha: 0.75)),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    t.budgetUnwatched(
                        Money.format(overall.uncategorisedSpend, currency)),
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85), fontSize: 11.5),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: -0.06, end: 0);
  }
}

class _PaceRow extends StatelessWidget {
  const _PaceRow({required this.overall, required this.currency});
  final OverallBudgetStatus overall;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final closed = overall.daysLeft == 0;
    final ahead = overall.isAheadOfPace;

    return Row(
      children: [
        Icon(
          closed
              ? Icons.event_available_rounded
              : ahead
                  ? Icons.speed_rounded
                  : Icons.check_circle_rounded,
          size: 15,
          color: ahead ? const Color(0xFFFDE047) : Colors.white,
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            closed
                ? t.budgetMonthClosed
                : ahead
                    ? t.budgetAheadOfPace
                    : t.budgetOnPace,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: ahead ? const Color(0xFFFDE047) : Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        if (!closed && overall.daysLeft != null)
          Text(
            overall.safeDailySpend != null && overall.remaining > 0
                ? t.budgetSafeDaily(
                    Money.compact(overall.safeDailySpend!))
                : t.budgetDaysLeft(overall.daysLeft!),
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.85), fontSize: 11.5),
          ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.17),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Text(label,
              style: const TextStyle(
                  color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _OverallMenu extends ConsumerWidget {
  const _OverallMenu({required this.overall, required this.month});
  final OverallBudgetStatus overall;
  final DateTime month;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_horiz_rounded, color: Colors.white, size: 20),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 40),
      onSelected: (v) async {
        if (v == 'edit') {
          showSetBudgetSheet(context,
              kind: BudgetKind.overall, currentAmount: overall.budget);
          return;
        }
        await ref.read(budgetsRepositoryProvider).removeOverall(
              overall.id,
              withSeries: v == 'delete-series',
            );
        ref.invalidate(budgetOverviewProvider);
      },
      itemBuilder: (_) => [
        PopupMenuItem(value: 'edit', child: Text(t.edit)),
        PopupMenuItem(value: 'delete', child: Text(t.budgetDeleteThisMonth)),
        if (overall.isRepeating)
          PopupMenuItem(value: 'delete-series', child: Text(t.budgetDeleteSeries)),
      ],
    );
  }
}

class _OverallEmptyCard extends StatelessWidget {
  const _OverallEmptyCard();

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.11),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.pie_chart_rounded,
                    color: AppColors.primary, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(t.budgetOverallNone,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(t.budgetOverallNoneBody,
              style: TextStyle(fontSize: 12.5, height: 1.45, color: context.muted)),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: FilledButton.icon(
              onPressed: () =>
                  showSetBudgetSheet(context, kind: BudgetKind.overall),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text(t.budgetSetOverall),
              style: FilledButton.styleFrom(
                shape:
                    RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════ category coverage

/// Sum of the category caps. Labelled as coverage, never as "the month's
/// budget" — that claim belongs to [_OverallBudgetCard] alone.
class _CoverageCard extends StatelessWidget {
  const _CoverageCard({required this.totals, required this.currency});
  final BudgetTotals totals;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final progress =
        totals.budgeted > 0 ? totals.spentOnBudgeted / totals.budgeted : 0.0;
    final over = totals.spentOnBudgeted > totals.budgeted;
    final barColor = over ? AppColors.danger : AppColors.primary;

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
          Row(
            children: [
              Expanded(
                child: Text(t.budgetCoverageTitle,
                    style: const TextStyle(
                        fontSize: 13.5, fontWeight: FontWeight.w700)),
              ),
              Text(
                '${Money.compact(totals.spentOnBudgeted)} / ${Money.compact(totals.budgeted)}',
                style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w800, color: barColor),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(t.budgetCoverageHint,
              style: TextStyle(fontSize: 11, height: 1.35, color: context.muted)),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Stack(
              children: [
                Container(height: 8, color: context.surfaceAlt),
                FractionallySizedBox(
                  widthFactor: progress.clamp(0, 1).toDouble(),
                  child: Container(height: 8, color: barColor),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _legend(AppColors.success, totals.onTrack, t.statusOk),
              _legend(AppColors.warning, totals.atRisk, t.statusWarning),
              _legend(AppColors.danger, totals.exceeded, t.statusExceeded),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legend(Color color, int count, String label) => Expanded(
        child: Row(
          children: [
            Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 6),
            Text('$count',
                style:
                    const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5)),
            const SizedBox(width: 4),
            Flexible(
              child: Builder(
                builder: (context) => Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: context.muted, fontSize: 10.5)),
              ),
            ),
          ],
        ),
      );
}

class _CategoriesEmpty extends StatelessWidget {
  const _CategoriesEmpty();

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      decoration: BoxDecoration(
        color: context.surfaceAlt,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Icon(Icons.savings_rounded, size: 34, color: context.muted),
          const SizedBox(height: 12),
          Text(t.noBudget,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: context.muted)),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: () =>
                showSetBudgetSheet(context, kind: BudgetKind.category),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: Text(t.setBudget),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════ chrome

class _MonthSwitcher extends StatelessWidget {
  final DateTime month;
  final WidgetRef ref;
  const _MonthSwitcher({required this.month, required this.ref});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
          decoration: BoxDecoration(
            color: context.surfaceAlt,
            borderRadius: BorderRadius.circular(30),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _navBtn(context, Icons.chevron_left_rounded,
                  () => ref.read(budgetMonthProvider.notifier).set(
                      DateTime(month.year, month.month - 1))),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Text(Dates.monthYear(month),
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              ),
              _navBtn(context, Icons.chevron_right_rounded,
                  () => ref.read(budgetMonthProvider.notifier).set(
                      DateTime(month.year, month.month + 1))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navBtn(BuildContext context, IconData icon, VoidCallback onTap) => Material(
        color: context.colors.surface,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(padding: const EdgeInsets.all(6), child: Icon(icon, size: 20)),
        ),
      );
}

class _AddChip extends StatelessWidget {
  final VoidCallback onTap;
  const _AddChip({required this.onTap});
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.add_rounded, size: 16, color: AppColors.primary),
            const SizedBox(width: 4),
            Text(context.t.add,
                style: const TextStyle(
                    color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 12.5)),
          ],
        ),
      ),
    );
  }
}

class _Ring extends StatelessWidget {
  final double progress;
  final bool over;
  const _Ring({required this.progress, required this.over});
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 92,
      height: 92,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 92,
            height: 92,
            child: CircularProgressIndicator(
              value: 1,
              strokeWidth: 9,
              valueColor: AlwaysStoppedAnimation(Colors.white.withValues(alpha: 0.22)),
            ),
          ),
          SizedBox(
            width: 92,
            height: 92,
            child: CircularProgressIndicator(
              value: progress.clamp(0, 1).toDouble(),
              strokeWidth: 9,
              strokeCap: StrokeCap.round,
              valueColor: AlwaysStoppedAnimation(over ? const Color(0xFFFDE047) : Colors.white),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${(progress * 100).round()}%',
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w800, fontSize: 19)),
              Text(context.t.spentWord,
                  style: const TextStyle(color: Colors.white70, fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }
}

class _BudgetCard extends ConsumerWidget {
  final BudgetStatus b;
  final String currency;
  final int index;
  final DateTime month;
  const _BudgetCard({
    required this.b,
    required this.currency,
    required this.index,
    required this.month,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final (barColor, label) = switch (b.status) {
      'exceeded' => (AppColors.danger, t.statusExceeded),
      'danger' => (AppColors.danger, t.statusCritical),
      'warning' => (AppColors.warning, t.statusWarning),
      _ => (AppColors.success, t.statusOk),
    };
    final pct = b.progress.round();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => showSetBudgetSheet(context,
              kind: BudgetKind.category,
              categoryId: b.categoryId,
              currentAmount: b.budget),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            b.color.withValues(alpha: 0.22),
                            b.color.withValues(alpha: 0.10),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(categoryIcon(b.icon), color: b.color, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(b.categoryName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 15)),
                          const SizedBox(height: 3),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: barColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(label,
                                style: TextStyle(
                                    color: barColor,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ),
                    ),
                    Text('$pct%',
                        style: TextStyle(
                            color: barColor, fontWeight: FontWeight.w800, fontSize: 18)),
                    const SizedBox(width: 2),
                    PopupMenuButton<String>(
                      icon: Icon(Icons.more_vert_rounded, color: context.muted, size: 20),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 40),
                      onSelected: (v) async {
                        if (v == 'edit') {
                          showSetBudgetSheet(context,
                              kind: BudgetKind.category,
                              categoryId: b.categoryId,
                              currentAmount: b.budget);
                          return;
                        }
                        await ref.read(budgetsRepositoryProvider).remove(
                              b.id,
                              withSeries: v == 'delete-series',
                            );
                        ref.invalidate(budgetOverviewProvider);
                      },
                      itemBuilder: (_) => [
                        PopupMenuItem(value: 'edit', child: Text(t.edit)),
                        PopupMenuItem(
                            value: 'delete', child: Text(t.budgetDeleteThisMonth)),
                        PopupMenuItem(
                            value: 'delete-series', child: Text(t.budgetDeleteSeries)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Stack(
                    children: [
                      Container(height: 9, color: context.surfaceAlt),
                      FractionallySizedBox(
                        widthFactor: (b.progress / 100).clamp(0, 1),
                        child: Container(
                          height: 9,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [barColor.withValues(alpha: 0.7), barColor],
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(t.spentLabel(Money.format(b.spent, currency)),
                        style: TextStyle(color: context.muted, fontSize: 12.5)),
                    Text(
                      b.remaining >= 0
                          ? t.remainingLabel(Money.format(b.remaining, currency))
                          : t.overLabel(Money.format(b.remaining.abs(), currency)),
                      style: TextStyle(
                          color: b.remaining >= 0 ? context.muted : AppColors.danger,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ).animate(delay: (60 * index).ms).fadeIn(duration: 280.ms).slideY(begin: 0.1, end: 0);
  }
}
