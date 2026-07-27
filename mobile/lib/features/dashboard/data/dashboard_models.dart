import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import 'package:flutter/material.dart';

double _d(dynamic v) => (v is num) ? v.toDouble() : 0.0;

class DashboardSummary {
  final double income, expenses, savings, savingsRate;
  final double incomeTrend, expenseTrend, savingsTrend;
  final double prevIncome, prevSavings;
  final int financialScore;
  final bool hasComparison;

  DashboardSummary({
    required this.income,
    required this.expenses,
    required this.savings,
    required this.savingsRate,
    required this.incomeTrend,
    required this.expenseTrend,
    required this.savingsTrend,
    required this.prevIncome,
    required this.prevSavings,
    required this.financialScore,
    required this.hasComparison,
  });

  /// Savings-rate change vs the comparison period, in percentage points.
  double get rateTrend {
    if (!hasComparison || prevIncome <= 0) return 0;
    final prevRate = prevSavings / prevIncome * 100;
    return (savingsRate - prevRate) * 10 / 10;
  }

  factory DashboardSummary.fromJson(Map<String, dynamic> j) {
    final trends = (j['trends'] ?? {}) as Map;
    final cmp = (j['comparison'] ?? {}) as Map;
    return DashboardSummary(
      income: _d(j['totalIncome']),
      expenses: _d(j['totalExpenses']),
      savings: _d(j['netSavings']),
      savingsRate: _d(j['savingsRate']),
      incomeTrend: _d(trends['income']),
      expenseTrend: _d(trends['expenses']),
      savingsTrend: _d(trends['savings']),
      prevIncome: _d(cmp['income']),
      prevSavings: _d(cmp['savings']),
      financialScore: (j['financialScore'] ?? 0) as int,
      hasComparison: j['hasComparison'] ?? false,
    );
  }
}

class CategorySlice {
  final String categoryId, name;
  final Color color;
  final double amount, percentage;
  CategorySlice(this.categoryId, this.name, this.color, this.amount, this.percentage);

  factory CategorySlice.fromJson(Map<String, dynamic> j) => CategorySlice(
        j['categoryId'] ?? '',
        j['name'] ?? '',
        AppColors.hexToColor(j['color']),
        _d(j['amount']),
        _d(j['percentage']),
      );
}

class BudgetStatus {
  final String id, categoryId, categoryName, status;
  final String? icon;
  final Color color;
  final double budget, spent, remaining, progress;
  BudgetStatus({
    required this.id,
    required this.categoryId,
    required this.categoryName,
    required this.status,
    required this.icon,
    required this.color,
    required this.budget,
    required this.spent,
    required this.remaining,
    required this.progress,
  });

  factory BudgetStatus.fromJson(Map<String, dynamic> j) => BudgetStatus(
        id: j['id'] ?? '',
        categoryId: j['categoryId'] ?? '',
        categoryName: j['categoryName'] ?? '',
        status: j['status'] ?? 'ok',
        icon: j['icon'],
        color: AppColors.hexToColor(j['color']),
        budget: _d(j['budget']),
        spent: _d(j['spent']),
        remaining: _d(j['remaining']),
        progress: _d(j['progress']),
      );
}

class RecentTx {
  final String id, type, title, category;
  final String? icon;
  final Color color;
  final double amount;
  final DateTime date;
  RecentTx(this.id, this.type, this.title, this.category, this.icon, this.color, this.amount,
      this.date);

  bool get isIncome => type == 'INCOME';

  factory RecentTx.fromJson(Map<String, dynamic> j) => RecentTx(
        j['id'] ?? '',
        j['type'] ?? 'EXPENSE',
        j['title'] ?? '',
        j['category'] ?? '',
        j['icon'],
        AppColors.hexToColor(j['color'], j['type'] == 'INCOME' ? AppColors.success : AppColors.danger),
        _d(j['amount']),
        DateTime.tryParse(j['date'] ?? '') ?? DateTime.now(),
      );
}

class TrendPoint {
  final String label;
  final int month, year;
  final double income, expenses;
  TrendPoint(this.label, this.month, this.year, this.income, this.expenses);

  /// Localized short month label (backend sends English), falling back to the
  /// raw label when month is unknown.
  String get shortLabel => month >= 1 && month <= 12 ? Dates.monthShort(month) : label;

  factory TrendPoint.fromJson(Map<String, dynamic> j) => TrendPoint(
        j['label'] ?? '',
        (j['month'] ?? 0) as int,
        (j['year'] ?? 0) as int,
        _d(j['income']),
        _d(j['expenses']),
      );
}

class DashboardData {
  final DashboardSummary summary;
  final List<CategorySlice> expenseDistribution;
  final List<BudgetStatus> budgets;
  final List<RecentTx> recent;
  final List<TrendPoint> trend;

  DashboardData({
    required this.summary,
    required this.expenseDistribution,
    required this.budgets,
    required this.recent,
    required this.trend,
  });

  factory DashboardData.fromJson(Map<String, dynamic> j) => DashboardData(
        summary: DashboardSummary.fromJson(Map<String, dynamic>.from(j['summary'])),
        expenseDistribution: ((j['expenseDistribution'] ?? []) as List)
            .map((e) => CategorySlice.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        budgets: ((j['budgets'] ?? []) as List)
            .map((e) => BudgetStatus.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        recent: ((j['recentTransactions'] ?? []) as List)
            .map((e) => RecentTx.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        trend: ((j['incomeVsExpenses'] ?? []) as List)
            .map((e) => TrendPoint.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
      );
}
