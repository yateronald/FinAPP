import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../dashboard/data/dashboard_models.dart';
import '../data/budget_models.dart';

class BudgetsRepository {
  final _api = ApiClient.instance;

  /// Overall cap, category budgets and month totals in one call.
  Future<BudgetOverview> overview(int month, int year) async {
    final data =
        await _api.get('/budgets/overview', query: {'month': month, 'year': year});
    return BudgetOverview.fromJson(Map<String, dynamic>.from(data));
  }

  Future<List<BudgetStatus>> statuses(int month, int year) async {
    final data = await _api.get('/budgets', query: {'month': month, 'year': year});
    return (data as List)
        .map((e) => BudgetStatus.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> upsert({
    required String categoryId,
    required double amount,
    required int month,
    required int year,
    int repeatMonths = 1,
  }) async {
    await _api.put('/budgets', body: {
      'categoryId': categoryId,
      'amount': amount,
      'month': month,
      'year': year,
      'repeatMonths': repeatMonths,
    });
  }

  Future<void> upsertOverall({
    required double amount,
    required int month,
    required int year,
    int repeatMonths = 1,
  }) async {
    await _api.put('/budgets/overall', body: {
      'amount': amount,
      'month': month,
      'year': year,
      'repeatMonths': repeatMonths,
    });
  }

  /// [withSeries] also clears the remaining months of a repeat; past months
  /// are never touched.
  Future<void> remove(String id, {bool withSeries = false}) async {
    await _api.delete('/budgets/$id${withSeries ? '?series=true' : ''}');
  }

  Future<void> removeOverall(String id, {bool withSeries = false}) async {
    await _api.delete('/budgets/overall/$id${withSeries ? '?series=true' : ''}');
  }
}

final budgetsRepositoryProvider = Provider((_) => BudgetsRepository());

/// The month currently displayed on the budgets screen (first-of-month).
class _BudgetMonthNotifier extends Notifier<DateTime> {
  @override
  DateTime build() {
    final now = DateTime.now();
    return DateTime(now.year, now.month);
  }

  void set(DateTime value) => state = value;
}

final budgetMonthProvider =
    NotifierProvider<_BudgetMonthNotifier, DateTime>(_BudgetMonthNotifier.new);

final budgetOverviewProvider = FutureProvider.autoDispose<BudgetOverview>((ref) async {
  final month = ref.watch(budgetMonthProvider);
  return ref.watch(budgetsRepositoryProvider).overview(month.month, month.year);
});

/// Kept for callers that only need the category list (e.g. the dashboard).
final budgetsProvider = FutureProvider.autoDispose<List<BudgetStatus>>((ref) async {
  final overview = await ref.watch(budgetOverviewProvider.future);
  return overview.categories;
});
