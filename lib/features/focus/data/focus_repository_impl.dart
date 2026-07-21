import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/utils/id_generator.dart';
import '../domain/focus_repository.dart';
import '../domain/focus_session.dart';

class FocusRepositoryImpl implements FocusRepository {
  FocusRepositoryImpl(this._db);

  final AppDatabase _db;

  @override
  Stream<List<FocusSession>> watchSessions(String userId) {
    final query = (_db.select(_db.focusSessions)
          ..where((FocusSessions tbl) => tbl.userId.equals(userId))
          ..orderBy(<OrderingTerm Function(FocusSessions)>[
            (FocusSessions tbl) => OrderingTerm.desc(tbl.startedAt),
          ]))
        .watch();
    return query.map((List<FocusSessionRow> rows) => rows.map(_map).toList());
  }

  @override
  Future<FocusSession> saveSession(String userId, FocusSession session) async {
    final String id = session.id.isEmpty ? IdGenerator.next() : session.id;
    final FocusSessionRow? existing = await (_db.select(_db.focusSessions)
          ..where((FocusSessions tbl) => tbl.id.equals(id)))
        .getSingleOrNull();

    if (existing != null) {
      await (_db.update(_db.focusSessions)..where((FocusSessions tbl) => tbl.id.equals(id))).write(
            FocusSessionsCompanion(
              durationMinutes: Value<int>(session.durationMinutes),
              completedMinutes: Value<int>(session.completedMinutes),
              mode: Value<String>(session.mode),
              completed: Value<bool>(session.completed),
              startedAt: Value<DateTime>(session.startedAt),
              endedAt: Value<DateTime?>(session.endedAt),
            ),
          );
    } else {
      await _db.into(_db.focusSessions).insert(
            FocusSessionsCompanion.insert(
              id: id,
              userId: userId,
              durationMinutes: session.durationMinutes,
              completedMinutes: Value<int>(session.completedMinutes),
              mode: Value<String>(session.mode),
              completed: Value<bool>(session.completed),
              startedAt: session.startedAt,
              endedAt: Value<DateTime?>(session.endedAt),
            ),
          );
    }

    final FocusSessionRow row =
        await (_db.select(_db.focusSessions)..where((FocusSessions tbl) => tbl.id.equals(id))).getSingle();
    return _map(row);
  }

  @override
  Future<FocusStats> getStats(String userId) async {
    final List<FocusSessionRow> rows = await (_db.select(_db.focusSessions)
          ..where((FocusSessions tbl) => tbl.userId.equals(userId)))
        .get();

    int totalMinutes = 0;
    int completedCount = 0;
    for (final FocusSessionRow row in rows) {
      totalMinutes += row.completedMinutes;
      if (row.completed) {
        completedCount += 1;
      }
    }
    return FocusStats(totalMinutes: totalMinutes, completedCount: completedCount);
  }

  FocusSession _map(FocusSessionRow row) {
    return FocusSession(
      id: row.id,
      durationMinutes: row.durationMinutes,
      completedMinutes: row.completedMinutes,
      mode: row.mode,
      completed: row.completed,
      startedAt: row.startedAt,
      endedAt: row.endedAt,
    );
  }
}
