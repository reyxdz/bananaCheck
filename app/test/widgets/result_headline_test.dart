import 'package:banana_classifier/theme/app_theme.dart';
import 'package:banana_classifier/theme/ripeness_helpers.dart';
import 'package:banana_classifier/widgets/result_headline.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget child) => MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  testWidgets('shows variety large, ripeness badge and its meaning',
      (tester) async {
    await tester.pumpWidget(
      _app(const ResultHeadline(variety: 'Lakatan', ripeness: 'Ripe')),
    );

    expect(find.text('Your banana'), findsOneWidget);
    expect(find.text('Lakatan'), findsOneWidget);
    expect(find.text('Ripe'), findsOneWidget);
    expect(find.text('Ready to eat today'), findsOneWidget);
    // Ripeness is never colour-only (§7.4).
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);

    // Variety is the dominant line.
    final varietySize =
        tester.widget<Text>(find.text('Lakatan')).style!.fontSize!;
    final ripenessSize = tester.getSize(find.text('Ripe')).height;
    expect(varietySize, greaterThan(ripenessSize));
  });

  testWidgets('no longer shows the old "Variety — Ripeness" line',
      (tester) async {
    await tester.pumpWidget(
      _app(const ResultHeadline(variety: 'Saba', ripeness: 'Unripe')),
    );
    expect(find.text('Saba — Unripe'), findsNothing);
    expect(find.text('Still green — give it a few days'), findsOneWidget);
  });

  testWidgets('hides the meaning line for an unknown ripeness', (tester) async {
    await tester.pumpWidget(
      _app(const ResultHeadline(variety: 'Saba', ripeness: 'Mystery')),
    );
    expect(find.text('Mystery'), findsOneWidget);
    expect(find.text(''), findsNothing);
  });

  testWidgets('is read by screen readers as one phrase', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      _app(const ResultHeadline(variety: 'Lakatan', ripeness: 'Overripe')),
    );
    expect(
      tester.getSemantics(find.text('Lakatan')).label,
      allOf(
        contains('Your banana'),
        contains('Lakatan'),
        contains('Overripe'),
        contains('best for cooking'),
      ),
    );
    handle.dispose();
  });

  testWidgets('long names wrap instead of overflowing on a small phone',
      (tester) async {
    tester.view.physicalSize = const Size(640, 1280);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _app(
        const SizedBox(
          width: 280,
          child: ResultHeadline(
            variety: 'Cavendish Grand Nain Extra',
            ripeness: 'Overripe',
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });

  test('summaryFor gives plain language for each ripeness', () {
    expect(RipenessHelpers.summaryFor('unripe'), contains('few days'));
    expect(RipenessHelpers.summaryFor('Ripe'), 'Ready to eat today');
    expect(RipenessHelpers.summaryFor('OVERRIPE'), contains('cooking'));
    expect(RipenessHelpers.summaryFor('unknown'), isEmpty);
  });
}
