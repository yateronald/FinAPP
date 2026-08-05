import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/i18n/app_text.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';

// ------------------------------------------------------------- Model

/// Buckets the type enum into the three tabs a user actually thinks in:
/// something is wrong, something is advice, something is just news.
enum NotifGroup { alert, tip, info }

class AppNotification {
  final String id, type, title, message;
  final bool isRead;
  final DateTime createdAt;
  AppNotification.fromJson(Map<String, dynamic> j)
      : id = j['id'] ?? '',
        type = j['type'] ?? 'SYSTEM',
        title = j['title'] ?? '',
        message = j['message'] ?? '',
        isRead = j['isRead'] ?? false,
        createdAt = DateTime.tryParse(j['createdAt'] ?? '')?.toLocal() ?? DateTime.now();

  (IconData, Color) get visual => switch (type) {
        'BUDGET_WARNING' => (Icons.warning_amber_rounded, AppColors.warning),
        'BUDGET_EXCEEDED' => (Icons.error_rounded, AppColors.danger),
        'AI_ALERT' => (Icons.auto_awesome_rounded, AppColors.primary),
        'MONTHLY_SUMMARY' => (Icons.insert_chart_rounded, AppColors.success),
        'LARGE_EXPENSE' => (Icons.trending_down_rounded, AppColors.danger),
        'GOAL_REACHED' => (Icons.emoji_events_rounded, AppColors.success),
        'RECURRING_INCOME' => (Icons.trending_up_rounded, AppColors.success),
        'RECURRING_EXPENSE' => (Icons.repeat_rounded, AppColors.warning),
        _ => (Icons.notifications_rounded, AppColors.info),
      };

  NotifGroup get group => switch (type) {
        'BUDGET_WARNING' || 'BUDGET_EXCEEDED' || 'LARGE_EXPENSE' => NotifGroup.alert,
        'AI_ALERT' => NotifGroup.tip,
        _ => NotifGroup.info,
      };
}

// ---------------------------------------------------------- Providers

class NotificationsRepository {
  final _api = ApiClient.instance;
  Future<List<AppNotification>> list() async {
    final data = await _api.get('/notifications');
    return (data as List)
        .map((e) => AppNotification.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<int> unreadCount() async {
    final data = await _api.get('/notifications/unread-count');
    return (Map<String, dynamic>.from(data)['count'] as int?) ?? 0;
  }

  Future<void> markAllRead() async => _api.patch('/notifications/read-all');
  Future<void> markRead(String id) async => _api.patch('/notifications/$id/read');
  Future<void> remove(String id) async => _api.delete('/notifications/$id');

  Future<void> removeAll() async => _api.delete('/notifications/all');
}

final notificationsRepositoryProvider = Provider((_) => NotificationsRepository());

final notificationsProvider =
    FutureProvider.autoDispose<List<AppNotification>>((ref) async {
  return ref.watch(notificationsRepositoryProvider).list();
});

final unreadCountProvider = FutureProvider.autoDispose<int>((ref) async {
  return ref.watch(notificationsRepositoryProvider).unreadCount();
});

// ------------------------------------------------------------- Screen

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  /// null = "Toutes".
  NotifGroup? _filter;
  bool _busy = false;

  Future<void> _refresh() async {
    ref.invalidate(unreadCountProvider);
    ref.invalidate(notificationsProvider);
    await ref.read(notificationsProvider.future);
  }

  Future<void> _markAllRead() async {
    setState(() => _busy = true);
    try {
      await ref.read(notificationsRepositoryProvider).markAllRead();
      await _refresh();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteOne(AppNotification n) async {
    await ref.read(notificationsRepositoryProvider).remove(n.id);
    await _refresh();
    if (mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(context.t.notifDeleted),
          behavior: SnackBarBehavior.floating,
        ));
    }
  }

  /// Clearing the whole inbox cannot be undone, so it asks first and names the
  /// number involved.
  Future<void> _deleteAll(int total) async {
    final t = context.t;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        icon: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: AppColors.danger.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.delete_sweep_rounded,
              color: AppColors.danger, size: 24),
        ),
        title: Text(t.notifDeleteAllTitle,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
        content: Text(t.notifDeleteAllBody(total),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, height: 1.45, color: ctx.muted)),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(t.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            child: Text(t.notifDeleteAll),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _busy = true);
    try {
      await ref.read(notificationsRepositoryProvider).removeAll();
      await _refresh();
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(
            content: Text(context.t.notifAllDeleted),
            behavior: SnackBarBehavior.floating,
          ));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final async = ref.watch(notificationsProvider);
    final all = async.value ?? const <AppNotification>[];
    final unread = all.where((n) => !n.isRead).length;
    final visible =
        _filter == null ? all : all.where((n) => n.group == _filter).toList();

