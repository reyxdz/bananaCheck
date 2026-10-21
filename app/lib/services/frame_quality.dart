import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:image/image.dart' as img;

import '../models/classification_result.dart';

/// What the live camera view should tell the user right now.
enum ScanCondition {
  /// No banana-like colours in the frame yet.
  searching,

  /// Banana-like colours fill a good part of the frame and the light is fine.
  ready,

  /// Too dark for a reliable scan.
  tooDark,

  /// Still searching after [ScanConditionTracker.notFoundAfter] — time for a
  /// fallback tip (move closer, or upload a photo instead).
  notFound,
}

/// Cheap per-frame measurements taken from the live camera stream.
///
/// This is a colour/brightness heuristic to drive on-screen hints only — it
/// is not the classifier. The real variety/ripeness result still comes from
/// the model after the user taps Scan.
class FrameStats {
  const FrameStats({required this.brightness, required this.bananaCoverage});

  /// Mean luma of the whole frame, 0 (black) to 1 (white).
  final double brightness;

  /// Share of the centre region whose colour looks like banana peel
  /// (yellow, green or brown), 0 to 1.
  final double bananaCoverage;
}

/// Measures a YUV 4:2:0 frame without decoding it to RGB.
///
/// Works for both camera layouts: Android's three planes (Y, U, V — U and V
/// may be interleaved with `uvPixelStride` 2) and iOS's two-plane NV12
/// (pass the CbCr plane as both [u] and [v] with `vOffset` 1).
///
/// Only every [step]-th pixel is read, so a 640×480 frame costs a few
/// thousand reads — fine to run a few times a second on low-end phones.
FrameStats analyzeYuvFrame({
  required int width,
  required int height,
  required Uint8List y,
  required int yRowStride,
  required Uint8List u,
  required Uint8List v,
  required int uvRowStride,
  required int uvPixelStride,
  int uOffset = 0,
  int vOffset = 0,
  double centerRegion = 0.6,
  int step = 8,
}) {
  var lumaSum = 0;
  var lumaCount = 0;
  var bananaCount = 0;
  var centerCount = 0;

  final left = width * (1 - centerRegion) / 2;
  final right = width - left;
  final top = height * (1 - centerRegion) / 2;
  final bottom = height - top;

  for (var row = 0; row < height; row += step) {
    for (var col = 0; col < width; col += step) {
      final luma = y[row * yRowStride + col];
      lumaSum += luma;
      lumaCount++;

      if (col < left || col >= right || row < top || row >= bottom) continue;
      centerCount++;

      final uvIndex = (row ~/ 2) * uvRowStride + (col ~/ 2) * uvPixelStride;
      final cb = u[uvIndex + uOffset];
      final cr = v[uvIndex + vOffset];
      if (isBananaColor(luma, cb, cr)) bananaCount++;
    }
  }

  return FrameStats(
    brightness: lumaCount == 0 ? 0 : lumaSum / lumaCount / 255,
    bananaCoverage: centerCount == 0 ? 0 : bananaCount / centerCount,
  );
}

