import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/feature_providers.dart';
import '../../../core/providers/providers.dart';
import '../../../shared/widgets/empty_state_view.dart';
import '../../../shared/widgets/loading_view.dart';
import '../domain/app_notification.dart';

IconData _iconForType(String type) {
  switch (type) {
    case 'task':
      return Icons.check_circle_outline;
    case 'event':
      return Icons.event_outlined;
    case 'habit':
      return Icons.repeat_rounded;
    case 'feedback':
      return Icons.feedback_outlined;
    case 'welcome':
      return Icons.waving_hand_outlined;
    default:
      return Icons.notifications_outlined;
  }
}

class NotificationsPage extends ConsumerStatefulWidget {
  const NotificationsPage({super.key});

  @override
  ConsumerState<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends ConsumerState<NotificationsPage> {
  bool _seeded = false;

  String? get _userId => ref.read(authSessionProvider).valueOrNull?.id;

  void _showError(Object error) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error: $error'), backgroundColor: Theme.of(context).colorScheme.error),
    );
  }

  Future<void> _seedWelcome(String userId) async {
    _seeded = true;
    try {
      await ref.read(notificationRepositoryProvider).addNotification(
            userId,
            const AppNotification(
              id: '',
              title: 'Welcome to LIFEOS AI',
              body: 'This is your notification center. Task reminders, event alerts, and habit nudges will show up here.',
              type: 'welcome',
            ),
          );
    } catch (_) {
      // Best-effort seed; ignore failures.
    }
  }

  Future<void> _markRead(AppNotification notification) async {
    if (notification.isRead) {
      return;
    }
    try {
      await ref.read(notificationRepositoryProvider).markRead(notification.id);
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _markAllRead(List<AppNotification> notifications) async {
    final String? userId = _userId;
    if (userId == null) {
      return;
    }
    try {
      await ref.read(notificationRepositoryProvider).markAllRead(userId);
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _delete(AppNotification notification) async {
    try {
      await ref.read(notificationRepositoryProvider).deleteNotification(notification.id);
    } catch (error) {
      _showError(error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<AppNotification>> notificationsAsync = ref.watch(watchNotificationsProvider);
    final String? userId = _userId;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: <Widget>[
          notificationsAsync.maybeWhen(
            data: (List<AppNotification> notifications) => IconButton(
              icon: const Icon(Icons.done_all),
              tooltip: 'Mark all read',
              onPressed: notifications.any((AppNotification n) => !n.isRead)
                  ? () => _markAllRead(notifications)
                  : null,
            ),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: notificationsAsync.when(
        data: (List<AppNotification> notifications) {
          if (notifications.isEmpty) {
            if (userId != null && !_seeded) {
              WidgetsBinding.instance.addPostFrameCallback((_) => _seedWelcome(userId));
            }
            return const EmptyStateView(
              title: 'No notifications',
              message: "You're all caught up. New alerts will appear here.",
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
            itemCount: notifications.length,
            itemBuilder: (BuildContext context, int index) {
              final AppNotification notification = notifications[index];
              return Dismissible(
                key: ValueKey<String>(notification.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.error,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.delete_outline, color: Colors.white),
                ),
                onDismissed: (_) => _delete(notification),
                child: Card(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  color: notification.isRead ? null : Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.35),
                  child: ListTile(
                    onTap: () => _markRead(notification),
                    leading: Icon(
                      _iconForType(notification.type),
                      color: notification.isRead ? null : Theme.of(context).colorScheme.primary,
                    ),
                    title: Text(
                      notification.title,
                      style: TextStyle(fontWeight: notification.isRead ? FontWeight.normal : FontWeight.w700),
                    ),
                    subtitle: Text(notification.body),
                    trailing: Text(
                      notification.createdAt != null ? DateFormat.MMMd().add_jm().format(notification.createdAt!) : '',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                    isThreeLine: false,
                  ),
                ),
              );
            },
          );
        },
        loading: () => const LoadingView(),
        error: (Object error, StackTrace stack) => ErrorView(error: error),
      ),
    );
  }
}
