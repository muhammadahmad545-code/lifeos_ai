class CalendarEvent {
  const CalendarEvent({
    required this.id,
    required this.title,
    this.description,
    required this.startTime,
    required this.endTime,
    this.location,
    this.isAllDay = false,
    this.isRecurring = false,
    this.isTimeBlock = false,
    this.color,
    this.createdAt,
  });

  final String id;
  final String title;
  final String? description;
  final DateTime startTime;
  final DateTime endTime;
  final String? location;
  final bool isAllDay;
  final bool isRecurring;
  final bool isTimeBlock;
  final String? color;
  final DateTime? createdAt;

  CalendarEvent copyWith({
    String? id,
    String? title,
    String? description,
    DateTime? startTime,
    DateTime? endTime,
    String? location,
    bool? isAllDay,
    bool? isRecurring,
    bool? isTimeBlock,
    String? color,
    DateTime? createdAt,
  }) {
    return CalendarEvent(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      location: location ?? this.location,
      isAllDay: isAllDay ?? this.isAllDay,
      isRecurring: isRecurring ?? this.isRecurring,
      isTimeBlock: isTimeBlock ?? this.isTimeBlock,
      color: color ?? this.color,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