/// Cuts [uprightCrop] out of a YUV 4:2:0 camera frame and returns it as an
/// [outputSize]×[outputSize] RGB image, ready for the classifier.
///
/// Camera frames arrive in the sensor's orientation (landscape on Android),
/// while the preview, the scan reticle and a captured photo are upright.
/// [rotation] is the clockwise turn (0, 90, 180 or 270) that makes the frame
/// upright, and [uprightCrop] is given in those upright pixel coordinates,
/// the same space [imageCropForReticle] works in. That keeps the live check
/// looking at exactly the region a capture would send to the model.
///
/// The crop is stretched to a square, as the classifier's own preprocessing
/// does with a captured crop. Plane arguments match [analyzeYuvFrame].
///
/// Returns `null` for an unsupported rotation, a crop that misses the frame,
/// or planes smaller than their strides claim.
img.Image? yuvRegionToRgb({
  required int width,
  required int height,
  required Uint8List y,
  required int yRowStride,
  required Uint8List u,
  required Uint8List v,
  required int uvRowStride,
  required int uvPixelStride,
  required int rotation,
  required Rect uprightCrop,
  int uOffset = 0,
  int vOffset = 0,
  int outputSize = 224,
}) {
  if (width <= 0 || height <= 0 || outputSize <= 0) return null;
  if (rotation != 0 && rotation != 90 && rotation != 180 && rotation != 270) {
    return null;
  }

  final quarterTurn = rotation == 90 || rotation == 270;
  final uprightWidth = quarterTurn ? height : width;
  final uprightHeight = quarterTurn ? width : height;

  final crop = uprightCrop.intersect(
    Rect.fromLTWH(0, 0, uprightWidth.toDouble(), uprightHeight.toDouble()),
  );
  if (crop.width < 1 || crop.height < 1) return null;

  final out = img.Image(width: outputSize, height: outputSize);
  final stepX = crop.width / outputSize;
  final stepY = crop.height / outputSize;

  try {
    for (var oy = 0; oy < outputSize; oy++) {
      final uy =
          (crop.top + (oy + 0.5) * stepY).floor().clamp(0, uprightHeight - 1);
      for (var ox = 0; ox < outputSize; ox++) {
        final ux =
            (crop.left + (ox + 0.5) * stepX).floor().clamp(0, uprightWidth - 1);

        // Upright pixel -> sensor pixel.
        final int sx;
        final int sy;
        switch (rotation) {
          case 90:
            sx = uy;
            sy = height - 1 - ux;
          case 180:
            sx = width - 1 - ux;
            sy = height - 1 - uy;
          case 270:
            sx = width - 1 - uy;
            sy = ux;
          default:
            sx = ux;
            sy = uy;
        }

        final luma = y[sy * yRowStride + sx];
        final uvIndex = (sy ~/ 2) * uvRowStride + (sx ~/ 2) * uvPixelStride;
        final cb = u[uvIndex + uOffset] - 128;
        final cr = v[uvIndex + vOffset] - 128;

        // BT.601 full range, as JPEG/JFIF (and so a captured photo) uses.
        out.setPixelRgb(
          ox,
          oy,
          (luma + 1.402 * cr).round().clamp(0, 255),
          (luma - 0.344136 * cb - 0.714136 * cr).round().clamp(0, 255),
          (luma + 1.772 * cb).round().clamp(0, 255),
        );
      }
    }
  } on RangeError {
    return null;
  }
  return out;
}

/// Whether one YCbCr pixel looks like banana peel.
///
/// Yellow (Cb ≈ 50), green (Cb ≈ 80) and brown (Cb ≈ 95) peels all sit well
/// below neutral Cb (128); white/grey backgrounds sit at ~128 and skin at
/// ~105, so a Cb cut-off separates them. Very dark pixels have unreliable
/// colour and are ignored.
bool isBananaColor(int luma, int cb, int cr) =>
    luma >= 40 && cb <= 98 && cr >= 90;

/// Turns noisy per-frame stats into a steady [ScanCondition].
///
/// Stats are smoothed over recent frames, and "too dark" uses separate
/// enter/leave thresholds so the hint does not flicker at the boundary.
class ScanConditionTracker {
  /// Below this smoothed brightness the frame counts as too dark…
  static const darkEnter = 0.22;

  /// …and it must rise above this to stop counting as too dark.
  static const darkExit = 0.28;

  /// Centre coverage needed to say a banana is in frame.
  static const readyCoverage = 0.15;

  /// Weight of the newest frame in the running average.
  static const smoothing = 0.4;

  /// How long to keep searching before showing the fallback tip.
  static const notFoundAfter = Duration(seconds: 5);

  double? _brightness;
  double? _coverage;
  ScanCondition _condition = ScanCondition.searching;

  /// When the current unbroken stretch of searching began.
  DateTime? _searchingSince;

  ScanCondition get condition => _condition;

  /// Consecutive model misses needed before a seen banana counts as gone.
  /// One stray miss (motion blur, a hand passing) won't flicker the hint.
  static const modelMissesToClear = 2;

  /// Default for [modelStaleAfter].
  static const defaultModelStaleAfter = Duration(seconds: 2);

  /// A model verdict older than this no longer counts. The camera widens it
  /// on slow phones, where verdicts arrive further apart (see
  /// [LiveCheckPacer.staleAfter]).
  Duration modelStaleAfter = defaultModelStaleAfter;

  /// When `true`, only the model can say a banana is in view: with no fresh
  /// verdict the hint keeps searching instead of guessing from colour. The
  /// camera turns this on while a live classifier is working, so the blue
  /// corners always mean the same thing a scan would say.
  ///
  /// When `false` (demo mode, or live classification has given up), a fresh
  /// verdict is still used if there is one, and the colour check fills in.
  bool modelOnly = false;

