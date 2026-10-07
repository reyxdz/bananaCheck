import 'dart:io';

import 'package:banana_classifier/models/app_exception.dart';
import 'package:banana_classifier/models/classification_result.dart';
import 'package:banana_classifier/services/bundle_scan_service.dart';
import 'package:banana_classifier/services/inference_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

// ═══════════════════════════════════════════════════════════════════════
//  BundleScanService — sliding window + overlap merging
// ═══════════════════════════════════════════════════════════════════════

/// A classifier that stands in for the real model's behaviour on a crop.
///
/// The real model only reads a banana reliably when the fruit fills most of
/// the frame — measured on the test set, 91% correct at 70% visibility but 65%
/// at 50%. This fake mirrors that: a crop is only called a banana when one
/// painted block covers at least [minCoverage] of it. Without that rule the
/// fake would accept any crop merely touching a block, and the tests would
/// prove nothing about the sliding window.
class _ColourClassifier implements RegionClassifier {
  _ColourClassifier(this.byColour, {this.confidenceFromCoverage = false});

  /// Maps a block's red channel to the result it should produce.
  final Map<int, ClassificationResult> byColour;

  /// Share of the crop one block must fill before this fake calls it a
  /// banana. Set high because the real model wants the fruit framed, not just
  /// present: a crop holding a banana off in one corner is not a confident
  /// read of that banana.
  static const double minCoverage = 0.85;

  /// When true, confidence is the measured coverage — so a crop framing the
  /// fruit better scores higher, as the real model does.
  final bool confidenceFromCoverage;

  int callCount = 0;

  static final ClassificationResult _notBanana = ClassificationResult(
    variety: ClassificationResult.notBananaVariety,
    ripeness: '',
    confidence: 0.99,
    margin: 0.99,
  );

  @override
  ClassificationResult classifyRegion(img.Image region) {
    callCount++;

    final counts = <int, int>{};
    var sampled = 0;
    for (var y = 0; y < region.height; y += 4) {
      for (var x = 0; x < region.width; x += 4) {
        final red = region.getPixel(x, y).r.toInt();
        sampled++;
        if (red == 0) continue; // background
        counts[red] = (counts[red] ?? 0) + 1;
      }
    }
    if (counts.isEmpty || sampled == 0) return _notBanana;

    final dominant = counts.entries.reduce((a, b) => b.value > a.value ? b : a);
    final coverage = dominant.value / sampled;
    if (coverage < minCoverage) return _notBanana;

    final base = byColour[dominant.key];
    if (base == null) return _notBanana;
    if (!confidenceFromCoverage) return base;

    return ClassificationResult(
      variety: base.variety,
      ripeness: base.ripeness,
      confidence: coverage.clamp(0.0, 1.0),
      margin: base.margin,
    );
  }
}

ClassificationResult _banana({
  String variety = 'Lakatan',
  String ripeness = 'Ripe',
  double confidence = 0.99,
  double margin = 0.90,
}) =>
    ClassificationResult(
      variety: variety,
      ripeness: ripeness,
      confidence: confidence,
      margin: margin,
    );

/// A canvas with [blocks] painted on it, each a solid square of its own red
/// value — a stand-in for bananas laid out on a background.
img.Image _canvas({
  int width = 400,
  int height = 400,
  Map<int, (int, int, int)> blocks = const {},
}) {
  final image = img.Image(width: width, height: height);
  img.fill(image, color: img.ColorRgb8(0, 0, 0));

  blocks.forEach((red, position) {
    final (left, top, size) = position;
    img.fillRect(
      image,
      x1: left,
      y1: top,
      x2: left + size - 1,
      y2: top + size - 1,
      color: img.ColorRgb8(red, 0, 0),
    );
  });

  return image;
}

