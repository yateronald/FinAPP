import '../../dashboard/data/dashboard_models.dart';

double _d(dynamic v) => v == null ? 0 : (v as num).toDouble();

/// The month-wide spending cap.
///
/// Distinct from the sum of the category caps: every expense counts against
/// this one, including those in categories that carry no budget at all.
class OverallBudgetStatus {
  final String id;
  final double budget, spent, remaining, progress;
  final String status; // ok | warning | danger | exceeded
  final int month, year;
  final String? seriesId;

  /// Spending this month that no category budget is watching.
  final double uncategorisedSpend;

  /// Where an even spend would put you today (null outside a live month).
  final double? expectedProgress;
  final int? daysLeft;
  final double? safeDailySpend;

  const OverallBudgetStatus({
    required this.id,
    required this.budget,
    required this.spent,
    required this.remaining,
    required this.progress,
    required this.status,
    required this.month,
    required this.year,
    required this.seriesId,
    required this.uncategorisedSpend,
    required this.expectedProgress,
    required this.daysLeft,
    required this.safeDailySpend,
  });

  factory OverallBudgetStatus.fromJson(Map<String, dynamic> j) => OverallBudgetStatus(
        id: j['id'] ?? '',
        budget: _d(j['budget']),
        spent: _d(j['spent']),
        remaining: _d(j['remaining']),
        progress: _d(j['progress']),
        status: j['status'] ?? 'ok',
        month: j['month'] ?? 1,
        year: j['year'] ?? 2000,
        seriesId: j['seriesId'],
        uncategorisedSpend: _d(j['uncategorisedSpend']),
        expectedProgress:
            j['expectedProgress'] == null ? null : _d(j['expectedProgress']),
        daysLeft: j['daysLeft'],
        safeDailySpend:
            j['safeDailySpend'] == null ? null : _d(j['safeDailySpend']),
      );

  bool get isOver => spent > budget;
  bool get isRepeating => seriesId != null;

  /// Ahead of an even pace by more than 8 points — early enough to matter,
  /// loose enough not to cry wolf on a normal lumpy week.
  bool get isAheadOfPace {
    final expected = expectedProgress;
    if (expected == null || daysLeft == null || daysLeft == 0) return false;
    return progress > expected + 8;
  }
}

/// Coverage figures for the category budgets — deliberately NOT presented as
/// the month's budget, which is [OverallBudgetStatus].
class BudgetTotals {
  /// Sum of the per-category caps.
  final double budgeted;

  /// Spending inside budgeted categories only.
  final double spentOnBudgeted;

  /// Every expense of the month.
  final double monthSpent;

  /// Spending that falls outside every budgeted category.
  final double unbudgetedSpend;

  final int categoryCount, onTrack, atRisk, exceeded;

  const BudgetTotals({
    required this.budgeted,
    required this.spentOnBudgeted,
    required this.monthSpent,
    required this.unbudgetedSpend,
    required this.categoryCount,
    required this.onTrack,
    required this.atRisk,
    required this.exceeded,
  });

  factory BudgetTotals.fromJson(Map<String, dynamic> j) => BudgetTotals(
        budgeted: _d(j['budgeted']),
        spentOnBudgeted: _d(j['spentOnBudgeted']),
        monthSpent: _d(j['monthSpent']),
        unbudgetedSpend: _d(j['unbudgetedSpend']),
        categoryCount: j['categoryCount'] ?? 0,
        onTrack: j['onTrack'] ?? 0,
        atRisk: j['atRisk'] ?? 0,
        exceeded: j['exceeded'] ?? 0,
      );
}

/// One month of budget state, fetched in a single round trip.
class BudgetOverview {
  final int month, year;
  final OverallBudgetStatus? overall;
  final List<BudgetStatus> categories;
  final BudgetTotals totals;

  const BudgetOverview({
    required this.month,
    required this.year,
    required this.overall,
    required this.categories,
    required this.totals,
  });

  factory BudgetOverview.fromJson(Map<String, dynamic> j) => BudgetOverview(
        month: j['month'] ?? 1,
        year: j['year'] ?? 2000,
        overall: j['overall'] == null
            ? null
            : OverallBudgetStatus.fromJson(Map<String, dynamic>.from(j['overall'])),
        categories: ((j['categories'] ?? []) as List)
            .map((e) => BudgetStatus.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        totals: BudgetTotals.fromJson(Map<String, dynamic>.from(j['totals'] ?? {})),
      );

  bool get isEmpty => overall == null && categories.isEmpty;
}
