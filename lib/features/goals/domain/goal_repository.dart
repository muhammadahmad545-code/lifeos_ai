import 'goal.dart';

abstract class GoalRepository {
  Stream<List<Goal>> watchGoals(String userId);

  Future<List<Goal>> getGoals(String userId);

  Future<Goal> createGoal(String userId, Goal goal);

  Future<Goal> updateGoal(Goal goal);

  Future<void> deleteGoal(String goalId);

  Future<Goal> updateProgress(String goalId, double progress);
}
