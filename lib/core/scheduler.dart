/// The timing rules. Plain Dart with no Flutter imports, so it is easy to test.
library;

import 'models.dart';

/// A med counts as due (and is pre-ticked) this long before its time,
/// as long as it is past its safe time.
const dueWindow = Duration(minutes: 20);

/// Everything the screens need to know about one med at a moment in time.
class MedStatus {
  const MedStatus({
    required this.med,
    required this.last,
    required this.safeAt,
    required this.planned,
    required this.nextDue,
    required this.tooEarly,
    required this.due,
    required this.shifted,
  });

  final Med med;
  final DateTime? last;

  /// Earliest time the next dose is safe (last dose + minimum gap).
  final DateTime? safeAt;

  /// When the schedule alone would put the next dose.
  final DateTime? planned;

  /// The later of [planned] and [safeAt].
  final DateTime? nextDue;
  final bool tooEarly;
  final bool due;

  /// True when a late dose pushed the next one later than planned.
  final bool shifted;
}

class AlertGroup {
  AlertGroup(this.time, this.names);
  final DateTime time;
  final List<String> names;
}

DateTime? lastTaken(Med med, List<DoseEntry> log) {
  DateTime? best;
  for (final e in log) {
    if (e.medIds.contains(med.id) &&
        (best == null || e.takenAt.isAfter(best))) {
      best = e.takenAt;
    }
  }
  return best;
}

/// Fixed-time slots for [days] days, starting the day before [date].
List<DateTime> slotsAround(
  List<ClockTime> times,
  DateTime date, {
  int days = 3,
}) {
  final out = <DateTime>[
    for (var d = -1; d < days - 1; d++)
      for (final t in times)
        DateTime(date.year, date.month, date.day + d, t.hour, t.minute),
  ];
  out.sort();
  return out;
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// When the next dose is planned, ignoring the safety gap.
DateTime? plannedNext(Med med, DateTime? last, DateTime now) {
  switch (med.schedule) {
    case IntervalSchedule(:final hours):
      if (last == null) return now;
      return last.add(Duration(minutes: (hours * 60).round()));

    case TimesSchedule(:final times):
      if (times.isEmpty) return null;
      if (last == null) {
        // Never taken: today's most recent slot is due now, otherwise the
        // next slot.
        final all = slotsAround(times, now);
        final past = all
            .where((s) => !s.isAfter(now) && _sameDay(s, now))
            .toList();
        if (past.isNotEmpty) return past.last;
        return all.firstWhere((s) => s.isAfter(now));
      }
      // The last dose covers the slot nearest to it, and the next dose is the
      // slot after that. If several slots were missed, that slot is in the
      // past, so one dose shows as due. Doses never stack up.
      final all = slotsAround(times, last);
      var covered = all.first;
      for (final s in all) {
        if (s.difference(last).abs() < covered.difference(last).abs()) {
          covered = s;
        }
      }
      return all.firstWhere((s) => s.isAfter(covered));
  }
}

MedStatus statusFor(Med med, List<DoseEntry> log, DateTime now) {
  final last = lastTaken(med, log);
  final safeAt = last?.add(Duration(minutes: med.minGapMinutes));
  final planned = plannedNext(med, last, now);

  // The key rule: a late dose pushes the next one back so it is never sooner
  // than the minimum gap.
  DateTime? nextDue;
  if (planned != null && safeAt != null) {
    nextDue = planned.isAfter(safeAt) ? planned : safeAt;
  } else {
    nextDue = planned ?? safeAt;
  }

  final tooEarly = safeAt != null && now.isBefore(safeAt);
  final due =
      !tooEarly &&
      nextDue != null &&
      !now.isBefore(nextDue.subtract(dueWindow));
  final shifted = planned != null && safeAt != null && safeAt.isAfter(planned);

  return MedStatus(
    med: med,
    last: last,
    safeAt: safeAt,
    planned: planned,
    nextDue: nextDue,
    tooEarly: tooEarly,
    due: due,
    shifted: shifted,
  );
}

/// Active meds, due ones first, then by next due time.
List<MedStatus> allStatuses(List<Med> meds, List<DoseEntry> log, DateTime now) {
  final far = DateTime(9999);
  final rows = [
    for (final m in meds)
      if (m.active) statusFor(m, log, now),
  ];
  rows.sort((a, b) {
    if (a.due != b.due) return a.due ? -1 : 1;
    return (a.nextDue ?? far).compareTo(b.nextDue ?? far);
  });
  return rows;
}

/// Upcoming due times, with meds due within 5 minutes of each other grouped.
List<AlertGroup> upcomingAlerts(
  List<MedStatus> statuses,
  DateTime now, {
  Duration horizon = const Duration(hours: 36),
}) {
  final end = now.add(horizon);
  final items = [
    for (final s in statuses)
      if (s.nextDue != null &&
          s.nextDue!.isAfter(now) &&
          s.nextDue!.isBefore(end))
        (s.nextDue!, s.med.name),
  ]..sort((a, b) => a.$1.compareTo(b.$1));

  final groups = <AlertGroup>[];
  for (final (t, name) in items) {
    if (groups.isNotEmpty &&
        t.difference(groups.last.time) <= const Duration(minutes: 5)) {
      groups.last.names.add(name);
    } else {
      groups.add(AlertGroup(t, [name]));
    }
  }
  return groups;
}
