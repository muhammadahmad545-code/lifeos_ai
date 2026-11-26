import '../data/database.dart';

// Reminder notification actions. The decisions are pure so they can be tested without the
// notification plugin; the background handler in services/reminder_actions_handler.dart applies them.

const String kActionMarkDone = 'mark_done';
const String kActionSnooze = 'snooze';
const Duration kSnooze = Duration(minutes: 10);

/// Reminder payloads are `task:<id>`.
String reminderPayload(String taskId) => 'task:$taskId';

String? taskIdFromPayload(String? payload) {
  if (payload == null || !payload.startsWith('task:')) return null;
  final id = payload.substring(5);
  return id.isEmpty ? null : id;
}

enum ReminderOutcome { apply, alreadyDone, missing }

/// What "Mark done" or "Snooze" should do for [task]. A notification can be stale (the task was
/// completed or deleted in the app, or by an earlier tap), so only an open task is changed.
ReminderOutcome reminderOutcome(TaskRow? task) {
  if (task == null) return ReminderOutcome.missing;
  if (task.isCompleted) return ReminderOutcome.alreadyDone;
  return ReminderOutcome.apply;
}
