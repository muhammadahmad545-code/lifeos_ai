import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/utils/id_generator.dart';
import '../domain/calendar_event.dart';
import '../domain/calendar_repository.dart';

class CalendarRepositoryImpl implements CalendarRepository {
  CalendarRepositoryImpl(this._db);

  final AppDatabase _db;

  @override
  Stream<List<CalendarEvent>> watchEvents(String userId) {
    final query = (_db.select(_db.calendarEvents)
          ..where((CalendarEvents tbl) => tbl.userId.equals(userId))
          ..orderBy(<OrderingTerm Function(CalendarEvents)>[
            (CalendarEvents tbl) => OrderingTerm(expression: tbl.startTime),
          ]))
        .watch();
    return query.map((List<CalendarEventRow> rows) => rows.map(_map).toList());
  }

  @override
  Future<List<CalendarEvent>> getEventsForDay(String userId, DateTime day) async {
    final DateTime start = DateTime(day.year, day.month, day.day);
    final DateTime end = start.add(const Duration(days: 1));
    return getEventsInRange(userId, start, end);
  }

  @override
  Future<List<CalendarEvent>> getEventsInRange(String userId, DateTime start, DateTime end) async {
    final List<CalendarEventRow> rows = await (_db.select(_db.calendarEvents)
          ..where(
            (CalendarEvents tbl) =>
                tbl.userId.equals(userId) &
                tbl.startTime.isBiggerOrEqualValue(start) &
                tbl.startTime.isSmallerThanValue(end),
          )
          ..orderBy(<OrderingTerm Function(CalendarEvents)>[
            (CalendarEvents tbl) => OrderingTerm(expression: tbl.startTime),
          ]))
        .get();
    return rows.map(_map).toList();
  }

  @override
  Future<CalendarEvent> createEvent(String userId, CalendarEvent event) async {
    final String id = event.id.isEmpty ? IdGenerator.next() : event.id;
    final DateTime now = DateTime.now();
    await _db.into(_db.calendarEvents).insert(
          CalendarEventsCompanion.insert(
            id: id,
            userId: userId,
            title: event.title,
            description: Value<String?>(event.description),
            startTime: event.startTime,
            endTime: event.endTime,
            location: Value<String?>(event.location),
            isAllDay: Value<bool>(event.isAllDay),
            isRecurring: Value<bool>(event.isRecurring),
            isTimeBlock: Value<bool>(event.isTimeBlock),
            color: Value<String?>(event.color),
            createdAt: event.createdAt ?? now,
          ),
        );
    final CalendarEventRow row =
        await (_db.select(_db.calendarEvents)..where((CalendarEvents tbl) => tbl.id.equals(id))).getSingle();
    return _map(row);
  }

  @override
  Future<CalendarEvent> updateEvent(CalendarEvent event) async {
    await (_db.update(_db.calendarEvents)..where((CalendarEvents tbl) => tbl.id.equals(event.id))).write(
          CalendarEventsCompanion(
            title: Value<String>(event.title),
            description: Value<String?>(event.description),
            startTime: Value<DateTime>(event.startTime),
            endTime: Value<DateTime>(event.endTime),
            location: Value<String?>(event.location),
            isAllDay: Value<bool>(event.isAllDay),
            isRecurring: Value<bool>(event.isRecurring),
            isTimeBlock: Value<bool>(event.isTimeBlock),
            color: Value<String?>(event.color),
          ),
        );
    final CalendarEventRow row =
        await (_db.select(_db.calendarEvents)..where((CalendarEvents tbl) => tbl.id.equals(event.id))).getSingle();
    return _map(row);
  }

  @override
  Future<void> deleteEvent(String eventId) async {
    await (_db.delete(_db.calendarEvents)..where((CalendarEvents tbl) => tbl.id.equals(eventId))).go();
  }

  CalendarEvent _map(CalendarEventRow row) {
    return CalendarEvent(
      id: row.id,
      title: row.title,
      description: row.description,
      startTime: row.startTime,
      endTime: row.endTime,
      location: row.location,
      isAllDay: row.isAllDay,
      isRecurring: row.isRecurring,
      isTimeBlock: row.isTimeBlock,
      color: row.color,
      createdAt: row.createdAt,
    );
  }
}
