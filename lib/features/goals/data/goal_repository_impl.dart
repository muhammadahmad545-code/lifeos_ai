import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/utils/id_generator.dart';
import '../../../core/utils/list_codec.dart';
import '../domain/goal.dart';
import '../domain/goal_repository.dart';

class GoalRepositoryImpl implements GoalRepository {
  GoalRepositoryImpl(this._db);

  final AppDatabase _db;

  @override
  Stream<List<Goal>> watchGoals(String userId) {
    final query = (_db.select(_db.goals)
          ..where((Goals tbl) => tbl.userId.equals(userId))
          ..orderBy(<OrderingTerm Function(Goals)>[
            (Goals tbl) => OrderingTerm(expression: tbl.isCompleted),
            (Goals tbl) => OrderingTerm(expression: tbl.targetDate),
          ]))
        .watch();
    return query.map((List<GoalRow> rows) => rows.map(_map).toList());
  }

  @override
  Future<List<Goal>> getGoals(String userId) async {
    final List<GoalRow> rows = await (_db.select(_db.goals)
          ..where((Goals tbl) => tbl.userId.equals(userId))
          ..orderBy(<OrderingTerm Function(Goals)>[
            (Goals tbl) => OrderingTerm(expression: tbl.isCompleted),
            (Goals tbl) => OrderingTerm(expression: tbl.targetDate),
          ]))
        .get();
    return rows.map(_map).toList();
  }

  @override
  Future<Goal> createGoal(String userId, Goal goal) async {
    final String id = goal.id.isEmpty ? IdGenerator.next() : goal.id;
    final DateTime now = DateTime.now();
    await _db.into(_db.goals).insert(
          GoalsCompanion.insert(
            id: id,
            userId: userId,
            title: goal.title,
            description: Value<String?>(goal.description),
            targetDate: goal.targetDate,
            category: Value<String?>(goal.category),
            progress: Value<double>(goal.progress.clamp(0.0, 1.0)),
            milestones: Value<String>(ListCodec.encode(goal.milestones)),
            isCompleted: Value<bool>(goal.isCompleted || goal.progress >= 1.0),
            createdAt: goal.createdAt ?? now,
          ),
        );
    final GoalRow row = await (_db.select(_db.goals)..where((Goals tbl) => tbl.id.equals(id))).getSingle();
    return _map(row);
  }

  @override
  Future<Goal> updateGoal(Goal goal) async {
    final double progress = goal.progress.clamp(0.0, 1.0);
    await (_db.update(_db.goals)..where((Goals tbl) => tbl.id.equals(goal.id))).write(
          GoalsCompanion(
            title: Value<String>(goal.title),
            description: Value<String?>(goal.description),
            targetDate: Value<DateTime>(goal.targetDate),
            category: Value<String?>(goal.category),
            progress: Value<double>(progress),
            milestones: Value<String>(ListCodec.encode(goal.milestones)),
            isCompleted: Value<bool>(goal.isCompleted || progress >= 1.0),
          ),
        );
    final GoalRow row = await (_db.select(_db.goals)..where((Goals tbl) => tbl.id.equals(goal.id))).getSingle();
    return _map(row);
  }

  @override
  Future<void> deleteGoal(String goalId) async {
    await (_db.delete(_db.goals)..where((Goals tbl) => tbl.id.equals(goalId))).go();
  }

  @override
  Future<Goal> updateProgress(String goalId, double progress) async {
    final double clamped = progress.clamp(0.0, 1.0);
    await (_db.update(_db.goals)..where((Goals tbl) => tbl.id.equals(goalId))).write(
          GoalsCompanion(
            progress: Value<double>(clamped),
            isCompleted: Value<bool>(clamped >= 1.0),
          ),
        );
    final GoalRow row = await (_db.select(_db.goals)..where((Goals tbl) => tbl.id.equals(goalId))).getSingle();
    return _map(row);
  }

  Goal _map(GoalRow row) {
    return Goal(
      id: row.id,
      title: row.title,
      description: row.description,
      targetDate: row.targetDate,
      category: row.category,
      progress: row.progress,
      milestones: ListCodec.decode(row.milestones),
      isCompleted: row.isCompleted,
      createdAt: row.createdAt,
    );
  }
}
