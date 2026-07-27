import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../dashboard/data/dashboard_models.dart';

class BudgetsRepository {
  final _api = ApiClient.instance;

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
  }) async {
    await _api.put('/budgets', body: {
      'categoryId': categoryId,
      'amount': amount,
      'month': month,
      'year': year,
    });
  }

  Future<void> remove(String id) async {
    await _api.delete('/budgets/$id');
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
final budgetMonthProvider = NotifierProvider<_BudgetMonthNotifier, DateTime>(_BudgetMonthNotifier.new);

final budgetsProvider = FutureProvider.autoDispose<List<BudgetStatus>>((ref) async {
  final month = ref.watch(budgetMonthProvider);
  return ref.watch(budgetsRepositoryProvider).statuses(month.month, month.year);
});
