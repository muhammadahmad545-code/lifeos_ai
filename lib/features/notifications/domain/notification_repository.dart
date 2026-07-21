import 'app_notification.dart';

abstract class NotificationRepository {
  Stream<List<AppNotification>> watchNotifications(String userId);

  Future<AppNotification> addNotification(String userId, AppNotification notification);

  Future<void> markRead(String notificationId);

  Future<void> markAllRead(String userId);

  Future<void> deleteNotification(String notificationId);
}
