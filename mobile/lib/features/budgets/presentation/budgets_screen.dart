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
import '../providers/budgets_provider.dart';
import 'set_budget_sheet.dart';

class BudgetsScreen extends ConsumerWidget {
  const BudgetsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(budgetsProvider);
    final month = ref.watch(budgetMonthProvider);
    final currency = ref.watch(authProvider).user?.currency ?? 'XOF';

    return Column(
      children: [
        _MonthSwitcher(month: month, ref: ref),
        Expanded(
          child: async.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text(e.toString())),
            data: (budgets) => RefreshIndicator(
              color: AppColors.primary,
              onRefresh: () async => ref.refresh(budgetsProvider.future),
              child: budgets.isEmpty
                  ? _empty(context)
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 120),
                      children: [
                        _OverallCard(budgets: budgets, currency: currency),
                        const SizedBox(height: 20),
                        RealAiAnalyticsWidget(date: month, scope: 'BUDGET'),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(context.t.byCategory,
                                style:
                                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                            _AddChip(onTap: () => showSetBudgetSheet(context)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ...budgets.asMap().entries.map((e) => _BudgetCard(
                              b: e.value,
                              currency: currency,
                              index: e.key,
                            )),
                      ],
                    ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _empty(BuildContext context) => ListView(
        children: [
          const SizedBox(height: 70),
          Container(
            width: 96,
            height: 96,
            margin: const EdgeInsets.symmetric(horizontal: 140),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.savings_rounded, size: 44, color: AppColors.primary),
          ),
          const SizedBox(height: 20),
          Center(
            child: Text(context.t.noBudget,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: 16),
          Center(
            child: FilledButton.icon(
              onPressed: () => showSetBudgetSheet(context),
              icon: const Icon(Icons.add_rounded),
              label: Text(context.t.setBudget),
            ),
          ),
        ],
      );
}

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

class _OverallCard extends StatelessWidget {
  final List<BudgetStatus> budgets;
  final String currency;
  const _OverallCard({required this.budgets, required this.currency});

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final totalBudget = budgets.fold<double>(0, (s, b) => s + b.budget);
    final totalSpent = budgets.fold<double>(0, (s, b) => s + b.spent);
    final remaining = totalBudget - totalSpent;
    final progress = totalBudget > 0 ? (totalSpent / totalBudget) : 0.0;
    final over = totalSpent > totalBudget;

    final onTrack = budgets.where((b) => b.status == 'ok').length;
    final warning = budgets.where((b) => b.status == 'warning' || b.status == 'danger').length;
    final exceeded = budgets.where((b) => b.status == 'exceeded').length;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: AppColors.brandGradient,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(t.monthBudget,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('${budgets.length} ${t.navBudgets.toLowerCase()}',
                    style: const TextStyle(
                        color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w700)),
              ),
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
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(Money.format(totalSpent, currency),
                          style: const TextStyle(
                              color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
                    ),
                    Text('${t.onOf} ${Money.format(totalBudget, currency)}',
                        style: const TextStyle(color: Colors.white70, fontSize: 13)),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(over ? Icons.warning_amber_rounded : Icons.account_balance_wallet_rounded,
                              size: 15, color: Colors.white),
                          const SizedBox(width: 6),
                          Text(
                            over
                                ? t.overLabel(Money.format(remaining.abs(), currency))
                                : t.remainingLabel(Money.format(remaining, currency)),
                            style: const TextStyle(
                                color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Divider(color: Colors.white.withValues(alpha: 0.18), height: 1),
          const SizedBox(height: 14),
          Row(
            children: [
              _legend(const Color(0xFF86EFAC), onTrack, t.statusOk),
              _legend(const Color(0xFFFDE68A), warning, t.statusWarning),
              _legend(const Color(0xFFFCA5A5), exceeded, t.statusExceeded),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: -0.06, end: 0);
  }

  Widget _legend(Color color, int count, String label) => Expanded(
        child: Row(
          children: [
            Container(width: 9, height: 9, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 6),
            Text('$count',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
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
          onTap: () =>
              showSetBudgetSheet(context, categoryId: b.categoryId, currentAmount: b.budget),
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
                              categoryId: b.categoryId, currentAmount: b.budget);
                        } else if (v == 'delete') {
                          await ref.read(budgetsRepositoryProvider).remove(b.id);
                          ref.invalidate(budgetsProvider);
                        }
                      },
                      itemBuilder: (_) => [
                        PopupMenuItem(value: 'edit', child: Text(t.edit)),
                        PopupMenuItem(value: 'delete', child: Text(t.delete)),
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
