import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/i18n/app_text.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/responsive.dart';
import '../../../core/utils/category_icons.dart';
import '../../../core/utils/formatters.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/loan_models.dart';
import '../providers/loans_provider.dart';
import 'loan_sheet.dart';

class LoanDetailScreen extends ConsumerWidget {
  const LoanDetailScreen({super.key, required this.loanId});
  final String loanId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final currency = ref.watch(authProvider).user?.currency ?? 'XOF';
    final async = ref.watch(loanDetailProvider(loanId));

    return Scaffold(
      appBar: AppBar(
        title: Text(
          async.hasValue ? async.value!.loan.name : t.titleLoans,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          if (async.hasValue)
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert_rounded, color: context.muted),
              onSelected: (v) async {
                final loan = async.value!.loan;
                if (v == 'edit') {
                  final saved = await showLoanSheet(context, existing: loan);
                  if (saved == true) ref.invalidate(loanDetailProvider(loanId));
                } else if (v == 'delete') {
                  await _confirmDelete(context, ref, loan);
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(value: 'edit', child: Text(t.edit)),
                PopupMenuItem(
                  value: 'delete',
                  child: Text(t.delete, style: const TextStyle(color: AppColors.danger)),
                ),
              ],
            ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Text(e.toString(),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12.5, color: context.muted)),
          ),
        ),
        data: (detail) => ResponsiveCenter(
          child: RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () async => ref.invalidate(loanDetailProvider(loanId)),
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                context.useCompactLayout ? 14 : 20,
                16,
                context.useCompactLayout ? 14 : 20,
                40,
              ),
              children: [
                _ProgressHeader(loan: detail.loan, currency: currency),
                const SizedBox(height: 16),
                _FactsGrid(loan: detail.loan, currency: currency),
                if (detail.loan.description != null &&
                    detail.loan.description!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: context.surfaceAlt,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(detail.loan.description!,
                        style: const TextStyle(fontSize: 12.5, height: 1.45)),
                  ),
                ],
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        detail.loan.isLent ? t.loanHistoryLent : t.loanHistory,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 14.5, fontWeight: FontWeight.w800),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(t.loanPaymentCount(detail.loan.paymentCount),
                        style: TextStyle(fontSize: 11.5, color: context.muted)),
                  ],
                ),
                const SizedBox(height: 12),
                if (detail.months.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: context.colors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: context.borderColor),
                    ),
                    child: Text(
                        detail.loan.isLent ? t.loanNoPaymentsLent : t.loanNoPayments,
                        textAlign: TextAlign.center,
                        style:
                            TextStyle(fontSize: 12.5, height: 1.45, color: context.muted)),
                  )
                else
                  ...detail.months.map(
                    (m) => _MonthGroup(
                      month: m,
                      currency: currency,
                      lent: detail.loan.isLent,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, Loan loan) async {
    final t = context.t;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(t.loanDeleteTitle,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
        content: Text(loan.isLent ? t.loanDeleteBodyLent : t.loanDeleteBody,
            style: const TextStyle(fontSize: 13.5, height: 1.45)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(t.cancel)),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(t.delete),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(loansRepositoryProvider).remove(loan.id);
      refreshLoansFrom(ref);
      if (context.mounted) Navigator.pop(context);
    } on ApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: AppColors.danger),
        );
      }
    }
  }
}

