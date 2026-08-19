import 'package:banana_classifier/models/classification_result.dart';
import 'package:banana_classifier/widgets/result_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final cases = <({double confidence, String label})>[
    (confidence: 0.92, label: "We're pretty sure"),
    (confidence: 0.72, label: 'This looks likely'),
    (confidence: 0.42, label: 'Try another photo to be sure'),
  ];

  for (final testCase in cases) {
    testWidgets('uses plain language at ${testCase.confidence}',
        (tester) async {
      final result = ClassificationResult(
        variety: 'Lakatan',
        ripeness: 'Ripe',
        confidence: testCase.confidence,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ResultCard(result: result)),
        ),
      );

      expect(find.text('Lakatan — Ripe'), findsOneWidget);
      expect(find.text(testCase.label), findsOneWidget);
    });
  }
}
