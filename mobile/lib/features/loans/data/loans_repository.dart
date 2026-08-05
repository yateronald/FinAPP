import '../../../core/network/api_client.dart';
import 'loan_models.dart';

class LoansRepository {
  final _api = ApiClient.instance;

  Future<List<Loan>> list({bool includeClosed = false}) async {
    final data = await _api.get('/loans', query: {
      if (includeClosed) 'includeClosed': 'true',
    });
    return ((data as List?) ?? [])
        .map((e) => Loan.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<LoanDetail> detail(String id) async {
    final data = await _api.get('/loans/$id');
    return LoanDetail.fromJson(Map<String, dynamic>.from(data));
  }

  /// Active loans an expense can be attached to. Empty means none exist yet,
  /// which the expense form turns into a "create one first" prompt.
  Future<List<SelectableLoan>> selectable() async {
    final data = await _api.get('/loans/selectable');
    return ((data as List?) ?? [])
        .map((e) => SelectableLoan.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<Loan> create({
    required String name,
    String? description,
    String? lender,
    required double principalAmount,
    double initialPaidAmount = 0,
    required DateTime startDate,
    DateTime? expectedEndDate,
  }) async {
    final data = await _api.post('/loans', body: {
      'name': name,
      if (description != null && description.isNotEmpty) 'description': description,
      if (lender != null && lender.isNotEmpty) 'lender': lender,
      'principalAmount': principalAmount,
      'initialPaidAmount': initialPaidAmount,
      'startDate': startDate.toUtc().toIso8601String(),
      if (expectedEndDate != null)
        'expectedEndDate': expectedEndDate.toUtc().toIso8601String(),
    });
    return Loan.fromJson(Map<String, dynamic>.from(data));
  }

  Future<Loan> update(
    String id, {
    String? name,
    String? description,
    String? lender,
    double? principalAmount,
    double? initialPaidAmount,
    DateTime? startDate,
    DateTime? expectedEndDate,
    String? status,
  }) async {
    final data = await _api.patch('/loans/$id', body: {
      if (name != null) 'name': name,
      if (description != null) 'description': description,
      if (lender != null) 'lender': lender,
      if (principalAmount != null) 'principalAmount': principalAmount,
      if (initialPaidAmount != null) 'initialPaidAmount': initialPaidAmount,
      if (startDate != null) 'startDate': startDate.toUtc().toIso8601String(),
      if (expectedEndDate != null)
        'expectedEndDate': expectedEndDate.toUtc().toIso8601String(),
      if (status != null) 'status': status,
    });
    return Loan.fromJson(Map<String, dynamic>.from(data));
  }

  Future<void> remove(String id) => _api.delete('/loans/$id');
}
