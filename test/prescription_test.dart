import 'package:flutter_test/flutter_test.dart';
import 'package:pill_time/core/models.dart';
import 'package:pill_time/core/prescription.dart';
import 'package:pill_time/core/scheduler.dart';
import 'package:pill_time/services/drug_search.dart';

void main() {
  group('metformin 1000 mg tablet', () {
    final rx = Prescription(
      drug: 'Metformin',
      strength: '1000 mg',
      form: 'tablet',
      directions: Directions.forForm(doseFormFor('tablet')),
    );

    test('reads like the bottle label', () {
      expect(rx.labelLine, 'Metformin 1000 mg Tablet');
      expect(rx.directionsText, 'Take 1 tablet by mouth twice a day.');
      expect(rx.medName, 'Metformin 1000 mg');
    });

    test('twice a day gives 8 AM and 8 PM with a 9 hour gap', () {
      final s = rx.directions.defaultSchedule() as TimesSchedule;
      expect(s.times, [const ClockTime(8, 0), const ClockTime(20, 0)]);
      expect(rx.directions.suggestedGapMinutes(), 9 * 60);
    });

    test('with food and two tablets', () {
      final d = rx.directions.copyWith(amount: 2, extra: 'food');
      expect(
        d.sentence(rx.doseForm),
        'Take 2 tablets by mouth twice a day with food.',
      );
    });

    test('saves and loads with the med', () {
      final med = Med(
        id: 'm',
        name: rx.medName,
        schedule: rx.directions.defaultSchedule(),
        minGapMinutes: 540,
        rx: rx,
      );
      final back = Med.fromJson(med.toJson());
      expect(back.rx!.labelLine, rx.labelLine);
      expect(back.rx!.directionsText, rx.directionsText);
    });

    test('old saved meds without a label still load', () {
      final j = Med(
        id: 'x',
        name: 'X',
        schedule: const IntervalSchedule(6),
        minGapMinutes: 300,
      ).toJson();
      expect(j.containsKey('rx'), isFalse);
      expect(Med.fromJson(j).rx, isNull);
    });
  });

  test('every 8 hours is an interval with an 8 hour gap', () {
    const d = Directions(
      amount: 1,
      unit: 'capsule',
      route: 'mouth',
      frequency: 'q8h',
    );
    expect((d.defaultSchedule() as IntervalSchedule).hours, 8);
    expect(d.suggestedGapMinutes(), 480);
  });

  test('half tablets and other forms', () {
    const d = Directions(
      amount: 0.5,
      unit: 'tablet',
      route: 'mouth',
      frequency: 'bedtime',
    );
    expect(
      d.sentence(doseFormFor('tablet')),
      'Take 1/2 tablet by mouth at bedtime.',
    );
    const puffs = Directions(
      amount: 2,
      unit: 'puff',
      route: 'inhaled',
      frequency: 'q4h',
    );
    expect(
      puffs.sentence(doseFormFor('inhaler')),
      'Inhale 2 puffs by inhalation every 4 hours.',
    );
  });

  group('drug list wording', () {
    test('strength and form', () {
      final a = parseStrengthForm('1000 mg Tab');
      expect((a.strength, a.form), ('1000 mg', 'tablet'));
      final b = parseStrengthForm('500 mg 24HR XR Tab');
      expect((b.strength, b.form), ('500 mg', 'er_tablet'));
      final c = parseStrengthForm('500 mg/5 mL Oral Solution');
      expect((c.strength, c.form), ('500 mg/5 mL', 'liquid'));
      final e = parseStrengthForm('20 mg DR Cap');
      expect((e.strength, e.form), ('20 mg', 'dr_capsule'));
      expect(parseStrengthForm('90 mcg/actuat Inhaler').form, 'inhaler');
    });

    test('drug names', () {
      expect(tidyDrugName('metFORMIN (Oral Pill)'), 'Metformin');
      expect(drugNameHint('metFORMIN (Oral Pill)'), 'Oral Pill');
      expect(
        tidyDrugName('hydroCHLOROthiazide (Oral Pill)'),
        'Hydrochlorothiazide',
      );
    });

    test('RxTerms answer', () {
      const body =
          '[2,["metFORMIN (Oral Pill)","metFORMIN (Oral Liquid)"],'
          '{"STRENGTHS_AND_FORMS":[["500 mg Tab","1000 mg Tab"],'
          '["500 mg/5 mL Oral Solution"]]},'
          '[["metFORMIN (Oral Pill)"],["metFORMIN (Oral Liquid)"]]]';
      final found = parseRxTerms(body);
      expect(found.length, 2);
      expect(found.first.name, 'Metformin');
      expect(found.first.options.map((o) => o.label), [
        '500 mg Tablet',
        '1000 mg Tablet',
      ]);
      expect(found.last.options.single.form, 'liquid');
    });

    test('offline list finds metformin from 3 letters', () {
      final found = offlineMatches('met');
      expect(found.first.name, 'Metformin');
      expect(
        found.first.options.map((o) => o.label),
        contains('1000 mg Tablet'),
      );
    });
  });

  group('as needed', () {
    const d = Directions(
      amount: 2,
      unit: 'tablet',
      route: 'mouth',
      frequency: 'q6h',
      asNeeded: true,
      asNeededFor: 'pain',
    );
    final med = Med(
      id: 'p',
      name: 'Ibuprofen 200 mg',
      schedule: d.defaultSchedule(),
      minGapMinutes: d.suggestedGapMinutes(),
      rx: Prescription(
        drug: 'Ibuprofen',
        strength: '200 mg',
        form: 'tablet',
        directions: d,
      ),
    );

    test('reads like the label', () {
      expect(
        med.rx!.directionsText,
        'Take 2 tablets by mouth every 6 hours as needed for pain.',
      );
      expect(med.minGapMinutes, 360);
    });

    test('3 times a day as needed is at least 8 hours apart', () {
      final t = d.copyWith(frequency: 'daily3');
      expect((t.defaultSchedule() as IntervalSchedule).hours, 8);
      expect(t.suggestedGapMinutes(), 480);
    });

    test('never due and no alarms, but still too early inside the gap', () {
      final now = DateTime(2026, 1, 1, 12);
      final log = [
        DoseEntry(
          id: '1',
          takenAt: DateTime(2026, 1, 1, 9),
          medIds: ['p'],
          medNames: [med.name],
        ),
      ];
      final s = statusFor(med, log, now);
      expect(s.due, isFalse);
      expect(s.nextDue, isNull);
      expect(s.tooEarly, isTrue);
      expect(s.safeAt, DateTime(2026, 1, 1, 15));
      expect(upcomingAlerts([s], now), isEmpty);
      expect(statusFor(med, [], now).due, isFalse);
      expect(statusFor(med, [], now).tooEarly, isFalse);
    });
  });

  test('label details save and load', () {
    final rx = Prescription(
      drug: 'Metformin',
      strength: '1000 mg',
      form: 'tablet',
      directions: Directions.forForm(doseFormFor('tablet')),
      details: LabelDetails(
        rxNumber: '7654321',
        rxDate: DateTime(2026, 11, 1),
        pharmacy: 'Walgreens #1234',
        pharmacyPhone: '555-1234',
        prescriber: 'Dr. Smith',
        quantity: '180',
        refills: 3,
        price: 4.5,
      ),
    );
    final back = Prescription.fromJson(rx.toJson()).details;
    expect(back.rxNumber, '7654321');
    expect(back.rxDate, DateTime(2026, 11, 1));
    expect(back.pharmacy, 'Walgreens #1234');
    expect(back.refills, 3);
    expect(priceText(back.price), r'$4.50');
    expect(rx.toJson().containsKey('details'), isTrue);
    expect(
      Prescription(
        drug: 'X',
        strength: '',
        form: 'tablet',
        directions: rx.directions,
      ).toJson().containsKey('details'),
      isFalse,
    );
  });
}
