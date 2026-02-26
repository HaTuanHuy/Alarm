class Alarm {
  final int id;
  final int hour;
  final int minute;
  final String label;
  final bool enabled;
  final bool repeatDaily;
  final int? scheduledAtEpochMs;

  const Alarm({
    required this.id,
    required this.hour,
    required this.minute,
    required this.label,
    required this.enabled,
    required this.repeatDaily,
    this.scheduledAtEpochMs,
  });

  Alarm copyWith({
    int? id,
    int? hour,
    int? minute,
    String? label,
    bool? enabled,
    bool? repeatDaily,
    int? scheduledAtEpochMs,
    bool clearScheduledAt = false,
  }) {
    return Alarm(
      id: id ?? this.id,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
      label: label ?? this.label,
      enabled: enabled ?? this.enabled,
      repeatDaily: repeatDaily ?? this.repeatDaily,
      scheduledAtEpochMs: clearScheduledAt
          ? null
          : (scheduledAtEpochMs ?? this.scheduledAtEpochMs),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'hour': hour,
    'minute': minute,
    'label': label,
    'enabled': enabled,
    'repeatDaily': repeatDaily,
    'scheduledAtEpochMs': scheduledAtEpochMs,
  };

  static Alarm fromJson(Map<String, dynamic> j) => Alarm(
    id: j['id'] as int,
    hour: j['hour'] as int,
    minute: j['minute'] as int,
    label: (j['label'] as String?) ?? '',
    enabled: j['enabled'] as bool? ?? false,
    repeatDaily: j['repeatDaily'] as bool? ?? false,
    scheduledAtEpochMs: j['scheduledAtEpochMs'] as int?,
  );
}
