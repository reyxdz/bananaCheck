import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import '../models/classification_result.dart';

abstract interface class InferenceService {
  Future<ClassificationResult> classify(File imageFile);
}

/// Classifies an already-decoded image region rather than a file on disk.
///
/// A bundle scan runs the model over a hundred-odd crops of one photo, so it
/// cannot go through [InferenceService.classify] — that would re-read and
/// re-decode the file every time. Keeping this separate from
/// [InferenceService] leaves the §9 contract untouched: the single-scan flow
/// still only knows about `classify(File)`.
abstract interface class RegionClassifier {
  ClassificationResult classifyRegion(img.Image region);
}

/// Decodes photo [bytes] into pixels the model can read.
///
/// Returns `null` when no decoder recognises the bytes; a decoder that
/// recognises the format and then chokes on the body throws instead. Both
/// call sites treat the two the same way, as an [ImageProcessingException].
///
/// Decoding alone is not enough: a JPEG straight off the camera stores the
/// sensor's raw landscape pixels plus an EXIF orientation tag, and
/// [img.decodeImage] leaves that tag unapplied. The model would then see a
/// banana lying on its side and fall back to `NotBanana`, which the UI reports
/// as "couldn't tell clearly". Gallery uploads do not hit this because
/// `image_picker` re-encodes the photo upright on the way out.
///
/// [img.bakeOrientation] rotates the pixels to match the tag, so both paths
/// reach the model the same way up — the way `Image.file` already draws them
/// on screen.
img.Image? decodeUprightImage(List<int> bytes) {
  final decoded = img.decodeImage(Uint8List.fromList(bytes));
  if (decoded == null) return null;

  final upright = img.bakeOrientation(decoded);

  if (kDebugMode) {
    final tag = decoded.exif.imageIfd.orientation ?? 1;
    debugPrint(
      '\u{1F4D0} exif orientation $tag  '
      '${decoded.width}x${decoded.height} -> '
      '${upright.width}x${upright.height}',
    );
  }

  return upright;
}
