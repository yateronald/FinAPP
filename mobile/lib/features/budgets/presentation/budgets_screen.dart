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

/// Budgets, split into the two things they actually are:
///
///  * **By category** — a cap per category. Their sum is a coverage figure.
///  * **Whole month** — ONE cap that every expense counts against, whatever
///    its category.
///
/// They live in separate tabs because conflating them is what made the old
/// header claim a "monthly budget" the user had never set: a user can sit
/// inside every category cap and still blow through the month.
class BudgetsScreen extends ConsumerStatefulWidget {
  const BudgetsScreen({super.key});

  @override
  ConsumerState<BudgetsScreen> createState() => _BudgetsScreenState();
}

class _BudgetsScreenState extends ConsumerState<BudgetsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final month = ref.watch(budgetMonthProvider);

    return Column(
      children: [
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
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 6),
              ],
            ),
            labelColor: AppColors.primary,
            unselectedLabelColor: context.muted,
            labelStyle: const TextStyle(fontWeight: FontWeight.w700),
            tabs: [
              Tab(text: t.budgetTabCategories),
              Tab(text: t.budgetTabMonth),
            ],
          ),
        ),
        _MonthSwitcher(month: month, ref: ref),
        Expanded(
          child: TabBarView(
            controller: _tab,
            children: const [_CategoriesTab(), _MonthTab()],
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════ tab 1 — categories

class _CategoriesTab extends ConsumerWidget {
  const _CategoriesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final async = ref.watch(budgetOverviewProvider);
    final currency = ref.watch(authProvider).user?.currency ?? 'XOF';

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _ErrorState(message: e.toString()),
      data: (data) {
        final cats = data.categories;
        final totals = data.totals;

        return RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () => _refresh(ref),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 120),
            children: [
              if (cats.isEmpty)
                const _CategoriesEmpty()
              else ...[
                _HeroCard(
                  title: t.budgetCoverageTitle,
                  badge: t.budgetCoverageCount(totals.categoryCount),
                  spent: totals.spentOnBudgeted,
                  budget: totals.budgeted,
                  currency: currency,
                  footer: _StatusLegend(totals: totals),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Text(t.budgetCoverageHint,
                      style: TextStyle(
                          fontSize: 11.5, height: 1.35, color: context.muted)),
                ),
                const SizedBox(height: 22),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(t.byCategory,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700)),
                    ),
                    _AddChip(
                      onTap: () =>
                          showSetBudgetSheet(context, kind: BudgetKind.category),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...cats.asMap().entries.map((e) =>
                    _BudgetCard(b: e.value, currency: currency, index: e.key)),
              ],
            ],
          ),
        );
      },
    );
  }
}

// ════════════════════════════════════════════════════ tab 2 — whole month

class _MonthTab extends ConsumerWidget {
  const _MonthTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final async = ref.watch(budgetOverviewProvider);
    final month = ref.watch(budgetMonthProvider);
    final currency = ref.watch(authProvider).user?.currency ?? 'XOF';

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _ErrorState(message: e.toString()),
      data: (data) {
        final overall = data.overall;

        return RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () => _refresh(ref),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 120),
            children: [
              if (overall == null)
                const _OverallEmptyCard()
              else ...[
                _HeroCard(
                  title: t.budgetOverallTitle,
                  badge: Dates.monthYear(month),
                  spent: overall.spent,
                  budget: overall.budget,
                  currency: currency,
                  danger: overall.isOver,
                  trailing: _OverallMenu(overall: overall),
                  repeating: overall.isRepeating,
                  footer: _PaceFooter(overall: overall, currency: currency),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Text(t.budgetOverallSubtitle,
                      style: TextStyle(
                          fontSize: 11.5, height: 1.35, color: context.muted)),
                ),
              ],
              const SizedBox(height: 22),
              // AI reads the month as a whole — this is where its advice belongs.
              RealAiAnalyticsWidget(date: month, scope: 'BUDGET'),
            ],
          ),
        );
      },
    );
  }
}

Future<void> _refresh(WidgetRef ref) async {
  ref.invalidate(budgetOverviewProvider);
  await ref.read(budgetOverviewProvider.future);
}

// ══════════════════════════════════════════════════════════════ hero card

/// The one card design both tabs share: gradient, progress ring, the two
/// amounts, what is left, and a tab-specific footer strip.
class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.title,
    required this.badge,
    required this.spent,
    required this.budget,
    required this.currency,
    required this.footer,
    this.danger = false,
    this.repeating = false,
    this.trailing,
  });

  final String title, badge, currency;
  final double spent, budget;
  final Widget footer;
  final bool danger, repeating;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final over = spent > budget;
    final remaining = budget - spent;
    final progress = budget > 0 ? spent / budget : 0.0;
    final alarm = danger || over;

    return Container(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
      decoration: BoxDecoration(
        gradient: alarm
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFE11D48), Color(0xFF9F1239)],
              )
            : AppColors.heroGradient,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: (alarm ? AppColors.danger : AppColors.primary)
                .withValues(alpha: 0.32),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700)),
              ),
              if (repeating) ...[
                const _Chip(icon: Icons.repeat_rounded),
                const SizedBox(width: 6),
              ],
              _Chip(label: badge),
              ?trailing,
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              _Ring(progress: progress, over: over),
              const SizedBox(width: 22),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(Money.format(spent, currency),
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 25,
                              fontWeight: FontWeight.w800)),
                    ),
                    Text('${t.onOf} ${Money.format(budget, currency)}',
                        style: const TextStyle(color: Colors.white70, fontSize: 13)),
                    const SizedBox(height: 12),
                    _Pill(
                      icon: over
                          ? Icons.warning_amber_rounded
                          : Icons.account_balance_wallet_rounded,
                      label: over
                          ? t.overLabel(Money.format(remaining.abs(), currency))
                          : t.remainingLabel(Money.format(remaining, currency)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(color: Colors.white.withValues(alpha: 0.18), height: 1),
          const SizedBox(height: 13),
          footer,
        ],
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: -0.06, end: 0);
  }
}

