import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/utils/id_generator.dart';
import '../../../core/utils/list_codec.dart';
import '../domain/journal_entry.dart';
import '../domain/journal_repository.dart';

class JournalRepositoryImpl implements JournalRepository {
  JournalRepositoryImpl(this._db);

  final AppDatabase _db;

  @override
  Stream<List<JournalEntry>> watchEntries(String userId) {
    final query = (_db.select(_db.journalEntries)
          ..where((JournalEntries tbl) => tbl.userId.equals(userId))
          ..orderBy(<OrderingTerm Function(JournalEntries)>[
            (JournalEntries tbl) => OrderingTerm.desc(tbl.createdAt),
          ]))
        .watch();
    return query.map((List<JournalEntryRow> rows) => rows.map(_map).toList());
  }

  @override
  Future<List<JournalEntry>> getEntries(String userId) async {
    final List<JournalEntryRow> rows = await (_db.select(_db.journalEntries)
          ..where((JournalEntries tbl) => tbl.userId.equals(userId))
          ..orderBy(<OrderingTerm Function(JournalEntries)>[
            (JournalEntries tbl) => OrderingTerm.desc(tbl.createdAt),
          ]))
        .get();
    return rows.map(_map).toList();
  }

  @override
  Future<JournalEntry> createEntry(String userId, JournalEntry entry) async {
    final DateTime now = DateTime.now();
    final String id = entry.id.isEmpty ? IdGenerator.next() : entry.id;
    await _db.into(_db.journalEntries).insert(
          JournalEntriesCompanion.insert(
            id: id,
            userId: userId,
            title: entry.title,
            content: entry.content,
            mood: Value<String?>(entry.mood),
            tags: Value<String>(ListCodec.encode(entry.tags)),
            createdAt: entry.createdAt ?? now,
            updatedAt: entry.updatedAt ?? now,
          ),
        );
    final JournalEntryRow row =
        await (_db.select(_db.journalEntries)..where((JournalEntries tbl) => tbl.id.equals(id))).getSingle();
    return _map(row);
  }

  @override
  Future<JournalEntry> updateEntry(JournalEntry entry) async {
    await (_db.update(_db.journalEntries)..where((JournalEntries tbl) => tbl.id.equals(entry.id))).write(
          JournalEntriesCompanion(
            title: Value<String>(entry.title),
            content: Value<String>(entry.content),
            mood: Value<String?>(entry.mood),
            tags: Value<String>(ListCodec.encode(entry.tags)),
            updatedAt: Value<DateTime>(DateTime.now()),
          ),
        );
    final JournalEntryRow row =
        await (_db.select(_db.journalEntries)..where((JournalEntries tbl) => tbl.id.equals(entry.id))).getSingle();
    return _map(row);
  }

  @override
  Future<void> deleteEntry(String entryId) async {
    await (_db.delete(_db.journalEntries)..where((JournalEntries tbl) => tbl.id.equals(entryId))).go();
  }

  @override
  Future<List<JournalEntry>> searchEntries(String userId, String query) async {
    final String q = query.trim().toLowerCase();
    final List<JournalEntry> all = await getEntries(userId);
    if (q.isEmpty) {
      return all;
    }
    return all
        .where(
          (JournalEntry entry) =>
              entry.title.toLowerCase().contains(q) ||
              entry.content.toLowerCase().contains(q) ||
              (entry.mood?.toLowerCase().contains(q) ?? false) ||
              entry.tags.any((String tag) => tag.toLowerCase().contains(q)),
        )
        .toList();
  }

  JournalEntry _map(JournalEntryRow row) {
    return JournalEntry(
      id: row.id,
      title: row.title,
      content: row.content,
      mood: row.mood,
      tags: ListCodec.decode(row.tags),
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }
}
