import 'models.dart';

String _two(int n) => n.toString().padLeft(2, '0');

String _escape(String s) {
  if (s.contains(',') || s.contains('"') || s.contains('\n')) {
    return '"${s.replaceAll('"', '""')}"';
  }
  return s;
}

/// The dose log as a CSV file a doctor or a spreadsheet can read.
String logToCsv(List<DoseEntry> log) {
  final sorted = [...log]..sort((a, b) => a.takenAt.compareTo(b.takenAt));
  final lines = ['date,time,meds,photo,note'];
  for (final e in sorted) {
    final t = e.takenAt;
    lines.add(
      [
        '${t.year}-${_two(t.month)}-${_two(t.day)}',
        '${_two(t.hour)}:${_two(t.minute)}',
        e.medNames.join('; '),
        e.photoFile ?? '',
        e.note,
      ].map(_escape).join(','),
    );
  }
  return '${lines.join('\n')}\n';
}
