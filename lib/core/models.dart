/// Data types for meds, schedules and logged doses.
library;

/// A time of day, like 08:00 or 20:30.
class ClockTime implements Comparable<ClockTime> {
  const ClockTime(this.hour, this.minute);

  final int hour;
  final int minute;

  /// Parses "8:00" or "20:30". Returns null if it isn't a valid time.
  static ClockTime? tryParse(String s) {
    final m = RegExp(r'^\s*(\d{1,2}):(\d{2})\s*$').firstMatch(s);
    if (m == null) return null;
    final h = int.parse(m.group(1)!), min = int.parse(m.group(2)!);
    if (h > 23 || min > 59) return null;
    return ClockTime(h, min);
  }

  String toJson() =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  @override
  int compareTo(ClockTime other) =>
      (hour * 60 + minute).compareTo(other.hour * 60 + other.minute);

  @override
  bool operator ==(Object other) =>
      other is ClockTime && other.hour == hour && other.minute == minute;

  @override
  int get hashCode => hour * 60 + minute;
}

/// How a med is scheduled.
sealed class DoseSchedule {
  const DoseSchedule();

  Map<String, dynamic> toJson();

  static DoseSchedule fromJson(Map<String, dynamic> j) {
    switch (j['type']) {
      case 'interval':
        return IntervalSchedule((j['hours'] as num).toDouble());
      case 'times':
        return TimesSchedule(
          [
            for (final t in (j['times'] as List))
              ClockTime.tryParse(t as String)!,
          ]..sort(),
        );
      default:
        throw FormatException('Unknown schedule type: ${j['type']}');
    }
  }
}

/// Every X hours, counted from the last dose.
class IntervalSchedule extends DoseSchedule {
  const IntervalSchedule(this.hours);
  final double hours;

  @override
  Map<String, dynamic> toJson() => {'type': 'interval', 'hours': hours};
}

/// Fixed clock times each day.
class TimesSchedule extends DoseSchedule {
  const TimesSchedule(this.times);
  final List<ClockTime> times;

  @override
  Map<String, dynamic> toJson() => {
    'type': 'times',
    'times': [for (final t in times) t.toJson()],
  };
}

class Med {
  Med({
    required this.id,
    required this.name,
    required this.schedule,
    required this.minGapMinutes,
    this.gapConfirmedAt,
    this.active = true,
    this.notes = '',
  });

  final String id;
  final String name;
  final DoseSchedule schedule;

  /// The shortest safe time between two doses. The next dose is never
  /// scheduled sooner than this after the last one.
  final int minGapMinutes;

  /// When a person last confirmed the minimum gap. Null means unconfirmed.
  final DateTime? gapConfirmedAt;
  final bool active;
  final String notes;

  bool get gapConfirmed => gapConfirmedAt != null;

  Med copyWith({
    String? name,
    DoseSchedule? schedule,
    int? minGapMinutes,
    DateTime? gapConfirmedAt,
    bool? active,
    String? notes,
  }) => Med(
    id: id,
    name: name ?? this.name,
    schedule: schedule ?? this.schedule,
    minGapMinutes: minGapMinutes ?? this.minGapMinutes,
    gapConfirmedAt: gapConfirmedAt ?? this.gapConfirmedAt,
    active: active ?? this.active,
    notes: notes ?? this.notes,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'schedule': schedule.toJson(),
    'minGapMinutes': minGapMinutes,
    'gapConfirmedAt': gapConfirmedAt?.toIso8601String(),
    'active': active,
    'notes': notes,
  };

  factory Med.fromJson(Map<String, dynamic> j) => Med(
    id: j['id'] as String,
    name: j['name'] as String,
    schedule: DoseSchedule.fromJson(j['schedule'] as Map<String, dynamic>),
    minGapMinutes: j['minGapMinutes'] as int,
    gapConfirmedAt: j['gapConfirmedAt'] == null
        ? null
        : DateTime.parse(j['gapConfirmedAt'] as String),
    active: j['active'] as bool? ?? true,
    notes: j['notes'] as String? ?? '',
  );
}

/// One logged dose: when, which meds, and an optional photo.
class DoseEntry {
  DoseEntry({
    required this.id,
    required this.takenAt,
    required this.medIds,
    required this.medNames,
    this.photoFile,
    this.note = '',
  });

  final String id;
  final DateTime takenAt;
  final List<String> medIds;

  /// Names as they were when logged, so history survives renames and deletes.
  final List<String> medNames;
  final String? photoFile;
  final String note;

  Map<String, dynamic> toJson() => {
    'id': id,
    'takenAt': takenAt.toIso8601String(),
    'medIds': medIds,
    'medNames': medNames,
    'photoFile': photoFile,
    'note': note,
  };

  factory DoseEntry.fromJson(Map<String, dynamic> j) => DoseEntry(
    id: j['id'] as String,
    takenAt: DateTime.parse(j['takenAt'] as String),
    medIds: [for (final x in j['medIds'] as List) x as String],
    medNames: [for (final x in j['medNames'] as List) x as String],
    photoFile: j['photoFile'] as String?,
    note: j['note'] as String? ?? '',
  );
}
