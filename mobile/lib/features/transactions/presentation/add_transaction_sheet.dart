import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/i18n/app_text.dart';
import '../../../core/network/api_client.dart';
import '../../../core/offline/sync_engine.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/category_icons.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/form_kit.dart';
import '../../categories/data/category_model.dart';
import '../../categories/presentation/categories_screen.dart' show showCategorySheet;
import '../../categories/providers/categories_provider.dart';
import '../../dashboard/providers/dashboard_provider.dart';
import '../data/transaction_models.dart';
import '../data/transaction_repository.dart';
import '../../loans/data/loan_models.dart';
import '../../loans/presentation/loan_payment_field.dart';
import '../../loans/providers/loans_provider.dart';
import '../providers/transactions_provider.dart';

/// Opens the add/edit transaction bottom sheet. Returns true if saved.
Future<bool?> showTransactionSheet(
  BuildContext context, {
  required TxType type,
  Transaction? existing,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => TransactionSheet(type: type, existing: existing),
  );
}

class TransactionSheet extends ConsumerStatefulWidget {
  final TxType type;
  final Transaction? existing;
  const TransactionSheet({super.key, required this.type, this.existing});

  @override
  ConsumerState<TransactionSheet> createState() => _TransactionSheetState();
}

class _TransactionSheetState extends ConsumerState<TransactionSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _amount;
  late final TextEditingController _note;
  late DateTime _date;
  String? _categoryId;
  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.existing != null;
  String get _catType => widget.type == TxType.income ? 'INCOME' : 'EXPENSE';

  /// Loan link. Both forms have one, pointing at opposite sides of the loan
  /// book: an expense repays what you borrowed, an income collects what you
  /// lent. [_loanDirection] is what keeps the two from crossing.
  bool _isLoanPayment = false;
  String? _loanId;

  /// Raised on a save attempt so the loan picker can flag itself. Ticking the
  /// box without choosing a loan is an incomplete answer, not a plain
  /// transaction.
  bool _loanTouched = false;

  /// Same idea for the category, which lives outside the Form validators.
  bool _categoryTouched = false;

  LoanDirection get _loanDirection =>
      widget.type.isIncome ? LoanDirection.lent : LoanDirection.borrowed;

  /// The message that belongs to this form's side of the loan book.
  String _loanRequiredMessage(BuildContext context) => widget.type.isIncome
      ? context.t.incomeLoanRequired
      : context.t.expenseLoanRequired;

  bool get _loanSelectionMissing => _isLoanPayment && _loanId == null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _title = TextEditingController(text: e?.title ?? '');
    _amount = TextEditingController(text: e != null ? e.amount.round().toString() : '');
    _note = TextEditingController(text: e?.description ?? '');
    _date = e?.date ?? DateTime.now();
    _categoryId = e?.categoryId;
    // Restore an existing loan link, otherwise re-saving would silently drop it.
    _loanId = e?.loanId;
    _isLoanPayment = _loanId != null;
  }

  @override
  void dispose() {
    _title.dispose();
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2015),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_categoryId == null) {
      setState(() {
        _categoryTouched = true;
        _error = context.t.chooseCategory;
      });
      return;
    }
    if (_loanSelectionMissing) {
      setState(() {
        _loanTouched = true;
        _error = _loanRequiredMessage(context);
      });
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final input = TransactionInput(
      title: _title.text.trim(),
      categoryId: _categoryId!,
      amount: double.parse(_amount.text.replaceAll(RegExp(r'[^0-9.]'), '')),
      date: _date,
      description: _note.text.trim(),
      // Guarded above: ticked always means a loan is selected by now.
      // '' clears an existing link when the box is unticked while editing;
      // on create there is nothing to clear, so the field is simply omitted.
      loanId: _isLoanPayment ? _loanId : (_isEdit ? '' : null),
    );
    try {
      final repo = ref.read(transactionRepositoryProvider);
      final result = _isEdit
          ? await repo.update(widget.type, widget.existing!.id, input)
          : await repo.create(widget.type, input);
      ref.invalidate(transactionsProvider(widget.type));
      ref.invalidate(financeOverviewProvider(widget.type));
      ref.invalidate(dashboardProvider);
      // Loan progress is derived from the linked transactions, so any save
      // that touches a link — including one that clears it — invalidates it.
      refreshLoansFrom(ref);
      if (result == WriteResult.queued) {
        await ref.read(syncEngineProvider).refreshCount();
      }
      if (mounted) {
        Navigator.pop(context, true);
        if (result == WriteResult.queued) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(context.t.offlineQueued)));
        }
      }
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = context.t.saveFailed);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Top-bar pill: the three answers that make a transaction complete.
  double get _completion {
    final done = [
      double.tryParse(_amount.text.replaceAll(RegExp(r'[^0-9.]'), '')) != null &&
          (double.tryParse(_amount.text.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0) > 0,
      _title.text.trim().isNotEmpty,
      _categoryId != null,
    ].where((e) => e).length;
    return done / 3;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final isIncome = widget.type.isIncome;
    final categories = ref.watch(categoriesByTypeProvider(_catType));
    final accent = isIncome ? AppColors.successDark : AppColors.danger;
    final selectedCategory =
        categories.where((c) => c.id == _categoryId).firstOrNull;

    return FormSheetShell(
      accent: accent,
      icon: isIncome ? Icons.savings_rounded : Icons.shopping_bag_rounded,
      title: isIncome
          ? (_isEdit ? t.editIncome() : t.newIncome())
          : (_isEdit ? t.editExpense() : t.newExpense()),
      formKey: _formKey,
      progress: _completion,
      footer: FormPrimaryButton(
        accent: accent,
        label: _isEdit
            ? (isIncome ? t.saveIncomeAction : t.saveExpenseAction)
            : (isIncome ? t.addIncomeAction : t.addExpenseAction),
        loading: _saving,
        onPressed: _saving ? null : _submit,
      ),
      children: [
        // The amount is the reason the sheet is open, so it gets the loudest
        // type: same card, oversized accent-coloured value.
        FormTextCard(
          icon: isIncome
              ? Icons.arrow_upward_rounded
              : Icons.arrow_downward_rounded,
          accent: accent,
          label: t.amount,
          hint: '0',
          controller: _amount,
          required: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
          suffix: 'FCFA',
          textStyle: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: accent,
            height: 1.25,
          ),
          onChanged: (_) => setState(() {}),
          validator: (v) {
            final n = double.tryParse((v ?? '').replaceAll(RegExp(r'[^0-9.]'), ''));
            if (n == null || n <= 0) return t.invalidAmount;
            return null;
          },
        ),
        FormTextCard(
          icon: Icons.edit_note_rounded,
          accent: accent,
          label: t.title,
          hint: t.titleHint,
          controller: _title,
          required: true,
          onChanged: (_) => setState(() {}),
          validator: (v) => (v == null || v.trim().isEmpty) ? t.required : null,
        ),
        if (categories.isEmpty)
          FormInfoBanner(
            accent: accent,
            icon: Icons.category_rounded,
            text: Text(t.noCategory,
                style: TextStyle(fontSize: 12.5, height: 1.4, color: context.muted)),
          )
        else
          FormPickerCard(
            icon: Icons.category_rounded,
            accent: accent,
            label: t.category,
            required: true,
            value: selectedCategory?.name ?? t.selectCategory,
            placeholder: selectedCategory == null,
            errorText: _categoryTouched && _categoryId == null ? t.chooseCategory : null,
            leading: selectedCategory == null
                ? null
                : _CategoryDot(category: selectedCategory),
            onTap: () async {
              FocusScope.of(context).unfocus();
              final id = await showCategoryPickerSheet(
                context,
                categories: categories,
                selectedId: _categoryId,
                type: _catType,
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
        FormPickerCard(
          icon: Icons.event_rounded,
          accent: accent,
          label: t.date,
          value: Dates.short(_date),
          onTap: _pickDate,
        ),
        FormTextCard(
          icon: Icons.notes_rounded,
          accent: accent,
          label: t.noteOptional,
          hint: t.noteHint,
          controller: _note,
          maxLines: 2,
          maxLength: 150,
          onChanged: (_) => setState(() {}),
        ),
        // Present on both forms, pointed at opposite sides of the loan book.
        LoanPaymentField(
          accent: accent,
          direction: _loanDirection,
          checked: _isLoanPayment,
          selectedLoanId: _loanId,
          showError: _loanTouched,
          onCheckedChanged: (v) => setState(() {
            _isLoanPayment = v;
            if (!v) {
              _loanId = null;
              // Unticking resolves the complaint either way.
              _loanTouched = false;
              if (_error == _loanRequiredMessage(context)) _error = null;
            }
          }),
          onLoanSelected: (id) => setState(() {
            _loanId = id;
            _loanTouched = false;
            if (_error == _loanRequiredMessage(context)) _error = null;
          }),
        ),
        if (_error != null) FormErrorLine(message: _error!),
      ],
    );
  }
}

/// The selected category's own colour and glyph, shown beside its name.
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

/// Opens the searchable category picker. Returns the chosen category id, or
/// null if dismissed. Shared by the transaction and budget sheets.
///
/// [type] ('INCOME' | 'EXPENSE') enables inline quick-add so the user can
/// create a missing category without leaving the flow — and it is always
/// created with the right type.
Future<String?> showCategoryPickerSheet(
  BuildContext context, {
  required List<Category> categories,
  String? selectedId,
  String? type,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) =>
        _CategorySheet(categories: categories, selectedId: selectedId, type: type),
  );
}

/// Searchable category list with inline "create category".
class _CategorySheet extends ConsumerStatefulWidget {
  final List<Category> categories;
  final String? selectedId;
  final String? type;
  const _CategorySheet({
    required this.categories,
    required this.selectedId,
    this.type,
  });
  @override
  ConsumerState<_CategorySheet> createState() => _CategorySheetState();
}

class _CategorySheetState extends ConsumerState<_CategorySheet> {
  String _query = '';
  bool _creating = false;

  /// Opens the full create-category sheet (name + icon + colour) for THIS
  /// flow's type, then selects the newly created category.
  Future<void> _promptNewCategory() async {
    if (widget.type == null || _creating) return;
    final createdName = await showCategorySheet(context, type: widget.type);
    if (createdName == null || !mounted) return;
    setState(() => _creating = true);
    try {
      // The create sheet already refreshed; read the settled list to resolve id.
      final fresh = await ref.read(categoriesProvider.future);
      final created = fresh
          .where((c) =>
              c.type == widget.type && c.name.toLowerCase() == createdName.toLowerCase())
          .firstOrNull;
      if (!mounted) return;
      Navigator.pop(context, created?.id);
    } catch (_) {
      if (mounted) setState(() => _creating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final q = _query.trim().toLowerCase();
    final items = q.isEmpty
        ? widget.categories
        : widget.categories.where((c) => c.name.toLowerCase().contains(q)).toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (_, scrollController) => Container(
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 42,
              height: 4.5,
              decoration: BoxDecoration(
                  color: context.borderColor, borderRadius: BorderRadius.circular(4)),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Text(t.category,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  const Spacer(),
                  // Quick-add a category of the current type (income/expense).
                  if (widget.type != null) ...[
                    InkWell(
                      onTap: _creating ? null : _promptNewCategory,
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _creating
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: AppColors.primary),
                                  )
                                : const Icon(Icons.add_rounded,
                                    size: 16, color: AppColors.primary),
                            const SizedBox(width: 5),
                            Text(t.newCategory,
                                style: const TextStyle(
                                    color: AppColors.primary,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w800)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  InkWell(
                    onTap: () => Navigator.pop(context),
                    customBorder: const CircleBorder(),
                    child: Container(
                      padding: const EdgeInsets.all(7),
                      decoration:
                          BoxDecoration(color: context.surfaceAlt, shape: BoxShape.circle),
                      child: Icon(Icons.close_rounded, size: 18, color: context.muted),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                autofocus: false,
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  hintText: t.search,
                  prefixIcon: Icon(Icons.search_rounded, color: context.muted, size: 20),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: items.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.search_off_rounded, size: 38, color: context.muted),
                          const SizedBox(height: 10),
                          Text(t.noCategory, style: TextStyle(color: context.muted)),
                          if (widget.type != null) ...[
                            const SizedBox(height: 14),
                            FilledButton.icon(
                              onPressed: _creating ? null : _promptNewCategory,
                              icon: const Icon(Icons.add_rounded, size: 17),
                              label: Text(t.newCategoryTitle),
                              style:
                                  FilledButton.styleFrom(backgroundColor: AppColors.primary),
                            ),
                          ],
                        ],
                      ),
                    )
                  : ListView.separated(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 6),
                      itemBuilder: (_, i) {
                        final c = items[i];
                        final sel = c.id == widget.selectedId;
                        return InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () => Navigator.pop(context, c.id),
                          child: Container(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                            decoration: BoxDecoration(
                              color: sel ? c.color.withValues(alpha: 0.10) : Colors.transparent,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: sel ? c.color : context.borderColor,
                                width: sel ? 1.4 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    color: c.color.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(categoryIcon(c.icon), size: 19, color: c.color),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(c.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                          fontSize: 15,
                                          fontWeight:
                                              sel ? FontWeight.w800 : FontWeight.w600)),
                                ),
                                if (sel)
                                  Icon(Icons.check_circle_rounded, color: c.color, size: 21),
                              ],
                            ),
                          ),
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
