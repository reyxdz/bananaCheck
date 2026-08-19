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
}
