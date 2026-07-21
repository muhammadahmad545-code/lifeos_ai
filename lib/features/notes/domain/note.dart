class Note {
  const Note({
    required this.id,
    required this.title,
    required this.content,
    this.color,
    this.tags = const <String>[],
    this.folder,
    this.isPinned = false,
    this.isFavorite = false,
    this.isArchived = false,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String title;
  final String content;
  final String? color;
  final List<String> tags;
  final String? folder;
  final bool isPinned;
  final bool isFavorite;
  final bool isArchived;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Note copyWith({
    String? id,
    String? title,
    String? content,
    String? color,
    List<String>? tags,
    String? folder,
    bool? isPinned,
    bool? isFavorite,
    bool? isArchived,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Note(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      color: color ?? this.color,
      tags: tags ?? this.tags,
      folder: folder ?? this.folder,
      isPinned: isPinned ?? this.isPinned,
      isFavorite: isFavorite ?? this.isFavorite,
      isArchived: isArchived ?? this.isArchived,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
