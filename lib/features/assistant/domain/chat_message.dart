class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    this.createdAt,
  });

  final String id;
  final String role;
  final String content;
  final DateTime? createdAt;

  bool get isUser => role == 'user';
  bool get isAssistant => role == 'assistant';

  ChatMessage copyWith({
    String? id,
    String? role,
    String? content,
    DateTime? createdAt,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      role: role ?? this.role,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
