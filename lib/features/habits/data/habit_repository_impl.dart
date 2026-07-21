import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/utils/id_generator.dart';
import '../domain/habit.dart';
import '../domain/habit_repository.dart';

class HabitRepositoryImpl implements HabitRepository {
  HabitRepositoryImpl(this._db);

  final AppDatabase _db;

  static const int _xpPerCompletion = 10;
  static const int _xpPerLevel = 100;

  @override
  Stream<List<Habit>> watchHabits(String userId) {
    final query = (_db.select(_db.habits)
          ..where((Habits tbl) => tbl.userId.equals(userId))
          ..orderBy(<OrderingTerm Function(Habits)>[
            (Habits tbl) => OrderingTerm.desc(tbl.isActive),
            (Habits tbl) => OrderingTerm.desc(tbl.currentStreak),
            (Habits tbl) => OrderingTerm.desc(tbl.createdAt),
          ]))
        .watch();
    return query.map((List<HabitRow> rows) => rows.map(_map).toList());
  }

  @override
  Future<List<Habit>> getHabits(String userId) async {
    final List<HabitRow> rows = await (_db.select(_db.habits)
          ..where((Habits tbl) => tbl.userId.equals(userId))
          ..orderBy(<OrderingTerm Function(Habits)>[
            (Habits tbl) => OrderingTerm.desc(tbl.isActive),
            (Habits tbl) => OrderingTerm.desc(tbl.currentStreak),
          ]))
        .get();
    return rows.map(_map).toList();
  }

  @override
  Future<Habit> createHabit(String userId, Habit habit) async {
    final String id = habit.id.isEmpty ? IdGenerator.next() : habit.id;
    final DateTime now = DateTime.now();
    await _db.into(_db.habits).insert(
          HabitsCompanion.insert(
            id: id,
            userId: userId,
            name: habit.name,
            description: Value<String?>(habit.description),
            frequency: Value<int>(habit.frequency.index),
            color: Value<String?>(habit.color),
            currentStreak: Value<int>(habit.currentStreak),
            longestStreak: Value<int>(habit.longestStreak),
            xp: Value<int>(habit.xp),
            level: Value<int>(habit.level),
            isActive: Value<bool>(habit.isActive),
            lastCompletedAt: Value<DateTime?>(habit.lastCompletedAt),
            createdAt: habit.createdAt ?? now,
          ),
        );
    final HabitRow row = await (_db.select(_db.habits)..where((Habits tbl) => tbl.id.equals(id))).getSingle();
    return _map(row);
  }

  @override
  Future<Habit> updateHabit(Habit habit) async {
    await (_db.update(_db.habits)..where((Habits tbl) => tbl.id.equals(habit.id))).write(
          HabitsCompanion(
            name: Value<String>(habit.name),
            description: Value<String?>(habit.description),
            frequency: Value<int>(habit.frequency.index),
            color: Value<String?>(habit.color),
            currentStreak: Value<int>(habit.currentStreak),
            longestStreak: Value<int>(habit.longestStreak),
            xp: Value<int>(habit.xp),
            level: Value<int>(habit.level),
            isActive: Value<bool>(habit.isActive),
            lastCompletedAt: Value<DateTime?>(habit.lastCompletedAt),
          ),
        );
    final HabitRow row = await (_db.select(_db.habits)..where((Habits tbl) => tbl.id.equals(habit.id))).getSingle();
    return _map(row);
  }

  @override
  Future<void> deleteHabit(String habitId) async {
    await (_db.delete(_db.habits)..where((Habits tbl) => tbl.id.equals(habitId))).go();
  }

  @override
  Future<Habit> logHabitCompletion(String habitId, DateTime date) async {
    final HabitRow row = await (_db.select(_db.habits)..where((Habits tbl) => tbl.id.equals(habitId))).getSingle();
    final DateTime day = DateTime(date.year, date.month, date.day);

    if (row.lastCompletedAt != null) {
      final DateTime last = DateTime(
        row.lastCompletedAt!.year,
        row.lastCompletedAt!.month,
        row.lastCompletedAt!.day,
      );
      if (last == day) {
        return _map(row);
      }
    }

    int streak = 1;
    if (row.lastCompletedAt != null) {
      final DateTime last = DateTime(
        row.lastCompletedAt!.year,
        row.lastCompletedAt!.month,
        row.lastCompletedAt!.day,
      );
      final int gapDays = day.difference(last).inDays;
      if (gapDays == 1) {
        streak = row.currentStreak + 1;
      } else if (gapDays == 0) {
        return _map(row);
      }
    }

    final int xp = row.xp + _xpPerCompletion;
    final int level = (xp ~/ _xpPerLevel) + 1;
    final int longest = streak > row.longestStreak ? streak : row.longestStreak;

    await (_db.update(_db.habits)..where((Habits tbl) => tbl.id.equals(habitId))).write(
          HabitsCompanion(
            currentStreak: Value<int>(streak),
            longestStreak: Value<int>(longest),
            xp: Value<int>(xp),
            level: Value<int>(level),
            lastCompletedAt: Value<DateTime>(date),
          ),
        );

    final HabitRow updated =
        await (_db.select(_db.habits)..where((Habits tbl) => tbl.id.equals(habitId))).getSingle();
    return _map(updated);
  }

  Habit _map(HabitRow row) {
    return Habit(
      id: row.id,
      name: row.name,
      description: row.description,
      frequency: HabitFrequencyX.fromIndex(row.frequency),
      color: row.color,
      currentStreak: row.currentStreak,
      longestStreak: row.longestStreak,
      xp: row.xp,
      level: row.level,
      isActive: row.isActive,
      lastCompletedAt: row.lastCompletedAt,
      createdAt: row.createdAt,
    );
  }
}
