import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

import '../models/app_exception.dart';
import '../models/classification_result.dart';
import 'inference_service.dart';

/// Real on-device [InferenceService] backed by a bundled TFLite model (B13).
///
/// Loads the `.tflite` model and `labels.txt` produced by the ML pipeline
/// (B11/B12) from app assets, then for each image:
///
/// 1. decodes and resizes it to the model's expected square input,
/// 2. normalises pixel values to `[0, 1]` (matching the training contract),
/// 3. runs the interpreter, and
/// 4. decodes the probability vector into a [ClassificationResult].
///
/// The confidence is the maximum softmax probability; the winning label
/// (`Variety_Ripeness`) is split into its variety and ripeness parts. The
/// low-confidence gate is intentionally **not** applied here — that policy
/// lives in the UI layer (`AnalyzingScreen`) so this service stays a thin,
/// swappable stand-in for [MockInferenceService] per the §9 contract.
///
/// Construct via [TFLiteInferenceService.create] in production; the primary
/// constructor takes an already-loaded [Interpreter] and labels so the
/// classification logic can be unit-tested without native assets.
class TFLiteInferenceService
    implements InferenceService, RegionClassifier, LiveFrameClassifier {
  TFLiteInferenceService({
    required Interpreter interpreter,
    required List<String> labels,
    int inputSize = defaultInputSize,
    Uint8List? modelBytes,
  })  : _interpreter = interpreter,
        _labels = labels,
        _inputSize = inputSize,
        _modelBytes = modelBytes {
    if (labels.isEmpty) {
      throw ArgumentError.value(labels, 'labels', 'must not be empty');
    }
    if (inputSize <= 0) {
      throw ArgumentError.value(inputSize, 'inputSize', 'must be positive');
    }
  }

  /// Default square input dimension (MobileNetV2 expects 224×224).
  static const int defaultInputSize = 224;

  /// Default asset paths for the bundled model and its labels.
  static const String defaultModelAsset =
      'assets/model/banana_classifier.tflite';
  static const String defaultLabelsAsset = 'assets/model/labels.txt';

  final Interpreter _interpreter;
  final List<String> _labels;
  final int _inputSize;

  /// The model file, kept so live classification can build its own
  /// interpreter. `null` (as in unit tests) turns live classification off.
  final Uint8List? _modelBytes;

  /// Longest a live frame may take before its runner counts as stuck.
  /// [IsolateInterpreter] never reports back if inference fails in its
  /// isolate, so without this one bad frame would stall the hint for good.
  /// Generous, so a slow phone is never mistaken for a stuck one.
  static const liveFrameTimeout = Duration(seconds: 5);

  /// How many times a stuck or failed live runner is rebuilt before live
  /// classification is switched off for the rest of the session.
  static const maxLiveRestarts = 3;

  Interpreter? _liveInterpreter;
  IsolateInterpreter? _liveRunner;
  Future<IsolateInterpreter>? _liveSetup;
  bool _liveBusy = false;
  bool _liveDisabled = false;
  int _liveFailures = 0;
  bool _disposed = false;

  @override
  bool get isAvailable => _modelBytes != null && !_liveDisabled && !_disposed;

  /// Load the model and labels from app assets and build a ready service.
  ///
  /// Reads the model into a buffer (avoiding asset-path prefixing quirks) and
  /// parses the labels file. Throws an [ImageProcessingException] if the model
  /// assets are missing or malformed.
  static Future<TFLiteInferenceService> create({
    String modelAsset = defaultModelAsset,
    String labelsAsset = defaultLabelsAsset,
    int inputSize = defaultInputSize,
  }) async {
    try {
      final modelData = await rootBundle.load(modelAsset);
      final modelBytes = modelData.buffer.asUint8List(
        modelData.offsetInBytes,
        modelData.lengthInBytes,
      );
      final interpreter = Interpreter.fromBuffer(modelBytes);
      final rawLabels = await rootBundle.loadString(labelsAsset);
      return TFLiteInferenceService(
        interpreter: interpreter,
        labels: parseLabels(rawLabels),
        inputSize: inputSize,
        modelBytes: modelBytes,
      );
    } on AppException {
      rethrow;
    } catch (_) {
      throw const ImageProcessingException();
    }
  }

  @override
  Future<ClassificationResult> classify(File imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final decoded = decodeUprightImage(bytes);
      if (decoded == null) {
        throw const ImageProcessingException();
      }

      return classifyRegion(decoded);
    } on AppException {
      rethrow;
    } catch (_) {
      // Any decode/inference failure surfaces as a plain-language image error.
      throw const ImageProcessingException();
    }
  }

  @override
  ClassificationResult classifyRegion(img.Image region) {
    final input = imageToInput(region, _inputSize);
    final output = <List<double>>[List<double>.filled(_labels.length, 0)];
    _interpreter.run(input, output);

    if (kDebugMode) {
      debugPrint('\u{1F34C} ${describeTopScores(output.first, _labels)}');
    }

    return decodeProbabilities(output.first, _labels);
  }

  @override
  Future<ClassificationResult?> classifyFrame(img.Image region) async {
    final bytes = _modelBytes;
    if (bytes == null || _liveBusy || _liveDisabled || _disposed) return null;
    _liveBusy = true;
    try {
      final runner = await (_liveSetup ??= _createLiveRunner(bytes));
      if (_disposed) return null;

      final input = imageToInput(region, _inputSize);
      final output = <List<double>>[List<double>.filled(_labels.length, 0)];
      await runner.run(input, output).timeout(liveFrameTimeout);
      if (_disposed) return null;

      if (kDebugMode) {
        debugPrint(
            '\u{1F34C} live ${describeTopScores(output.first, _labels)}');
      }
      return decodeProbabilities(output.first, _labels);
    } catch (_) {
      // Stuck (timeout) or broken: rebuild the runner on the next frame, up
      // to [maxLiveRestarts] times. Scanning itself is never affected.
      if (!_disposed) _abandonLiveRunner();
      return null;
    } finally {
      _liveBusy = false;
      if (_disposed) _closeLive();
    }
  }

  /// Builds the interpreter used only for live frames, on its own isolate.
  Future<IsolateInterpreter> _createLiveRunner(Uint8List bytes) async {
    final interpreter = Interpreter.fromBuffer(bytes);
    try {
      final runner = await IsolateInterpreter.create(
        address: interpreter.address,
        debugName: 'LiveBananaCheck',
      );
      _liveInterpreter = interpreter;
      _liveRunner = runner;
      return runner;
    } catch (_) {
      // Nothing is running on it yet, so it is safe to free.
      interpreter.close();
      rethrow;
    }
  }

  /// Drops the current live runner so the next frame builds a fresh one.
  ///
  /// The isolate is stopped, but its interpreter is deliberately not freed:
  /// a stuck isolate may still be inside native inference on it, and freeing
  /// memory under a running inference would crash the app. Capping restarts
  /// at [maxLiveRestarts] bounds what is left behind to a few interpreters.
  void _abandonLiveRunner() {
    final runner = _liveRunner;
    _liveRunner = null;
    _liveInterpreter = null;
    _liveSetup = null;
    runner?.close();

    _liveFailures++;
    if (_liveFailures > maxLiveRestarts) _liveDisabled = true;
  }

  void _closeLive() {
    final runner = _liveRunner;
    final interpreter = _liveInterpreter;
    _liveRunner = null;
    _liveInterpreter = null;
    // Stop the isolate before deleting the interpreter it points at.
    runner?.close().whenComplete(() => interpreter?.close());
    if (runner == null) interpreter?.close();
  }

  /// Release native interpreter resources. Call when the service is disposed.
  void dispose() {
    _disposed = true;
    _interpreter.close();
    // A live frame still running closes its interpreter when it finishes.
    if (!_liveBusy) _closeLive();
  }

  // -------------------------------------------------------------------------
  // Pure helpers (no plugin / asset dependencies — unit-testable)
  // -------------------------------------------------------------------------

  /// Parse a raw `labels.txt` string into a trimmed, blank-free list.
  @visibleForTesting
  static List<String> parseLabels(String raw) => raw
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList();

  /// Resize *image* to `size × size` and normalise to a `[1, size, size, 3]`
  /// float tensor with values in `[0, 1]`, matching the training contract.
  @visibleForTesting
  static List<List<List<List<double>>>> imageToInput(
    img.Image image,
    int size,
  ) {
    final resized = img.copyResize(
      image,
      width: size,
      height: size,
      interpolation: img.Interpolation.linear,
    );

    return <List<List<List<double>>>>[
      List<List<List<double>>>.generate(
        size,
        (y) => List<List<double>>.generate(size, (x) {
          final pixel = resized.getPixel(x, y);
          return <double>[
            pixel.r / 255.0,
            pixel.g / 255.0,
            pixel.b / 255.0,
          ];
        }),
      ),
    ];
  }

  /// Human-readable summary of the highest-scoring classes, for debug logs.
  ///
  /// Shows the top [count] `label probability%` pairs, highest first, so a
  /// scan can be sanity-checked against the photo that produced it (e.g. to
  /// see whether the right variety merely lost to a close runner-up).
  @visibleForTesting
  static String describeTopScores(
    List<double> probabilities,
    List<String> labels, {
    int count = 3,
  }) {
    final ranked = List<int>.generate(probabilities.length, (i) => i)
      ..sort((a, b) => probabilities[b].compareTo(probabilities[a]));

    return ranked
        .take(count)
        .map((i) =>
            '${labels[i]} ${(probabilities[i] * 100).toStringAsFixed(1)}%')
        .join('  |  ');
  }

  /// Decode a probability vector into a [ClassificationResult].
  ///
  /// Picks the highest-probability class (confidence = that probability),
  /// records the gap to the runner-up as the margin, and splits the winning
  /// label into variety and ripeness. Labels may use either the
  /// `Variety_Ripeness` (shipped `labels.txt`) or `Variety|Ripeness` format.
  @visibleForTesting
  static ClassificationResult decodeProbabilities(
    List<double> probabilities,
    List<String> labels,
  ) {
    if (probabilities.length != labels.length) {
      throw ArgumentError(
        'Expected ${labels.length} probabilities, '
        'got ${probabilities.length}',
      );
    }

    var maxIndex = 0;
    var runnerUp = double.negativeInfinity;
    for (var i = 1; i < probabilities.length; i++) {
      if (probabilities[i] > probabilities[maxIndex]) {
        runnerUp = probabilities[maxIndex];
        maxIndex = i;
      } else if (probabilities[i] > runnerUp) {
        runnerUp = probabilities[i];
      }
    }
    if (runnerUp == double.negativeInfinity) {
      runnerUp = 0;
    }

    final label = labels[maxIndex];
    final separator = label.contains('|') ? '|' : '_';
    final splitAt = label.indexOf(separator);
    final variety = splitAt >= 0 ? label.substring(0, splitAt) : label;
    final ripeness = splitAt >= 0 ? label.substring(splitAt + 1) : '';

    return ClassificationResult(
      variety: variety,
      ripeness: ripeness,
      confidence: probabilities[maxIndex].clamp(0.0, 1.0),
      margin: (probabilities[maxIndex] - runnerUp).clamp(0.0, 1.0),
    );
  }
}
