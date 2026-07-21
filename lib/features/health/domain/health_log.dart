enum HealthLogType { water, sleep, weight, workout, medicine }

extension HealthLogTypeX on HealthLogType {
  String get storageValue => name;

  static HealthLogType fromStorage(String value) {
    return HealthLogType.values.firstWhere(
      (HealthLogType type) => type.name == value,
      orElse: () => HealthLogType.water,
    );
  }
}

class HealthLog {
  const HealthLog({
    required this.id,
    required this.type,
    required this.value,
    this.unit = '',
    this.note,
    required this.loggedAt,
  });

  final String id;
  final HealthLogType type;
  final double value;
  final String unit;
  final String? note;
  final DateTime loggedAt;

  HealthLog copyWith({
    String? id,
    HealthLogType? type,
    double? value,
    String? unit,
    String? note,
    DateTime? loggedAt,
  }) {
    return HealthLog(
      id: id ?? this.id,
      type: type ?? this.type,
      value: value ?? this.value,
      unit: unit ?? this.unit,
      note: note ?? this.note,
      loggedAt: loggedAt ?? this.loggedAt,
    );
  }
}
