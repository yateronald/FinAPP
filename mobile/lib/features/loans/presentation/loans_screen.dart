import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/i18n/app_text.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/responsive.dart';
import '../../../core/utils/formatters.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/loan_models.dart';
import '../providers/loans_provider.dart';
import 'loan_detail_screen.dart';
import 'loan_sheet.dart';

class LoansScreen extends ConsumerStatefulWidget {
  const LoansScreen({super.key});
  @override
  ConsumerState<LoansScreen> createState() => _LoansScreenState();
}

class _LoansScreenState extends ConsumerState<LoansScreen> {
  /// Settled and archived loans are hidden by default so the list shows what
  /// still needs attention.
  bool _showClosed = false;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final currency = ref.watch(authProvider).user?.currency ?? 'XOF';
    final async = ref.watch(_showClosed ? allLoansProvider : loansProvider);

    return ResponsiveCenter(
      child: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorState(
          message: e.toString(),
          onRetry: () => refreshLoansFrom(ref),
        ),
        data: (loans) {
          if (loans.isEmpty && !_showClosed) {
            return _EmptyState(onCreate: () => _openSheet(context));
          }

          final totalRemaining =
              loans.where((l) => !l.isPaidOff).fold<double>(0, (a, l) => a + l.remaining);
          final totalBorrowed = loans.fold<double>(0, (a, l) => a + l.principalAmount);
          final totalPaid = loans.fold<double>(0, (a, l) => a + l.totalPaid);

          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () async => refreshLoansFrom(ref),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
              children: [
                _SummaryCard(
                  remaining: totalRemaining,
                  paid: totalPaid,
                  borrowed: totalBorrowed,
                  currency: currency,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Text(
                      t.titleLoans,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                    ),
                    const Spacer(),
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
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => LoanDetailScreen(loanId: l.id),
                          ),
                        ),
                      ),
                    )),
                const SizedBox(height: 8),
                SizedBox(
                  height: 50,
                  child: OutlinedButton.icon(
                    onPressed: () => _openSheet(context),
                    icon: const Icon(Icons.add_rounded, size: 19),
                    label: Text(t.loanNew),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
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
    final created = await showLoanSheet(context);
    if (created == true) refreshLoansFrom(ref);
  }
}

// ---------------------------------------------------------------- Summary
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.remaining,
    required this.paid,
    required this.borrowed,
    required this.currency,
  });
  final double remaining, paid, borrowed;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final pct = borrowed > 0 ? (paid / borrowed).clamp(0.0, 1.0) : 0.0;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.brandGradient,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t.loanRemaining,
              style: const TextStyle(color: Colors.white70, fontSize: 12.5)),
          const SizedBox(height: 4),
          Text(
            Money.format(remaining, currency),
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
              Text('${t.loanPaid} ${Money.compact(paid)}',
                  style: const TextStyle(color: Colors.white70, fontSize: 11.5)),
              Text('${t.loanTotal} ${Money.compact(borrowed)}',
                  style: const TextStyle(color: Colors.white70, fontSize: 11.5)),
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
    final done = loan.isPaidOff;
    final accent = done
        ? AppColors.success
        : loan.isOverdue
            ? AppColors.danger
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
                    done ? Icons.verified_rounded : Icons.account_balance_rounded,
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
                      if (loan.lender != null && loan.lender!.isNotEmpty)
                        Text(loan.lender!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 11.5, color: context.muted)),
                    ],
                  ),
                ),
                _StatusPill(loan: loan),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.loanRemaining,
                        style: TextStyle(fontSize: 10.5, color: context.muted)),
                    Text(
                      Money.format(loan.remaining, currency),
                      style: TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w800, color: accent),
                    ),
                  ],
                ),
                const Spacer(),
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
                Text(
                  '${Money.compact(loan.totalPaid)} / ${Money.compact(loan.principalAmount)}',
                  style: TextStyle(fontSize: 11, color: context.muted),
                ),
                const Spacer(),
                if (!done && loan.monthsRemaining != null)
                  Text(t.loanMonthsLeft(loan.monthsRemaining!),
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
    late final String label;
    late final Color color;
    if (loan.isPaidOff) {
      label = t.loanPaidOff;
      color = AppColors.success;
    } else if (loan.isOverdue) {
      label = t.loanOverdue;
      color = AppColors.danger;
    } else {
      label = t.loanActive;
      color = AppColors.primary;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: color)),
    );
  }
}

// ------------------------------------------------------------ Empty/error
class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onCreate});
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(26),
              ),
              child: const Icon(Icons.account_balance_rounded,
                  size: 36, color: AppColors.primary),
            ),
            const SizedBox(height: 18),
            Text(t.loanEmptyTitle,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(t.loanEmptyBody,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, height: 1.45, color: context.muted)),
            const SizedBox(height: 22),
            FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add_rounded, size: 19),
              label: Text(t.loanCreateFirst),
            ),
          ],
        ),
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
            const Icon(Icons.error_outline_rounded,
                size: 34, color: AppColors.danger),
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
