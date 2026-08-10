import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/i18n/app_text.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/money_input.dart';
import '../../../core/widgets/form_kit.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/loan_models.dart';
import '../providers/loans_provider.dart';

/// Create or edit a loan. Resolves true when something was saved.
///
/// [direction] seeds a new loan; on an edit it is ignored, because the loan's
/// own direction wins and cannot be changed (see [_LoanSheetState._direction]).
Future<bool?> showLoanSheet(
  BuildContext context, {
  Loan? existing,
  LoanDirection direction = LoanDirection.borrowed,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => LoanSheet(existing: existing, direction: direction),
  );
}

class LoanSheet extends ConsumerStatefulWidget {
  const LoanSheet({
    super.key,
    this.existing,
    this.direction = LoanDirection.borrowed,
  });
  final Loan? existing;
  final LoanDirection direction;

  @override
  ConsumerState<LoanSheet> createState() => _LoanSheetState();
}

class _LoanSheetState extends ConsumerState<LoanSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _lender;
  late final TextEditingController _description;
  late final TextEditingController _principal;
  late final TextEditingController _paid;

  late DateTime _startDate;
  DateTime? _endDate;
  late LoanDirection _direction;
  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.existing != null;
  bool get _lent => _direction.isLent;

  /// Green for money owed to the user, indigo for money the user owes — the
  /// same coding as the tabs, so the sheet never looks like the wrong side.
  Color get _accent => _lent ? AppColors.success : AppColors.primary;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.name ?? '');
    _lender = TextEditingController(text: e?.lender ?? '');
    _description = TextEditingController(text: e?.description ?? '');
    _principal = TextEditingController(
        text: MoneyInput.forEditing(e?.principalAmount));
    _paid = TextEditingController(
        text: e == null || e.initialPaidAmount == 0
            ? ''
            : MoneyInput.forEditing(e.initialPaidAmount));
    _startDate = e?.startDate ?? DateTime.now();
    _endDate = e?.expectedEndDate;
    // An existing loan keeps its own direction: its progress is derived from
    // transactions on one side only, and flipping it would silently rewrite
    // the history. The server has no update path for it either.
    _direction = e?.direction ?? widget.direction;
  }

  @override
  void dispose() {
    _name.dispose();
    _lender.dispose();
    _description.dispose();
    _principal.dispose();
    _paid.dispose();
    super.dispose();
  }

  double get _principalValue =>
      MoneyInput.round(MoneyInput.parseOr(_principal.text));
  double get _paidValue => MoneyInput.round(MoneyInput.parseOr(_paid.text));

  /// Drives the pill in the top bar. The two required fields carry most of the
  /// weight; the optional ones round it off so a complete form reads as full.
  double get _completion {
    final req = [_name.text.trim().isNotEmpty, _principalValue > 0]
        .where((e) => e)
        .length;
    final opt = [
      _lender.text.trim().isNotEmpty,
      _endDate != null,
      _description.text.trim().isNotEmpty,
    ].where((e) => e).length;
    return (req / 2) * 0.8 + (opt / 3) * 0.2;
  }

  Future<void> _pickDate({required bool start}) async {
    FocusScope.of(context).unfocus();
    final initial = start ? _startDate : (_endDate ?? DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      if (start) {
        _startDate = picked;
      } else {
        _endDate = picked;
      }
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final repo = ref.read(loansRepositoryProvider);
      if (_isEdit) {
        await repo.update(
          widget.existing!.id,
          name: _name.text.trim(),
          description: _description.text.trim(),
          lender: _lender.text.trim(),
          principalAmount: _principalValue,
          initialPaidAmount: _paidValue,
          startDate: _startDate,
          expectedEndDate: _endDate,
        );
      } else {
        await repo.create(
          direction: _direction,
          name: _name.text.trim(),
          description: _description.text.trim(),
          lender: _lender.text.trim(),
          principalAmount: _principalValue,
          initialPaidAmount: _paidValue,
          startDate: _startDate,
          expectedEndDate: _endDate,
        );
      }
      refreshLoansFrom(ref);
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      setState(() {
        _error = e.message;
        _saving = false;
      });
    } catch (_) {
      setState(() {
        _error = context.t.genericError;
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final currency = ref.watch(authProvider).user?.currency ?? 'XOF';
    final currencyLabel = currency == 'XOF' ? 'FCFA' : currency;
    // Live preview of what will remain, so the numbers make sense before saving.
    final remaining = (_principalValue - _paidValue).clamp(0, double.infinity);

    return FormSheetShell(
      accent: _accent,
      icon: _lent
          ? Icons.volunteer_activism_rounded
          : Icons.account_balance_wallet_rounded,
      title: _isEdit
          ? (_lent ? t.loanEditLent : t.loanEdit)
          : (_lent ? t.loanNewLent : t.loanNew),
      formKey: _formKey,
      progress: _completion,
      footer: FormPrimaryButton(
        accent: _accent,
        label: _isEdit
            ? (_lent ? t.loanSaveActionLent : t.loanSaveAction)
            : (_lent ? t.loanCreateActionLent : t.loanCreateAction),
        loading: _saving,
        onPressed: _saving ? null : _save,
      ),
      children: [
        // Offered on create only — see _direction in initState.
        if (!_isEdit)
          _DirectionPicker(
            value: _direction,
            onChanged: (d) => setState(() => _direction = d),
          ),
        FormTextCard(
          icon: _lent
              ? Icons.volunteer_activism_rounded
              : Icons.account_balance_rounded,
          accent: _accent,
          label: t.loanName,
          hint: _lent ? t.loanNameHintLent : t.loanNameHint,
          controller: _name,
          required: true,
          onChanged: (_) => setState(() {}),
          validator: (v) => (v == null || v.trim().isEmpty) ? t.required : null,
        ),
        FormTextCard(
          icon: _lent ? Icons.person_rounded : Icons.storefront_rounded,
          accent: _accent,
          label: _lent ? t.loanBorrower : t.loanLender,
          hint: _lent ? t.loanBorrowerHint : t.loanLenderHint,
          controller: _lender,
          onChanged: (_) => setState(() {}),
        ),
        FormTextCard(
          icon: Icons.payments_rounded,
          accent: _accent,
          label: _lent ? t.loanPrincipalLent : t.loanPrincipal,
          hint: '0',
          controller: _principal,
          required: true,
          keyboardType: MoneyInput.keyboard,
          inputFormatters: MoneyInput.formatters,
          suffix: currencyLabel,
          onChanged: (_) => setState(() {}),
          validator: (v) {
            final n = MoneyInput.parseOr(v);
            return n <= 0 ? t.required : null;
          },
        ),
        FormTextCard(
          icon: Icons.history_rounded,
          accent: _accent,
          label: _lent ? t.loanAlreadyPaidLent : t.loanAlreadyPaid,
          hint: '0',
          controller: _paid,
          keyboardType: MoneyInput.keyboard,
          inputFormatters: MoneyInput.formatters,
          suffix: currencyLabel,
          onChanged: (_) => setState(() {}),
          validator: (v) {
            final n = MoneyInput.parseOr(v);
            // Caught here as well as server-side so the user gets the
            // message without a round trip.
            if (n > _principalValue && _principalValue > 0) {
              return _lent
                  ? context.t.loanAlreadyPaidTooHighLent
                  : context.t.loanAlreadyPaidTooHigh;
            }
            return null;
          },
        ),
        FormInfoBanner(
          accent: _accent,
          text: Text.rich(
            TextSpan(
              style: TextStyle(fontSize: 12.5, height: 1.4, color: context.muted),
              children: [
                TextSpan(
                    text: _lent ? t.loanAlreadyPaidHelpLent : t.loanAlreadyPaidHelp),
              ],
            ),
          ),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: FormCompactPicker(
                icon: Icons.event_rounded,
                accent: _accent,
                label: t.loanStartDate,
                value: Dates.short(_startDate),
                onTap: () => _pickDate(start: true),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FormCompactPicker(
                icon: Icons.event_available_rounded,
                accent: _accent,
                label: t.loanEndDate,
                value: _endDate == null ? t.loanNoEndDate : Dates.short(_endDate!),
                placeholder: _endDate == null,
                onTap: () => _pickDate(start: false),
                onClear:
                    _endDate == null ? null : () => setState(() => _endDate = null),
              ),
            ),
          ],
        ),
        FormTextCard(
          icon: Icons.description_rounded,
          accent: _accent,
          label: t.loanDescription,
          hint: _lent ? t.loanDescriptionHintLent : t.loanDescriptionHint,
          controller: _description,
          maxLines: 2,
          maxLength: 150,
          onChanged: (_) => setState(() {}),
        ),
        if (_principalValue > 0)
          _RemainingPreview(
            lent: _lent,
            label: _lent ? t.loanRemainingLent : t.loanRemaining,
            amount: Money.format(remaining.toDouble(), currency),
          ),
        if (_error != null) FormErrorLine(message: _error!),
      ],
    );
  }
}

/// Which way the money went — a two-option segmented card.
///
/// Shown on create only: the direction decides whether an expense or an income
/// settles this loan, and every figure on the loan is derived from those
/// transactions. Flipping it later would orphan the ones already recorded, so
/// the server has no update path for it and neither does this form.
class _DirectionPicker extends StatelessWidget {
  const _DirectionPicker({required this.value, required this.onChanged});
  final LoanDirection value;
  final ValueChanged<LoanDirection> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return Padding(
      padding: const EdgeInsets.only(bottom: FormKit.cardGap),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(FormKit.cardRadius),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t.loanDirectionQuestion,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
                color: context.muted,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _DirectionOption(
                    icon: Icons.account_balance_rounded,
                    accent: AppColors.primary,
                    label: t.loanDirectionBorrowed,
                    hint: t.loanDirectionBorrowedHint,
                    selected: !value.isLent,
                    onTap: () => onChanged(LoanDirection.borrowed),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _DirectionOption(
                    icon: Icons.volunteer_activism_rounded,
                    accent: AppColors.success,
                    label: t.loanDirectionLent,
                    hint: t.loanDirectionLentHint,
                    selected: value.isLent,
                    onTap: () => onChanged(LoanDirection.lent),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DirectionOption extends StatelessWidget {
  const _DirectionOption({
    required this.icon,
    required this.accent,
    required this.label,
    required this.hint,
    required this.selected,
    required this.onTap,
  });
  final IconData icon;
  final Color accent;
  final String label, hint;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      label: '$label. $hint',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 12),
          decoration: BoxDecoration(
            color: selected
                ? accent.withValues(alpha: context.isDark ? 0.18 : 0.08)
                : context.surfaceAlt,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? accent : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(icon, size: 18, color: selected ? accent : context.muted),
                  const Spacer(),
                  Icon(
                    selected
                        ? Icons.check_circle_rounded
                        : Icons.circle_outlined,
                    size: 16,
                    color: selected ? accent : context.muted,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: selected ? accent : null,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                hint,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 10.5, height: 1.25, color: context.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Live "what will be left" summary — the one number the user is really after.
class _RemainingPreview extends StatelessWidget {
  const _RemainingPreview({
    required this.lent,
    required this.label,
    required this.amount,
  });
  final bool lent;
  final String label;
  final String amount;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 2, bottom: FormKit.cardGap),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(FormKit.cardRadius),
          gradient: lent ? AppColors.successGradient : AppColors.heroGradient,
          boxShadow: [
            BoxShadow(
              color: (lent ? AppColors.success : AppColors.primary)
                  .withValues(alpha: 0.28),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.20),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(
                  lent ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                  size: 19,
                  color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ),
            ),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(
                  amount,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
