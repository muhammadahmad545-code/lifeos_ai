import 'health_log.dart';

abstract class HealthRepository {
  Stream<List<HealthLog>> watchByType(String userId, HealthLogType type);

  Future<HealthLog> addLog(String userId, HealthLog log);

  Future<void> deleteLog(String logId);

  Future<double> getTodayWaterMl(String userId);

  Future<double?> getLatestWeight(String userId);
}
