import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pill_time/core/models.dart';
import 'package:pill_time/core/prescription.dart';
import 'package:pill_time/services/store.dart';
import 'package:pill_time/ui/brand.dart';
import 'package:pill_time/ui/dose_screen.dart';
import 'package:pill_time/ui/store_scope.dart';

void main() {
  testWidgets('log 3 aspirin when the usual dose is 2', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final dir = Directory.systemTemp.createTempSync('pilltime');
    addTearDown(() => dir.deleteSync(recursive: true));
    final store = (await tester.runAsync(() => Store.openAt(dir)))!;
    final aspirin = Med(
      id: 'asp',
      name: 'Aspirin 81 mg',
      schedule: const IntervalSchedule(24),
      minGapMinutes: 1080,
      rx: const Prescription(
        drug: 'Aspirin',
        strength: '81 mg',
        form: 'tablet',
        directions: Directions(
          amount: 4,
          unit: 'tablet',
          route: 'mouth',
          frequency: 'q24h',
        ),
        myAmount: 2,
      ),
    );
    await tester.runAsync(() => store.upsertMed(aspirin));

    await tester.pumpWidget(
      StoreScope(
        store: store,
        child: MaterialApp(
          theme: toolageTheme(Brightness.light),
          home: const DoseScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // Never taken, so it's due and ticked, starting at your dose of 2.
    expect(find.text('2 tablets'), findsOneWidget);
    await tester.tap(find.byTooltip('More'));
    await tester.pump();
    expect(find.text('3 tablets'), findsOneWidget);
    expect(find.text('Usual: 2'), findsOneWidget);

    await tester.runAsync(() async {
      await tester.tap(find.text('SAVE (1)'));
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    expect(store.log.single.lines, ['Aspirin 81 mg (3 tablets)']);
  });
}
