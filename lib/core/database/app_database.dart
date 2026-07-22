import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'tables.dart';

export 'tables.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    Users,
    Tasks,
    Notes,
    CalendarEvents,
    Habits,
    JournalEntries,
    Expenses,
    Goals,
    HealthLogs,
    FocusSessions,
    AppFiles,
    AppNotifications,
    ChatMessages,
    Budgets,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) async {
          await m.createAll();
        },
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
        },
      );

  static QueryExecutor _openConnection() {
    return driftDatabase(name: 'lifeos_ai');
  }
}
