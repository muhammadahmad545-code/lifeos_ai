import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/utils/id_generator.dart';
import '../domain/app_notification.dart';
import '../domain/notification_repository.dart';

class NotificationRepositoryImpl implements NotificationRepository {
  NotificationRepositoryImpl(this._db);

  final AppDatabase _db;

  @override
  Stream<List<AppNotification>> watchNotifications(String userId) {
    final query = (_db.select(_db.appNotifications)
          ..where((AppNotifications tbl) => tbl.userId.equals(userId))
          ..orderBy(<OrderingTerm Function(AppNotifications)>[
            (AppNotifications tbl) => OrderingTerm(expression: tbl.isRead),
            (AppNotifications tbl) => OrderingTerm.desc(tbl.createdAt),
          ]))
        .watch();
    return query.map((List<AppNotificationRow> rows) => rows.map(_map).toList());
  }

  @override
  Future<AppNotification> addNotification(String userId, AppNotification notification) async {
    final String id = notification.id.isEmpty ? IdGenerator.next() : notification.id;
    final DateTime now = DateTime.now();
    await _db.into(_db.appNotifications).insert(
          AppNotificationsCompanion.insert(
            id: id,
            userId: userId,
            title: notification.title,
            body: notification.body,
            type: Value<String>(notification.type),
            isRead: Value<bool>(notification.isRead),
            createdAt: notification.createdAt ?? now,
            scheduledFor: Value<DateTime?>(notification.scheduledFor),
          ),
        );
    final AppNotificationRow row = await (_db.select(_db.appNotifications)
          ..where((AppNotifications tbl) => tbl.id.equals(id)))
        .getSingle();
    return _map(row);
  }

  @override
  Future<void> markRead(String notificationId) async {
    await (_db.update(_db.appNotifications)..where((AppNotifications tbl) => tbl.id.equals(notificationId))).write(
          const AppNotificationsCompanion(isRead: Value<bool>(true)),
        );
  }

  @override
  Future<void> markAllRead(String userId) async {
    await (_db.update(_db.appNotifications)..where((AppNotifications tbl) => tbl.userId.equals(userId))).write(
          const AppNotificationsCompanion(isRead: Value<bool>(true)),
        );
  }

  @override
  Future<void> deleteNotification(String notificationId) async {
    await (_db.delete(_db.appNotifications)..where((AppNotifications tbl) => tbl.id.equals(notificationId))).go();
  }

  AppNotification _map(AppNotificationRow row) {
    return AppNotification(
      id: row.id,
      title: row.title,
      body: row.body,
      type: row.type,
      isRead: row.isRead,
      createdAt: row.createdAt,
      scheduledFor: row.scheduledFor,
    );
  }
}