  /// Latest model verdict on the reticle region: `true` once it has seen a
  /// confident banana, `false` after [modelMissesToClear] misses. `null`
  /// until the model has reported at all.
  bool? _modelSeesBanana;
  int _modelMisses = 0;
  DateTime? _modelAt;

  /// Feeds one frame's stats in. [at] is the frame time (defaults to now;
  /// tests pass it explicitly).
  ScanCondition update(FrameStats stats, {DateTime? at}) {
    _brightness = _blend(_brightness, stats.brightness);
    _coverage = _blend(_coverage, stats.bananaCoverage);
    return _evaluate(at ?? DateTime.now());
  }

  /// Feeds in the classifier's verdict on the reticle region. While a recent
  /// verdict exists it decides whether a banana is in view, using the same
  /// rule the Analyzing screen accepts a scan on
  /// ([ClassificationResult.isConfidentBanana]).
  ScanCondition reportModel(ClassificationResult result, {DateTime? at}) {
    final now = at ?? DateTime.now();
    if (result.isConfidentBanana) {
      _modelSeesBanana = true;
      _modelMisses = 0;
    } else {
      _modelMisses++;
      if (_modelSeesBanana != true || _modelMisses >= modelMissesToClear) {
        _modelSeesBanana = false;
      }
    }
    _modelAt = now;
    // No brightness yet means no frame stats yet: nothing to re-judge.
    return _brightness == null ? _condition : _evaluate(now);
  }

  ScanCondition _evaluate(DateTime now) {
    final wasDark = _condition == ScanCondition.tooDark;
    final dark = wasDark ? _brightness! < darkExit : _brightness! < darkEnter;

    final modelFresh =
        _modelAt != null && now.difference(_modelAt!) < modelStaleAfter;
    final bool bananaInView;
    if (modelFresh && _modelSeesBanana != null) {
      bananaInView = _modelSeesBanana!;
    } else if (modelOnly) {
      // No fresh verdict: say nothing rather than guess.
      bananaInView = false;
    } else {
      bananaInView = (_coverage ?? 0) >= readyCoverage;
    }

    if (dark) {
      // Poor light is the real problem — fix that first, restart the clock.
      _searchingSince = null;
      _condition = ScanCondition.tooDark;
    } else if (bananaInView) {
      _searchingSince = null;
      _condition = ScanCondition.ready;
    } else {
      _searchingSince ??= now;
      _condition = now.difference(_searchingSince!) >= notFoundAfter
          ? ScanCondition.notFound
          : ScanCondition.searching;
    }
    return _condition;
  }

  void reset() {
    _brightness = null;
    _coverage = null;
    _searchingSince = null;
    _condition = ScanCondition.searching;
    _modelSeesBanana = null;
    _modelMisses = 0;
    _modelAt = null;
  }

  static double _blend(double? previous, double next) =>
      previous == null ? next : previous + smoothing * (next - previous);
}

/// Sets how often live frames go to the model, so slow phones stay smooth.
///
/// Each run is timed. The next frame is sent no sooner than twice the
/// (smoothed) run time after the last one started, which leaves the phone at
/// least as much free time as the model takes. Fast phones check about twice
/// a second; slow ones back off to as little as once every two seconds.
class LiveCheckPacer {
  /// Fastest pace, for phones that run the model quickly.
  static const minInterval = Duration(milliseconds: 500);

  /// Slowest pace. Slower than this and the hint would feel stuck.
  static const maxInterval = Duration(seconds: 2);

  /// Weight of the newest run time in the running average.
  static const smoothing = 0.3;

  double? _averageMs;

  /// Time to wait from the start of one model run to the start of the next.
  Duration get interval {
    final average = _averageMs;
    if (average == null) return minInterval;
    final ms = (average * 2).round().clamp(
          minInterval.inMilliseconds,
          maxInterval.inMilliseconds,
        );
    return Duration(milliseconds: ms);
  }

  /// How long a verdict stays valid: long enough to span three runs, so one
  /// slow or skipped frame never blanks the hint. Never under the tracker's
  /// default.
  Duration get staleAfter {
    final threeRuns = interval * 3;
    return threeRuns > ScanConditionTracker.defaultModelStaleAfter
        ? threeRuns
        : ScanConditionTracker.defaultModelStaleAfter;
  }

  /// Records how long one model run took.
  void record(Duration took) {
    final ms = took.inMicroseconds / 1000;
    final average = _averageMs;
    _averageMs = average == null ? ms : average + smoothing * (ms - average);
  }

  void reset() => _averageMs = null;
}
