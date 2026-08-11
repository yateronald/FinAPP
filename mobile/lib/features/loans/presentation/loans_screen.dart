import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/i18n/app_text.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/responsive.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/amount_text.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/loan_models.dart';
import '../providers/loans_provider.dart';
import 'loan_detail_screen.dart';
import 'loan_sheet.dart';

/// Loans, split in two by direction.
///
/// Money you owe and money you are owed are opposite sides of the balance
/// sheet: summing them would be meaningless, so they never share a total.
/// Everything below the tab bar is a single widget parameterised by direction
/// — one design, two datasets.
class LoansScreen extends ConsumerStatefulWidget {
  const LoansScreen({super.key});
  @override
  ConsumerState<LoansScreen> createState() => _LoansScreenState();
}

class _LoansScreenState extends ConsumerState<LoansScreen>
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
    final compact = context.useCompactLayout;

    return Column(
      children: [
        Container(
          margin: EdgeInsets.fromLTRB(compact ? 14 : 20, 4, compact ? 14 : 20, 10),
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
            labelStyle: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: compact ? 13 : 14,
            ),
            tabs: [
              Tab(text: t.loanTabBorrowed),
              Tab(text: t.loanTabLent),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tab,
            children: const [
              _LoansTab(direction: LoanDirection.borrowed),
              _LoansTab(direction: LoanDirection.lent),
            ],
          ),
        ),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════ one side

class _LoansTab extends ConsumerStatefulWidget {
  const _LoansTab({required this.direction});
  final LoanDirection direction;

  @override
  ConsumerState<_LoansTab> createState() => _LoansTabState();
}

class _LoansTabState extends ConsumerState<_LoansTab>
    with AutomaticKeepAliveClientMixin {
  /// Settled and archived loans are hidden by default so the list shows what
  /// still needs attention.
  bool _showClosed = false;

  /// Keeps each tab's scroll position and toggle when switching between them.
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final t = context.t;
    final lent = widget.direction.isLent;
    final currency = ref.watch(authProvider).user?.currency ?? 'XOF';
    final async = ref.watch(
      _showClosed ? allLoansProvider(widget.direction) : loansProvider(widget.direction),
    );
    final compact = context.useCompactLayout;
    final pad = compact ? 14.0 : 20.0;

    return ResponsiveCenter(
      child: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorState(
          message: e.toString(),
          onRetry: () => refreshLoansFrom(ref),
        ),
        data: (loans) {
          if (loans.isEmpty && !_showClosed) {
            return _EmptyState(
              lent: lent,
              onCreate: () => _openSheet(context),
            );
          }

          final totalRemaining =
              loans.where((l) => !l.isPaidOff).fold<double>(0, (a, l) => a + l.remaining);
          final totalPrincipal = loans.fold<double>(0, (a, l) => a + l.principalAmount);
          final totalSettled = loans.fold<double>(0, (a, l) => a + l.totalPaid);

          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () async => refreshLoansFrom(ref),
            child: ListView(
              padding: EdgeInsets.fromLTRB(pad, 4, pad, 120),
              children: [
                _SummaryCard(
                  lent: lent,
                  remaining: totalRemaining,
                  settled: totalSettled,
                  principal: totalPrincipal,
                  currency: currency,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        lent ? t.titleLoansLent : t.titleLoans,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => setState(() => _showClosed = !_showClosed),
                      icon: Icon(
                        _showClosed
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        size: 16,
                      ),
                      label: Text(
                        _showClosed ? t.loanActive : t.seeAll,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                if (loans.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Text(t.noData,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: context.muted)),
                  ),
                ...loans.map((l) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _LoanCard(
                        loan: l,
                        currency: currency,
                        onTap: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => LoanDetailScreen(loanId: l.id),
                            ),
                          );
                          if (mounted) refreshLoansFrom(ref);
                        },
                      ),
                    )),
                const SizedBox(height: 8),
                SizedBox(
                  height: 50,
                  child: OutlinedButton.icon(
                    onPressed: () => _openSheet(context),
                    icon: const Icon(Icons.add_rounded, size: 19),
                    label: Text(
                      lent ? t.loanNewLent : t.loanNew,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    style: OutlinedButton.styleFrom(
                      shape:
                          RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _openSheet(BuildContext context) async {
    final created = await showLoanSheet(context, direction: widget.direction);
    if (created == true && mounted) refreshLoansFrom(ref);
  }
}

// ---------------------------------------------------------------- Summary
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.lent,
    required this.remaining,
    required this.settled,
    required this.principal,
    required this.currency,
  });
  final bool lent;
  final double remaining, settled, principal;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final pct = principal > 0 ? (settled / principal).clamp(0.0, 1.0) : 0.0;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        // Money owed to you is an asset, not a debt — the green gradient keeps
        // the two tabs readable at a glance without reading the labels.
        gradient: lent ? AppColors.successGradient : AppColors.brandGradient,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(lent ? t.loanLentSummaryTitle : t.loanRemaining,
              style: const TextStyle(color: Colors.white70, fontSize: 12.5)),
          const SizedBox(height: 4),
          AmountText(
            amount: remaining,
            currency: currency,
            style: const TextStyle(
                color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 7,
              backgroundColor: Colors.white.withValues(alpha: 0.25),
              valueColor: const AlwaysStoppedAnimation(Colors.white),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  '${lent ? t.loanPaidLent : t.loanPaid} ${Money.compact(settled)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70, fontSize: 11.5),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  '${lent ? t.loanTotalLent : t.loanTotal} ${Money.compact(principal)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: const TextStyle(color: Colors.white70, fontSize: 11.5),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------- Loan card
class _LoanCard extends StatelessWidget {
  const _LoanCard({required this.loan, required this.currency, required this.onTap});
  final Loan loan;
  final String currency;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final lent = loan.isLent;
    final done = loan.isPaidOff;
    final accent = done
        ? AppColors.success
        : loan.isOverdue
            ? AppColors.danger
            : lent
                ? AppColors.success
                : AppColors.primary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
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
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(
                    done
                        ? Icons.verified_rounded
                        : lent
                            ? Icons.volunteer_activism_rounded
                            : Icons.account_balance_rounded,
                    color: accent,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(loan.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 14.5, fontWeight: FontWeight.w700)),
                      if (loan.counterparty != null && loan.counterparty!.isNotEmpty)
                        Text(loan.counterparty!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 11.5, color: context.muted)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _StatusPill(loan: loan),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(lent ? t.loanRemainingLent : t.loanRemaining,
                          style: TextStyle(fontSize: 10.5, color: context.muted)),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          Money.format(loan.remaining, currency),
                          style: TextStyle(
                              fontSize: 17, fontWeight: FontWeight.w800, color: accent),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${loan.progress.toStringAsFixed(0)}%',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: (loan.progress / 100).clamp(0.0, 1.0),
                minHeight: 6,
                backgroundColor: context.surfaceAlt,
                valueColor: AlwaysStoppedAnimation(accent),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Flexible(
                  child: Text(
                    '${Money.compact(loan.totalPaid)} / ${Money.compact(loan.principalAmount)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: context.muted),
                  ),
                ),
                const Spacer(),
                if (!done && loan.monthsRemaining != null)
                  Text(t.loanMonthsLeft(loan.monthsRemaining!),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, color: context.muted)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.loan});
  final Loan loan;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final lent = loan.isLent;
    late final String label;
    late final Color color;
    if (loan.isPaidOff) {
      label = lent ? t.loanPaidOffLent : t.loanPaidOff;
      color = AppColors.success;
    } else if (loan.isOverdue) {
      label = lent ? t.loanOverdueLent : t.loanOverdue;
      color = AppColors.danger;
    } else {
      label = t.loanActive;
      color = lent ? AppColors.success : AppColors.primary;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: color)),
    );
  }
}

// ------------------------------------------------------------ Empty/error
class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.lent, required this.onCreate});
  final bool lent;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final accent = lent ? AppColors.success : AppColors.primary;
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(26),
            ),
            child: Icon(
              lent
                  ? Icons.volunteer_activism_rounded
                  : Icons.account_balance_rounded,
              size: 36,
              color: accent,
            ),
          ),
          const SizedBox(height: 18),
          Text(lent ? t.loanEmptyTitleLent : t.loanEmptyTitle,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(lent ? t.loanEmptyBodyLent : t.loanEmptyBody,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, height: 1.45, color: context.muted)),
          const SizedBox(height: 22),
          FilledButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.add_rounded, size: 19),
            label: Text(lent ? t.loanCreateFirstLent : t.loanCreateFirst),
            style: FilledButton.styleFrom(backgroundColor: accent),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 34, color: AppColors.danger),
            const SizedBox(height: 12),
            Text(message,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12.5, color: context.muted)),
            const SizedBox(height: 14),
            OutlinedButton(onPressed: onRetry, child: Text(context.t.retry)),
          ],
        ),
      ),
    );
  }
}
