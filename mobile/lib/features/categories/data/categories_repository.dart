import '../../../core/network/api_client.dart';

class CategoriesRepository {
  final _api = ApiClient.instance;

  Future<void> create({
    required String name,
    required String type, // INCOME | EXPENSE
    String? icon,
    String? color,
  }) async {
    await _api.post('/categories', body: {
      'name': name,
      'type': type,
      if (icon != null) 'icon': icon,
      if (color != null) 'color': color,
    });
  }

  Future<void> update(String id, {String? name, String? icon, String? color}) async {
    await _api.patch('/categories/$id', body: {
      if (name != null) 'name': name,
      if (icon != null) 'icon': icon,
      if (color != null) 'color': color,
    });
  }

  Future<void> archive(String id, bool archived) async {
    await _api.patch('/categories/$id/${archived ? 'archive' : 'unarchive'}');
  }

  /// What deleting this category would destroy — shown in the confirmation
  /// dialog so the user sees the real cost before agreeing to it.
  Future<CategoryImpact> impact(String id) async {
    final data = await _api.get('/categories/$id/impact');
    return CategoryImpact.fromJson(Map<String, dynamic>.from(data));
  }

  Future<void> remove(String id) async {
    await _api.delete('/categories/$id');
  }
}

class CategoryImpact {
  final String name;
  final bool isDefault;
  final int expenses;
  final int incomes;
  final int budgets;
  final int recurring;
  final int totalRecords;
  final double expenseAmount;
  final double incomeAmount;

  const CategoryImpact({
    required this.name,
    required this.isDefault,
    required this.expenses,
    required this.incomes,
    required this.budgets,
    required this.recurring,
    required this.totalRecords,
    required this.expenseAmount,
    required this.incomeAmount,
  });

  bool get isEmpty => totalRecords == 0;

  factory CategoryImpact.fromJson(Map<String, dynamic> j) {
    final c = Map<String, dynamic>.from(j['category'] ?? const {});
    double num_(dynamic v) => (v as num?)?.toDouble() ?? 0;
    int int_(dynamic v) => (v as num?)?.toInt() ?? 0;
    return CategoryImpact(
      name: c['name'] as String? ?? '',
      isDefault: c['isDefault'] as bool? ?? false,
      expenses: int_(j['expenses']),
      incomes: int_(j['incomes']),
      budgets: int_(j['budgets']),
      recurring: int_(j['recurring']),
      totalRecords: int_(j['totalRecords']),
      expenseAmount: num_(j['expenseAmount']),
      incomeAmount: num_(j['incomeAmount']),
    );
  }
}
