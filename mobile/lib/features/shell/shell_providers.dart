import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The selected bottom-nav tab (0 Accueil, 1 Finances, 2 Budgets, 3 IA).
/// Shared so screens like the dashboard's "Voir tout" links can switch tabs.
class _ShellIndexNotifier extends Notifier<int> {
  @override
  int build() => 0;
  void set(int value) => state = value;
}
final shellIndexProvider = NotifierProvider<_ShellIndexNotifier, int>(_ShellIndexNotifier.new);
