class Goal {
  const Goal({
    required this.id,
    required this.title,
    this.description,
    required this.targetDate,
    this.category,
    this.progress = 0,
    this.milestones = const <String>[],
    this.isCompleted = false,
    this.visionImagePath,
    this.visionColor,
    this.createdAt,
  });

  final String id;
  final String title;
  final String? description;
  final DateTime targetDate;
  final String? category;
  final double progress;
  final List<String> milestones;
  final bool isCompleted;
  final String? visionImagePath;
  final String? visionColor;
  final DateTime? createdAt;

  Goal copyWith({
    String? id,
    String? title,
    String? description,
    DateTime? targetDate,
    String? category,
    double? progress,
    List<String>? milestones,
    bool? isCompleted,
    String? visionImagePath,
    String? visionColor,
    DateTime? createdAt,
    bool clearVisionImage = false,
  }) {
    return Goal(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      targetDate: targetDate ?? this.targetDate,
      category: category ?? this.category,
      progress: progress ?? this.progress,
      milestones: milestones ?? this.milestones,
      isCompleted: isCompleted ?? this.isCompleted,
      visionImagePath: clearVisionImage ? null : visionImagePath ?? this.visionImagePath,
      visionColor: visionColor ?? this.visionColor,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
