import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/i18n/app_text.dart';
import '../../core/offline/sync_engine.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/responsive.dart';
import '../ai/presentation/ai_screen.dart';
import '../auth/presentation/biometric_prompt.dart';
import '../auth/presentation/terms_acceptance_gate.dart';
import '../auth/presentation/welcome_sheet.dart';
import '../auth/providers/auth_provider.dart';
import '../budgets/presentation/budgets_screen.dart';
import '../budgets/presentation/set_budget_sheet.dart';
import '../dashboard/presentation/dashboard_screen.dart';
import '../dashboard/providers/dashboard_provider.dart';
import '../loans/presentation/loans_screen.dart';
import '../notifications/notifications_feature.dart';
import '../reports/reports_feature.dart';
import '../transactions/data/transaction_models.dart';
import '../transactions/presentation/add_transaction_sheet.dart';
import '../transactions/presentation/finances_screen.dart';
import '../transactions/providers/transactions_provider.dart';
import 'shell_providers.dart';

class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});
  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  @override
  void initState() {
    super.initState();
    // Deferred to the first frame so dialogs have a mounted route to attach to.
    WidgetsBinding.instance.addPostFrameCallback((_) => _runFirstRunFlow());
  }

  /// Greet, then offer app-lock — strictly in sequence. Both are one-time and
  /// showing them at once would stack two modals over an empty dashboard.
  Future<void> _runFirstRunFlow() async {
    if (!mounted) return;

    // Consent comes first and blocks: accounts created before consent was
    // recorded must accept the published documents before anything else.
    await maybePromptTermsAcceptance(context, ref);
    if (!mounted) return;

    final wantsToAdd = await maybeShowWelcome(context, ref);

    if (wantsToAdd && mounted) {
      // Honour the CTA: land them straight on the expense form.
      await showTransactionSheet(context, type: TxType.expense);
    }

    if (mounted) await maybeOfferBiometricEnrolment(context, ref);
  }

  String _title(AppText t, int index) => [
        t.titleHome,
        t.titleFinances,
        t.titleBudgets,
        t.titleAi,
        t.titleLoans,
      ][index];

  Widget _body(int index) {
    switch (index) {
      case 0:
        return const DashboardScreen();
      case 1:
        return const FinancesScreen();
      case 2:
        return const BudgetsScreen();
      case 4:
        return const LoansScreen();
      default:
        return const AiScreen();
    }
  }

  void _openAddSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _AddActionSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    // Start the offline sync engine and refresh data whenever a flush completes.
    ref.watch(syncEngineProvider);
    ref.listen(syncTickProvider, (_, __) {
      ref.invalidate(dashboardProvider);
      ref.invalidate(transactionsProvider(TxType.income));
      ref.invalidate(transactionsProvider(TxType.expense));
    });
    final online = ref.watch(isOnlineProvider);
    final pending = ref.watch(pendingCountProvider);
    final index = ref.watch(shellIndexProvider);
    // Tablets/large screens get a side navigation rail (the standard large-screen
    // pattern) instead of a bottom bar floating in the middle of a wide screen.
    final wide = context.isTablet;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: Text(_title(context.t, index),
            style: const TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          _NotificationBell(),
          Padding(
            padding: const EdgeInsets.only(right: 16, left: 4),
            child: GestureDetector(
              onTap: () => context.push('/settings'),
              child: CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                child: Text(
                  user?.initials ?? '?',
                  style: const TextStyle(
                      color: AppColors.primary, fontWeight: FontWeight.w800, fontSize: 13),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _SyncBanner(online: online, pending: pending),
          Expanded(
            child: wide
                ? Row(
                    children: [
                      _SideRail(
                        index: index,
                        onTap: (i) => ref.read(shellIndexProvider.notifier).set(i),
                        onAdd: _openAddSheet,
                        onReports: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const ReportsScreen()),
                        ),
                      ),
                      const VerticalDivider(width: 1, thickness: 1),
                      // Page content stays in a comfortable centred column.
                      Expanded(child: ResponsiveCenter(child: _body(index))),
                    ],
                  )
                : _body(index),
          ),
        ],
      ),
      // The add button now lives inside the floating bar (and the rail on wide
      // screens), so no separate FAB is needed.
      bottomNavigationBar: wide
          ? null
          : _BottomBar(
              index: index,
              onTap: (i) => ref.read(shellIndexProvider.notifier).set(i),
              onAdd: _openAddSheet,
              onReports: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ReportsScreen()),
              ),
            ),
    );
  }
}

