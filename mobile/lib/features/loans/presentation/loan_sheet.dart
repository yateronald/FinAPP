import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/i18n/app_text.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/form_kit.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/loan_models.dart';
import '../providers/loans_provider.dart';

/// Create or edit a loan. Resolves true when something was saved.
Future<bool?> showLoanSheet(BuildContext context, {Loan? existing}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => LoanSheet(existing: existing),
  );
}

class LoanSheet extends ConsumerStatefulWidget {
  const LoanSheet({super.key, this.existing});
  final Loan? existing;

  @override
  ConsumerState<LoanSheet> createState() => _LoanSheetState();
}

class _LoanSheetState extends ConsumerState<LoanSheet> {
  static const _accent = AppColors.primary;

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _lender;
  late final TextEditingController _description;
  late final TextEditingController _principal;
  late final TextEditingController _paid;

  late DateTime _startDate;
  DateTime? _endDate;
  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.name ?? '');
    _lender = TextEditingController(text: e?.lender ?? '');
    _description = TextEditingController(text: e?.description ?? '');
    _principal = TextEditingController(
        text: e == null ? '' : e.principalAmount.round().toString());
    _paid = TextEditingController(
        text: e == null || e.initialPaidAmount == 0
            ? ''
            : e.initialPaidAmount.round().toString());
    _startDate = e?.startDate ?? DateTime.now();
    _endDate = e?.expectedEndDate;
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

  double get _principalValue => double.tryParse(_principal.text.trim()) ?? 0;
  double get _paidValue => double.tryParse(_paid.text.trim()) ?? 0;

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
      icon: Icons.account_balance_wallet_rounded,
      title: _isEdit ? t.loanEdit : t.loanNew,
      formKey: _formKey,
      progress: _completion,
      footer: FormPrimaryButton(
        accent: _accent,
        label: _isEdit ? t.loanSaveAction : t.loanCreateAction,
        loading: _saving,
        onPressed: _saving ? null : _save,
      ),
      children: [
        FormTextCard(
          icon: Icons.account_balance_rounded,
          accent: _accent,
          label: t.loanName,
          hint: t.loanNameHint,
          controller: _name,
          required: true,
          onChanged: (_) => setState(() {}),
          validator: (v) => (v == null || v.trim().isEmpty) ? t.required : null,
        ),
        FormTextCard(
          icon: Icons.storefront_rounded,
          accent: _accent,
          label: t.loanLender,
          hint: t.loanLenderHint,
          controller: _lender,
          onChanged: (_) => setState(() {}),
        ),
        FormTextCard(
          icon: Icons.payments_rounded,
          accent: _accent,
          label: t.loanPrincipal,
          hint: '0',
          controller: _principal,
          required: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          suffix: currencyLabel,
          onChanged: (_) => setState(() {}),
          validator: (v) {
            final n = double.tryParse((v ?? '').trim()) ?? 0;
            return n <= 0 ? t.required : null;
          },
        ),
        FormTextCard(
          icon: Icons.history_rounded,
          accent: _accent,
          label: t.loanAlreadyPaid,
          hint: '0',
          controller: _paid,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          suffix: currencyLabel,
          onChanged: (_) => setState(() {}),
          validator: (v) {
            final n = double.tryParse((v ?? '').trim()) ?? 0;
            // Caught here as well as server-side so the user gets the
            // message without a round trip.
            if (n > _principalValue && _principalValue > 0) {
              return context.t.loanAlreadyPaidTooHigh;
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
                TextSpan(text: t.loanAlreadyPaidHelp),
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
          hint: t.loanDescriptionHint,
          controller: _description,
          maxLines: 2,
          maxLength: 150,
          onChanged: (_) => setState(() {}),
        ),
        if (_principalValue > 0)
          _RemainingPreview(
            label: t.loanRemaining,
            amount: Money.format(remaining.toDouble(), currency),
          ),
        if (_error != null) FormErrorLine(message: _error!),
      ],
    );
  }
}

/// Live "what will be left" summary — the one number the user is really after.
class _RemainingPreview extends StatelessWidget {
  const _RemainingPreview({required this.label, required this.amount});
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
          gradient: AppColors.heroGradient,
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.28),
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
              child: const Icon(Icons.trending_down_rounded,
                  size: 19, color: Colors.white),
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
            Text(
              amount,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
