import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/utils/id_generator.dart';
import '../domain/health_log.dart';
import '../domain/health_repository.dart';

class HealthRepositoryImpl implements HealthRepository {
  HealthRepositoryImpl(this._db);

  final AppDatabase _db;

  @override
  Stream<List<HealthLog>> watchByType(String userId, HealthLogType type) {
    final query = (_db.select(_db.healthLogs)
          ..where(
            (HealthLogs tbl) => tbl.userId.equals(userId) & tbl.type.equals(type.storageValue),
          )
          ..orderBy(<OrderingTerm Function(HealthLogs)>[
            (HealthLogs tbl) => OrderingTerm.desc(tbl.loggedAt),
          ]))
        .watch();
    return query.map((List<HealthLogRow> rows) => rows.map(_map).toList());
  }

  @override
  Future<HealthLog> addLog(String userId, HealthLog log) async {
    final String id = log.id.isEmpty ? IdGenerator.next() : log.id;
    await _db.into(_db.healthLogs).insert(
          HealthLogsCompanion.insert(
            id: id,
            userId: userId,
            type: log.type.storageValue,
            value: log.value,
            unit: Value<String>(log.unit),
            note: Value<String?>(log.note),
            loggedAt: log.loggedAt,
          ),
        );
    final HealthLogRow row =
        await (_db.select(_db.healthLogs)..where((HealthLogs tbl) => tbl.id.equals(id))).getSingle();
    return _map(row);
  }

  @override
  Future<void> deleteLog(String logId) async {
    await (_db.delete(_db.healthLogs)..where((HealthLogs tbl) => tbl.id.equals(logId))).go();
  }

  @override
  Future<double> getTodayWaterMl(String userId) async {
    final DateTime now = DateTime.now();
    final DateTime start = DateTime(now.year, now.month, now.day);
    final DateTime end = start.add(const Duration(days: 1));
    final List<HealthLogRow> rows = await (_db.select(_db.healthLogs)
          ..where(
            (HealthLogs tbl) =>
                tbl.userId.equals(userId) &
                tbl.type.equals(HealthLogType.water.storageValue) &
                tbl.loggedAt.isBiggerOrEqualValue(start) &
                tbl.loggedAt.isSmallerThanValue(end),
          ))
        .get();
    double total = 0;
    for (final HealthLogRow row in rows) {
      total += row.value;
    }
    return total;
  }

  @override
  Future<double?> getLatestWeight(String userId) async {
    final HealthLogRow? row = await (_db.select(_db.healthLogs)
          ..where(
            (HealthLogs tbl) =>
                tbl.userId.equals(userId) & tbl.type.equals(HealthLogType.weight.storageValue),
          )
          ..orderBy(<OrderingTerm Function(HealthLogs)>[
            (HealthLogs tbl) => OrderingTerm.desc(tbl.loggedAt),
          ])
          ..limit(1))
        .getSingleOrNull();
    return row?.value;
  }

  HealthLog _map(HealthLogRow row) {
    return HealthLog(
      id: row.id,
      type: HealthLogTypeX.fromStorage(row.type),
      value: row.value,
      unit: row.unit,
      note: row.note,
      loggedAt: row.loggedAt,
    );
  }
}
