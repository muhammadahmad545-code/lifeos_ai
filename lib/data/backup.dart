import 'dart:convert';

import 'package:drift/drift.dart';

import 'database.dart';

/// Thrown when a file is not a Plania backup.
class BackupFormatException implements Exception {
  const BackupFormatException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// JSON export/import of everything the user created. Import merges by id, so importing
/// the same file twice does not duplicate anything.
class Backup {
  Backup(this.db);

  final AppDatabase db;

  static const int formatVersion = 1;

  Future<String> export() async {
    final data = <String, Object?>{
      'app': 'lifeos',
      'format': formatVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'tasks': [for (final r in await db.select(db.tasks).get()) r.toJson()],
      'notes': [for (final r in await db.select(db.notes).get()) r.toJson()],
      'events': [for (final r in await db.select(db.calendarEvents).get()) r.toJson()],
      'habits': [for (final r in await db.select(db.habits).get()) r.toJson()],
      'habitLogs': [for (final r in await db.select(db.habitLogs).get()) r.toJson()],
      'journal': [for (final r in await db.select(db.journalEntries).get()) r.toJson()],
      'expenses': [for (final r in await db.select(db.expenses).get()) r.toJson()],
      'budgets': [for (final r in await db.select(db.budgets).get()) r.toJson()],
      'goals': [for (final r in await db.select(db.goals).get()) r.toJson()],
      'focus': [for (final r in await db.select(db.focusSessions).get()) r.toJson()],
    };
    return const JsonEncoder.withIndent('  ').convert(data);
  }

  /// Parses and validates a backup. Returns the number of items per section.
  static Map<String, int> inspect(String json) {
    final data = _decode(json);
    return {
      for (final k in _sections)
        if (data[k] is List && (data[k] as List).isNotEmpty) k: (data[k] as List).length,
    };
  }

  static const _sections = [
    'tasks',
    'notes',
    'events',
    'habits',
    'habitLogs',
    'journal',
    'expenses',
    'budgets',
    'goals',
    'focus',
  ];

  static Map<String, dynamic> _decode(String json) {
    Object? data;
    try {
      data = jsonDecode(json);
    } catch (_) {
      throw const BackupFormatException('This file is not valid JSON.');
    }
    if (data is! Map || data['app'] != 'lifeos') {
      throw const BackupFormatException('This file is not a Plania backup.');
    }
    final format = data['format'];
    if (format is! int || format > formatVersion) {
      throw const BackupFormatException('This backup was made by a newer version of Plania.');
    }
    return Map<String, dynamic>.from(data);
  }

  /// Imports a backup in one transaction. Returns the number of rows written.
  Future<int> import(String json) async {
    final data = _decode(json);
    var count = 0;
    Future<void> rows<T extends Table, D extends Insertable<D>>(
      TableInfo<T, D> table,
      String key,
      D Function(Map<String, dynamic>) fromJson,
    ) async {
      final list = data[key];
      if (list is! List) return;
      for (final item in list) {
        if (item is! Map) continue;
        final D row;
        try {
          row = fromJson(Map<String, dynamic>.from(item));
        } catch (_) {
          throw BackupFormatException('A $key entry in this backup is damaged.');
        }
        await db.into(table).insertOnConflictUpdate(row);
        count++;
      }
    }

    await db.transaction(() async {
      await rows(db.tasks, 'tasks', TaskRow.fromJson);
      await rows(db.notes, 'notes', NoteRow.fromJson);
      await rows(db.calendarEvents, 'events', CalendarEventRow.fromJson);
      await rows(db.habits, 'habits', HabitRow.fromJson);
      await rows(db.habitLogs, 'habitLogs', HabitLogRow.fromJson);
      await rows(db.journalEntries, 'journal', JournalEntryRow.fromJson);
      await rows(db.expenses, 'expenses', ExpenseRow.fromJson);
      await rows(db.budgets, 'budgets', BudgetRow.fromJson);
      await rows(db.goals, 'goals', GoalRow.fromJson);
      await rows(db.focusSessions, 'focus', FocusSessionRow.fromJson);
    });
    return count;
  }
}
