import 'dart:io';

import 'package:banana_classifier/models/app_exception.dart';
import 'package:banana_classifier/models/classification_result.dart';
import 'package:banana_classifier/services/tflite_inference_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:mocktail/mocktail.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

class _MockInterpreter extends Mock implements Interpreter {}

/// Stubs [Interpreter.run] so the output tensor is filled with [probabilities].
void _stubRun(_MockInterpreter interpreter, List<double> probabilities) {
  when(() => interpreter.run(any<Object>(), any<Object>())).thenAnswer(
    (invocation) {
      final output = invocation.positionalArguments[1] as List<List<double>>;
      output[0].setAll(0, probabilities);
    },
  );
}

void main() {
  setUpAll(() {
    registerFallbackValue(Object());
  });

  // ═══════════════════════════════════════════════════════════════════════
  //  parseLabels
  // ═══════════════════════════════════════════════════════════════════════
  group('parseLabels', () {
    test('trims lines and drops blank ones', () {
      const raw = 'Cavendish_Unripe\n  Cavendish_Ripe  \n\nSaba_Overripe\n';

      final labels = TFLiteInferenceService.parseLabels(raw);

      expect(labels, ['Cavendish_Unripe', 'Cavendish_Ripe', 'Saba_Overripe']);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  //  decodeProbabilities (pure logic — mirrors ml.inference_contract)
  // ═══════════════════════════════════════════════════════════════════════
  group('decodeProbabilities', () {
    const labels = ['Cavendish_Unripe', 'Lakatan_Ripe', 'Saba_Overripe'];

    test('picks the argmax class and splits variety/ripeness', () {
      final result = TFLiteInferenceService.decodeProbabilities(
        [0.1, 0.7, 0.2],
        labels,
      );

      expect(result.variety, 'Lakatan');
      expect(result.ripeness, 'Ripe');
      expect(result.confidence, closeTo(0.7, 1e-9));
    });

    test('supports the pipe-delimited label format', () {
      final result = TFLiteInferenceService.decodeProbabilities(
        [0.9, 0.05, 0.05],
        ['Cavendish|Unripe', 'Lakatan|Ripe', 'Saba|Overripe'],
      );

      expect(result.variety, 'Cavendish');
      expect(result.ripeness, 'Unripe');
    });

    test('throws when probability length does not match labels', () {
      expect(
        () => TFLiteInferenceService.decodeProbabilities([0.5, 0.5], labels),
        throwsArgumentError,
      );
    });

    test('clamps confidence into the valid [0, 1] range', () {
      // A tiny floating-point overshoot must not violate the
      // ClassificationResult invariant.
      final result = TFLiteInferenceService.decodeProbabilities(
        [1.0000001, 0.0, 0.0],
        labels,
      );

      expect(result.confidence, lessThanOrEqualTo(1.0));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  //  imageToInput (preprocessing)
  // ═══════════════════════════════════════════════════════════════════════
  group('imageToInput', () {
    test('produces a [1, size, size, 3] tensor normalised to [0, 1]', () {
      final image = img.Image(width: 10, height: 6);
      img.fill(image, color: img.ColorRgb8(255, 128, 0));

      final input = TFLiteInferenceService.imageToInput(image, 4);

      expect(input.length, 1);
      expect(input[0].length, 4); // height
      expect(input[0][0].length, 4); // width
      expect(input[0][0][0].length, 3); // channels

      final pixel = input[0][0][0];
      expect(pixel[0], closeTo(1.0, 1e-9)); // R = 255/255
      expect(pixel[1], closeTo(128 / 255.0, 1e-6)); // G
      expect(pixel[2], closeTo(0.0, 1e-9)); // B
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  //  Constructor validation
  // ═══════════════════════════════════════════════════════════════════════
  group('constructor', () {
    test('rejects empty labels', () {
      expect(
        () => TFLiteInferenceService(
          interpreter: _MockInterpreter(),
          labels: const [],
        ),
        throwsArgumentError,
      );
    });

    test('rejects non-positive input size', () {
      expect(
        () => TFLiteInferenceService(
          interpreter: _MockInterpreter(),
          labels: const ['A_B'],
          inputSize: 0,
        ),
        throwsArgumentError,
      );
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  //  classify (end-to-end with a mocked interpreter + real image file)
  // ═══════════════════════════════════════════════════════════════════════
  group('classify', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('tflite_test');
    });

    tearDown(() {
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });

    File writeJpeg() {
      final image = img.Image(width: 8, height: 8);
      img.fill(image, color: img.ColorRgb8(10, 200, 50));
      final file = File('${tempDir.path}/banana.jpg')
        ..writeAsBytesSync(img.encodeJpg(image));
      return file;
    }

    test('preprocesses, runs the model, and decodes the winning class',
        () async {
      final interpreter = _MockInterpreter();
      _stubRun(interpreter, [0.05, 0.9, 0.05]);

      final service = TFLiteInferenceService(
        interpreter: interpreter,
        labels: const ['Cavendish_Unripe', 'Lakatan_Ripe', 'Saba_Overripe'],
        inputSize: 4,
      );

      final result = await service.classify(writeJpeg());

      expect(result.variety, 'Lakatan');
      expect(result.ripeness, 'Ripe');
      expect(result.confidence, closeTo(0.9, 1e-9));
      verify(() => interpreter.run(any<Object>(), any<Object>())).called(1);
    });

    test('throws ImageProcessingException on an undecodable file', () async {
      final interpreter = _MockInterpreter();
      final badFile = File('${tempDir.path}/broken.jpg')
        ..writeAsBytesSync([0, 1, 2, 3]); // not a valid image

      final service = TFLiteInferenceService(
        interpreter: interpreter,
        labels: const ['A_B', 'C_D'],
        inputSize: 4,
      );

      expect(
        () => service.classify(badFile),
        throwsA(isA<ImageProcessingException>()),
      );
      verifyNever(() => interpreter.run(any<Object>(), any<Object>()));
    });

    test('throws ImageProcessingException on a missing file', () async {
      final service = TFLiteInferenceService(
        interpreter: _MockInterpreter(),
        labels: const ['A_B', 'C_D'],
        inputSize: 4,
      );

      expect(
        () => service.classify(File('${tempDir.path}/does_not_exist.jpg')),
        throwsA(isA<ImageProcessingException>()),
      );
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  //  dispose
  // ═══════════════════════════════════════════════════════════════════════
  group('dispose', () {
    test('closes the interpreter', () {
      final interpreter = _MockInterpreter();
      when(() => interpreter.close()).thenReturn(null);

      TFLiteInferenceService(
        interpreter: interpreter,
        labels: const ['A_B'],
      ).dispose();

      verify(() => interpreter.close()).called(1);
    });
  });

  // ── A21: the bundled assets must agree with the trained model ──
  group('shipped model assets', () {
    final labels = TFLiteInferenceService.parseLabels(
      File(TFLiteInferenceService.defaultLabelsAsset).readAsStringSync(),
    );

    test('labels.txt lists all 18 variety × ripeness classes plus NotBanana',
        () {
      expect(labels, hasLength(19));
      expect(labels.toSet(), hasLength(19));
      expect(labels, contains(ClassificationResult.notBananaVariety));
      for (final label in labels) {
        if (label == ClassificationResult.notBananaVariety) {
          // The rejection class has no ripeness, and deliberately no
          // underscore — decodeProbabilities splits on the first one.
          expect(label, isNot(contains('_')));
          continue;
        }
        expect(label, matches(RegExp(r'^[A-Z][a-z]+_(Unripe|Ripe|Overripe)$')));
      }
    });

    test('labels.txt is in the model output order (alphabetical)', () {
      // The model was trained with Keras' image_dataset_from_directory, which
      // numbers classes by sorted folder name. Any other order shows every
      // scan under the wrong variety/ripeness.
      expect(labels, [...labels]..sort());
    });

    test('the validated model file is bundled', () {
      final model = File(TFLiteInferenceService.defaultModelAsset);
      expect(model.existsSync(), isTrue);
      // A real MobileNetV2 export is several MB — not an empty placeholder.
      expect(model.lengthSync(), greaterThan(1024 * 1024));
    });
  });
}
