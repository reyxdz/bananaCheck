import 'package:banana_classifier/models/classification_result.dart';
import 'package:banana_classifier/screens/results_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ResultsScreen', () {
    late ClassificationResult highConfidenceResult;
    late ClassificationResult medConfidenceResult;
    late ClassificationResult lowConfidenceResult;
    late bool scanAgainPressed;

    setUp(() {
      scanAgainPressed = false;
      highConfidenceResult = ClassificationResult(
        variety: 'Lakatan',
        ripeness: 'Ripe',
        confidence: 0.92,
      );
      medConfidenceResult = ClassificationResult(
        variety: 'Cavendish',
        ripeness: 'Unripe',
        confidence: 0.72,
      );
      lowConfidenceResult = ClassificationResult(
        variety: 'Saba',
        ripeness: 'Overripe',
        confidence: 0.40,
      );
    });

    Widget buildScreen({required ClassificationResult result}) {
      return MaterialApp(
        home: ResultsScreen(
          result: result,
          onScanAgain: () => scanAgainPressed = true,
        ),
      );
    }

    // ── Layout structure (§7.2: card-based, modern, flat) ──

    testWidgets('shows "Your Result" title in the top bar', (tester) async {
      await tester.pumpWidget(buildScreen(result: highConfidenceResult));

      expect(find.text('Your Result'), findsOneWidget);
    });

    testWidgets('shows the ResultCard with variety–ripeness headline',
        (tester) async {
      await tester.pumpWidget(buildScreen(result: highConfidenceResult));

      // §7.3: large, clear text "Lakatan — Ripe" as the headline.
      expect(find.text('Lakatan — Ripe'), findsOneWidget);
    });

    // ── §7.3: plain-language confidence, no jargon ──

    testWidgets('shows plain-language confidence for high confidence',
        (tester) async {
      await tester.pumpWidget(buildScreen(result: highConfidenceResult));

      expect(find.text("We're pretty sure"), findsOneWidget);
      // Must NOT show raw numbers or "confidence score" etc.
      expect(find.text('0.92'), findsNothing);
      expect(find.textContaining('confidence'), findsNothing);
    });

    testWidgets('shows plain-language confidence for medium confidence',
        (tester) async {
      await tester.pumpWidget(buildScreen(result: medConfidenceResult));

      expect(find.text('Cavendish — Unripe'), findsOneWidget);
      expect(find.text('This looks likely'), findsOneWidget);
    });

    testWidgets('shows actionable message for low confidence',
        (tester) async {
      await tester.pumpWidget(buildScreen(result: lowConfidenceResult));

      expect(find.text('Saba — Overripe'), findsOneWidget);
      expect(
        find.text('Not very clear — try another photo'),
        findsOneWidget,
      );
    });

    // ── §7.1: one primary action per screen — "Scan Again" ──

    testWidgets('shows "Scan Again" as the single primary action',
        (tester) async {
      await tester.pumpWidget(buildScreen(result: highConfidenceResult));

      expect(find.text('Scan Again'), findsOneWidget);
      expect(find.byIcon(Icons.camera_alt), findsOneWidget);
    });

    testWidgets('tapping "Scan Again" triggers onScanAgain callback',
        (tester) async {
      await tester.pumpWidget(buildScreen(result: highConfidenceResult));

      await tester.tap(find.text('Scan Again'));
      await tester.pumpAndSettle();

      expect(scanAgainPressed, isTrue);
    });

    // ── §7.2: icon paired with label (never icon-only for critical actions) ──

    testWidgets('"Scan Again" button pairs icon with text label',
        (tester) async {
      await tester.pumpWidget(buildScreen(result: highConfidenceResult));

      // Per §7.2: always pair an icon with a short, plain-language label.
      expect(find.byIcon(Icons.camera_alt), findsOneWidget);
      expect(find.text('Scan Again'), findsOneWidget);
    });

    // ── §7.4: never rely on color alone ──

    testWidgets('ripeness is conveyed with icon, not just color',
        (tester) async {
      await tester.pumpWidget(buildScreen(result: highConfidenceResult));

      // "Ripe" should have a check icon — not relying on color alone.
      expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
    });

    testWidgets('unripe result shows hourglass icon', (tester) async {
      await tester.pumpWidget(buildScreen(result: medConfidenceResult));

      expect(find.byIcon(Icons.hourglass_empty), findsOneWidget);
    });

    testWidgets('overripe result shows warning icon', (tester) async {
      await tester.pumpWidget(buildScreen(result: lowConfidenceResult));

      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    });

    // ── Back navigation ──

    testWidgets('back button triggers onScanAgain', (tester) async {
      await tester.pumpWidget(buildScreen(result: highConfidenceResult));

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      expect(scanAgainPressed, isTrue);
    });

    // ── Helpful context ──

    testWidgets('shows helpful context text for the user', (tester) async {
      await tester.pumpWidget(buildScreen(result: highConfidenceResult));

      expect(
        find.textContaining('scan again'),
        findsWidgets,
      );
    });

    // ── No technical jargon anywhere on screen ──

    testWidgets('never shows raw jargon terms', (tester) async {
      await tester.pumpWidget(buildScreen(result: highConfidenceResult));

      // §7.3: these terms must never appear on screen.
      expect(find.textContaining('confidence score'), findsNothing);
      expect(find.textContaining('inference'), findsNothing);
      expect(find.textContaining('class probability'), findsNothing);
      expect(find.textContaining('Classification:'), findsNothing);
    });
  });
}
