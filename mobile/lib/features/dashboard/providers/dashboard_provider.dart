import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/utils/formatters.dart';
import '../../transactions/providers/finance_filters.dart';
import '../data/dashboard_models.dart';

class _DashboardPeriodNotifier extends Notifier<FinancePeriod> {
  @override
  FinancePeriod build() => FinancePeriod.month(DateTime.now());
  void set(FinancePeriod value) => state = value;
}
final dashboardPeriodProvider = NotifierProvider<_DashboardPeriodNotifier, FinancePeriod>(_DashboardPeriodNotifier.new);

/// Fetches the dashboard for the selected dashboard period, comparing against the previous period.
final dashboardProvider = FutureProvider.autoDispose<DashboardData>((ref) async {
  final period = ref.watch(dashboardPeriodProvider);
  final from = period.from;
  final to = period.toExclusive;
  final days = to.difference(from).inDays;
  final compareFrom = from.subtract(Duration(days: days));
  final compareTo = from;

  final data = await ApiClient.instance.get('/dashboard', query: {
    'from': Dates.iso(from),
    'to': Dates.iso(to),
    'compareFrom': Dates.iso(compareFrom),
    'compareTo': Dates.iso(compareTo),
  });
  return DashboardData.fromJson(Map<String, dynamic>.from(data));
});

