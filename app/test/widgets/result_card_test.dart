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

    // ── A29: HealthBenefitsCard + DishSuggestionsCard wired into ResultCard ──

    testWidgets('shows Health Benefits section for known variety',
        (tester) async {
      final result = ClassificationResult(
        variety: 'Saba',
        ripeness: 'Ripe',
        confidence: 0.90,
      );

      await tester.pumpWidget(buildCard(result: result));

      expect(find.text('Health Benefits'), findsOneWidget);
      expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);
    });

    testWidgets('shows Suggested Dishes section for known variety + ripeness',
        (tester) async {
      final result = ClassificationResult(
        variety: 'Saba',
        ripeness: 'Ripe',
        confidence: 0.90,
      );

      await tester.pumpWidget(buildCard(result: result));

      expect(find.text('Suggested Dishes'), findsOneWidget);
      expect(find.byIcon(Icons.restaurant_rounded), findsOneWidget);
    });

    testWidgets('shows actual Saba ripe dishes from bananaInfoMap',
        (tester) async {
      final result = ClassificationResult(
        variety: 'Saba',
        ripeness: 'Ripe',
        confidence: 0.90,
      );

      await tester.pumpWidget(buildCard(result: result));

      expect(find.text('Banana cue'), findsOneWidget);
      expect(find.text('Turon'), findsOneWidget);
      expect(find.text('Maruya'), findsOneWidget);
    });

    testWidgets('shows general health benefits for Saba', (tester) async {
      final result = ClassificationResult(
        variety: 'Saba',
        ripeness: 'Ripe',
        confidence: 0.90,
      );

      await tester.pumpWidget(buildCard(result: result));

      expect(
        find.text('Rich in potassium — good for heart health'),
        findsOneWidget,
      );
    });

    testWidgets('hides dish suggestions when ripeness key missing',
        (tester) async {
      // Cordova has no 'unripe' key.
      final result = ClassificationResult(
        variety: 'Cordova',
        ripeness: 'Unripe',
        confidence: 0.80,
      );

      await tester.pumpWidget(buildCard(result: result));

      // Health benefits still shown (general).
      expect(find.text('Health Benefits'), findsOneWidget);
      // Dish suggestions hidden — no ripeness key.
      expect(find.text('Suggested Dishes'), findsNothing);
    });

    testWidgets('hides both info cards for unknown variety', (tester) async {
      final result = ClassificationResult(
        variety: 'UnknownBanana',
        ripeness: 'Ripe',
        confidence: 0.85,
      );

      await tester.pumpWidget(buildCard(result: result));

      // Unknown variety → no info cards at all.
      expect(find.text('Health Benefits'), findsNothing);
      expect(find.text('Suggested Dishes'), findsNothing);
    });

    // ── Vendor advice (per ripeness) ──

    testWidgets('shows vendor advice for ripe', (tester) async {
      final result = ClassificationResult(
        variety: 'Lakatan',
        ripeness: 'Ripe',
        confidence: 0.90,
      );

      await tester.pumpWidget(buildCard(result: result));

      expect(
        find.textContaining('Ready for immediate consumption'),
        findsOneWidget,
      );
    });

    testWidgets('shows vendor advice for unripe', (tester) async {
      final result = ClassificationResult(
        variety: 'Cavendish',
        ripeness: 'Unripe',
        confidence: 0.88,
      );

      await tester.pumpWidget(buildCard(result: result));

      expect(
        find.textContaining('Store at room temperature'),
        findsOneWidget,
      );
    });

    testWidgets('shows vendor advice for overripe', (tester) async {
      final result = ClassificationResult(
        variety: 'Saba',
        ripeness: 'Overripe',
        confidence: 0.75,
      );

      await tester.pumpWidget(buildCard(result: result));

      expect(
        find.textContaining('Best used immediately'),
        findsOneWidget,
      );
    });

    // ── InfoPill badges ──

    testWidgets('shows variety and ripeness as InfoPill badges', (tester) async {
      final result = ClassificationResult(
        variety: 'Lakatan',
        ripeness: 'Ripe',
        confidence: 0.92,
      );

      await tester.pumpWidget(buildCard(result: result));

      // Both variety and ripeness appear as pill badges + in headline.
      expect(find.text('Lakatan'), findsAtLeast(1));
      expect(find.text('Ripe'), findsAtLeast(1));
    });

    // ── All 6 varieties show info cards ──

    for (final variety in ['saba', 'lakatan', 'cavendish', 'cordova', 'senorita', 'latundan']) {
      testWidgets('shows info cards for $variety variety', (tester) async {
        final result = ClassificationResult(
          variety: variety[0].toUpperCase() + variety.substring(1),
          ripeness: 'Ripe',
          confidence: 0.90,
        );

        await tester.pumpWidget(buildCard(result: result));

        expect(find.text('Health Benefits'), findsOneWidget);
      });
    }
  });
}

