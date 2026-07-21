import 'note.dart';

abstract class NoteRepository {
  Stream<List<Note>> watchNotes(String userId);

  Future<List<Note>> getNotes(String userId);

  Future<Note> createNote(String userId, Note note);

  Future<Note> updateNote(Note note);

  Future<void> deleteNote(String noteId);

  Future<List<Note>> searchNotes(String userId, String query);

  Future<void> togglePin(String noteId);

  Future<void> toggleFavorite(String noteId);

  Future<void> archiveNote(String noteId, {required bool archived});
}
