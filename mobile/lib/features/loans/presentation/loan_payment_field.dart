import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/i18n/app_text.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/loans_provider.dart';
import 'loan_sheet.dart';

/// "This repays a loan" checkbox plus the loan picker it reveals.
///
/// When the user has no loans yet, the picker is replaced by an explanation and
/// a shortcut to create one — ticking the box then leads somewhere useful
/// instead of showing an empty dropdown.
class LoanPaymentField extends ConsumerWidget {
  const LoanPaymentField({
    super.key,
    required this.checked,
    required this.selectedLoanId,
    required this.onCheckedChanged,
    required this.onLoanSelected,
  });

  final bool checked;
  final String? selectedLoanId;
  final ValueChanged<bool> onCheckedChanged;
  final ValueChanged<String?> onLoanSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final currency = ref.watch(authProvider).user?.currency ?? 'XOF';
    final async = ref.watch(selectableLoansProvider);

    return Container(
      decoration: BoxDecoration(
        color: checked ? AppColors.primary.withValues(alpha: 0.05) : context.surfaceAlt,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: checked ? AppColors.primary.withValues(alpha: 0.35) : Colors.transparent,
        ),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => onCheckedChanged(!checked),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  SizedBox(
                    height: 24,
                    width: 24,
                    child: Checkbox(
                      value: checked,
                      onChanged: (v) => onCheckedChanged(v ?? false),
                      shape:
                          RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      activeColor: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Icon(Icons.account_balance_rounded,
                      size: 18,
                      color: checked ? AppColors.primary : context.muted),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      t.expenseIsLoanPayment,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: checked ? FontWeight.w700 : FontWeight.w600,
                        color: checked ? AppColors.primary : context.colors.onSurface,
                      ),
                    ),
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
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.2),
                  ),
                ),
                error: (e, _) => Text(e.toString(),
                    style: const TextStyle(fontSize: 12, color: AppColors.danger)),
                data: (loans) {
                  if (loans.isEmpty) return _NoLoansYet(onCreated: () => refreshLoansFrom(ref));
                  return Column(
                    children: [
                      for (final l in loans)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _LoanOption(
                            name: l.name,
                            remaining: l.remaining,
                            progress: l.progress,
                            suggested: l.suggestedMonthlyPayment,
                            currency: currency,
                            selected: selectedLoanId == l.id,
                            onTap: () => onLoanSelected(l.id),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _LoanOption extends StatelessWidget {
  const _LoanOption({
    required this.name,
    required this.remaining,
    required this.progress,
    required this.suggested,
    required this.currency,
    required this.selected,
    required this.onTap,
  });

  final String name;
  final double remaining, progress;
  final double? suggested;
  final String currency;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(13),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
            color: selected ? AppColors.primary : context.borderColor,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_unchecked_rounded,
              size: 18,
              color: selected ? AppColors.primary : context.muted,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Text('${t.loanRemaining} ${Money.compact(remaining)}',
                          style: TextStyle(fontSize: 11, color: context.muted)),
                      if (suggested != null) ...[
                        Text(' · ', style: TextStyle(color: context.muted)),
                        Text('${Money.compact(suggested!)} ${t.loanPerMonth}',
                            style: TextStyle(fontSize: 11, color: context.muted)),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: (progress / 100).clamp(0.0, 1.0),
                      minHeight: 4,
                      backgroundColor: context.surfaceAlt,
                      valueColor: const AlwaysStoppedAnimation(AppColors.primary),
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

/// Shown when the checkbox is ticked but no loans exist.
class _NoLoansYet extends StatelessWidget {
  const _NoLoansYet({required this.onCreated});
  final VoidCallback onCreated;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: context.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline_rounded,
                  size: 16, color: AppColors.warning),
              const SizedBox(width: 8),
              Expanded(
                child: Text(t.expenseNoLoanYet,
                    style: TextStyle(
                        fontSize: 12, height: 1.4, color: context.muted)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 40,
            child: OutlinedButton.icon(
              onPressed: () async {
                final created = await showLoanSheet(context);
                if (created == true) onCreated();
              },
              icon: const Icon(Icons.add_rounded, size: 17),
              label: Text(t.loanCreateFirst, style: const TextStyle(fontSize: 13)),
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
