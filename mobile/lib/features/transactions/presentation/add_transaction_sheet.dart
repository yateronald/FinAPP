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
import '../../categories/data/category_model.dart';
import '../../categories/presentation/categories_screen.dart' show showCategorySheet;
import '../../categories/providers/categories_provider.dart';
import '../../dashboard/providers/dashboard_provider.dart';
import '../data/transaction_models.dart';
import '../data/transaction_repository.dart';
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

  /// Loan repayment link — expenses only. Income can never repay a loan.
  bool _isLoanPayment = false;
  String? _loanId;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _title = TextEditingController(text: e?.title ?? '');
    _amount = TextEditingController(text: e != null ? e.amount.round().toString() : '');
    _note = TextEditingController(text: e?.description ?? '');
    _date = e?.date ?? DateTime.now();
    _categoryId = e?.categoryId;
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
      setState(() => _error = context.t.chooseCategory);
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
      // '' clears an existing link when the box is unticked while editing.
      loanId: widget.type.isIncome ? null : (_isLoanPayment ? _loanId : ''),
    );
    try {
      final repo = ref.read(transactionRepositoryProvider);
      final result = _isEdit
          ? await repo.update(widget.type, widget.existing!.id, input)
          : await repo.create(widget.type, input);
      ref.invalidate(transactionsProvider(widget.type));
      ref.invalidate(financeOverviewProvider(widget.type));
      ref.invalidate(dashboardProvider);
      // Loan progress is derived from expenses, so it must be re-read.
      if (!widget.type.isIncome) refreshLoansFrom(ref);
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

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoriesByTypeProvider(_catType));
    final accent = widget.type.isIncome ? AppColors.success : AppColors.danger;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(20, 12, 20, 24 + MediaQuery.of(context).padding.bottom),
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
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Header: coloured badge + title.
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: accent,
                        borderRadius: BorderRadius.circular(13),
                        boxShadow: [
                          BoxShadow(
                            color: accent.withValues(alpha: 0.35),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(
                        widget.type.isIncome
                            ? Icons.arrow_upward_rounded
                            : Icons.arrow_downward_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.type.isIncome
                            ? (_isEdit ? context.t.editIncome() : context.t.newIncome())
                            : (_isEdit ? context.t.editExpense() : context.t.newExpense()),
                        style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
                      ),
                    ),
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
                const SizedBox(height: 18),
                // Amount — highlighted hero field tinted with the type colour.
                Container(
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: accent.withValues(alpha: 0.22)),
                  ),
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(context.t.amount,
                          style: TextStyle(
                              color: context.muted,
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                      TextFormField(
                        controller: _amount,
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
                        ],
                        style: TextStyle(
                            fontSize: 30, fontWeight: FontWeight.w800, color: accent),
                        decoration: InputDecoration(
                          hintText: '0',
                          filled: false,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          errorBorder: InputBorder.none,
                          focusedErrorBorder: InputBorder.none,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(vertical: 4),
                          prefixIcon: Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: Text(widget.type.isIncome ? '+' : '−',
                                style: TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w800,
                                    color: accent)),
                          ),
                          prefixIconConstraints: const BoxConstraints(minWidth: 0),
                          suffixText: 'FCFA',
                          suffixStyle: TextStyle(
                              color: context.muted,
                              fontSize: 14,
                              fontWeight: FontWeight.w700),
                        ),
                        validator: (v) {
                          final n =
                              double.tryParse((v ?? '').replaceAll(RegExp(r'[^0-9.]'), ''));
                          if (n == null || n <= 0) return context.t.invalidAmount;
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _title,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                      labelText: context.t.title, hintText: context.t.titleHint),
                  validator: (v) => (v == null || v.trim().isEmpty) ? context.t.required : null,
                ),
                const SizedBox(height: 16),
                Text(context.t.category, style: TextStyle(color: context.muted, fontSize: 13)),
                const SizedBox(height: 8),
                _CategoryPicker(
                  categories: categories,
                  selectedId: _categoryId,
                  onSelect: (id) => setState(() => _categoryId = id),
                  type: _catType,
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: _pickDate,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    decoration: BoxDecoration(
                      color: context.surfaceAlt,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today_rounded, size: 20, color: context.muted),
                        const SizedBox(width: 12),
                        Text(Dates.short(_date), style: const TextStyle(fontWeight: FontWeight.w600)),
                        const Spacer(),
                        Icon(Icons.expand_more_rounded, color: context.muted),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _note,
                  maxLines: 2,
                  decoration: InputDecoration(labelText: context.t.noteOptional),
                ),
                // Expenses only — repaying a loan is never income.
                if (!widget.type.isIncome) ...[
                  const SizedBox(height: 16),
                  LoanPaymentField(
                    checked: _isLoanPayment,
                    selectedLoanId: _loanId,
                    onCheckedChanged: (v) => setState(() {
                      _isLoanPayment = v;
                      if (!v) _loanId = null;
                    }),
                    onLoanSelected: (id) => setState(() => _loanId = id),
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      const Icon(Icons.error_outline_rounded, color: AppColors.danger, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text(_error!, style: const TextStyle(color: AppColors.danger))),
                    ],
                  ),
                ],
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _saving ? null : _submit,
                    child: _saving
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                          )
                        : Text(_isEdit ? context.t.save : context.t.addAction),
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

/// Compact, dropdown-style category field. Shows the current selection in a
/// single row and opens a searchable list sheet — this scales cleanly to any
/// number of categories, unlike a wrap of chips.
class _CategoryPicker extends StatelessWidget {
  final List<Category> categories;
  final String? selectedId;
  final ValueChanged<String> onSelect;
  final String type; // INCOME | EXPENSE — new categories inherit this
  const _CategoryPicker({
    required this.categories,
    required this.selectedId,
    required this.onSelect,
    required this.type,
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
          type: type,
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
