import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/i18n/app_text.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/category_icons.dart';
import '../../categories/data/category_model.dart';
import '../../categories/providers/categories_provider.dart';
import '../../transactions/presentation/add_transaction_sheet.dart' show showCategoryPickerSheet;
import '../providers/budgets_provider.dart';

Future<void> showSetBudgetSheet(
  BuildContext context, {
  String? categoryId,
  double? currentAmount,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => SetBudgetSheet(categoryId: categoryId, currentAmount: currentAmount),
  );
}

class SetBudgetSheet extends ConsumerStatefulWidget {
  final String? categoryId;
  final double? currentAmount;
  const SetBudgetSheet({super.key, this.categoryId, this.currentAmount});

  @override
  ConsumerState<SetBudgetSheet> createState() => _SetBudgetSheetState();
}

class _SetBudgetSheetState extends ConsumerState<SetBudgetSheet> {
  late final TextEditingController _amount;
  String? _categoryId;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _categoryId = widget.categoryId;
    _amount = TextEditingController(
        text: widget.currentAmount != null ? widget.currentAmount!.round().toString() : '');
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final amount = double.tryParse(_amount.text.replaceAll(RegExp(r'[^0-9.]'), ''));
    if (_categoryId == null) {
      setState(() => _error = context.t.chooseCategory);
      return;
    }
    if (amount == null || amount <= 0) {
      setState(() => _error = context.t.invalidAmount);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final month = ref.read(budgetMonthProvider);
    try {
      await ref.read(budgetsRepositoryProvider).upsert(
            categoryId: _categoryId!,
            amount: amount,
            month: month.month,
            year: month.year,
          );
      ref.invalidate(budgetsProvider);
      if (mounted) Navigator.pop(context);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoriesByTypeProvider('EXPENSE'));
    final locked = widget.categoryId != null;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: EdgeInsets.fromLTRB(20, 12, 20, 24 + MediaQuery.of(context).padding.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                    color: context.borderColor, borderRadius: BorderRadius.circular(4)),
              ),
            ),
            const SizedBox(height: 16),
            // Header: brand badge + title + close.
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(13),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.35),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.savings_rounded, color: Colors.white, size: 21),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(locked ? context.t.editBudget : context.t.setBudget,
                      style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
                ),
                InkWell(
                  onTap: () => Navigator.pop(context),
                  customBorder: const CircleBorder(),
                  child: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(color: context.surfaceAlt, shape: BoxShape.circle),
                    child: Icon(Icons.close_rounded, size: 18, color: context.muted),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            if (!locked) ...[
              Text(context.t.category, style: TextStyle(color: context.muted, fontSize: 13)),
              const SizedBox(height: 8),
              _BudgetCategoryField(
                categories: categories,
                selectedId: _categoryId,
                onSelect: (id) => setState(() => _categoryId = id),
              ),
              const SizedBox(height: 18),
            ],
            // Amount — highlighted hero field.
            Container(
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.22)),
              ),
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(context.t.monthlyAmount,
                      style: TextStyle(
                          color: context.muted, fontSize: 12, fontWeight: FontWeight.w600)),
                  TextField(
                    controller: _amount,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                    style: const TextStyle(
                        fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.primary),
                    decoration: InputDecoration(
                      hintText: '0',
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 4),
                      suffixText: 'FCFA',
                      suffixStyle: TextStyle(
                          color: context.muted, fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: AppColors.danger)),
            ],
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                    : Text(context.t.save),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact category field for the budget sheet — mirrors the transaction sheet's
/// dropdown-style selector so both flows feel identical.
class _BudgetCategoryField extends StatelessWidget {
  final List<Category> categories;
  final String? selectedId;
  final ValueChanged<String> onSelect;
  const _BudgetCategoryField({
    required this.categories,
    required this.selectedId,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) {
      return Text(context.t.noCategory, style: TextStyle(color: context.muted));
    }
    final selected = categories.where((c) => c.id == selectedId).firstOrNull;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () async {
        final id = await showCategoryPickerSheet(
          context,
          categories: categories,
          selectedId: selectedId,
          type: 'EXPENSE', // budgets always cap an expense category
        );
        if (id != null) onSelect(id);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: context.surfaceAlt,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected != null ? selected.color.withValues(alpha: 0.45) : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: (selected?.color ?? context.muted).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(
                selected != null ? categoryIcon(selected.icon) : Icons.category_rounded,
                size: 19,
                color: selected?.color ?? context.muted,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                selected?.name ?? context.t.selectCategory,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: selected != null ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 15,
                  color: selected != null ? context.colors.onSurface : context.muted,
                ),
              ),
            ),
            Icon(Icons.expand_more_rounded, color: context.muted),
          ],
        ),
      ),
    );
  }
}
