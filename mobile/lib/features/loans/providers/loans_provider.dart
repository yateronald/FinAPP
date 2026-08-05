import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/loan_models.dart';
import '../data/loans_repository.dart';

final loansRepositoryProvider = Provider((_) => LoansRepository());

/// Active loans. autoDispose so a stale list is never shown after the user
/// records a payment elsewhere in the app.
final loansProvider = FutureProvider.autoDispose<List<Loan>>((ref) {
  return ref.watch(loansRepositoryProvider).list();
});

/// Includes archived and settled loans — used by the "show all" toggle.
final allLoansProvider = FutureProvider.autoDispose<List<Loan>>((ref) {
  return ref.watch(loansRepositoryProvider).list(includeClosed: true);
});

final loanDetailProvider =
    FutureProvider.autoDispose.family<LoanDetail, String>((ref, id) {
  return ref.watch(loansRepositoryProvider).detail(id);
});

/// Loans the expense form can attach a payment to.
final selectableLoansProvider =
    FutureProvider.autoDispose<List<SelectableLoan>>((ref) {
  return ref.watch(loansRepositoryProvider).selectable();
});

/// Refreshes every loan view. Called after recording an expense linked to a
/// loan, so progress updates without the user pulling to refresh.
void refreshLoans(Ref ref) {
  ref.invalidate(loansProvider);
  ref.invalidate(allLoansProvider);
  ref.invalidate(selectableLoansProvider);
}

/// WidgetRef variant for call sites inside widgets.
void refreshLoansFrom(WidgetRef ref) {
  ref.invalidate(loansProvider);
  ref.invalidate(allLoansProvider);
  ref.invalidate(selectableLoansProvider);
}