    return Scaffold(
      backgroundColor: context.isDark ? AppColors.darkBg : AppColors.lightBg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _Header(
              unread: unread,
              total: all.length,
              busy: _busy,
              onBack: () => Navigator.maybePop(context),
              onMarkAllRead: unread == 0 || _busy ? null : _markAllRead,
              onDeleteAll:
                  all.isEmpty || _busy ? null : () => _deleteAll(all.length),
            ),
            if (all.isNotEmpty)
              _FilterBar(
                items: all,
                selected: _filter,
                onSelect: (g) => setState(() => _filter = g),
              ),
            Expanded(
              child: async.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => _EmptyState(
                  icon: Icons.cloud_off_rounded,
                  title: t.genericError,
                  body: e.toString(),
                ),
                data: (_) {
                  if (all.isEmpty) {
                    return _EmptyState(
                      icon: Icons.notifications_none_rounded,
                      title: t.noNotifications,
                      body: t.noNotificationsBody,
                    );
                  }
                  if (visible.isEmpty) {
                    return _EmptyState(
                      icon: Icons.filter_alt_off_rounded,
                      title: t.notifNoneInFilter,
                      body: '',
                    );
                  }
                  return RefreshIndicator(
                    color: AppColors.primary,
                    onRefresh: _refresh,
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                      itemCount: visible.length,
                      itemBuilder: (_, i) => _Tile(
                        n: visible[i],
                        onDelete: () => _deleteOne(visible[i]),
                        onRead: () async {
                          await ref
                              .read(notificationsRepositoryProvider)
                              .markRead(visible[i].id);
                          await _refresh();
                        },
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------- Header

class _Header extends StatelessWidget {
  const _Header({
    required this.unread,
    required this.total,
    required this.busy,
    required this.onBack,
    required this.onMarkAllRead,
    required this.onDeleteAll,
  });

  final int unread, total;
  final bool busy;
  final VoidCallback onBack;
  final VoidCallback? onMarkAllRead;
  final VoidCallback? onDeleteAll;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              InkWell(
                onTap: onBack,
                customBorder: const CircleBorder(),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primary.withValues(alpha: 0.10),
                  ),
                  // The screen is pushed, so this circle is the way back —
                  // it shows an arrow rather than a decorative bell.
                  child: const Icon(Icons.arrow_back_ios_new_rounded,
                      size: 17, color: AppColors.primary),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      t.notifications,
                      style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.4),
                    ),
                    if (unread > 0)
                      Text(
                        '$unread ${unread > 1 ? t.notifUnreadMany : t.notifUnreadOne}',
                        style: TextStyle(fontSize: 12, color: context.muted),
                      ),
                  ],
                ),
              ),
              if (busy)
                const Padding(
                  padding: EdgeInsets.only(right: 6),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2.2),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          // The two bulk actions sit together, weighted so the destructive one
          // reads as secondary.
          Row(
            children: [
              _HeaderAction(
                icon: Icons.done_all_rounded,
                label: t.markAllRead,
                color: AppColors.primary,
                onTap: onMarkAllRead,
              ),
              const SizedBox(width: 8),
              _HeaderAction(
                icon: Icons.delete_sweep_rounded,
                label: t.notifDeleteAll,
                color: AppColors.danger,
                onTap: onDeleteAll,
              ),
              const Spacer(),
              if (total > 0)
                Text('$total',
                    style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: context.muted)),
              const SizedBox(width: 6),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeaderAction extends StatelessWidget {
  const _HeaderAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: Material(
        color: color.withValues(alpha: context.isDark ? 0.18 : 0.09),
        borderRadius: BorderRadius.circular(11),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(11),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 6),
                Text(label,
                    style: TextStyle(
                        fontSize: 12.5, fontWeight: FontWeight.w700, color: color)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ----------------------------------------------------------- Filter bar

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.items,
    required this.selected,
    required this.onSelect,
  });

  final List<AppNotification> items;
  final NotifGroup? selected;
  final ValueChanged<NotifGroup?> onSelect;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    int count(NotifGroup g) => items.where((n) => n.group == g).length;

    final chips = <(String, int, NotifGroup?, Color)>[
      (t.notifFilterAll, items.length, null, AppColors.primary),
      (t.notifFilterAlerts, count(NotifGroup.alert), NotifGroup.alert, AppColors.danger),
      (t.notifFilterTips, count(NotifGroup.tip), NotifGroup.tip, AppColors.accent),
      (t.notifFilterInfo, count(NotifGroup.info), NotifGroup.info, AppColors.info),
    ];

    return SizedBox(
      height: 46,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: chips.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final (label, n, group, color) = chips[i];
          final active = selected == group;
          // An empty bucket stays visible but inert — the counts double as a
          // summary of what arrived.
          final enabled = n > 0 || group == null;
          return Opacity(
            opacity: enabled ? 1 : 0.45,
            child: Material(
              color: active ? color : context.colors.surface,
              borderRadius: BorderRadius.circular(22),
              child: InkWell(
                onTap: enabled ? () => onSelect(group) : null,
                borderRadius: BorderRadius.circular(22),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: active ? color : context.borderColor,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: active ? Colors.white : context.colors.onSurface,
                        ),
                      ),
                      const SizedBox(width: 7),
                      Container(
                        constraints: const BoxConstraints(minWidth: 19),
                        padding:
                            const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: active
                              ? Colors.white.withValues(alpha: 0.26)
                              : color.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Text(
                          '$n',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: active ? Colors.white : color,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------- Tile

class _Tile extends StatelessWidget {
  const _Tile({required this.n, required this.onDelete, required this.onRead});
  final AppNotification n;
  final VoidCallback onDelete;
  final Future<void> Function() onRead;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = n.visual;
    final unread = !n.isRead;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Dismissible(
        key: ValueKey(n.id),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 22),
          decoration: BoxDecoration(
            color: AppColors.danger,
            borderRadius: BorderRadius.circular(18),
          ),
          child: const Icon(Icons.delete_rounded, color: Colors.white),
        ),
        onDismissed: (_) => onDelete(),
        child: Material(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: unread ? () => onRead() : null,
            child: Container(
              // The unread spine is a LEFT BORDER, not a stretched child: a
              // Row with CrossAxisAlignment.stretch inside a ListView gets an
              // unbounded height constraint, which silently paints nothing in
              // release builds.
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border(
                  left: BorderSide(
                    color: unread ? color : context.borderColor,
                    width: unread ? 4 : 1,
                  ),
                  top: BorderSide(
                      color: unread
                          ? color.withValues(alpha: 0.30)
                          : context.borderColor),
                  right: BorderSide(
                      color: unread
                          ? color.withValues(alpha: 0.30)
                          : context.borderColor),
                  bottom: BorderSide(
                      color: unread
                          ? color.withValues(alpha: 0.30)
                          : context.borderColor),
                ),
              ),
              child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 13, 8, 13),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: color.withValues(
                                    alpha: context.isDark ? 0.22 : 0.13),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Icon(icon, color: color, size: 21),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    n.title,
                                    style: TextStyle(
                                      fontSize: 14.5,
                                      height: 1.25,
                                      fontWeight:
                                          unread ? FontWeight.w800 : FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    n.message,
                                    style: TextStyle(
                                        color: context.muted,
                                        fontSize: 13,
                                        height: 1.4),
                                  ),
                                  const SizedBox(height: 9),
                                  Row(
                                    children: [
                                      Icon(Icons.event_rounded,
                                          size: 13, color: context.muted),
                                      const SizedBox(width: 5),
                                      Expanded(
                                        child: Text(
                                          Dates.relative(n.createdAt),
                                          style: TextStyle(
                                              color: context.muted, fontSize: 11.5),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 4),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  Dates.hourMinute(n.createdAt),
                                  style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                      color: context.muted),
                                ),
                                const SizedBox(height: 6),
                                if (unread)
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                        color: color, shape: BoxShape.circle),
                                  )
                                else
                                  const SizedBox(height: 8),
                                const SizedBox(height: 4),
                                // Explicit delete, for anyone who never
                                // discovers the swipe.
                                InkWell(
                                  onTap: onDelete,
                                  customBorder: const CircleBorder(),
                                  child: Padding(
                                    padding: const EdgeInsets.all(6),
                                    child: Icon(Icons.delete_outline_rounded,
                                        size: 18,
                                        color: context.muted
                                            .withValues(alpha: 0.85)),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
            ),
          ),
        ),
      ),
    );
  }
}

// --------------------------------------------------------------- Empty

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.title, required this.body});
  final IconData icon;
  final String title, body;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 82,
              height: 82,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(alpha: 0.08),
              ),
              child: Icon(icon, size: 36, color: AppColors.primary),
            ),
            const SizedBox(height: 18),
            Text(title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            if (body.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(body,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, height: 1.5, color: context.muted)),
            ],
          ],
        ),
      ),
    );
  }
}
