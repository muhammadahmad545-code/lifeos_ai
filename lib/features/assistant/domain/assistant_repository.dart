import 'chat_message.dart';

abstract class AssistantRepository {
  Stream<List<ChatMessage>> watchMessages(String userId);

  Future<ChatMessage> addMessage(String userId, ChatMessage message);

  Future<void> clearHistory(String userId);
}
