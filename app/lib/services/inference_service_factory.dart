import 'package:flutter/foundation.dart';

import 'inference_service.dart';
import 'mock_inference_service.dart';
import 'tflite_inference_service.dart';

/// Builds the [InferenceService] the app runs against (A21 integration).
///
/// Prefers the real on-device [TFLiteInferenceService]; if the bundled model
/// cannot be loaded — e.g. the validated `.tflite` has not been dropped into
/// `assets/model/` yet — it falls back to [MockInferenceService] so the app
/// still launches. Once the real model asset is present, no code change is
/// needed: the real service is picked up automatically.
Future<InferenceService> createInferenceService() {
  return buildInferenceService(
    loadReal: () => TFLiteInferenceService.create(),
    loadMock: MockInferenceService.new,
  );
}

/// Core factory logic, split out with injectable loaders for testing.
///
/// Returns the result of [loadReal]; if it throws for any reason, returns
/// [loadMock] instead.
@visibleForTesting
Future<InferenceService> buildInferenceService({
  required Future<InferenceService> Function() loadReal,
  required InferenceService Function() loadMock,
}) async {
  try {
    return await loadReal();
  } catch (error) {
    debugPrint(
      '⚠️  DEMO MODE: real TFLite model unavailable ($error).\n'
      '⚠️  Falling back to MockInferenceService: every scan returns the same '
      'fake result. Add assets/model/banana_classifier.tflite to fix.',
    );
    return loadMock();
  }
}

/// Whether [service] is the fake fallback rather than the real model, so the
/// app can flag "demo mode" instead of silently showing fake results.
bool isDemoInference(InferenceService service) =>
    service is MockInferenceService;
