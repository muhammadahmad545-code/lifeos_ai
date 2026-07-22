class NoteVersion {
  const NoteVersion({
    required this.id,
    required this.noteId,
    required this.title,
    required this.content,
    required this.createdAt,
  });

  final String id;
  final String noteId;
  final String title;
  final String content;
  final DateTime createdAt;
}
