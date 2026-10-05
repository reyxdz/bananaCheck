import 'package:banana_classifier/theme/app_theme.dart';
import 'package:banana_classifier/theme/design_tokens.dart';
import 'package:banana_classifier/theme/ripeness_helpers.dart';
import 'package:banana_classifier/widgets/result_headline.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget child, {bool reduceMotion = false}) => MaterialApp(
      theme: AppTheme.light,
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduceMotion),
        child: Scaffold(body: Center(child: child)),
      ),
    );

/// Height of the scale segment above the stage label [label].
double _segmentHeight(WidgetTester tester, String label) {
  final segment = find
      .ancestor(
        of: find.descendant(
            of: find.byType(RipeningScale), matching: find.text(label)),
        matching: find.byType(Column),
      )
      .first;
  final bar =
      find.descendant(of: segment, matching: find.byType(Container)).first;
  // The bar's own height, excluding the margin that centres faded segments.
  return tester.widget<Container>(bar).constraints!.maxHeight;
}

void main() {
  testWidgets('variety is the largest text on the headline', (tester) async {
    await tester.pumpWidget(
      _app(const ResultHeadline(variety: 'Lakatan', ripeness: 'Ripe')),
    );
    await tester.pumpAndSettle();

    final variety = tester.widget<Text>(find.text('Lakatan'));
    expect(variety.style!.fontSize, DesignTokens.varietyHeadlineSize);
    // No generic label above it any more.
    expect(find.text('Your banana'), findsNothing);
  });

  testWidgets('ripeness is stated large, with icon, colour and meaning',
      (tester) async {
    await tester.pumpWidget(
      _app(const ResultHeadline(variety: 'Lakatan', ripeness: 'Ripe')),
    );
    await tester.pumpAndSettle();

    final statement = tester
        .widgetList<Text>(find.text('Ripe'))
        .firstWhere((t) => t.style?.fontSize == DesignTokens.headingTextSize);
    expect(statement.style!.color, RipenessHelpers.colorFor('Ripe'));
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    expect(find.text('Ready to eat today'), findsOneWidget);
  });

  testWidgets('scale shows all three stages and marks the detected one',
      (tester) async {
    await tester.pumpWidget(
      _app(const ResultHeadline(variety: 'Saba', ripeness: 'Overripe')),
    );
    await tester.pumpAndSettle();

    final scale = find.byType(RipeningScale);
    expect(scale, findsOneWidget);
    for (final stage in RipeningScale.stages) {
      expect(
        find.descendant(of: scale, matching: find.text(stage)),
        findsOneWidget,
      );
    }

    // Detected stage: taller segment, bold label.
    expect(
      _segmentHeight(tester, 'Overripe'),
      DesignTokens.ripenessScaleActiveHeight,
    );
    expect(_segmentHeight(tester, 'Ripe'), DesignTokens.ripenessScaleHeight);
    final activeLabel = tester.widget<Text>(
      find.descendant(of: scale, matching: find.text('Overripe')),
    );
    expect(activeLabel.style!.fontWeight, FontWeight.w700);
  });

  testWidgets('no scale for a ripeness outside the three stages',
      (tester) async {
    await tester.pumpWidget(
      _app(const ResultHeadline(variety: 'Saba', ripeness: 'Mystery')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Mystery'), findsOneWidget);
    expect(find.byType(RipeningScale), findsNothing);
  });

  testWidgets('is read by screen readers as one phrase', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      _app(const ResultHeadline(variety: 'Lakatan', ripeness: 'Unripe')),
    );
    await tester.pumpAndSettle();
    expect(
      find.bySemanticsLabel(
        'Lakatan. Unripe, stage 1 of 3. Still green — give it a few days',
      ),
      findsOneWidget,
    );
    handle.dispose();
  });

  testWidgets('detected segment fills in once, then settles', (tester) async {
    await tester.pumpWidget(
      _app(const ResultHeadline(variety: 'Lakatan', ripeness: 'Ripe')),
    );
    final fill = find.byType(FractionallySizedBox);
    expect(tester.widget<FractionallySizedBox>(fill).widthFactor, 0);
    await tester.pumpAndSettle();
    expect(tester.widget<FractionallySizedBox>(fill).widthFactor, 1);
  });

  testWidgets('no fill animation when the OS asks to reduce motion',
      (tester) async {
    await tester.pumpWidget(
      _app(
        const ResultHeadline(variety: 'Lakatan', ripeness: 'Ripe'),
        reduceMotion: true,
      ),
    );
    expect(
      tester
          .widget<FractionallySizedBox>(find.byType(FractionallySizedBox))
          .widthFactor,
      1,
    );
  });

  testWidgets('long names wrap instead of overflowing on a small phone',
      (tester) async {
    tester.view.physicalSize = const Size(640, 1280);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _app(
        const SizedBox(
          width: 260,
          child: ResultHeadline(
            variety: 'Cavendish Grand Nain Extra',
            ripeness: 'Overripe',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  test('stageIndexOf maps the three stages, case-insensitively', () {
    expect(RipeningScale.stageIndexOf('unripe'), 0);
    expect(RipeningScale.stageIndexOf('Ripe'), 1);
    expect(RipeningScale.stageIndexOf(' OVERRIPE '), 2);
    expect(RipeningScale.stageIndexOf('NotBanana'), isNull);
  });

  test('summaryFor gives plain language for each ripeness', () {
    expect(RipenessHelpers.summaryFor('unripe'), contains('few days'));
    expect(RipenessHelpers.summaryFor('Ripe'), 'Ready to eat today');
    expect(RipenessHelpers.summaryFor('OVERRIPE'), contains('cooking'));
    expect(RipenessHelpers.summaryFor('unknown'), isEmpty);
  });
}
