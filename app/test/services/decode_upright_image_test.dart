import 'dart:io';

import 'package:banana_classifier/services/inference_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

/// A 12×4 landscape image with a red left half, so a rotation is visible in
/// both the dimensions and the pixel the corner lands on.
img.Image _landscape() {
  final image = img.Image(width: 12, height: 4);
  img.fill(image, color: img.ColorRgb8(0, 0, 255));
  img.fillRect(
    image,
    x1: 0,
    y1: 0,
    x2: 5,
    y2: 3,
    color: img.ColorRgb8(255, 0, 0),
  );
  return image;
}

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('decode_upright');
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  /// Encodes [image] as a JPEG tagged with EXIF `orientation`, the way a
  /// phone camera writes a photo taken in portrait.
  List<int> encodeWithOrientation(img.Image image, int orientation) {
    final tagged = image.clone()..exif.imageIfd.orientation = orientation;
    return img.encodeJpg(tagged);
  }

  test('rotates a camera JPEG so the model sees it the way up it was shot',
      () async {
    final bytes = encodeWithOrientation(_landscape(), 6); // 90° clockwise

    final upright = decodeUprightImage(bytes);

    // The stored pixels are 12×4; honouring the tag makes them 4×12.
    expect(upright, isNotNull);
    expect(upright!.width, 4);
    expect(upright.height, 12);

    // The red half was on the left; a 90° clockwise turn puts it on top.
    expect(upright.getPixel(1, 1).r, greaterThan(200));
    expect(upright.getPixel(1, 10).b, greaterThan(200));
  });

  test('leaves an already-upright upload untouched', () async {
    final bytes = encodeWithOrientation(_landscape(), 1); // no rotation

    final upright = decodeUprightImage(bytes);

    expect(upright, isNotNull);
    expect(upright!.width, 12);
    expect(upright.height, 4);
    expect(upright.getPixel(1, 1).r, greaterThan(200));
  });

  test('decodes a PNG upload that carries no orientation tag', () {
    final bytes = img.encodePng(_landscape());

    final upright = decodeUprightImage(bytes);

    expect(upright, isNotNull);
    expect(upright!.width, 12);
    expect(upright.height, 4);
  });
}
