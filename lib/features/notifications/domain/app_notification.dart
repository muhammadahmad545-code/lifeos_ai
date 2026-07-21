class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    this.type = 'general',
    this.isRead = false,
    this.createdAt,
    this.scheduledFor,
  });

  final String id;
  final String title;
  final String body;
  final String type;
  final bool isRead;
  final DateTime? createdAt;
  final DateTime? scheduledFor;

  AppNotification copyWith({
    String? id,
    String? title,
    String? body,
    String? type,
    bool? isRead,
    DateTime? createdAt,
    DateTime? scheduledFor,
  }) {
    return AppNotification(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      type: type ?? this.type,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
      scheduledFor: scheduledFor ?? this.scheduledFor,
    );
  }
}
