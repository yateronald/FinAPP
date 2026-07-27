import '../../../core/utils/formatters.dart';
import '../../dashboard/data/dashboard_models.dart' show CategorySlice;
import 'transaction_models.dart';

/// Unified overview for the Finances screen (works for both income & expenses).
class FinanceOverview {
  final TxType type;
  final double total;
  final int count;
  final double totalTrend; // % vs the preceding equal window
  final double secondaryValue; // avg/day (expense) or avg/month (income)
  final double secondaryTrend;
  final CategorySlice? topCategory; // biggest expense category / biggest income
  final List<CategorySlice> distribution;
  final List<double> trendValues; // 6-month series for the sparkline

  FinanceOverview({
    required this.type,
    required this.total,
    required this.count,
    required this.totalTrend,
    required this.secondaryValue,
    required this.secondaryTrend,
    required this.topCategory,
    required this.distribution,
    required this.trendValues,
  });

  factory FinanceOverview.fromJson(Map<String, dynamic> j, TxType type) {
    final isIncome = type.isIncome;
    final dist = ((j['distribution'] ?? []) as List)
        .map((e) => CategorySlice.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    final trend = ((j['trend'] ?? []) as List)
        .map((e) => asDouble((e as Map)[isIncome ? 'income' : 'expenses']))
        .toList();
    // distribution is already sorted descending by the backend.
    final top = dist.isNotEmpty ? dist.first : null;
    return FinanceOverview(
      type: type,
      total: asDouble(j['total']),
      count: (j['count'] ?? 0) as int,
      totalTrend: asDouble(j['totalTrend']),
      secondaryValue: asDouble(isIncome ? j['average'] : j['avgPerDay']),
      secondaryTrend: asDouble(isIncome ? j['averageTrend'] : j['totalTrend']),
      topCategory: top,
      distribution: dist,
      trendValues: trend,
    );
  }
}
