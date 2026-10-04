import 'dart:math' as math;
import 'dart:ui';

/// Maps the on-screen scan reticle onto the pixels of the captured photo.
///
/// The preview is drawn with [BoxFit.cover], so the photo is scaled up until it
/// fills the preview box and the overflow is clipped — what the user sees is a
/// centre crop of the full frame, not the whole thing. Undoing that transform is
/// what lets the reticle the user framed their banana in pick out the matching
/// pixels of the capture.
///
/// Returns `null` when the geometry is degenerate (an empty preview, a
/// zero-sized photo, or a reticle that lands entirely off the image), which
/// tells the caller to fall back to the uncropped photo.
Rect? imageCropForReticle({
  required Size previewSize,
  required Rect reticle,
  required int imageWidth,
  required int imageHeight,
}) {
  if (previewSize.width <= 0 ||
      previewSize.height <= 0 ||
      imageWidth <= 0 ||
      imageHeight <= 0) {
    return null;
  }

  // BoxFit.cover: the larger of the two ratios wins, so neither axis gaps.
  final scale = math.max(
    previewSize.width / imageWidth,
    previewSize.height / imageHeight,
  );
  if (scale <= 0) return null;

  // The scaled photo is centred in the preview box; these are negative on the
  // axis that overflows, which is exactly the part that was clipped.
  final dx = (previewSize.width - imageWidth * scale) / 2;
  final dy = (previewSize.height - imageHeight * scale) / 2;

  final crop = Rect.fromLTRB(
    (reticle.left - dx) / scale,
    (reticle.top - dy) / scale,
    (reticle.right - dx) / scale,
    (reticle.bottom - dy) / scale,
  ).intersect(
    Rect.fromLTWH(0, 0, imageWidth.toDouble(), imageHeight.toDouble()),
  );

  // `intersect` can return a negative-sized rect when there is no overlap.
  if (crop.width < 1 || crop.height < 1) return null;
  return crop;
}
