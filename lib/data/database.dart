import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../logic/dates.dart';
import 'tables.dart';

export 'tables.dart';

part 'database.g.dart';

/// Plania is single-user. Every row belongs to this id.
const String kLocalUserId = 'local';

/// Tables that carry a user_id column (including tables of 1.x modules that were removed,
/// whose rows are kept untouched in the file).
const List<String> _userTables = [
  'tasks',
  'notes',
  'calendar_events',
  'habits',
  'journal_entries',
  'expenses',
  'budgets',
  'goals',
  'focus_sessions',
  'health_logs',
  'app_files',
  'app_notifications',
  'chat_messages',
];

@DriftDatabase(
  tables: [
    Tasks,
    Notes,
    CalendarEvents,
    Habits,
    HabitLogs,
    JournalEntries,
    Expenses,
    RecurringEntries,
    Budgets,
    Goals,
    FocusSessions,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? driftDatabase(name: 'lifeos_ai'));

  @override
  int get schemaVersion => 6;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) => m.createAll(),
        onUpgrade: (Migrator m, int from, int to) async {
          if (from < 2) {
            await m.addColumn(tasks, tasks.recurrence);
            await m.addColumn(tasks, tasks.reminderAt);
          }
          if (from < 3) {
            await m.addColumn(expenses, expenses.receiptPath);
            await m.addColumn(goals, goals.visionImagePath);
            await m.addColumn(goals, goals.visionColor);
          }
          if (from < 4) {
            await m.addColumn(calendarEvents, calendarEvents.isTimeBlock);
            await m.addColumn(calendarEvents, calendarEvents.color);
          }
          if (from < 5) {
            await m.addColumn(notes, notes.checklist);
            await m.createTable(habitLogs);
            await _adoptRowsForLocalUser();
            await _seedHabitLogsFromStreaks();
            // 1.x stored local accounts with password hashes. 2.0 has no accounts.
            await customStatement('DROP TABLE IF EXISTS users');
          }
          if (from < 6) {
            // 2.1: recurring expenses and income. Existing rows are untouched.
            await m.addColumn(expenses, expenses.recurringId);
            await m.createTable(recurringEntries);
          }
        },
      );

  Future<Set<String>> _existingTables() async {
    final rows = await customSelect("SELECT name FROM sqlite_master WHERE type = 'table'").get();
    return {for (final r in rows) r.read<String>('name')};
  }

  /// 1.x kept data per signed-in account. Assign every row to the single local user.
  Future<void> _adoptRowsForLocalUser() async {
    final existing = await _existingTables();
    for (final t in _userTables) {
      if (existing.contains(t)) {
        await customStatement('UPDATE $t SET user_id = ?', [kLocalUserId]);
      }
    }
  }

  /// 1.x only kept a streak counter and the last completion. Rebuild the matching day logs
  /// so streaks carry over.
  Future<void> _seedHabitLogsFromStreaks() async {
    final rows = await customSelect(
      'SELECT id, current_streak, last_completed_at FROM habits WHERE last_completed_at IS NOT NULL',
    ).get();
    final created = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    for (final r in rows) {
      final id = r.read<String>('id');
      final streak = r.read<int>('current_streak');
      final last = r.read<DateTime>('last_completed_at');
      final days = streak < 1 ? 1 : (streak > 3650 ? 3650 : streak);
      for (var i = 0; i < days; i++) {
        await customStatement(
          'INSERT OR IGNORE INTO habit_logs (habit_id, day, created_at) VALUES (?, ?, ?)',
          [id, dayKey(addDays(last, -i)), created],
        );
      }
    }
  }
}