class _NotificationBell extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(unreadCountProvider).value ?? 0;
    return Stack(
      alignment: Alignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.notifications_none_rounded),
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const NotificationsScreen()),
            );
            ref.invalidate(unreadCountProvider);
          },
        ),
        if (unread > 0)
          Positioned(
            top: 10,
            right: 10,
            child: Container(
              padding: const EdgeInsets.all(4),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              decoration: const BoxDecoration(color: AppColors.danger, shape: BoxShape.circle),
              child: Text(
                unread > 9 ? '9+' : '$unread',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800),
              ),
            ),
          ),
      ],
    );
  }
}

class _SyncBanner extends StatelessWidget {
  final bool online;
  final int pending;
  const _SyncBanner({required this.online, required this.pending});

  @override
  Widget build(BuildContext context) {
    if (online && pending == 0) return const SizedBox.shrink();
    final offline = !online;
    final color = offline ? AppColors.warning : AppColors.info;
    final icon = offline ? Icons.cloud_off_rounded : Icons.sync_rounded;
    final text = offline
        ? (pending > 0 ? context.t.offlinePending(pending) : context.t.offlineNoPending)
        : context.t.syncing(pending);
    return Container(
      width: double.infinity,
      color: color.withValues(alpha: 0.14),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Flexible(
            child: Text(text,
                style: TextStyle(color: color, fontSize: 12.5, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

/// Large-screen side navigation (tablets, landscape, foldables). Replaces the
/// bottom bar, which looks stranded in the middle of a wide screen.
class _SideRail extends StatelessWidget {
  final int index;
  final ValueChanged<int> onTap;
  final VoidCallback onAdd;
  final VoidCallback onReports;
  const _SideRail({
    required this.index,
    required this.onTap,
    required this.onAdd,
    required this.onReports,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return NavigationRail(
      selectedIndex: index,
      // The 5th destination (Reports) is a pushed screen, not a shell tab.
      // Reports is a pushed route, not a tab — it moved to slot 5 when Loans
      // was inserted at 4.
      onDestinationSelected: (i) => i == 5 ? onReports() : onTap(i),
      labelType: NavigationRailLabelType.all,
      backgroundColor: context.colors.surface,
      indicatorColor: AppColors.primary.withValues(alpha: 0.12),
      selectedIconTheme: const IconThemeData(color: AppColors.primary, size: 24),
      unselectedIconTheme: IconThemeData(color: context.muted, size: 23),
      selectedLabelTextStyle:
          const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 12),
      unselectedLabelTextStyle:
          TextStyle(color: context.muted, fontWeight: FontWeight.w600, fontSize: 12),
      leading: Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 12),
        child: FloatingActionButton(
          onPressed: onAdd,
          elevation: 2,
          tooltip: t.navFinances,
          child: const Icon(Icons.add_rounded, size: 28),
        ),
      ),
      destinations: [
        NavigationRailDestination(
          icon: const Icon(Icons.home_outlined),
          selectedIcon: const Icon(Icons.home_rounded),
          label: Text(t.navHome),
        ),
        NavigationRailDestination(
          icon: const Icon(Icons.swap_vert_rounded),
          selectedIcon: const Icon(Icons.swap_vert_rounded),
          label: Text(t.navFinances),
        ),
        NavigationRailDestination(
          icon: const Icon(Icons.savings_outlined),
          selectedIcon: const Icon(Icons.savings_rounded),
          label: Text(t.navBudgets),
        ),
        NavigationRailDestination(
          icon: const Icon(Icons.auto_awesome_outlined),
          selectedIcon: const Icon(Icons.auto_awesome_rounded),
          label: Text(t.navAiShort),
        ),
        // Index 4 — must match the tab order in _body().
        NavigationRailDestination(
          icon: const Icon(Icons.account_balance_outlined),
          selectedIcon: const Icon(Icons.account_balance_rounded),
          label: Text(t.navLoans),
        ),
        NavigationRailDestination(
          icon: const Icon(Icons.bar_chart_rounded),
          selectedIcon: const Icon(Icons.bar_chart_rounded),
          label: Text(t.reports),
        ),
      ],
    );
  }
}

/// Modern floating navigation bar: a raised, rounded pill holding the five
/// destinations, with a prominent gradient "add" button that sits above it.
class _BottomBar extends StatelessWidget {
  final int index;
  final ValueChanged<int> onTap;
  final VoidCallback onAdd;
  final VoidCallback onReports;
  const _BottomBar({
    required this.index,
    required this.onTap,
    required this.onAdd,
    required this.onReports,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(14, 0, 14, 10 + bottomInset * 0.4),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          Container(
            height: 66,
            decoration: BoxDecoration(
              color: context.colors.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: context.borderColor),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.10),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                _item(context, 0, Icons.home_rounded, Icons.home_outlined, t.navHome),
                _item(context, 1, Icons.swap_vert_rounded, Icons.swap_vert_rounded, t.navFinances),
                _item(context, 2, Icons.savings_rounded, Icons.savings_outlined, t.navBudgets),
                _item(context, 4, Icons.account_balance_rounded,
                    Icons.account_balance_outlined, t.navLoans),
                _action(context, Icons.bar_chart_rounded, t.reports, onReports),
                _item(context, 3, Icons.auto_awesome_rounded, Icons.auto_awesome_outlined,
                    t.navAiShort),
                // Reserved space so the floating add button never covers a tab.
                const SizedBox(width: 62),
              ],
            ),
          ),
          // Prominent gradient add button, lifted above the bar on the right.
          // Hidden on the AI tab, where it would sit over the chat send button.
          if (index != 3)
          Positioned(
            top: -22,
            right: 4,
            child: GestureDetector(
              onTap: onAdd,
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: AppColors.brandGradient,
                  borderRadius: BorderRadius.circular(19),
                  border: Border.all(color: context.colors.surface, width: 3.5),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.45),
                      blurRadius: 18,
                      offset: const Offset(0, 7),
                    ),
                  ],
                ),
                child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// A bar entry that opens a pushed screen (Reports) rather than a shell tab.
  Widget _action(BuildContext context, IconData icon, String label, VoidCallback onTap) {
    final color = context.muted;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Icon(icon, color: color, size: 21),
            ),
            const SizedBox(height: 2),
            Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _item(BuildContext context, int i, IconData active, IconData inactive, String label) {
    final selected = index == i;
    final color = selected ? AppColors.primary : context.muted;
    return Expanded(
      child: InkWell(
        onTap: () => onTap(i),
        borderRadius: BorderRadius.circular(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: selected ? AppColors.primary.withValues(alpha: 0.12) : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(selected ? active : inactive, color: color, size: 21),
            ),
            const SizedBox(height: 2),
            Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: color,
                    fontSize: 10,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _AddActionSheet extends StatelessWidget {
  const _AddActionSheet();

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return Container(
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
      ),
      padding: EdgeInsets.fromLTRB(18, 10, 18, 18 + MediaQuery.of(context).padding.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 42,
            height: 4.5,
            decoration: BoxDecoration(
              color: context.borderColor,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 20),
          // Header: gradient badge + title/subtitle + close.
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: AppColors.brandGradient,
                  borderRadius: BorderRadius.circular(13),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(Icons.add_rounded, color: Colors.white, size: 23),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.add,
                        style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
                    Text(t.addSheetSubtitle,
                        style: TextStyle(color: context.muted, fontSize: 12.5)),
                  ],
                ),
              ),
              InkWell(
                onTap: () => Navigator.pop(context),
                customBorder: const CircleBorder(),
                child: Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: context.surfaceAlt,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.close_rounded, size: 18, color: context.muted),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _action(
            context,
            icon: Icons.arrow_upward_rounded,
            color: AppColors.success,
            title: t.newIncome(),
            sub: t.incomeSub,
            onTap: () {
              Navigator.pop(context);
              showTransactionSheet(context, type: TxType.income);
            },
          ),
          const SizedBox(height: 10),
          _action(
            context,
            icon: Icons.arrow_downward_rounded,
            color: AppColors.danger,
            title: t.newExpense(),
            sub: t.expenseSub,
            onTap: () {
              Navigator.pop(context);
              showTransactionSheet(context, type: TxType.expense);
            },
          ),
          const SizedBox(height: 10),
          _action(
            context,
            icon: Icons.savings_rounded,
            color: AppColors.primary,
            title: t.setBudget,
            sub: t.budgetSub,
            onTap: () {
              Navigator.pop(context);
              showSetBudgetSheet(context);
            },
          ),
        ],
      ),
    );
  }

  Widget _action(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String title,
    required String sub,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        splashColor: color.withValues(alpha: 0.10),
        highlightColor: color.withValues(alpha: 0.06),
        child: Ink(
          decoration: BoxDecoration(
            // Soft tint of the action's own colour, with a matching hairline.
            color: color.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: color.withValues(alpha: 0.18)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.35),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(icon, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                      const SizedBox(height: 2),
                      Text(sub,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: context.muted, fontSize: 12.5)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.arrow_forward_rounded, color: color, size: 15),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
