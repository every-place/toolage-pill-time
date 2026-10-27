import 'package:flutter_test/flutter_test.dart';
import 'package:pill_time/core/csv_export.dart';
import 'package:pill_time/core/format.dart';
import 'package:pill_time/core/gap_parser.dart';
import 'package:pill_time/core/models.dart';
import 'package:pill_time/core/scheduler.dart';

DateTime d(int day, int h, [int m = 0]) => DateTime(2026, 1, day, h, m);

List<DoseEntry> logOf(List<(DateTime, Med)> doses) => [
  for (final (i, (t, med)) in doses.indexed)
    DoseEntry(id: '$i', takenAt: t, medIds: [med.id], medNames: [med.name]),
];

final every6 = Med(
  id: 'a',
  name: 'A',
  schedule: const IntervalSchedule(6),
  minGapMinutes: 300,
);

final twiceDaily = Med(
  id: 'b',
  name: 'B',
  schedule: const TimesSchedule([ClockTime(8, 0), ClockTime(20, 0)]),
  minGapMinutes: 600,
);

void main() {
  group('interval schedule', () {
    test('never taken is due now', () {
      expect(statusFor(every6, [], d(1, 3)).due, isTrue);
    });

    test('too early before the minimum gap', () {
      final s = statusFor(every6, logOf([(d(1, 2), every6)]), d(1, 4));
      expect(s.tooEarly, isTrue);
      expect(s.due, isFalse);
      expect(s.safeAt, d(1, 7));
      expect(s.nextDue, d(1, 8));
    });

    test('a late dose moves the next one later', () {
      final s = statusFor(every6, logOf([(d(1, 5, 30), every6)]), d(1, 6));
      expect(s.nextDue, d(1, 11, 30));
    });

    test('due window starts 20 minutes early', () {
      final log = logOf([(d(1, 0), every6)]);
      expect(statusFor(every6, log, d(1, 5, 45)).due, isTrue);
      expect(statusFor(every6, log, d(1, 5, 30)).due, isFalse);
    });

    test('never due before the safe time, even inside the window', () {
      final tight = every6.copyWith(minGapMinutes: 360);
      final log = logOf([(d(1, 0), tight)]);
      expect(statusFor(tight, log, d(1, 5, 50)).due, isFalse);
      expect(statusFor(tight, log, d(1, 5, 50)).tooEarly, isTrue);
    });
  });

  group('fixed-time schedule', () {
    test('a late morning dose pushes the evening dose later', () {
      final log = logOf([(d(1, 11), twiceDaily)]);
      final s = statusFor(twiceDaily, log, d(1, 12));
      expect(s.planned, d(1, 20));
      expect(s.nextDue, d(1, 21));
      expect(s.shifted, isTrue);
      expect(statusFor(twiceDaily, log, d(1, 20, 30)).tooEarly, isTrue);
      expect(statusFor(twiceDaily, log, d(1, 21)).due, isTrue);
    });

    test('a slightly early dose still covers its slot', () {
      final s = statusFor(
        twiceDaily,
        logOf([(d(1, 7, 50), twiceDaily)]),
        d(1, 8, 5),
      );
      expect(s.planned, d(1, 20));
      expect(s.due, isFalse);
    });

    test('the evening dose rolls over to tomorrow morning', () {
      final s = statusFor(
        twiceDaily,
        logOf([(d(1, 20, 10), twiceDaily)]),
        d(1, 23),
      );
      expect(s.nextDue, d(2, 8));
    });

    test('missed slots show one dose due, not several', () {
      final s = statusFor(twiceDaily, logOf([(d(1, 8), twiceDaily)]), d(3, 9));
      expect(s.due, isTrue);
      expect(s.nextDue, d(1, 20));
    });

    test('never taken: most recent slot today is due', () {
      expect(statusFor(twiceDaily, [], d(1, 9)).nextDue, d(1, 8));
      expect(statusFor(twiceDaily, [], d(1, 6)).nextDue, d(1, 8));
    });
  });

  test('statuses put due meds first and skip inactive ones', () {
    final off = every6.copyWith(name: 'Off', active: false);
    final log = logOf([(d(1, 5), every6)]);
    final rows = allStatuses([every6, twiceDaily, off], log, d(1, 9));
    expect(rows.map((r) => r.med.name), ['B', 'A']);
  });

  test('alerts within 5 minutes are grouped', () {
    final a = statusFor(every6, logOf([(d(1, 0), every6)]), d(1, 1));
    final b = statusFor(
      every6.copyWith(name: 'A2'),
      logOf([(d(1, 0, 3), every6)]),
      d(1, 1),
    );
    final groups = upcomingAlerts([a, b], d(1, 1));
    expect(groups.length, 1);
    expect(groups.first.time, d(1, 6));
  });

  group('gap suggestions from label text', () {
    test('ranges use the lower number', () {
      final s = suggestGap(
        'Take 1 tablet every 4 to 6 hours while symptoms persist',
      );
      expect(s!.minutes, 240);
      expect(s.phrase, 'every 4 to 6 hours');
    });
    test(
      'words',
      () => expect(suggestGap('one tablet every twelve hours')!.minutes, 720),
    );
    test(
      'twice daily',
      () =>
          expect(suggestGap('Administer twice daily with food')!.minutes, 720),
    );
    test(
      'once daily',
      () => expect(suggestGap('Take once daily')!.minutes, 1440),
    );
    test(
      'nothing found',
      () => expect(suggestGap('as directed by a physician'), isNull),
    );
  });

  test('json round trip', () {
    final m = Med.fromJson(twiceDaily.toJson());
    expect(m.name, 'B');
    expect((m.schedule as TimesSchedule).times, [
      const ClockTime(8, 0),
      const ClockTime(20, 0),
    ]);
    final e = DoseEntry.fromJson(logOf([(d(1, 3), every6)]).first.toJson());
    expect(e.takenAt, d(1, 3));
  });

  test('csv', () {
    final csv = logToCsv([
      DoseEntry(
        id: '1',
        takenAt: d(1, 3, 5),
        medIds: ['a', 'b'],
        medNames: ['A', 'B, extra'],
      ),
    ]);
    expect(
      csv,
      'date,time,meds,photo,note\n2026-01-01,03:05,"A; B, extra",,\n',
    );
  });

  test('formatting', () {
    expect(gapText(270), '4 hr 30 min');
    expect(whenText(d(2, 3, 40), d(1, 22)), 'Tomorrow 3:40 AM');
    expect(whenText(d(1, 15), d(1, 9)), '3:00 PM');
  });
}
