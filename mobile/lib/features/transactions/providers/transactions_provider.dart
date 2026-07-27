import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/overview_models.dart';
import '../data/transaction_models.dart';
import '../data/transaction_repository.dart';
import 'finance_filters.dart';

final transactionRepositoryProvider = Provider((_) => TransactionRepository());

/// Live search query shared across the finances tabs.
class _TxSearchNotifier extends Notifier<String> {
  @override
  String build() => '';
  void set(String value) => state = value;
}
final txSearchProvider = NotifierProvider.autoDispose<_TxSearchNotifier, String>(_TxSearchNotifier.new);

/// First page of transactions for a given type, reacting to search + period +
/// category. Watching all three means any filter change refetches automatically.
final transactionsProvider =
    FutureProvider.autoDispose.family<TxPage, TxType>((ref, type) async {
  final search = ref.watch(txSearchProvider);
  final period = ref.watch(financePeriodProvider);
  final categoryIds = ref.watch(financeCategoryProvider(type.categoryType));
  final repo = ref.watch(transactionRepositoryProvider);
  return repo.list(
    type,
    search: search.trim().isEmpty ? null : search.trim(),
    categoryIds: categoryIds,
    from: period.from,
    to: period.toExclusive,
  );
});

/// Rich overview (totals, trend, distribution) for the selected period and
/// category filter.
final financeOverviewProvider =
    FutureProvider.autoDispose.family<FinanceOverview, TxType>((ref, type) async {
  final period = ref.watch(financePeriodProvider);
  final categoryIds = ref.watch(financeCategoryProvider(type.categoryType));
  final repo = ref.watch(transactionRepositoryProvider);
  return repo.overview(
    type,
    from: period.from,
    toInclusive: period.lastDay,
    categoryIds: categoryIds,
  );
});
