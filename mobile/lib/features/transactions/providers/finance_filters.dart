import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/formatters.dart';

/// The date window the Finances screen operates on: a whole month or a custom
/// range. `toExclusive` is the first instant after the window.
class FinancePeriod {
  final DateTime from;
  final DateTime toExclusive;
  final bool isMonth;
  const FinancePeriod(this.from, this.toExclusive, this.isMonth);

  factory FinancePeriod.month(DateTime m) => FinancePeriod(
        DateTime(m.year, m.month, 1),
        DateTime(m.year, m.month + 1, 1),
        true,
      );

  factory FinancePeriod.custom(DateTime from, DateTime to) => FinancePeriod(
        DateTime(from.year, from.month, from.day),
        DateTime(to.year, to.month, to.day).add(const Duration(days: 1)),
        false,
      );

  /// Inclusive last day (for the overview endpoint, which treats `to` as
  /// inclusive and adds a day internally).
  DateTime get lastDay => toExclusive.subtract(const Duration(days: 1));

  String get label {
    if (isMonth) return Dates.monthYear(from);
    return '${Dates.short(from)} – ${Dates.short(lastDay)}';
  }

  /// Whether this window is (or contains) the current calendar month.
  bool get isCurrentMonth {
    final now = DateTime.now();
    return from.year == now.year && from.month == now.month && isMonth;
  }
}

class _FinancePeriodNotifier extends Notifier<FinancePeriod> {
  @override
  FinancePeriod build() => FinancePeriod.month(DateTime.now());
  void set(FinancePeriod value) => state = value;
}
final financePeriodProvider = NotifierProvider<_FinancePeriodNotifier, FinancePeriod>(_FinancePeriodNotifier.new);

/// Optional category filter for the Finances screen, kept per tab type
/// ('INCOME' | 'EXPENSE') so switching tabs doesn't carry an invalid filter.
/// null = all categories.
/// Multi-select category filter. An empty set means "all categories".
class _FinanceCategoryNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() => const {};

  /// Adds or removes a category from the selection.
  void toggle(String categoryId) {
    final next = Set<String>.from(state);
    next.contains(categoryId) ? next.remove(categoryId) : next.add(categoryId);
    state = next;
  }

  void add(String categoryId) => state = {...state, categoryId};

  /// Back to the default: no category filter.
  void clear() => state = const {};
}

final _expenseCategoryFilter =
    NotifierProvider<_FinanceCategoryNotifier, Set<String>>(_FinanceCategoryNotifier.new);
final _incomeCategoryFilter =
    NotifierProvider<_FinanceCategoryNotifier, Set<String>>(_FinanceCategoryNotifier.new);

/// The category filter for a given category type ('INCOME' | 'EXPENSE').
/// Expenses and Income keep independent selections.
NotifierProvider<_FinanceCategoryNotifier, Set<String>> financeCategoryProvider(String type) =>
    type == 'INCOME' ? _incomeCategoryFilter : _expenseCategoryFilter;
