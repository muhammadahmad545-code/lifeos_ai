import 'calendar_event.dart';

abstract class CalendarRepository {
  Stream<List<CalendarEvent>> watchEvents(String userId);

  Future<List<CalendarEvent>> getEventsForDay(String userId, DateTime day);

  Future<List<CalendarEvent>> getEventsInRange(String userId, DateTime start, DateTime end);

  Future<CalendarEvent> createEvent(String userId, CalendarEvent event);

  Future<CalendarEvent> updateEvent(CalendarEvent event);

  Future<void> deleteEvent(String eventId);
}
