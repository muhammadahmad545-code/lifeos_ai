import 'habit.dart';

abstract class HabitRepository {
  Stream<List<Habit>> watchHabits(String userId);

  Future<List<Habit>> getHabits(String userId);

  Future<Habit> createHabit(String userId, Habit habit);

  Future<Habit> updateHabit(Habit habit);

  Future<void> deleteHabit(String habitId);

  Future<Habit> logHabitCompletion(String habitId, DateTime date);
}
