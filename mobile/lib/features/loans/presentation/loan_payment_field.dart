import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/i18n/app_text.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/form_kit.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/loan_models.dart';
import '../providers/loans_provider.dart';
import 'loan_sheet.dart';

/// "This settles a loan" toggle plus the loan picker it reveals.
///
/// Used by both transaction forms, switched by [direction]: an expense repays
/// money BORROWED, an income collects money LENT. The picker only ever lists
/// loans of that side — and the server enforces the same rule, so a tampered
/// client cannot credit a payment against the wrong loan.
///
/// When the user has no loans on that side yet, the picker is replaced by an
/// explanation and a shortcut to create one — ticking the box then leads
/// somewhere useful instead of showing an empty dropdown.
///
/// Ticking the box is a claim that this transaction settles a loan, so it is
/// only complete once a loan is picked. [showError] is raised by the parent
/// form when the user tries to save while that claim is still unfulfilled.
class LoanPaymentField extends ConsumerWidget {
  const LoanPaymentField({
    super.key,
    required this.checked,
    required this.selectedLoanId,
    required this.onCheckedChanged,
    required this.onLoanSelected,
    this.direction = LoanDirection.borrowed,
    this.accent = AppColors.danger,
    this.showError = false,
  });

  final bool checked;
  final String? selectedLoanId;
  final ValueChanged<bool> onCheckedChanged;
  final ValueChanged<String?> onLoanSelected;

  /// Which side of the loan book this form is allowed to settle.
  final LoanDirection direction;

  /// Matches the host form (red on expenses, green on income). The loans
  /// themselves keep their own tone so the link back to Loans stays readable.
  final Color accent;
  final bool showError;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final lent = direction.isLent;
    final currency = ref.watch(authProvider).user?.currency ?? 'XOF';
    final async = ref.watch(selectableLoansProvider(direction));
    final invalid = showError && checked && selectedLoanId == null;
    final tint = invalid ? AppColors.danger : accent;

    return Padding(
      padding: const EdgeInsets.only(bottom: FormKit.cardGap),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(FormKit.cardRadius),
          border: Border.all(
            width: 1.4,
            color: invalid
                ? AppColors.danger
                : checked
                    ? accent.withValues(alpha: 0.45)
                    : Colors.transparent,
          ),
        ),
        child: Column(
          children: [
            InkWell(
              onTap: () => onCheckedChanged(!checked),
              borderRadius: BorderRadius.circular(FormKit.cardRadius),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
                child: Row(
                  children: [
                    Container(
                      width: FormKit.iconTile,
                      height: FormKit.iconTile,
                      decoration: BoxDecoration(
                        color: tint.withValues(alpha: context.isDark ? 0.20 : 0.11),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        lent
                            ? Icons.volunteer_activism_rounded
                            : Icons.account_balance_rounded,
                        size: 24,
                        color: tint,
                      ),
                    ),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            lent ? t.incomeIsLoanRepayment : t.expenseIsLoanPayment,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w700, height: 1.2),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            checked
                                ? (lent ? t.incomeChooseLoan : t.expenseChooseLoan)
                                : (lent
                                    ? t.incomeLoanToggleHint
                                    : t.expenseLoanToggleHint),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.3,
                              color: invalid ? AppColors.danger : context.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch.adaptive(
                      value: checked,
                      activeThumbColor: Colors.white,
                      activeTrackColor: tint,
                      onChanged: onCheckedChanged,
                    ),
                  ],
                ),
              ),
            ),
            if (checked)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: async.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.2),
                    ),
                  ),
                  error: (e, _) => Text(e.toString(),
                      style: const TextStyle(fontSize: 12, color: AppColors.danger)),
                  data: (loans) {
                    // Belt and braces: the request was already filtered by
                    // direction, but a mismatched row must never be selectable.
                    final options =
                        loans.where((l) => l.direction == direction).toList();
                    if (options.isEmpty) {
                      return _NoLoansYet(
                        lent: lent,
                        onCreated: () => refreshLoansFrom(ref),
                        onUncheck: () => onCheckedChanged(false),
                      );
                    }
                    return Column(
                      children: [
                        for (final l in options)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _LoanOption(
                              lent: lent,
                              name: l.name,
                              remaining: l.remaining,
                              progress: l.progress,
                              suggested: l.suggestedMonthlyPayment,
                              currency: currency,
                              selected: selectedLoanId == l.id,
                              onTap: () => onLoanSelected(l.id),
                            ),
                          ),
                        if (invalid)
                          _RequiredHint(
                            message:
                                lent ? t.incomeLoanRequired : t.expenseLoanRequired,
                          ),
                      ],
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _LoanOption extends StatelessWidget {
  const _LoanOption({
    required this.lent,
    required this.name,
    required this.remaining,
    required this.progress,
    required this.suggested,
    required this.currency,
    required this.selected,
    required this.onTap,
  });

  final bool lent;
  final String name;
  final double remaining, progress;
  final double? suggested;
  final String currency;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final tone = lent ? AppColors.success : AppColors.primary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
        decoration: BoxDecoration(
          color: selected
              ? tone.withValues(alpha: context.isDark ? 0.18 : 0.07)
              : context.surfaceAlt,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? tone : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_unchecked_rounded,
              size: 19,
              color: selected ? tone : context.muted,
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 13.5, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 3),
                  Text(
                    [
                      '${lent ? t.loanRemainingLent : t.loanRemaining} '
                          '${Money.compact(remaining)}',
                      if (suggested != null)
                        '${Money.compact(suggested!)} '
                            '${lent ? t.loanPerMonthLent : t.loanPerMonth}',
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: context.muted),
                  ),
                  const SizedBox(height: 7),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: (progress / 100).clamp(0.0, 1.0),
                      minHeight: 4,
                      backgroundColor: context.borderColor,
                      valueColor: AlwaysStoppedAnimation(tone),
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

/// Inline "you must still pick a loan" message, shown once the user has tried
/// to save with the box ticked and nothing selected.
class _RequiredHint extends StatelessWidget {
  const _RequiredHint({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 1),
          child: Icon(Icons.error_outline_rounded, size: 15, color: AppColors.danger),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            message,
            style: const TextStyle(
                fontSize: 12, height: 1.35, color: AppColors.danger),
          ),
        ),
      ],
    );
  }
}

/// Shown when the toggle is on but no loans exist.
class _NoLoansYet extends StatelessWidget {
  const _NoLoansYet({
    required this.lent,
    required this.onCreated,
    required this.onUncheck,
  });
  final bool lent;
  final VoidCallback onCreated;
  final VoidCallback onUncheck;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final tone = lent ? AppColors.success : AppColors.primary;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.surfaceAlt,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 1),
                child: Icon(Icons.info_outline_rounded,
                    size: 16, color: AppColors.warning),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(lent ? t.incomeNoLoanYet : t.expenseNoLoanYet,
                    style: TextStyle(
                        fontSize: 12, height: 1.4, color: context.muted)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 42,
                  child: FilledButton.icon(
                    onPressed: () async {
                      final created = await showLoanSheet(
                        context,
                        direction:
                            lent ? LoanDirection.lent : LoanDirection.borrowed,
                      );
                      if (created == true) onCreated();
                    },
                    icon: const Icon(Icons.add_rounded, size: 17),
                    label: Text(
                      lent ? t.loanCreateFirstLent : t.loanCreateFirst,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: tone,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(13)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 42,
                child: TextButton(
                  onPressed: onUncheck,
                  child: Text(t.expenseUntickLoan,
                      style: const TextStyle(fontSize: 13)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
