class Habit {
  const Habit({
    required this.id,
    required this.name,
    this.description,
    required this.frequency,
    this.color,
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.xp = 0,
    this.level = 1,
    this.isActive = true,
    this.lastCompletedAt,
    this.createdAt,
  });

  final String id;
  final String name;
  final String? description;
  final HabitFrequency frequency;
  final String? color;
  final int currentStreak;
  final int longestStreak;
  final int xp;
  final int level;
  final bool isActive;
  final DateTime? lastCompletedAt;
  final DateTime? createdAt;

  Habit copyWith({
    String? id,
    String? name,
    String? description,
    HabitFrequency? frequency,
    String? color,
    int? currentStreak,
    int? longestStreak,
    int? xp,
    int? level,
    bool? isActive,
    DateTime? lastCompletedAt,
    DateTime? createdAt,
  }) {
    return Habit(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      frequency: frequency ?? this.frequency,
      color: color ?? this.color,
      currentStreak: currentStreak ?? this.currentStreak,
      longestStreak: longestStreak ?? this.longestStreak,
      xp: xp ?? this.xp,
      level: level ?? this.level,
      isActive: isActive ?? this.isActive,
      lastCompletedAt: lastCompletedAt ?? this.lastCompletedAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

enum HabitFrequency { daily, weekly, monthly }

extension HabitFrequencyX on HabitFrequency {
  static HabitFrequency fromIndex(int value) {
    if (value < 0 || value >= HabitFrequency.values.length) {
      return HabitFrequency.daily;
    }
    return HabitFrequency.values[value];
  }
}
