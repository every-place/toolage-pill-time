import 'models.dart';

String gapText(int minutes) {
  final h = minutes ~/ 60, m = minutes % 60;
  if (h == 0) return '$m min';
  if (m == 0) return '$h hr';
  return '$h hr $m min';
}

String hoursText(double hours) => hours == hours.roundToDouble()
    ? hours.toInt().toString()
    : hours.toStringAsFixed(1);

String clockText(DateTime t) {
  final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
  final mm = t.minute.toString().padLeft(2, '0');
  return '$h:$mm ${t.hour < 12 ? 'AM' : 'PM'}';
}

String clockTimeText(ClockTime t) =>
    clockText(DateTime(2000, 1, 1, t.hour, t.minute));

const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// "3:40 AM", "Tomorrow 3:40 AM", "Yesterday 9:00 PM" or "Mon 3:40 AM".
String whenText(DateTime? t, DateTime now) {
  if (t == null) return '-';
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(t.year, t.month, t.day);
  final diff = (day.difference(today).inHours / 24).round();
  final clock = clockText(t);
  if (diff == 0) return clock;
  if (diff == 1) return 'Tomorrow $clock';
  if (diff == -1) return 'Yesterday $clock';
  if (diff.abs() < 7) return '${_days[t.weekday - 1]} $clock';
  return '${_months[t.month - 1]} ${t.day} $clock';
}

String scheduleText(DoseSchedule s) => switch (s) {
  IntervalSchedule(:final hours) => 'Every ${hoursText(hours)} hours',
  TimesSchedule(:final times) =>
    times.isEmpty
        ? 'No times set'
        : 'At ${times.map(clockTimeText).join(', ')}',
};
