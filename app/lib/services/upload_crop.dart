import 'dart:math' as math;
import 'dart:ui';

/// Geometry for the gallery crop box.
///
/// The camera path has a reticle the user frames their banana in, and
/// `imageCropForReticle` maps that reticle onto the capture. Gallery uploads
/// have no reticle, so [detectSubjectBounds] locates the banana and these
/// functions turn those bounds into the square the model is given.
///
/// Everything here works in source-photo pixels.

/// Fraction of the shortest side the centred fallback box uses.
///
/// The classifier wants a banana that fills roughly the middle two-thirds of
/// the frame: wider and the background dominates, tighter and it sees bare
/// peel with no shape and reads `NotBanana`. Measured against real uploads,
/// this is the framing that classified them confidently.
const double defaultCropFraction = 0.65;

/// Smallest fraction of the shortest side the box may shrink to.
const double minimumCropFraction = 0.2;


/// Square box to start with: [defaultCropFraction] of the shortest side of
/// [imageRect], centred on the image.
Rect initialCropBox(Rect imageRect) {
  final extent = math.min(imageRect.width, imageRect.height) *
      defaultCropFraction;
  return Rect.fromCenter(
    center: imageRect.center,
    width: extent,
    height: extent,
  );
}

/// Where a [BoxFit.contain] image of [imageWidth] x [imageHeight] lands inside
/// a widget of [containerSize].
///
/// Returns [Rect.zero] for degenerate input, which tells the caller it has
/// nothing meaningful to draw or crop yet.
Rect fittedImageRect({
  required Size containerSize,
  required int imageWidth,
  required int imageHeight,
}) {
  if (containerSize.width <= 0 ||
      containerSize.height <= 0 ||
      imageWidth <= 0 ||
      imageHeight <= 0) {
    return Rect.zero;
  }

  // BoxFit.contain: the smaller of the two ratios wins, so nothing is clipped.
  final scale = math.min(
    containerSize.width / imageWidth,
    containerSize.height / imageHeight,
  );
  final width = imageWidth * scale;
  final height = imageHeight * scale;

  return Rect.fromLTWH(
    (containerSize.width - width) / 2,
    (containerSize.height - height) / 2,
    width,
    height,
  );
}

/// Maps [box] — in widget coordinates — onto the pixels of the source photo.
///
/// [imageRect] is where the photo is actually drawn, from [fittedImageRect].
/// Returns `null` when the geometry is degenerate or the box lands off the
/// image, which tells the caller to fall back to the uncropped photo.
Rect? imageCropForBox({
  required Rect imageRect,
  required Rect box,
  required int imageWidth,
  required int imageHeight,
}) {
  if (imageRect.width <= 0 ||
      imageRect.height <= 0 ||
      imageWidth <= 0 ||
      imageHeight <= 0) {
    return null;
  }

  final scale = imageWidth / imageRect.width;
  if (scale <= 0) return null;

  final crop = Rect.fromLTRB(
    (box.left - imageRect.left) * scale,
    (box.top - imageRect.top) * scale,
    (box.right - imageRect.left) * scale,
    (box.bottom - imageRect.top) * scale,
  ).intersect(
    Rect.fromLTWH(0, 0, imageWidth.toDouble(), imageHeight.toDouble()),
  );

  // `intersect` can return a negative-sized rect when there is no overlap.
  if (crop.width < 1 || crop.height < 1) return null;
  return crop;
}

/// Maps [crop] — in source photo pixels — into widget coordinates.
///
/// The inverse of [imageCropForBox], for placing a box that was computed
/// against the pixels rather than drawn on screen.
Rect widgetRectForImageCrop({
  required Rect imageRect,
  required Rect crop,
  required int imageWidth,
  required int imageHeight,
}) {
  if (imageWidth <= 0 || imageHeight <= 0 || imageRect.isEmpty) {
    return Rect.zero;
  }

  final scale = imageRect.width / imageWidth;
  return Rect.fromLTRB(
    imageRect.left + crop.left * scale,
    imageRect.top + crop.top * scale,
    imageRect.left + crop.right * scale,
    imageRect.top + crop.bottom * scale,
  );
}

/// How much wider than the detected subject the starting box is drawn.
///
/// The classifier was trained on photos of a banana with some surface around
/// it, not on peel filling the frame edge to edge. A box hugging the subject
/// would hand it a composition it has never seen — the same class of
/// train/serve mismatch the matched centre-crop exists to prevent — so the
/// detected bounds are padded back out to that familiar framing.
const double subjectPadding = 1.3;

/// Square box around [subject] — in widget coordinates — padded to the
/// framing the classifier was trained on and clamped inside [imageRect].
///
/// Falls back to [initialCropBox] for a degenerate subject, so the caller can
/// use this unconditionally once detection has produced something.
Rect cropBoxForSubject({required Rect subject, required Rect imageRect}) {
  if (subject.isEmpty || imageRect.isEmpty) return initialCropBox(imageRect);

  // Square on the longer side: a banana lying flat is far wider than it is
  // tall, and a box sized to its height would cut both ends off.
  final extent = math.max(subject.width, subject.height) * subjectPadding;

  return clampCropBox(
    box: Rect.fromCenter(
      center: subject.center,
      width: extent,
      height: extent,
    ),
    bounds: imageRect,
  );
}


/// Keeps [box] square, no larger than [bounds], no smaller than
/// [minimumCropFraction] of it, and fully inside it.
///
/// Resizing is applied before moving so a box pinched larger than the photo
/// still ends up on the photo instead of hanging off one edge.
Rect clampCropBox({required Rect box, required Rect bounds}) {
  if (bounds.width <= 0 || bounds.height <= 0) return bounds;

  final shortest = math.min(bounds.width, bounds.height);
  final extent = box.width.clamp(shortest * minimumCropFraction, shortest);

  final half = extent / 2;
  final centerX = box.center.dx.clamp(
    bounds.left + half,
    bounds.right - half,
  );
  final centerY = box.center.dy.clamp(
    bounds.top + half,
    bounds.bottom - half,
  );

  return Rect.fromCenter(
    center: Offset(centerX, centerY),
    width: extent,
    height: extent,
  );
}

