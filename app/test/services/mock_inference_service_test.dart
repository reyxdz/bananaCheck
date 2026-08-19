import 'dart:io';

import 'package:banana_classifier/models/classification_result.dart';
import 'package:banana_classifier/services/mock_inference_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('returns its deterministic configured result', () async {
    final expected = ClassificationResult(
      variety: 'Saba',
      ripeness: 'Unripe',
      confidence: 0.88,
    );
    final service = MockInferenceService(result: expected);

    final actual = await service.classify(File('unused.jpg'));

    expect(actual, same(expected));
  });
}
