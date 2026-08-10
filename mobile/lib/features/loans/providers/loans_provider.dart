import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/loan_models.dart';
import '../data/loans_repository.dart';

final loansRepositoryProvider = Provider((_) => LoansRepository());

/// Active loans for one direction. autoDispose so a stale list is never shown
/// after the user records a payment elsewhere in the app.
final loansProvider =
    FutureProvider.autoDispose.family<List<Loan>, LoanDirection>((ref, direction) {
  return ref.watch(loansRepositoryProvider).list(direction: direction);
});

/// Includes archived and settled loans — used by the "show all" toggle.
final allLoansProvider =
    FutureProvider.autoDispose.family<List<Loan>, LoanDirection>((ref, direction) {
  return ref
      .watch(loansRepositoryProvider)
      .list(includeClosed: true, direction: direction);
});

final loanDetailProvider =
    FutureProvider.autoDispose.family<LoanDetail, String>((ref, id) {
  return ref.watch(loansRepositoryProvider).detail(id);
});

/// Loans a transaction form can attach to: borrowed ones for the expense form,
/// lent ones for the income form.
final selectableLoansProvider = FutureProvider.autoDispose
    .family<List<SelectableLoan>, LoanDirection>((ref, direction) {
  return ref.watch(loansRepositoryProvider).selectable(direction: direction);
});

/// Refreshes every loan view, both directions. Called after recording a
/// transaction linked to a loan, so progress updates without a pull-to-refresh.
///
/// Invalidating the family without an argument clears every instance, which is
/// what we want: the caller rarely knows which side it just touched.
void refreshLoans(Ref ref) {
  ref.invalidate(loansProvider);
  ref.invalidate(allLoansProvider);
  ref.invalidate(selectableLoansProvider);
  ref.invalidate(loanDetailProvider);
}

/// WidgetRef variant for call sites inside widgets.
void refreshLoansFrom(WidgetRef ref) {
  ref.invalidate(loansProvider);
  ref.invalidate(allLoansProvider);
  ref.invalidate(selectableLoansProvider);
  ref.invalidate(loanDetailProvider);
}
