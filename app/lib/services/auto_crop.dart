import 'dart:io';
import 'dart:ui';

import 'package:image/image.dart' as img;

import 'banana_detect.dart';
import 'inference_service.dart';
import 'upload_crop.dart';

/// Crops an uploaded photo to the banana without asking the user.
///
/// The camera path crops to the reticle the user aimed; this gives gallery
/// uploads the same square framing, using [detectSubjectBounds] in place of
/// the reticle. The user goes straight from picking a photo to the result,
/// exactly like a capture (§7.1).
///
/// **When no subject is found** — roughly one photo in three, a busy surface
/// or a banana running off the frame — this centre-crops instead of handing
/// the model the whole picture. A square from the middle is not necessarily
/// the banana, but it is at least the shape the classifier was trained on; a
/// whole 4:3 photo is the framing that reads a small banana on a wide table
/// as `NotBanana`, which is the failure this path exists to prevent.
///
/// Returns `null` only when the photo cannot be read or the crop cannot be
/// written, leaving the caller to scan it as picked.
Future<File?> autoCropToSubject(File photo) async {
  try {
    final decoded = decodeUprightImage(await photo.readAsBytes());
    if (decoded == null) return null;

    final frame = Rect.fromLTWH(
      0,
      0,
      decoded.width.toDouble(),
      decoded.height.toDouble(),
    );

    final subject = detectSubjectBounds(decoded);
    final box = subject == null
        ? initialCropBox(frame)
        : cropBoxForSubject(subject: subject, imageRect: frame);
    if (box.width < 1 || box.height < 1) return null;

    final cropped = img.copyCrop(
      decoded,
      x: box.left.round(),
      y: box.top.round(),
      width: box.width.round(),
      height: box.height.round(),
    );

    final target = File('${photo.path}.auto.jpg');
    await target.writeAsBytes(img.encodeJpg(cropped, quality: 95));
    return target;
  } catch (_) {
    // Unreadable or unwritable: the caller scans the photo as picked, which
    // is a worse scan but never a broken one.
    return null;
  }
}
