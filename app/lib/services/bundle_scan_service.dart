import 'dart:io';

import 'package:image/image.dart' as img;

import '../models/app_exception.dart';
import '../models/bundle_scan_result.dart';
import '../models/classification_result.dart';
import 'inference_service.dart';

/// Finds the individual bananas in a photo of a bundle.
///
/// The classifier is trained on one whole banana filling the frame, so a photo
/// of several bananas gives one arbitrary answer — it has to pick a single
/// class. This service works around that without a second model: it slides a
/// square window over the photo at a few sizes, classifies each crop, throws
/// away everything the model calls `NotBanana`, and merges the overlapping
/// windows that landed on the same fruit.
///
/// The `NotBanana` class is what makes this possible — it is what rejects the
/// background and half-empty windows that would otherwise each be forced into
/// a variety.
///
/// Two limits worth knowing before trusting the output:
///
/// * **Counts are approximate.** Merging overlapping windows is a heuristic;
///   one banana can survive as two regions, and two touching bananas can merge
///   into one. Present the count as "about N" (§7.3).
/// * **Each banana must be mostly visible.** Measured on the test set, the
///   model reads a banana correctly 91% of the time at 70% visibility but only
///   65% at 50%, so heavily overlapping hands of bananas will under-report.
class BundleScanService {
  BundleScanService({
    required RegionClassifier classifier,
    this.minConfidence = defaultMinConfidence,
    this.minMargin = defaultMinMargin,
    this.maxOverlap = defaultMaxOverlap,
    this.windowScales = defaultWindowScales,
  }) : _classifier = classifier;

  /// Minimum confidence for a window to count as a banana.
  ///
  /// Higher than the single-scan gate: with a hundred windows to choose from,
  /// discarding a real banana costs less than inventing one.
  static const double defaultMinConfidence = 0.80;

  /// Minimum gap to the runner-up class for a window to count.
  static const double defaultMinMargin = 0.30;

  /// Above this overlap, two regions are treated as the same banana.
  static const double defaultMaxOverlap = 0.30;

  /// Window sizes to try, as a fraction of the photo's shorter side.
  ///
  /// Three scales cover bananas that sit a little closer or further from the
  /// camera without multiplying the number of crops too far.
  static const List<double> defaultWindowScales = [0.40, 0.50, 0.60];

  /// Fraction of the window size to step between crops.
  static const double _strideFraction = 0.25;

  final RegionClassifier _classifier;
  final double minConfidence;
  final double minMargin;
  final double maxOverlap;
  final List<double> windowScales;

  /// Scan [imageFile] and report every banana found.
  ///
  /// Throws [ImageProcessingException] if the photo cannot be decoded, matching
  /// how [InferenceService.classify] reports the same failure.
  Future<BundleScanResult> scan(File imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final decoded = decodeUprightImage(bytes);
      if (decoded == null) {
        throw const ImageProcessingException();
      }
      return scanImage(decoded);
    } on AppException {
      rethrow;
    } catch (_) {
      // A missing file, or bytes the decoder chokes on, are the same problem
      // to the user as an undecodable photo (§7.3).
      throw const ImageProcessingException();
    }
  }

  /// Scan an already-decoded [image]. Split out so the sliding-window logic can
  /// be tested without touching the filesystem.
  BundleScanResult scanImage(img.Image image) {
    final candidates = _collectCandidates(image);

    // Strongest first, so merging keeps the best read of each banana.
    candidates.sort(
      (a, b) => b.result.confidence.compareTo(a.result.confidence),
    );

    return BundleScanResult(regions: _mergeOverlapping(candidates));
  }

  /// Every window the model confidently called a banana.
  List<BundleRegion> _collectCandidates(img.Image image) {
    final shorterSide = image.width < image.height ? image.width : image.height;
    final candidates = <BundleRegion>[];

    for (final scale in windowScales) {
      final windowSize = (shorterSide * scale).round();
      if (windowSize <= 0) continue;

      final stride =
          (windowSize * _strideFraction).round().clamp(1, windowSize);

      for (var top = 0; top <= image.height - windowSize; top += stride) {
        for (var left = 0; left <= image.width - windowSize; left += stride) {
          final crop = img.copyCrop(
            image,
            x: left,
            y: top,
            width: windowSize,
            height: windowSize,
          );

          final result = _classifier.classifyRegion(crop);
          if (!_isConfidentBanana(result)) continue;

          candidates.add(
            BundleRegion(
              left: left,
              top: top,
              size: windowSize,
              result: result,
            ),
          );
        }
      }
    }

    return candidates;
  }

  bool _isConfidentBanana(ClassificationResult result) =>
      result.isBanana &&
      result.confidence >= minConfidence &&
      result.margin >= minMargin;

  /// Keep the strongest region and drop every later one that overlaps it —
  /// non-maximum suppression, so one banana yields one region.
  List<BundleRegion> _mergeOverlapping(List<BundleRegion> sorted) {
    final kept = <BundleRegion>[];

    for (final candidate in sorted) {
      final overlapsKept = kept.any(
        (region) => candidate.overlapWith(region) >= maxOverlap,
      );
      if (!overlapsKept) kept.add(candidate);
    }

    return kept;
  }
}
