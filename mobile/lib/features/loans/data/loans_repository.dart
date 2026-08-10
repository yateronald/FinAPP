import '../../../core/network/api_client.dart';
import 'loan_models.dart';

class LoansRepository {
  final _api = ApiClient.instance;

  Future<List<Loan>> list({
    bool includeClosed = false,
    LoanDirection? direction,
  }) async {
    final data = await _api.get('/loans', query: {
      if (includeClosed) 'includeClosed': 'true',
      if (direction != null) 'direction': direction.wire,
    });
    return ((data as List?) ?? [])
        .map((e) => Loan.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<LoanDetail> detail(String id) async {
    final data = await _api.get('/loans/$id');
    return LoanDetail.fromJson(Map<String, dynamic>.from(data));
  }

  /// Active loans a transaction can be attached to — borrowed ones for the
  /// expense form, lent ones for the income form. Empty means none exist yet,
  /// which the form turns into a "create one first" prompt.
  ///
  /// The server applies the same filter, so a tampered client cannot widen it.
  Future<List<SelectableLoan>> selectable({
    LoanDirection direction = LoanDirection.borrowed,
  }) async {
    final data = await _api.get('/loans/selectable',
        query: {'direction': direction.wire});
    return ((data as List?) ?? [])
        .map((e) => SelectableLoan.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<Loan> create({
    required String name,
    LoanDirection direction = LoanDirection.borrowed,
    String? description,
    String? lender,
    required double principalAmount,
    double initialPaidAmount = 0,
    required DateTime startDate,
    DateTime? expectedEndDate,
  }) async {
    final data = await _api.post('/loans', body: {
      'name': name,
      'direction': direction.wire,
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
