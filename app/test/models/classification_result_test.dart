import 'package:banana_classifier/models/classification_result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('accepts normalized confidence values', () {
    final result = ClassificationResult(
      variety: 'Lakatan',
      ripeness: 'Ripe',
      confidence: 0.92,
    );

    expect(result.variety, 'Lakatan');
    expect(result.ripeness, 'Ripe');
    expect(result.confidence, 0.92);
  });

  test('rejects confidence outside zero to one', () {
    expect(
      () => ClassificationResult(
        variety: 'Lakatan',
        ripeness: 'Ripe',
        confidence: 1.1,
      ),
      throwsArgumentError,
    );
  });

  group('isConfidentBanana', () {
    ClassificationResult r({
      String variety = 'Saba',
      double confidence = 0.9,
      double margin = 0.8,
    }) =>
        ClassificationResult(
          variety: variety,
          ripeness:
              variety == ClassificationResult.notBananaVariety ? '' : 'Ripe',
          confidence: confidence,
          margin: margin,
        );

    test('a sure banana passes', () {
      expect(r().isConfidentBanana, isTrue);
    });

    test('the limits themselves pass', () {
      expect(
        r(
          confidence: ClassificationResult.lowConfidenceThreshold,
          margin: ClassificationResult.lowMarginThreshold,
        ).isConfidentBanana,
        isTrue,
      );
    });

    test('low confidence, low margin or NotBanana fail', () {
      expect(r(confidence: 0.49).isConfidentBanana, isFalse);
      expect(r(margin: 0.09).isConfidentBanana, isFalse);
      expect(
        r(variety: ClassificationResult.notBananaVariety).isConfidentBanana,
        isFalse,
      );
    });
  });
}