// ------------------------------------------------------------ Header
class _ProgressHeader extends StatelessWidget {
  const _ProgressHeader({required this.loan, required this.currency});
  final Loan loan;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final done = loan.isPaidOff;
    final lent = loan.isLent;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: done
            ? const LinearGradient(colors: [Color(0xFF10B981), Color(0xFF059669)])
            : lent
                ? AppColors.successGradient
                : AppColors.brandGradient,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: Text(
                  done
                      ? (lent ? t.loanPaidOffLent : t.loanPaidOff)
                      : (lent ? t.loanRemainingLent : t.loanRemaining),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70, fontSize: 12.5),
                ),
              ),
              const Spacer(),
              if (loan.isOverdue && !done)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(lent ? t.loanOverdueLent : t.loanOverdue,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w800)),
                ),
            ],
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              Money.format(done ? loan.totalPaid : loan.remaining, currency),
              style: const TextStyle(
                  color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: (loan.progress / 100).clamp(0.0, 1.0),
              minHeight: 8,
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
                  '${Money.format(loan.totalPaid, currency)} '
                  '${(lent ? t.loanPaidLent : t.loanPaid).toLowerCase()}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70, fontSize: 11.5),
                ),
              ),
              const SizedBox(width: 8),
              Text('${loan.progress.toStringAsFixed(0)}%',
                  style: const TextStyle(
                      color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)),
            ],
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------- Facts
class _FactsGrid extends StatelessWidget {
  const _FactsGrid({required this.loan, required this.currency});
  final Loan loan;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final lent = loan.isLent;
    final tone = lent ? AppColors.success : AppColors.primary;
    final facts = <(IconData, String, String)>[
      (
        Icons.payments_rounded,
        lent ? t.loanTotalLent : t.loanTotal,
        Money.format(loan.principalAmount, currency)
      ),
      (Icons.event_rounded, t.loanStartDate, Dates.short(loan.startDate)),
      if (loan.expectedEndDate != null)
        (Icons.flag_rounded, t.loanEndDate, Dates.short(loan.expectedEndDate!)),
      if (loan.suggestedMonthlyPayment != null)
        (
          Icons.calendar_month_rounded,
          lent ? t.loanPerMonthLent : t.loanPerMonth,
          Money.format(loan.suggestedMonthlyPayment!, currency)
        ),
      if (loan.counterparty != null && loan.counterparty!.isNotEmpty)
        (
          lent ? Icons.person_rounded : Icons.storefront_rounded,
          lent ? t.loanBorrower : t.loanLender,
          loan.counterparty!
        ),
    ];

    // Two per row on a phone, but never narrower than ~150pt: below that the
    // label and the value both ellipsise and the card says nothing.
    final available = MediaQuery.of(context).size.width -
        (context.useCompactLayout ? 38 : 50);
    final tileWidth = available / 2 < 150 ? available : available / 2;

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final (icon, label, value) in facts)
          Container(
            width: tileWidth,
            constraints: const BoxConstraints(maxWidth: 260),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            decoration: BoxDecoration(
              color: context.colors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: context.borderColor),
            ),
            child: Row(
              children: [
                Icon(icon, size: 16, color: tone),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 10, color: context.muted)),
                      Text(value,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 12.5, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// ------------------------------------------------------- Month timeline
class _MonthGroup extends StatelessWidget {
  const _MonthGroup({
    required this.month,
    required this.currency,
    required this.lent,
  });
  final LoanMonth month;
  final String currency;
  final bool lent;

  String _label() {
    // `YYYY-MM` → "juillet 2026" / "July 2026".
    final parts = month.month.split('-');
    if (parts.length != 2) return month.month;
    final d = DateTime(int.parse(parts[0]), int.parse(parts[1]));
    final s = DateFormat('MMMM y', dateLocale).format(d);
    return s[0].toUpperCase() + s.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: Text(_label(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 12.5, fontWeight: FontWeight.w800)),
              ),
              const Spacer(),
              Text(Money.format(month.total, currency),
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: lent ? AppColors.success : AppColors.primary)),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: context.colors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: context.borderColor),
            ),
            child: Column(
              children: [
                for (var i = 0; i < month.payments.length; i++) ...[
                  if (i > 0) Divider(height: 1, color: context.borderColor),
                  _PaymentRow(
                    payment: month.payments[i],
                    currency: currency,
                    lent: lent,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentRow extends StatelessWidget {
  const _PaymentRow({
    required this.payment,
    required this.currency,
    required this.lent,
  });
  final LoanPayment payment;
  final String currency;
  final bool lent;

  @override
  Widget build(BuildContext context) {
    final color = _parseColor(payment.categoryColor) ??
        (lent ? AppColors.success : AppColors.primary);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(categoryIcon(payment.categoryIcon), size: 16, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(payment.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                Text(Dates.short(payment.date),
                    style: TextStyle(fontSize: 11, color: context.muted)),
              ],
            ),
          ),
          // A repayment received is money in; one you made is money out.
          Text(
            '${lent ? '+' : '−'} ${Money.format(payment.amount, currency)}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: lent ? AppColors.success : null,
            ),
          ),
        ],
      ),
    );
  }

  static Color? _parseColor(String? hex) {
    if (hex == null || hex.isEmpty) return null;
    final h = hex.replaceFirst('#', '');
    final v = int.tryParse(h.length == 6 ? 'FF$h' : h, radix: 16);
    return v == null ? null : Color(v);
  }
}
