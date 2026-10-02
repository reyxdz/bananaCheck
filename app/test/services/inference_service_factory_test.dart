import 'dart:io';

import 'package:banana_classifier/models/classification_result.dart';
import 'package:banana_classifier/services/inference_service.dart';
import 'package:banana_classifier/services/inference_service_factory.dart';
import 'package:banana_classifier/services/mock_inference_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// A trivial stand-in used to prove which branch the factory took.
class _FakeRealService implements InferenceService {
  @override
  Future<ClassificationResult> classify(File imageFile) async {
    return ClassificationResult(
      variety: 'Lakatan',
      ripeness: 'Ripe',
      confidence: 1.0,
    );
  }
}

void main() {
  test('uses the real service when it loads successfully', () async {
    final real = _FakeRealService();

    final service = await buildInferenceService(
      loadReal: () async => real,
      loadMock: MockInferenceService.new,
    );

    expect(service, same(real));
  });

  test('falls back to the mock when the real service fails to load', () async {
    final service = await buildInferenceService(
      loadReal: () async => throw Exception('model asset missing'),
      loadMock: MockInferenceService.new,
    );

    expect(service, isA<MockInferenceService>());
  });

  test('fallback service still classifies without throwing', () async {
    final service = await buildInferenceService(
      loadReal: () async => throw Exception('boom'),
      loadMock: MockInferenceService.new,
    );

    final result = await service.classify(File('unused.jpg'));
    expect(result, isA<ClassificationResult>());
  });

  test('isDemoInference flags only the mock fallback', () {
    expect(isDemoInference(MockInferenceService()), isTrue);
    expect(isDemoInference(_FakeRealService()), isFalse);
  });

  test('a failed model load ends up in demo mode', () async {
    final service = await buildInferenceService(
      loadReal: () async => throw Exception('missing .tflite'),
      loadMock: MockInferenceService.new,
    );

    expect(isDemoInference(service), isTrue);
  });
}
