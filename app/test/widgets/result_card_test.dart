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
        home: Scaffold(body: SingleChildScrollView(
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
      testWidgets(
          'uses plain language at confidence ${testCase.confidence}',
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

      expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
    });

    testWidgets('shows hourglass icon for unripe result', (tester) async {
      final result = ClassificationResult(
        variety: 'Cavendish',
        ripeness: 'Unripe',
        confidence: 0.88,
      );

      await tester.pumpWidget(buildCard(result: result));

      expect(find.byIcon(Icons.hourglass_empty), findsOneWidget);
    });

    testWidgets('shows warning icon for overripe result', (tester) async {
      final result = ClassificationResult(
        variety: 'Saba',
        ripeness: 'Overripe',
        confidence: 0.75,
      );

      await tester.pumpWidget(buildCard(result: result));

      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    });

    // ── Image handling ──

    testWidgets('renders without image when imagePath is null',
        (tester) async {
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
  });
}