class _Chip extends StatelessWidget {
  const _Chip({this.label, this.icon});
  final String? label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: label == null ? 7 : 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
      ),
      child: icon != null
          ? Icon(icon, size: 13, color: Colors.white)
          : Text(label!,
              style: const TextStyle(
                  color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w700)),
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.17),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: Colors.white),
          const SizedBox(width: 6),
          Flexible(
            child: Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

/// Footer of the categories card: how many caps are healthy, at risk, blown.
class _StatusLegend extends StatelessWidget {
  const _StatusLegend({required this.totals});
  final BudgetTotals totals;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return Row(
      children: [
        _item(const Color(0xFF86EFAC), totals.onTrack, t.statusOk),
        _item(const Color(0xFFFDE68A), totals.atRisk, t.statusWarning),
        _item(const Color(0xFFFCA5A5), totals.exceeded, t.statusExceeded),
      ],
    );
  }

  Widget _item(Color color, int count, String label) => Expanded(
        child: Row(
          children: [
            Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 6),
            Text('$count',
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
            const SizedBox(width: 4),
            Flexible(
              child: Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70, fontSize: 11)),
            ),
          ],
        ),
      );
}

/// Footer of the month card: being under the cap on the 28th means something
/// very different from being under it on the 3rd.
class _PaceFooter extends StatelessWidget {
  const _PaceFooter({required this.overall, required this.currency});
  final OverallBudgetStatus overall;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final closed = overall.daysLeft == 0;
    final ahead = overall.isAheadOfPace;
    final accent = ahead ? const Color(0xFFFDE047) : Colors.white;

    return Column(
      children: [
        Row(
          children: [
            Icon(
              closed
                  ? Icons.event_available_rounded
                  : ahead
                      ? Icons.speed_rounded
                      : Icons.check_circle_rounded,
              size: 15,
              color: accent,
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
                    color: accent, fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ),
            if (!closed && overall.daysLeft != null)
              Text(
                overall.safeDailySpend != null && overall.remaining > 0
                    ? t.budgetSafeDaily(Money.compact(overall.safeDailySpend!))
                    : t.budgetDaysLeft(overall.daysLeft!),
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85), fontSize: 11.5),
              ),
          ],
        ),
        if (overall.uncategorisedSpend > 0) ...[
          const SizedBox(height: 9),
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
    );
  }
}

class _OverallMenu extends ConsumerWidget {
  const _OverallMenu({required this.overall});
  final OverallBudgetStatus overall;

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
        await ref
            .read(budgetsRepositoryProvider)
            .removeOverall(overall.id, withSeries: v == 'delete-series');
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

// ═════════════════════════════════════════════════════════════ empty states

class _OverallEmptyCard extends StatelessWidget {
  const _OverallEmptyCard();

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: AppColors.heroGradient,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.28),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.20),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(Icons.pie_chart_rounded,
                    color: Colors.white, size: 23),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Text(t.budgetOverallNone,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(t.budgetOverallNoneBody,
              style: const TextStyle(
                  color: Colors.white70, fontSize: 12.5, height: 1.45)),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: FilledButton.icon(
              onPressed: () =>
                  showSetBudgetSheet(context, kind: BudgetKind.overall),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text(t.budgetSetOverall),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.primary,
                textStyle: const TextStyle(fontWeight: FontWeight.w700),
                shape:
                    RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: -0.06, end: 0);
  }
}

class _CategoriesEmpty extends StatelessWidget {
  const _CategoriesEmpty();

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 34),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: context.borderColor),
      ),
      child: Column(
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.09),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.savings_rounded,
                size: 34, color: AppColors.primary),
          ),
          const SizedBox(height: 18),
          Text(t.noBudget,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 18),
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

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded, size: 38, color: context.muted),
            const SizedBox(height: 14),
            Text(message,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12.5, color: context.muted)),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════ chrome

class _MonthSwitcher extends StatelessWidget {
  final DateTime month;
  final WidgetRef ref;
  const _MonthSwitcher({required this.month, required this.ref});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
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
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5)),
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
              valueColor:
                  AlwaysStoppedAnimation(Colors.white.withValues(alpha: 0.22)),
            ),
          ),
          SizedBox(
            width: 92,
            height: 92,
            child: CircularProgressIndicator(
              value: progress.clamp(0, 1).toDouble(),
              strokeWidth: 9,
              strokeCap: StrokeCap.round,
              valueColor: AlwaysStoppedAnimation(
                  over ? const Color(0xFFFDE047) : Colors.white),
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
  const _BudgetCard({required this.b, required this.currency, required this.index});

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
                            padding:
                                const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
                            color: barColor,
                            fontWeight: FontWeight.w800,
                            fontSize: 18)),
                    const SizedBox(width: 2),
                    PopupMenuButton<String>(
                      icon: Icon(Icons.more_vert_rounded,
                          color: context.muted, size: 20),
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
                            value: 'delete-series',
                            child: Text(t.budgetDeleteSeries)),
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
