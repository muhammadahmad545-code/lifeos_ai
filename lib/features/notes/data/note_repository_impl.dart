import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/utils/id_generator.dart';
import '../../../core/utils/list_codec.dart';
import '../domain/note.dart';
import '../domain/note_repository.dart';

class NoteRepositoryImpl implements NoteRepository {
  NoteRepositoryImpl(this._db);

  final AppDatabase _db;

  @override
  Stream<List<Note>> watchNotes(String userId) {
    final query = (_db.select(_db.notes)
          ..where((Notes tbl) => tbl.userId.equals(userId))
          ..orderBy(<OrderingTerm Function(Notes)>[
            (Notes tbl) => OrderingTerm.desc(tbl.isPinned),
            (Notes tbl) => OrderingTerm.desc(tbl.updatedAt),
          ]))
        .watch();
    return query.map((List<NoteRow> rows) => rows.map(_map).toList());
  }

  @override
  Future<List<Note>> getNotes(String userId) async {
    final List<NoteRow> rows = await (_db.select(_db.notes)
          ..where((Notes tbl) => tbl.userId.equals(userId))
          ..orderBy(<OrderingTerm Function(Notes)>[
            (Notes tbl) => OrderingTerm.desc(tbl.isPinned),
            (Notes tbl) => OrderingTerm.desc(tbl.updatedAt),
          ]))
        .get();
    return rows.map(_map).toList();
  }

  @override
  Future<Note> createNote(String userId, Note note) async {
    final DateTime now = DateTime.now();
    final String id = note.id.isEmpty ? IdGenerator.next() : note.id;
    await _db.into(_db.notes).insert(
          NotesCompanion.insert(
            id: id,
            userId: userId,
            title: note.title,
            content: note.content,
            color: Value<String?>(note.color),
            tags: Value<String>(ListCodec.encode(note.tags)),
            folder: Value<String?>(note.folder),
            isPinned: Value<bool>(note.isPinned),
            isFavorite: Value<bool>(note.isFavorite),
            isArchived: Value<bool>(note.isArchived),
            createdAt: now,
            updatedAt: now,
          ),
        );
    final NoteRow row = await (_db.select(_db.notes)..where((Notes tbl) => tbl.id.equals(id))).getSingle();
    return _map(row);
  }

  @override
  Future<Note> updateNote(Note note) async {
    await (_db.update(_db.notes)..where((Notes tbl) => tbl.id.equals(note.id))).write(
          NotesCompanion(
            title: Value<String>(note.title),
            content: Value<String>(note.content),
            color: Value<String?>(note.color),
            tags: Value<String>(ListCodec.encode(note.tags)),
            folder: Value<String?>(note.folder),
            isPinned: Value<bool>(note.isPinned),
            isFavorite: Value<bool>(note.isFavorite),
            isArchived: Value<bool>(note.isArchived),
            updatedAt: Value<DateTime>(DateTime.now()),
          ),
        );
    final NoteRow row = await (_db.select(_db.notes)..where((Notes tbl) => tbl.id.equals(note.id))).getSingle();
    return _map(row);
  }

  @override
  Future<void> deleteNote(String noteId) async {
    await (_db.delete(_db.notes)..where((Notes tbl) => tbl.id.equals(noteId))).go();
  }

  @override
  Future<List<Note>> searchNotes(String userId, String query) async {
    final String q = query.trim().toLowerCase();
    final List<Note> all = await getNotes(userId);
    if (q.isEmpty) {
      return all;
    }
    return all
        .where(
          (Note note) =>
              note.title.toLowerCase().contains(q) ||
              note.content.toLowerCase().contains(q) ||
              (note.folder?.toLowerCase().contains(q) ?? false) ||
              note.tags.any((String tag) => tag.toLowerCase().contains(q)),
        )
        .toList();
  }

  @override
  Future<void> togglePin(String noteId) async {
    final NoteRow row = await (_db.select(_db.notes)..where((Notes tbl) => tbl.id.equals(noteId))).getSingle();
    await (_db.update(_db.notes)..where((Notes tbl) => tbl.id.equals(noteId))).write(
          NotesCompanion(
            isPinned: Value<bool>(!row.isPinned),
            updatedAt: Value<DateTime>(DateTime.now()),
          ),
        );
  }

  @override
  Future<void> toggleFavorite(String noteId) async {
    final NoteRow row = await (_db.select(_db.notes)..where((Notes tbl) => tbl.id.equals(noteId))).getSingle();
    await (_db.update(_db.notes)..where((Notes tbl) => tbl.id.equals(noteId))).write(
          NotesCompanion(
            isFavorite: Value<bool>(!row.isFavorite),
            updatedAt: Value<DateTime>(DateTime.now()),
          ),
        );
  }

  @override
  Future<void> archiveNote(String noteId, {required bool archived}) async {
    await (_db.update(_db.notes)..where((Notes tbl) => tbl.id.equals(noteId))).write(
          NotesCompanion(
            isArchived: Value<bool>(archived),
            updatedAt: Value<DateTime>(DateTime.now()),
          ),
        );
  }

  Note _map(NoteRow row) {
    return Note(
      id: row.id,
      title: row.title,
      content: row.content,
      color: row.color,
      tags: ListCodec.decode(row.tags),
      folder: row.folder,
      isPinned: row.isPinned,
      isFavorite: row.isFavorite,
      isArchived: row.isArchived,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }
}
