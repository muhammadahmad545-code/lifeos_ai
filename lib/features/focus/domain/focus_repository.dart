import 'focus_session.dart';

abstract class FocusRepository {
  Stream<List<FocusSession>> watchSessions(String userId);

  Future<FocusSession> saveSession(String userId, FocusSession session);

  Future<FocusStats> getStats(String userId);
}
