import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

/// Keeps a permanent copy of each scan's photo.
///
/// The camera and the gallery picker both hand us files in the app's
/// **cache** folder, which Android may empty at any time (low storage, or
/// the user tapping "Clear cache"). History would then lose its photos. So
/// when a scan is saved, its photo is copied into [directory] (inside the
/// app's documents folder, which is never cleared automatically) as
/// `<scan id>.jpg`, scaled down so a long history stays small.
class ScanPhotoStore {
  ScanPhotoStore(this.directory);

  /// Where saved scan photos live, e.g. `<documents>/scan_photos`.
  final Directory directory;

  /// Longest side of a stored photo. Plenty for the results hero and history
  /// thumbnails, and keeps each photo to roughly 100–200 KB.
  static const int maxDimension = 1024;
  static const int jpegQuality = 85;

  /// Copies the photo at [sourcePath] into the store for scan [id] and
  /// returns the new path.
  ///
  /// Large photos are scaled down (orientation preserved); anything the
  /// decoder can't read is copied as-is. Throws if the source can't be read
  /// or the copy can't be written — callers decide how to fall back.
  Future<String> persist(String sourcePath, String id) async {
    final destination = File(p.join(directory.path, '$id.jpg'));
    if (p.equals(sourcePath, destination.path)) return destination.path;

    await directory.create(recursive: true);
    final bytes = await File(sourcePath).readAsBytes();
    final shrunk = await _shrinkInBackground(bytes);

    if (shrunk != null) {
      await destination.writeAsBytes(shrunk, flush: true);
    } else {
      await File(sourcePath).copy(destination.path);
    }
    return destination.path;
  }

  /// Whether [path] is a photo this store manages (and may delete).
  bool owns(String path) => p.isWithin(directory.path, path);

  /// Deletes the stored photo at [path]. Paths outside the store (e.g. old
  /// records that still point at the cache) are left alone.
  Future<void> delete(String path) async {
    if (!owns(path)) return;
    try {
      await File(path).delete();
    } on FileSystemException {
      // Already gone — nothing to do.
    }
  }

  /// Deletes every stored photo.
  Future<void> clear() async {
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  }

  /// Static so the isolate closure captures only [bytes] — never `this`.
  static Future<Uint8List?> _shrinkInBackground(Uint8List bytes) =>
      Isolate.run(() => shrinkToJpeg(bytes));

  /// Decodes [bytes], applies the EXIF rotation (re-encoding drops EXIF, so
  /// the rotation must be baked into the pixels), scales the longest side
  /// down to [maxDimension] if needed, and re-encodes as JPEG.
  ///
  /// Returns `null` if [bytes] are not a decodable image.
  @visibleForTesting
  static Uint8List? shrinkToJpeg(Uint8List bytes) {
    final img.Image? decoded;
    try {
      decoded = img.decodeImage(bytes);
    } catch (_) {
      return null;
    }
    if (decoded == null) return null;

    var image = img.bakeOrientation(decoded);
    final longest = image.width > image.height ? image.width : image.height;
    if (longest > maxDimension) {
      image = image.width >= image.height
          ? img.copyResize(image, width: maxDimension)
          : img.copyResize(image, height: maxDimension);
    }
    return img.encodeJpg(image, quality: jpegQuality);
  }
}
