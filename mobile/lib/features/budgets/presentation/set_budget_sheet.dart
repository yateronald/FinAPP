import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/i18n/app_text.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/category_icons.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/money_input.dart';
import '../../../core/widgets/form_kit.dart';
import '../../auth/providers/auth_provider.dart';
import '../../categories/data/category_model.dart';
import '../../categories/providers/categories_provider.dart';
import '../../transactions/presentation/add_transaction_sheet.dart'
    show showCategoryPickerSheet;
import '../providers/budgets_provider.dart';

/// Which layer a budget belongs to — the month as a whole, or one category.
enum BudgetKind { overall, category }

Future<void> showSetBudgetSheet(
  BuildContext context, {
  BudgetKind kind = BudgetKind.category,
  String? categoryId,
  double? currentAmount,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => SetBudgetSheet(
      kind: kind,
      categoryId: categoryId,
      currentAmount: currentAmount,
    ),
  );
}

class SetBudgetSheet extends ConsumerStatefulWidget {
  final BudgetKind kind;
  final String? categoryId;
  final double? currentAmount;
  const SetBudgetSheet({
    super.key,
    required this.kind,
    this.categoryId,
    this.currentAmount,
  });

  @override
  ConsumerState<SetBudgetSheet> createState() => _SetBudgetSheetState();
}

class _SetBudgetSheetState extends ConsumerState<SetBudgetSheet> {
  static const _accent = AppColors.primary;

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amount;
  late BudgetKind _kind;
  String? _categoryId;

  /// 1 = this month only. Anything higher writes one independent budget per
  /// month, so each month keeps its own record.
  int _repeatMonths = 1;

  bool _saving = false;
  bool _categoryTouched = false;
  String? _error;

  /// Editing an existing budget: the layer is fixed, and so is the category.
  bool get _isEdit => widget.currentAmount != null;
  bool get _isOverall => _kind == BudgetKind.overall;

  @override
  void initState() {
    super.initState();
    _kind = widget.kind;
    _categoryId = widget.categoryId;
    _amount = TextEditingController(
        text: MoneyInput.forEditing(widget.currentAmount));
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  /// Rounded to the stored precision so the value sent matches the value the
  /// database keeps — otherwise the sheet would show a figure the server never
  /// agreed to.
  double get _amountValue => MoneyInput.round(MoneyInput.parseOr(_amount.text));

  double get _completion {
    final done = [
      _amountValue > 0,
      _isOverall || _categoryId != null,
    ].where((e) => e).length;
    return done / 2;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_isOverall && _categoryId == null) {
      setState(() {
        _categoryTouched = true;
        _error = context.t.chooseCategory;
      });
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _error = null;
    });

    final month = ref.read(budgetMonthProvider);
    final repo = ref.read(budgetsRepositoryProvider);
    try {
      if (_isOverall) {
        await repo.upsertOverall(
          amount: _amountValue,
          month: month.month,
          year: month.year,
          repeatMonths: _repeatMonths,
        );
      } else {
        await repo.upsert(
          categoryId: _categoryId!,
          amount: _amountValue,
          month: month.month,
          year: month.year,
          repeatMonths: _repeatMonths,
        );
      }
      ref.invalidate(budgetOverviewProvider);
      if (mounted) {
        Navigator.pop(context);
        if (_repeatMonths > 1) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(
              content: Text(context.t.budgetAppliedTo(_repeatMonths)),
              behavior: SnackBarBehavior.floating,
            ));
        }
      }
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = context.t.genericError);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final month = ref.watch(budgetMonthProvider);
    final currency = ref.watch(authProvider).user?.currency ?? 'XOF';
    final categories = ref.watch(categoriesByTypeProvider('EXPENSE'));
    final selected = categories.where((c) => c.id == _categoryId).firstOrNull;

    return FormSheetShell(
      accent: _accent,
      icon: _isOverall ? Icons.pie_chart_rounded : Icons.savings_rounded,
      title: _isEdit
          ? (_isOverall ? t.budgetEditOverall : t.editBudget)
          : (_isOverall ? t.budgetSetOverall : t.setBudget),
      subtitle: Dates.monthYear(month),
      formKey: _formKey,
      progress: _completion,
      footer: FormPrimaryButton(
        accent: _accent,
        label: t.save,
        loading: _saving,
        onPressed: _saving ? null : _save,
      ),
      children: [
        // The layer is a property of the budget itself, so it is only
        // selectable while creating one.
        if (!_isEdit) ...[
          _KindSelector(
            value: _kind,
            onChanged: (k) => setState(() {
              _kind = k;
              _error = null;
              _categoryTouched = false;
            }),
          ),
          const SizedBox(height: FormKit.cardGap),
        ],

        if (_isOverall)
          FormInfoBanner(
            accent: _accent,
            icon: Icons.pie_chart_rounded,
            text: Text(t.budgetOverallSubtitle,
                style: TextStyle(fontSize: 12.5, height: 1.4, color: context.muted)),
          )
        else
          FormPickerCard(
            icon: Icons.category_rounded,
            accent: _accent,
            label: t.category,
            required: true,
            value: selected?.name ?? t.selectCategory,
            placeholder: selected == null,
            errorText:
                _categoryTouched && _categoryId == null ? t.chooseCategory : null,
            leading: selected == null ? null : _CategoryDot(category: selected),
            onTap: widget.categoryId != null
                ? () {} // locked while editing a specific category budget
                : () async {
                    FocusScope.of(context).unfocus();
                    final id = await showCategoryPickerSheet(
                      context,
                      categories: categories,
                      selectedId: _categoryId,
                      type: 'EXPENSE',
                    );
                    if (id != null) {
                      setState(() {
                        _categoryId = id;
                        _categoryTouched = false;
                        if (_error == t.chooseCategory) _error = null;
                      });
                    }
                  },
          ),

        FormTextCard(
          icon: Icons.payments_rounded,
          accent: _accent,
          label: t.monthlyAmount,
          hint: '0',
          controller: _amount,
          required: true,
          keyboardType: MoneyInput.keyboard,
          inputFormatters: MoneyInput.formatters,
          suffix: currency == 'XOF' ? 'FCFA' : currency,
          textStyle: const TextStyle(
              fontSize: 24, fontWeight: FontWeight.w800, height: 1.25),
          onChanged: (_) => setState(() {}),
          validator: (v) {
            final n = MoneyInput.tryParse(v);
            return (n == null || n <= 0) ? t.invalidAmount : null;
          },
        ),

        // Repetition is only offered on creation: editing one month must not
        // silently rewrite the months around it.
        if (!_isEdit) ...[
          _RepeatSelector(
            value: _repeatMonths,
            onChanged: (n) => setState(() => _repeatMonths = n),
          ),
          FormInfoBanner(
            accent: _accent,
            icon: Icons.history_toggle_off_rounded,
            text: Text(t.budgetRepeatHint,
                style: TextStyle(fontSize: 12, height: 1.4, color: context.muted)),
          ),
        ],

        if (_error != null) FormErrorLine(message: _error!),
      ],
    );
  }
}

