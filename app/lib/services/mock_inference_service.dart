import 'dart:io';

import '../models/classification_result.dart';
import 'inference_service.dart';

class MockInferenceService implements InferenceService {
  MockInferenceService({
    this.delay = Duration.zero,
    ClassificationResult? result,
  }) : result = result ??
            ClassificationResult(
              variety: 'Lakatan',
              ripeness: 'Ripe',
              confidence: 0.92,
            );

  final Duration delay;
  final ClassificationResult result;

  @override
  Future<ClassificationResult> classify(File imageFile) async {
    await Future<void>.delayed(delay);
    return result;
  }
}
