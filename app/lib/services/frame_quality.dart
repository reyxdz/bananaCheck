import 'dart:typed_data';

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

  /// Feeds one frame's stats in. [at] is the frame time (defaults to now;
  /// tests pass it explicitly).
  ScanCondition update(FrameStats stats, {DateTime? at}) {
    final now = at ?? DateTime.now();
    _brightness = _blend(_brightness, stats.brightness);
    _coverage = _blend(_coverage, stats.bananaCoverage);

    final wasDark = _condition == ScanCondition.tooDark;
    final dark = wasDark ? _brightness! < darkExit : _brightness! < darkEnter;

    if (dark) {
      // Poor light is the real problem — fix that first, restart the clock.
      _searchingSince = null;
      _condition = ScanCondition.tooDark;
    } else if (_coverage! >= readyCoverage) {
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
  }

  static double _blend(double? previous, double next) =>
      previous == null ? next : previous + smoothing * (next - previous);
}
