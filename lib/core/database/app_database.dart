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
  int get schemaVersion => 1;

  static QueryExecutor _openConnection() {
    return driftDatabase(name: 'lifeos_ai');
  }
}
