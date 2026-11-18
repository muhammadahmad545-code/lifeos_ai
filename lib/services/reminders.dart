import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../data/database.dart';
import '../data/repo.dart';

/// Local notifications for task reminders and the focus timer.
///
/// Reminders use exact alarms when the system allows them (USE_EXACT_ALARM on Android 13+,
/// SCHEDULE_EXACT_ALARM on 12) and fall back to inexact ones otherwise. The plugin's boot
/// receiver restores them after a reboot or an app update.
class Reminders implements ReminderScheduler {
  Reminders._();

  static final Reminders instance = Reminders._();

  static const int focusNotificationId = 1;

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  static const _taskDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      'lifeos_reminders',
      'Task reminders',
      channelDescription: 'Reminders you set on tasks',
      importance: Importance.high,
      priority: Priority.high,
      icon: 'ic_stat_lifeos',
    ),
  );

  static const _focusDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      'lifeos_focus',
      'Focus timer',
      channelDescription: 'Tells you when a focus session ends',
      importance: Importance.high,
      priority: Priority.high,
      icon: 'ic_stat_lifeos',
    ),
  );

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

  Future<void> init() async {
    if (_ready) return;
    try {
      tz_data.initializeTimeZones();
      await _plugin.initialize(
        settings: const InitializationSettings(android: AndroidInitializationSettings('ic_stat_lifeos')),
      );
      _ready = true;
    } catch (e) {
      debugPrint('notifications init failed: $e');
    }
  }

  /// Asks for POST_NOTIFICATIONS (Android 13+). Returns whether notifications are allowed.
  Future<bool> ensurePermission() async {
    await init();
    try {
      final android = _android;
      if (android == null) return false;
      if (await android.areNotificationsEnabled() ?? false) return true;
      return await android.requestNotificationsPermission() ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> notificationsAllowed() async {
    await init();
    try {
      return await _android?.areNotificationsEnabled() ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> exactAlarmsAllowed() async {
    await init();
    try {
      return await _android?.canScheduleExactNotifications() ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Stable notification id for a task (String.hashCode is not stable across runs).
  static int idForTask(String taskId) {
    var h = 0x811c9dc5;
    for (final c in 'task:$taskId'.codeUnits) {
      h ^= c;
      h = (h * 0x01000193) & 0x7fffffff;
    }
    // Keep clear of the fixed ids below 100.
    return h < 100 ? h + 100 : h;
  }

  Future<void> _schedule(int id, String title, String body, DateTime when, NotificationDetails details) async {
    await init();
    if (!_ready || !when.isAfter(DateTime.now())) return;
    final at = tz.TZDateTime.from(when, tz.UTC);
    final exact = await exactAlarmsAllowed();
    try {
      await _plugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: at,
        notificationDetails: details,
        androidScheduleMode: exact ? AndroidScheduleMode.exactAllowWhileIdle : AndroidScheduleMode.inexactAllowWhileIdle,
      );
    } on PlatformException catch (e) {
      if (!exact) rethrow;
      debugPrint('exact alarm refused ($e), using an inexact one');
      await _plugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: at,
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
  }

  Future<void> _cancel(int id) async {
    await init();
    if (!_ready) return;
    try {
      await _plugin.cancel(id: id);
    } catch (e) {
      debugPrint('cancel notification failed: $e');
    }
  }

  @override
  Future<void> syncTask(TaskRow task) async {
    final id = idForTask(task.id);
    await _cancel(id);
    final at = task.reminderAt;
    if (task.isCompleted || at == null || !at.isAfter(DateTime.now())) return;
    try {
      await _schedule(id, task.title, _taskBody(task), at, _taskDetails);
    } catch (e) {
      debugPrint('schedule reminder failed: $e');
    }
  }

  String _taskBody(TaskRow t) {
    final notes = t.description?.trim() ?? '';
    return notes.isEmpty ? 'Task reminder' : notes;
  }

  @override
  Future<void> cancelTask(String taskId) => _cancel(idForTask(taskId));

  /// Re-registers every pending task reminder (after start-up and after a backup import).
  Future<void> syncAll(List<TaskRow> tasks) async {
    for (final t in tasks) {
      if (t.reminderAt != null) await syncTask(t);
    }
  }

  Future<void> scheduleFocusEnd(DateTime when, int minutes) async {
    try {
      await _schedule(focusNotificationId, 'Focus session complete', '$minutes minutes done. Time for a break.', when, _focusDetails);
    } catch (e) {
      debugPrint('schedule focus alarm failed: $e');
    }
  }

  Future<void> cancelFocusEnd() => _cancel(focusNotificationId);

  Future<void> showTest() async {
    await init();
    if (!_ready) return;
    await _plugin.show(
      id: 2,
      title: 'Reminders are on',
      body: 'Task reminders will appear like this.',
      notificationDetails: _taskDetails,
    );
  }
}