void main() {
  group('BundleScanService', () {
    test('finds nothing when the model rejects every window', () {
      final service = BundleScanService(
        classifier: _ColourClassifier(const {}),
      );

      final result = service.scanImage(_canvas());

      expect(result.isEmpty, isTrue);
      expect(result.approximateCount, 0);
    });

    test('a photo of one banana is not reported as a bundle', () {
      // One large block, so every accepted window lands on the same fruit and
      // merging collapses them to a single region.
      final service = BundleScanService(
        classifier: _ColourClassifier({100: _banana()}),
      );

      final result = service.scanImage(
        _canvas(blocks: const {100: (100, 100, 200)}),
      );

      expect(result.approximateCount, 1);
      expect(result.isBundle, isFalse);
      expect(result.dominantVariety, 'Lakatan');
    });

    test('separates two bananas far apart in the frame', () {
      final service = BundleScanService(
        classifier: _ColourClassifier({
          100: _banana(ripeness: 'Ripe'),
          200: _banana(ripeness: 'Overripe'),
        }),
      );

      final result = service.scanImage(
        _canvas(
          width: 800,
          height: 400,
          blocks: const {
            100: (20, 100, 180),
            200: (600, 100, 180),
          },
        ),
      );

      expect(result.isBundle, isTrue);
      expect(result.approximateCount, 2);
      expect(result.ripenessCounts, {'Ripe': 1, 'Overripe': 1});
      expect(result.hasMixedRipeness, isTrue);
    });

    test('drops windows the model is not confident about', () {
      final service = BundleScanService(
        classifier: _ColourClassifier({100: _banana(confidence: 0.5)}),
      );

      final result = service.scanImage(
        _canvas(blocks: const {100: (100, 100, 200)}),
      );

      expect(result.isEmpty, isTrue);
    });

    test('drops windows where the top two classes are close', () {
      final service = BundleScanService(
        classifier: _ColourClassifier({100: _banana(margin: 0.05)}),
      );

      final result = service.scanImage(
        _canvas(blocks: const {100: (100, 100, 200)}),
      );

      expect(result.isEmpty, isTrue);
    });

    test('never keeps a NotBanana region', () {
      final service = BundleScanService(
        classifier: _ColourClassifier({
          100: ClassificationResult(
            variety: ClassificationResult.notBananaVariety,
            ripeness: '',
            confidence: 0.99,
            margin: 0.99,
          ),
        }),
      );

      final result = service.scanImage(
        _canvas(blocks: const {100: (100, 100, 200)}),
      );

      expect(result.isEmpty, isTrue);
    });

    test('merging keeps the best-framed read of the same banana', () {
      // Many windows land on one banana; the one that frames it fully scores
      // highest. Merging must keep that read, not whichever came first.
      final service = BundleScanService(
        classifier: _ColourClassifier(
          {100: _banana()},
          confidenceFromCoverage: true,
        ),
      );

      final result = service.scanImage(
        _canvas(blocks: const {100: (100, 100, 200)}),
      );

      expect(result.approximateCount, 1);
      expect(result.regions.single.result.confidence, 1.0);
    });

    test('scan() reports an undecodable file as an image problem', () async {
      final file = File(
        '${Directory.systemTemp.createTempSync('bundle').path}/not_an_image.jpg',
      )..writeAsBytesSync([1, 2, 3, 4]);

      final service = BundleScanService(
        classifier: _ColourClassifier(const {}),
      );

      await expectLater(
        () => service.scan(file),
        throwsA(isA<ImageProcessingException>()),
      );
    });

    test('scan() reports a missing file as an image problem', () async {
      final service = BundleScanService(
        classifier: _ColourClassifier(const {}),
      );

      await expectLater(
        () => service.scan(File('does/not/exist.jpg')),
        throwsA(isA<ImageProcessingException>()),
      );
    });

    test('tighter window scales mean fewer crops to classify', () {
      // Scanning cost is the feature's main UX risk (every crop is one model
      // run), so the knob that controls it is worth pinning down.
      final many = _ColourClassifier(const {});
      BundleScanService(
        classifier: many,
        windowScales: const [0.40, 0.50, 0.60],
      ).scanImage(_canvas());

      final few = _ColourClassifier(const {});
      BundleScanService(
        classifier: few,
        windowScales: const [0.50],
      ).scanImage(_canvas());

      expect(few.callCount, lessThan(many.callCount));
      expect(few.callCount, greaterThan(0));
    });
  });
}
