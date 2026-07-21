import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/utils/id_generator.dart';
import '../domain/assistant_repository.dart';
import '../domain/chat_message.dart';

class AssistantRepositoryImpl implements AssistantRepository {
  AssistantRepositoryImpl(this._db);

  final AppDatabase _db;

  @override
  Stream<List<ChatMessage>> watchMessages(String userId) {
    final query = (_db.select(_db.chatMessages)
          ..where((ChatMessages tbl) => tbl.userId.equals(userId))
          ..orderBy(<OrderingTerm Function(ChatMessages)>[
            (ChatMessages tbl) => OrderingTerm(expression: tbl.createdAt),
          ]))
        .watch();
    return query.map((List<ChatMessageRow> rows) => rows.map(_map).toList());
  }

  @override
  Future<ChatMessage> addMessage(String userId, ChatMessage message) async {
    final String id = message.id.isEmpty ? IdGenerator.next() : message.id;
    final DateTime now = DateTime.now();
    await _db.into(_db.chatMessages).insert(
          ChatMessagesCompanion.insert(
            id: id,
            userId: userId,
            role: message.role,
            content: message.content,
            createdAt: message.createdAt ?? now,
          ),
        );
    final ChatMessageRow row =
        await (_db.select(_db.chatMessages)..where((ChatMessages tbl) => tbl.id.equals(id))).getSingle();
    return _map(row);
  }

  @override
  Future<void> clearHistory(String userId) async {
    await (_db.delete(_db.chatMessages)..where((ChatMessages tbl) => tbl.userId.equals(userId))).go();
  }

  ChatMessage _map(ChatMessageRow row) {
    return ChatMessage(
      id: row.id,
      role: row.role,
      content: row.content,
      createdAt: row.createdAt,
    );
  }
}
