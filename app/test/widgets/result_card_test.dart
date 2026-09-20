import 'package:banana_classifier/models/classification_result.dart';
import 'package:banana_classifier/widgets/result_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ResultCard', () {
    Widget buildCard({
      required ClassificationResult result,
      String? imagePath,
    }) {
      return MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
          child: ResultCard(result: result, imagePath: imagePath),
        )),
      );
    }

    // ── Headline tests (§7.3: "Lakatan — Ripe" as clear text) ──

    testWidgets('shows variety and ripeness as headline', (tester) async {
      final result = ClassificationResult(
        variety: 'Lakatan',
        ripeness: 'Ripe',
        confidence: 0.92,
      );

      await tester.pumpWidget(buildCard(result: result));

      expect(find.text('Lakatan — Ripe'), findsOneWidget);
    });

    testWidgets('shows headline for Saba — Unripe', (tester) async {
      final result = ClassificationResult(
        variety: 'Saba',
        ripeness: 'Unripe',
        confidence: 0.80,
      );

      await tester.pumpWidget(buildCard(result: result));

      expect(find.text('Saba — Unripe'), findsOneWidget);
    });

    // ── Confidence indicator tests (§7.3: plain language, no jargon) ──

    final confidenceCases = <({double confidence, String label})>[
      (confidence: 0.92, label: "We're pretty sure"),
      (confidence: 0.72, label: 'This looks likely'),
      (confidence: 0.42, label: 'Not very clear — try another photo'),
    ];

    for (final testCase in confidenceCases) {
      testWidgets('uses plain language at confidence ${testCase.confidence}',
          (tester) async {
        final result = ClassificationResult(
          variety: 'Lakatan',
          ripeness: 'Ripe',
          confidence: testCase.confidence,
        );

        await tester.pumpWidget(buildCard(result: result));

        expect(find.text(testCase.label), findsOneWidget);
      });
    }

    // ── Ripeness icon tests (§7.4: never rely on color alone) ──

    testWidgets('shows check icon for ripe result', (tester) async {
      final result = ClassificationResult(
        variety: 'Lakatan',
        ripeness: 'Ripe',
        confidence: 0.90,
      );

      await tester.pumpWidget(buildCard(result: result));

      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    });

    testWidgets('shows hourglass icon for unripe result', (tester) async {
      final result = ClassificationResult(
        variety: 'Cavendish',
        ripeness: 'Unripe',
        confidence: 0.88,
      );

      await tester.pumpWidget(buildCard(result: result));

      expect(find.byIcon(Icons.hourglass_top_rounded), findsOneWidget);
    });

    testWidgets('shows warning icon for overripe result', (tester) async {
      final result = ClassificationResult(
        variety: 'Saba',
        ripeness: 'Overripe',
        confidence: 0.75,
      );

      await tester.pumpWidget(buildCard(result: result));

      expect(find.byIcon(Icons.warning_rounded), findsOneWidget);
    });

    // ── Image handling ──

    testWidgets('renders without image when imagePath is null', (tester) async {
      final result = ClassificationResult(
        variety: 'Lakatan',
        ripeness: 'Ripe',
        confidence: 0.92,
      );

      await tester.pumpWidget(buildCard(result: result, imagePath: null));

      // Card still shows headline and confidence without crashing.
      expect(find.text('Lakatan — Ripe'), findsOneWidget);
      expect(find.text("We're pretty sure"), findsOneWidget);
    });

    // ── A28: Health Benefits & Dish Suggestions wiring (§7.6) ──

    testWidgets('known variety + known ripeness shows both info cards',
        (tester) async {
      final result = ClassificationResult(
        variety: 'Saba',
        ripeness: 'Ripe',
        confidence: 0.90,
      );

      await tester.pumpWidget(buildCard(result: result));

      // HealthBenefitsCard header.
      expect(find.text('Health Benefits'), findsOneWidget);
      // A general benefit from Saba.
      expect(find.text('Rich in potassium — good for heart health'),
          findsOneWidget);
      // A ripeness-specific benefit from Saba + ripe.
      expect(find.text('Natural sugars provide quick energy'), findsOneWidget);

      // DishSuggestionsCard header.
      expect(find.text('Suggested Dishes'), findsOneWidget);
      // Specific ripe Saba dish.
      expect(find.text('Banana cue'), findsOneWidget);
      expect(find.text('Turon'), findsOneWidget);
    });

    testWidgets('known variety + missing ripeness shows health card only',
        (tester) async {
      // Cordova has no 'unripe' key.
      final result = ClassificationResult(
        variety: 'Cordova',
        ripeness: 'Unripe',
        confidence: 0.85,
      );

      await tester.pumpWidget(buildCard(result: result));

      // HealthBenefitsCard still visible with general benefits.
      expect(find.text('Health Benefits'), findsOneWidget);
      expect(find.text('Good source of Vitamin C — supports immune health'),
          findsOneWidget);

      // DishSuggestionsCard hidden (no unripe data for Cordova).
      expect(find.text('Suggested Dishes'), findsNothing);
    });

    testWidgets('unknown variety hides both info cards', (tester) async {
      final result = ClassificationResult(
        variety: 'Mango',
        ripeness: 'Ripe',
        confidence: 0.88,
      );

      await tester.pumpWidget(buildCard(result: result));

      // Neither card should appear.
      expect(find.text('Health Benefits'), findsNothing);
      expect(find.text('Suggested Dishes'), findsNothing);

      // But the rest of the card still renders.
      expect(find.text('Mango — Ripe'), findsOneWidget);
    });
  });
}
