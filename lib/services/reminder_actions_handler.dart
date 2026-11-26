import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../data/database.dart';
import '../data/repo.dart';
import '../logic/reminder_actions.dart';
import 'reminders.dart';

/// Runs on a background isolate when "Mark done" or "Snooze 10 min" is tapped on a reminder,
/// even if Plania is not running. It opens its own connection to the database, applies the
/// action through [LifeRepo] (so repeats, reminders and completion history behave exactly as
/// in the app), then closes it. The app refreshes its lists when it comes back to the front.
@pragma('vm:entry-point')
Future<void> onReminderAction(NotificationResponse response) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  final taskId = taskIdFromPayload(response.payload);
  final action = response.actionId;
  if (taskId == null || (action != kActionMarkDone && action != kActionSnooze)) return;
  final db = AppDatabase();
  try {
    final repo = LifeRepo(db, Reminders.instance);
    if (action == kActionMarkDone) {
      await repo.markDoneFromReminder(taskId);
    } else {
      await repo.snoozeFromReminder(taskId, DateTime.now());
    }
  } catch (e) {
    debugPrint('reminder action failed: $e');
  } finally {
    await db.close();
  }
}
