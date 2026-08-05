import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/i18n/app_text.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
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

  Future<void> _pickDate({required bool start}) async {
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
    // Live preview of what will remain, so the numbers make sense before saving.
    final remaining = (_principalValue - _paidValue).clamp(0, double.infinity);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: EdgeInsets.fromLTRB(
            20, 12, 20, 20 + MediaQuery.of(context).padding.bottom),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                        color: context.borderColor,
                        borderRadius: BorderRadius.circular(4)),
                  ),
                ),
                const SizedBox(height: 18),
                Text(_isEdit ? t.loanEdit : t.loanNew,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 18),

                TextFormField(
                  controller: _name,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: t.loanName,
                    hintText: t.loanNameHint,
                    prefixIcon: const Icon(Icons.account_balance_rounded, size: 20),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? t.required : null,
                ),
                const SizedBox(height: 14),

                TextFormField(
                  controller: _lender,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: t.loanLender,
                    hintText: t.loanLenderHint,
                    prefixIcon: const Icon(Icons.storefront_rounded, size: 20),
                  ),
                ),
                const SizedBox(height: 14),

                TextFormField(
                  controller: _principal,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: t.loanPrincipal,
                    prefixIcon: const Icon(Icons.payments_rounded, size: 20),
                    suffixText: currency == 'XOF' ? 'FCFA' : currency,
                  ),
                  validator: (v) {
                    final n = double.tryParse((v ?? '').trim()) ?? 0;
                    return n <= 0 ? t.required : null;
                  },
                ),
                const SizedBox(height: 14),

                TextFormField(
                  controller: _paid,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: t.loanAlreadyPaid,
                    prefixIcon: const Icon(Icons.history_rounded, size: 20),
                    suffixText: currency == 'XOF' ? 'FCFA' : currency,
                  ),
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
                const SizedBox(height: 6),
                Text(t.loanAlreadyPaidHelp,
                    style: TextStyle(fontSize: 11, height: 1.35, color: context.muted)),
                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: _DateField(
                        label: t.loanStartDate,
                        value: Dates.short(_startDate),
                        onTap: () => _pickDate(start: true),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _DateField(
                        label: t.loanEndDate,
                        value: _endDate == null ? t.loanNoEndDate : Dates.short(_endDate!),
                        onTap: () => _pickDate(start: false),
                        onClear: _endDate == null
                            ? null
                            : () => setState(() => _endDate = null),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                TextFormField(
                  controller: _description,
                  maxLines: 2,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(labelText: t.loanDescription),
                ),

                if (_principalValue > 0) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.trending_down_rounded,
                            size: 17, color: AppColors.primary),
                        const SizedBox(width: 10),
                        Text('${t.loanRemaining} : ',
                            style: const TextStyle(fontSize: 12.5)),
                        Text(
                          Money.format(remaining, currency),
                          style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary),
                        ),
                      ],
                    ),
                  ),
                ],

                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!,
                      style: const TextStyle(color: AppColors.danger, fontSize: 12.5)),
                ],

                const SizedBox(height: 20),
                SizedBox(
                  height: 52,
                  child: FilledButton(
                    onPressed: _saving ? null : _save,
                    style: FilledButton.styleFrom(
                      shape:
                          RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2.2))
                        : Text(_isEdit ? t.save : t.create,
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onTap,
    this.onClear,
  });
  final String label;
  final String value;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.event_rounded, size: 19),
          suffixIcon: onClear == null
              ? null
              : IconButton(
                  icon: const Icon(Icons.close_rounded, size: 16),
                  onPressed: onClear,
                ),
        ),
        child: Text(value, style: const TextStyle(fontSize: 13.5)),
      ),
    );
  }
}
