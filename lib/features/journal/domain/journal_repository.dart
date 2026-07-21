import 'journal_entry.dart';

abstract class JournalRepository {
  Stream<List<JournalEntry>> watchEntries(String userId);

  Future<List<JournalEntry>> getEntries(String userId);

  Future<JournalEntry> createEntry(String userId, JournalEntry entry);

  Future<JournalEntry> updateEntry(JournalEntry entry);

  Future<void> deleteEntry(String entryId);

  Future<List<JournalEntry>> searchEntries(String userId, String query);
}
