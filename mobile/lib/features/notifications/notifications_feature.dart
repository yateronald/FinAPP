import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/i18n/app_text.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';

// ------------------------------------------------------------- Model

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
        'MONTHLY_SUMMARY' => (Icons.summarize_rounded, AppColors.info),
        'LARGE_EXPENSE' => (Icons.trending_down_rounded, AppColors.danger),
        'GOAL_REACHED' => (Icons.emoji_events_rounded, AppColors.success),
        'RECURRING_INCOME' => (Icons.trending_up_rounded, AppColors.success),
        'RECURRING_EXPENSE' => (Icons.repeat_rounded, AppColors.warning),
        _ => (Icons.notifications_rounded, AppColors.info),
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

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(notificationsProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(context.t.notifications),
        actions: [
          TextButton(
            onPressed: () async {
              await ref.read(notificationsRepositoryProvider).markAllRead();
              ref.invalidate(notificationsProvider);
              ref.invalidate(unreadCountProvider);
            },
            child: Text(context.t.markAllRead),
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(e.toString())),
        data: (items) {
          if (items.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.notifications_none_rounded, size: 56, color: context.muted),
                  const SizedBox(height: 14),
                  Text(context.t.noNotifications, style: TextStyle(color: context.muted)),
                ],
              ),
            );
          }
          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () async {
              ref.invalidate(unreadCountProvider);
              return ref.refresh(notificationsProvider.future);
            },
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) => _Tile(n: items[i]),
            ),
          );
        },
      ),
    );
  }
}

class _Tile extends ConsumerWidget {
  final AppNotification n;
  const _Tile({required this.n});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (icon, color) = n.visual;
    return Dismissible(
      key: ValueKey(n.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
            color: AppColors.danger, borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.delete_rounded, color: Colors.white),
      ),
      onDismissed: (_) async {
        await ref.read(notificationsRepositoryProvider).remove(n.id);
        ref.invalidate(unreadCountProvider);
      },
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: n.isRead
            ? null
            : () async {
                await ref.read(notificationsRepositoryProvider).markRead(n.id);
                ref.invalidate(notificationsProvider);
                ref.invalidate(unreadCountProvider);
              },
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: n.isRead ? context.colors.surface : color.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: n.isRead ? context.borderColor : color.withValues(alpha: 0.25)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(n.title,
                              style: TextStyle(
                                  fontWeight:
                                      n.isRead ? FontWeight.w600 : FontWeight.w800)),
                        ),
                        if (!n.isRead)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(n.message,
                        style: TextStyle(color: context.muted, fontSize: 13, height: 1.35)),
                    const SizedBox(height: 6),
                    Text(Dates.relative(n.createdAt),
                        style: TextStyle(color: context.muted, fontSize: 11.5)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
