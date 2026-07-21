class JournalEntry {
  const JournalEntry({
    required this.id,
    required this.title,
    required this.content,
    this.mood,
    this.tags = const <String>[],
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String title;
  final String content;
  final String? mood;
  final List<String> tags;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  JournalEntry copyWith({
    String? id,
    String? title,
    String? content,
    String? mood,
    List<String>? tags,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return JournalEntry(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      mood: mood ?? this.mood,
      tags: tags ?? this.tags,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
