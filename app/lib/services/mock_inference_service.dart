import 'dart:io';

import '../models/app_exception.dart';
import '../models/classification_result.dart';
import 'inference_service.dart';

/// Fake implementation of [InferenceService] for development and testing.
///
/// Returns a configurable [ClassificationResult] after an optional [delay].
/// Set [shouldThrow] to `true` to simulate error scenarios — the service
/// will throw [errorToThrow] (defaults to [UnknownException]).
class MockInferenceService implements InferenceService {
  MockInferenceService({
    this.delay = Duration.zero,
    ClassificationResult? result,
    this.shouldThrow = false,
    AppException? errorToThrow,
  })  : result = result ??
            ClassificationResult(
              variety: 'Saba',
              ripeness: 'Ripe',
              confidence: 0.92,
            ),
        errorToThrow = errorToThrow ?? const UnknownException();

  final Duration delay;
  final ClassificationResult result;

  /// When `true`, [classify] throws [errorToThrow] instead of returning.
  final bool shouldThrow;

  /// The error thrown when [shouldThrow] is `true`.
  final AppException errorToThrow;

  @override
  Future<ClassificationResult> classify(File imageFile) async {
    await Future<void>.delayed(delay);
    if (shouldThrow) throw errorToThrow;
    return result;
  }
}
