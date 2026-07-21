class FocusSession {
  const FocusSession({
    required this.id,
    required this.durationMinutes,
    this.completedMinutes = 0,
    this.mode = 'pomodoro',
    this.completed = false,
    required this.startedAt,
    this.endedAt,
  });

  final String id;
  final int durationMinutes;
  final int completedMinutes;
  final String mode;
  final bool completed;
  final DateTime startedAt;
  final DateTime? endedAt;

  FocusSession copyWith({
    String? id,
    int? durationMinutes,
    int? completedMinutes,
    String? mode,
    bool? completed,
    DateTime? startedAt,
    DateTime? endedAt,
  }) {
    return FocusSession(
      id: id ?? this.id,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      completedMinutes: completedMinutes ?? this.completedMinutes,
      mode: mode ?? this.mode,
      completed: completed ?? this.completed,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
    );
  }
}

class FocusStats {
  const FocusStats({
    required this.totalMinutes,
    required this.completedCount,
  });

  final int totalMinutes;
  final int completedCount;
}
