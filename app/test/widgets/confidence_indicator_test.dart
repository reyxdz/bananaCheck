import 'package:banana_classifier/widgets/confidence_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ConfidenceIndicator', () {
    Widget buildIndicator(double confidence) {
      return MaterialApp(
        home: Scaffold(
          body: ConfidenceIndicator(confidence: confidence),
        ),
      );
    }

    // ── High confidence (≥ 0.85) ──

    testWidgets('shows "We\'re pretty sure" for high confidence',
        (tester) async {
      await tester.pumpWidget(buildIndicator(0.92));

      expect(find.text("We're pretty sure"), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    });

    testWidgets('shows "We\'re pretty sure" at exactly 0.85', (tester) async {
      await tester.pumpWidget(buildIndicator(0.85));

      expect(find.text("We're pretty sure"), findsOneWidget);
    });

    // ── Medium confidence (0.65–0.84) ──

    testWidgets('shows "This looks likely" for medium confidence',
        (tester) async {
      await tester.pumpWidget(buildIndicator(0.72));

      expect(find.text('This looks likely'), findsOneWidget);
      expect(find.byIcon(Icons.info), findsOneWidget);
    });

    testWidgets('shows "This looks likely" at exactly 0.65', (tester) async {
      await tester.pumpWidget(buildIndicator(0.65));

      expect(find.text('This looks likely'), findsOneWidget);
    });

    // ── Low confidence (< 0.65) ──

    testWidgets('shows actionable message for low confidence', (tester) async {
      await tester.pumpWidget(buildIndicator(0.42));

      expect(
        find.text('Not very clear — try another photo'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.help_outline), findsOneWidget);
    });

    testWidgets('shows actionable message at exactly 0.64', (tester) async {
      await tester.pumpWidget(buildIndicator(0.64));

      expect(
        find.text('Not very clear — try another photo'),
        findsOneWidget,
      );
    });

    // ── §7.4: icon is always paired with text (never color alone) ──

    testWidgets('pairs icon with text label at all confidence levels',
        (tester) async {
      for (final confidence in [0.95, 0.75, 0.40]) {
        await tester.pumpWidget(buildIndicator(confidence));
        await tester.pumpAndSettle();

        // At least one icon and one text widget should be present in the
        // indicator — meaning is never conveyed by color alone.
        final icons = find.byType(Icon);
        final texts = find.byType(Text);
        expect(icons, findsWidgets, reason: 'Icon present at $confidence');
        expect(texts, findsWidgets, reason: 'Text present at $confidence');
      }
    });
  });
}