/// Two mutually exclusive layers, shown side by side so the difference is
/// visible at the moment of choosing.
class _KindSelector extends StatelessWidget {
  const _KindSelector({required this.value, required this.onChanged});
  final BudgetKind value;
  final ValueChanged<BudgetKind> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(t.budgetAppliesTo,
              style: TextStyle(
                  fontSize: 12.5, fontWeight: FontWeight.w700, color: context.muted)),
        ),
        Row(
          children: [
            Expanded(
              child: _KindOption(
                icon: Icons.pie_chart_rounded,
                label: t.budgetKindOverall,
                selected: value == BudgetKind.overall,
                onTap: () => onChanged(BudgetKind.overall),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _KindOption(
                icon: Icons.category_rounded,
                label: t.budgetKindCategory,
                selected: value == BudgetKind.category,
                onTap: () => onChanged(BudgetKind.category),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _KindOption extends StatelessWidget {
  const _KindOption({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? AppColors.primary.withValues(alpha: context.isDark ? 0.22 : 0.10)
          : context.colors.surface,
      borderRadius: BorderRadius.circular(FormKit.cardRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(FormKit.cardRadius),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(FormKit.cardRadius),
            border: Border.all(
              width: 1.4,
              color: selected ? AppColors.primary : Colors.transparent,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon,
                  size: 21,
                  color: selected ? AppColors.primary : context.muted),
              const SizedBox(height: 9),
              Text(
                label,
                maxLines: 2,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.25,
                  fontWeight: FontWeight.w700,
                  color: selected ? AppColors.primary : context.colors.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// How many consecutive months to write. Each one becomes its own row.
class _RepeatSelector extends StatelessWidget {
  const _RepeatSelector({required this.value, required this.onChanged});
  final int value;
  final ValueChanged<int> onChanged;

  static const _choices = [1, 3, 6, 12];

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return Padding(
      padding: const EdgeInsets.only(bottom: FormKit.cardGap),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 13, 14, 14),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(FormKit.cardRadius),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.repeat_rounded, size: 18, color: AppColors.primary),
                const SizedBox(width: 9),
                Text(t.budgetRepeat,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                for (final n in _choices) ...[
                  Expanded(
                    child: _RepeatChip(
                      label: n == 1 ? t.budgetRepeatOnce : t.budgetRepeatMonths(n),
                      selected: value == n,
                      onTap: () => onChanged(n),
                    ),
                  ),
                  if (n != _choices.last) const SizedBox(width: 7),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RepeatChip extends StatelessWidget {
  const _RepeatChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primary : context.surfaceAlt,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 40,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          // Scales down rather than spilling past the chip, whatever the
          // translation turns the label into.
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              maxLines: 1,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : context.colors.onSurface,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryDot extends StatelessWidget {
  const _CategoryDot({required this.category});
  final Category category;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        color: category.color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(categoryIcon(category.icon), size: 16, color: category.color),
    );
  }
}
