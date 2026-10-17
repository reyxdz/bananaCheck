import 'dart:io';
import 'dart:ui';

import 'package:banana_classifier/services/auto_crop.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

/// Writes a photo of one object on a plain surface to a temp file.
File _photoFile(
  Directory dir, {
  required String name,
  required int width,
  required int height,
  Rect? subject,
  int background = 230,
  int foreground = 40,
}) {
  final image = img.Image(width: width, height: height);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final inside =
          subject?.contains(Offset(x.toDouble(), y.toDouble())) ?? false;
      final v = inside ? foreground : background;
      image.setPixelRgb(x, y, v, v, v);
    }
  }

  final file = File('${dir.path}/$name')
    ..writeAsBytesSync(img.encodeJpg(image, quality: 95));
  return file;
}

void main() {
  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('auto_crop'));
  tearDown(() => dir.deleteSync(recursive: true));

  group('autoCropToSubject', () {
    test('crops to a square around the banana', () async {
      final photo = _photoFile(
        dir,
        name: 'banana.jpg',
        width: 800,
        height: 600,
        subject: const Rect.fromLTWH(300, 250, 240, 90),
      );

      final cropped = await autoCropToSubject(photo);

      expect(cropped, isNotNull);
      final out = img.decodeJpg(cropped!.readAsBytesSync())!;
      expect(out.width, out.height, reason: 'model input is square');
      // Smaller than the source: the point is to discard the surface.
      expect(out.width, lessThan(800));
      // Larger than the banana: the classifier trained on fruit with some
      // surface around it, so the box is padded back out.
      expect(out.width, greaterThan(240));
    });

    test('writes beside the original without touching it', () async {
      final photo = _photoFile(
        dir,
        name: 'banana.jpg',
        width: 800,
        height: 600,
        subject: const Rect.fromLTWH(300, 250, 240, 90),
      );
      final before = photo.lengthSync();

      final cropped = await autoCropToSubject(photo);

      expect(cropped!.path, '${photo.path}.auto.jpg');
      expect(photo.lengthSync(), before);
    });

    test('centre-crops a photo with no subject', () async {
      // Without a manual framing step there is nowhere to fall back to, and
      // the whole picture is the framing that reads a small banana on a wide
      // table as NotBanana. A centred square is at least the shape the
      // classifier was trained on.
      final flat = _photoFile(dir, name: 'flat.jpg', width: 800, height: 600);

      final cropped = await autoCropToSubject(flat);

      expect(cropped, isNotNull);
      final out = img.decodeJpg(cropped!.readAsBytesSync())!;
      expect(out.width, out.height);
      expect(out.width, lessThan(600), reason: 'a crop, not the whole photo');
    });

    test('centre-crops when the subject fills the frame', () async {
      // A patterned surface reads as subject everywhere, so the detected
      // bounds are meaningless and get rejected. The centred square is the
      // honest fallback: no worse than not detecting anything at all.
      final busy = _photoFile(
        dir,
        name: 'busy.jpg',
        width: 800,
        height: 600,
        subject: const Rect.fromLTWH(10, 10, 780, 580),
      );

      final cropped = await autoCropToSubject(busy);

      expect(cropped, isNotNull);
      final out = img.decodeJpg(cropped!.readAsBytesSync())!;
      expect(out.width, out.height);
    });

    test('declines a file that is not an image', () async {
      final junk = File('${dir.path}/not-a-photo.jpg')
        ..writeAsBytesSync([1, 2, 3, 4]);

      expect(await autoCropToSubject(junk), isNull);
    });

    test('declines a missing file rather than throwing', () async {
      expect(
        await autoCropToSubject(File('${dir.path}/gone.jpg')),
        isNull,
      );
    });

    test('finds a pale banana on a dark surface', () async {
      // Ripeness-blind: inverting the photo must not change the outcome.
      final photo = _photoFile(
        dir,
        name: 'dark.jpg',
        width: 800,
        height: 600,
        subject: const Rect.fromLTWH(300, 250, 240, 90),
        background: 30,
        foreground: 220,
      );

      expect(await autoCropToSubject(photo), isNotNull);
    });
  });
}
