/// Which way the money went.
///
/// A loan is one model with two directions rather than two models: every field
/// and every derived figure is identical, only who owes whom differs. The
/// direction decides which transaction settles it — an expense repays what you
/// borrowed, an income collects what you lent.
enum LoanDirection {
  borrowed,
  lent;

  static LoanDirection fromJson(dynamic v) =>
      (v as String?) == 'LENT' ? LoanDirection.lent : LoanDirection.borrowed;

  String get wire => this == LoanDirection.lent ? 'LENT' : 'BORROWED';

  bool get isLent => this == LoanDirection.lent;
}

/// A loan and its repayment progress.
///
/// Every derived figure (`totalPaid`, `remaining`, `progress`) is computed
/// server-side from the linked expenses — the client never recalculates them,
/// so the two can't disagree.
class Loan {
  final String id;
  final String name;
  final LoanDirection direction;
  final String? description;
  final String? lender;
  final double principalAmount;
  final double initialPaidAmount;
  final double totalPaid;
  final double remaining;

  /// 0–100.
  final double progress;
  final DateTime startDate;
  final DateTime? expectedEndDate;

  /// ACTIVE | PAID_OFF | ARCHIVED
  final String status;
  final int paymentCount;
  final DateTime? lastPaymentDate;
  final int? monthsRemaining;
  final double? suggestedMonthlyPayment;
  final bool isOverdue;

  const Loan({
    required this.id,
    required this.name,
    this.direction = LoanDirection.borrowed,
    this.description,
    this.lender,
    required this.principalAmount,
    required this.initialPaidAmount,
    required this.totalPaid,
    required this.remaining,
    required this.progress,
    required this.startDate,
    this.expectedEndDate,
    required this.status,
    required this.paymentCount,
    this.lastPaymentDate,
    this.monthsRemaining,
    this.suggestedMonthlyPayment,
    required this.isOverdue,
  });

  bool get isPaidOff => status == 'PAID_OFF' || remaining <= 0;

  /// The other party: the lender on a borrowed loan, the borrower on a lent one.
  /// Stored in one column — the direction is what gives it its meaning.
  String? get counterparty => lender;

  bool get isLent => direction.isLent;

  static double _d(dynamic v) => (v as num?)?.toDouble() ?? 0;
  static DateTime? _dt(dynamic v) =>
      v == null ? null : DateTime.tryParse(v as String)?.toLocal();

  factory Loan.fromJson(Map<String, dynamic> j) => Loan(
        id: j['id'] as String,
        name: j['name'] as String? ?? '',
        direction: LoanDirection.fromJson(j['direction']),
        description: j['description'] as String?,
        lender: j['lender'] as String?,
        principalAmount: _d(j['principalAmount']),
        initialPaidAmount: _d(j['initialPaidAmount']),
        totalPaid: _d(j['totalPaid']),
        remaining: _d(j['remaining']),
        progress: _d(j['progress']),
        startDate: _dt(j['startDate']) ?? DateTime.now(),
        expectedEndDate: _dt(j['expectedEndDate']),
        status: j['status'] as String? ?? 'ACTIVE',
        paymentCount: (j['paymentCount'] as num?)?.toInt() ?? 0,
        lastPaymentDate: _dt(j['lastPaymentDate']),
        monthsRemaining: (j['monthsRemaining'] as num?)?.toInt(),
        suggestedMonthlyPayment: j['suggestedMonthlyPayment'] == null
            ? null
            : _d(j['suggestedMonthlyPayment']),
        isOverdue: j['isOverdue'] as bool? ?? false,
      );
}

/// A single repayment — an expense linked to the loan.
class LoanPayment {
  final String id;
  final String title;
  final double amount;
  final DateTime date;
  final String? description;
  final String? categoryName;
  final String? categoryIcon;
  final String? categoryColor;

  const LoanPayment({
    required this.id,
    required this.title,
    required this.amount,
    required this.date,
    this.description,
    this.categoryName,
    this.categoryIcon,
    this.categoryColor,
  });

  factory LoanPayment.fromJson(Map<String, dynamic> j) {
    final cat = j['category'] as Map<String, dynamic>?;
    return LoanPayment(
      id: j['id'] as String,
      title: j['title'] as String? ?? '',
      amount: (j['amount'] as num?)?.toDouble() ?? 0,
      date: DateTime.tryParse(j['date'] as String? ?? '')?.toLocal() ?? DateTime.now(),
      description: j['description'] as String?,
      categoryName: cat?['name'] as String?,
      categoryIcon: cat?['icon'] as String?,
      categoryColor: cat?['color'] as String?,
    );
  }
}

/// Payments for one calendar month, as grouped by the server.
class LoanMonth {
  /// `YYYY-MM`.
  final String month;
  final double total;
  final List<LoanPayment> payments;

  const LoanMonth({required this.month, required this.total, required this.payments});

  factory LoanMonth.fromJson(Map<String, dynamic> j) => LoanMonth(
        month: j['month'] as String? ?? '',
        total: (j['total'] as num?)?.toDouble() ?? 0,
        payments: ((j['payments'] as List?) ?? [])
            .map((e) => LoanPayment.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
      );
}

class LoanDetail {
  final Loan loan;
  final List<LoanMonth> months;

  const LoanDetail({required this.loan, required this.months});

  factory LoanDetail.fromJson(Map<String, dynamic> j) => LoanDetail(
        loan: Loan.fromJson(j),
        months: ((j['months'] as List?) ?? [])
            .map((e) => LoanMonth.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
      );
}

/// Trimmed shape used by the expense form's loan picker.
class SelectableLoan {
  final String id;
  final String name;
  final LoanDirection direction;
  final double remaining;
  final double progress;
  final double? suggestedMonthlyPayment;

  const SelectableLoan({
    required this.id,
    required this.name,
    this.direction = LoanDirection.borrowed,
    required this.remaining,
    required this.progress,
    this.suggestedMonthlyPayment,
  });

  factory SelectableLoan.fromJson(Map<String, dynamic> j) => SelectableLoan(
        id: j['id'] as String,
        name: j['name'] as String? ?? '',
        direction: LoanDirection.fromJson(j['direction']),
        remaining: (j['remaining'] as num?)?.toDouble() ?? 0,
        progress: (j['progress'] as num?)?.toDouble() ?? 0,
        suggestedMonthlyPayment:
            (j['suggestedMonthlyPayment'] as num?)?.toDouble(),
      );
}
