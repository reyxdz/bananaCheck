import 'package:banana_classifier/models/bundle_scan_result.dart';
import 'package:banana_classifier/models/classification_result.dart';
import 'package:flutter_test/flutter_test.dart';

// ═══════════════════════════════════════════════════════════════════════
//  BundleScanResult / BundleRegion unit tests
// ═══════════════════════════════════════════════════════════════════════

BundleRegion _region({
  int left = 0,
  int top = 0,
  int size = 100,
  String variety = 'Lakatan',
  String ripeness = 'Ripe',
  double confidence = 0.95,
}) {
  return BundleRegion(
    left: left,
    top: top,
    size: size,
    result: ClassificationResult(
      variety: variety,
      ripeness: ripeness,
      confidence: confidence,
    ),
  );
}

void main() {
  group('BundleRegion', () {
    test('rejects a non-positive size', () {
      expect(
        () => _region(size: 0),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('identical regions overlap completely', () {
      expect(_region().overlapWith(_region()), closeTo(1.0, 1e-9));
    });

    test('regions that do not touch have no overlap', () {
      expect(_region().overlapWith(_region(left: 500)), 0);
    });

    test('regions touching edge-to-edge still have no overlap', () {
      expect(_region().overlapWith(_region(left: 100)), 0);
    });

    test('half-shifted regions overlap by a third (IoU, not area)', () {
      // Intersection 50x100 = 5000; union 10000 + 10000 - 5000 = 15000.
      expect(_region().overlapWith(_region(left: 50)), closeTo(1 / 3, 1e-9));
    });

    test('overlap is symmetric', () {
      final a = _region();
      final b = _region(left: 40, top: 30);
      expect(a.overlapWith(b), closeTo(b.overlapWith(a), 1e-9));
    });
  });

  group('BundleScanResult', () {
    test('an empty scan reports nothing found', () {
      final result = BundleScanResult(regions: []);

      expect(result.isEmpty, isTrue);
      expect(result.isBundle, isFalse);
      expect(result.approximateCount, 0);
      expect(result.dominantVariety, isNull);
      expect(result.dominantRipeness, isNull);
      expect(result.ripenessCounts, isEmpty);
    });

    test('a single banana is not a bundle', () {
      final result = BundleScanResult(regions: [_region()]);

      expect(result.isEmpty, isFalse);
      expect(result.isBundle, isFalse);
      expect(result.approximateCount, 1);
    });

    test('counts ripeness across the bundle', () {
      final result = BundleScanResult(
        regions: [
          _region(ripeness: 'Ripe'),
          _region(left: 200, ripeness: 'Ripe'),
          _region(left: 400, ripeness: 'Overripe'),
        ],
      );

      expect(result.isBundle, isTrue);
      expect(result.ripenessCounts, {'Ripe': 2, 'Overripe': 1});
      expect(result.dominantRipeness, 'Ripe');
      expect(result.hasMixedRipeness, isTrue);
    });

    test('a bundle at one ripeness stage is not mixed', () {
      final result = BundleScanResult(
        regions: [
          _region(ripeness: 'Ripe'),
          _region(left: 200, ripeness: 'Ripe'),
        ],
      );

      expect(result.hasMixedRipeness, isFalse);
    });

    test('the majority variety wins even with an odd region out', () {
      final result = BundleScanResult(
        regions: [
          _region(variety: 'Lakatan'),
          _region(left: 200, variety: 'Lakatan'),
          _region(left: 400, variety: 'Cordova'),
        ],
      );

      expect(result.dominantVariety, 'Lakatan');
    });

    test('ignores the empty ripeness of a non-banana region', () {
      // Defensive: the scanner filters these out, but the model should never
      // put "NotBanana — " on screen if one slips through.
      final result = BundleScanResult(
        regions: [
          _region(ripeness: 'Ripe'),
          _region(
            left: 200,
            variety: ClassificationResult.notBananaVariety,
            ripeness: '',
          ),
        ],
      );

      expect(result.ripenessCounts, {'Ripe': 1});
      expect(result.dominantRipeness, 'Ripe');
    });
  });
}
