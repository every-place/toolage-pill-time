import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pill_time/ui/brand.dart';
import 'package:pill_time/ui/prescription_screen.dart';

void main() {
  testWidgets('enter Metformin 1000 mg from the label', (tester) async {
    // Tall, so the whole form is built at once.
    tester.view.physicalSize = const Size(1170, 7500);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: toolageTheme(Brightness.light),
        home: const PrescriptionScreen(),
      ),
    );

    // No suggestions before 3 letters.
    await tester.enterText(find.byType(TextField).first, 'me');
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Metformin'), findsNothing);

    // Tests have no internet, so this uses the built-in list.
    await tester.enterText(find.byType(TextField).first, 'metf');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.text('Metformin'), findsWidgets);

    await tester.tap(find.text('Oral Pill'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('1000 mg Tablet'));
    await tester.pumpAndSettle();

    expect(find.text('Metformin 1000 mg Tablet'), findsOneWidget);
    expect(find.text('Take 1 tablet by mouth twice a day.'), findsOneWidget);
    expect(find.text('8:00 AM'), findsOneWidget);
    expect(find.text('8:00 PM'), findsOneWidget);
    expect(find.text('9 hr'), findsOneWidget);

    // As needed: no dose times, the label says so.
    await tester.tap(find.text('As needed'));
    await tester.pumpAndSettle();
    expect(
      find.text('Take 1 tablet by mouth twice a day as needed.'),
      findsOneWidget,
    );
    expect(find.text('8:00 AM'), findsNothing);
    expect(find.text('12 hr'), findsOneWidget);

    // The rest of the label is tucked away until opened.
    await tester.tap(find.text('Pharmacy and label details'));
    await tester.pumpAndSettle();
    expect(find.text('Rx number'), findsOneWidget);
    expect(find.text('Refills'), findsOneWidget);
    expect(find.text('Price'), findsOneWidget);
  });
}
