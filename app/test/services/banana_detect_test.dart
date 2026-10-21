import 'dart:math' as math;
import 'dart:ui';

import 'package:banana_classifier/services/banana_detect.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

/// Paints [subject] onto a plain background, the composition the detector is
/// built for: one object on a roughly even surface.
img.Image _photo({
  required int width,
  required int height,
  required Rect subject,
  int background = 230,
  int foreground = 40,
  int noise = 0,
}) {
  final image = img.Image(width: width, height: height);
  final random = math.Random(7);

  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final inside = subject.contains(Offset(x.toDouble(), y.toDouble()));
      final base = inside ? foreground : background;
      final jitter = noise == 0 ? 0 : random.nextInt(noise * 2) - noise;
      final v = (base + jitter).clamp(0, 255);
      image.setPixelRgb(x, y, v, v, v);
    }
  }

  return image;
}

void main() {
  group('detectSubjectBounds', () {
    test('finds a dark subject on a pale background', () {
      const subject = Rect.fromLTWH(120, 180, 260, 120);

      final bounds = detectSubjectBounds(
        _photo(width: 600, height: 480, subject: subject),
      );

      expect(bounds, isNotNull);
      // The 96-cell analysis grid quantises the edges, so allow one cell.
      const tolerance = 600 / 96 + 1;
      expect(bounds!.left, closeTo(subject.left, tolerance));
      expect(bounds.right, closeTo(subject.right, tolerance));
      expect(bounds.top, closeTo(subject.top, 480 / 96 + 1));
      expect(bounds.bottom, closeTo(subject.bottom, 480 / 96 + 1));
    });

    test('finds a pale subject on a dark background', () {
      // Ripeness-blind by construction: the detector is told nothing about
      // colour, so inverting the photo must not change the outcome. This is
      // what a banana-colour rule could not do for black overripe peel.
      const subject = Rect.fromLTWH(150, 150, 200, 200);

      final bounds = detectSubjectBounds(_photo(
        width: 600,
        height: 480,
        subject: subject,
        background: 30,
        foreground: 220,
      ));

      expect(bounds, isNotNull);
      expect(bounds!.center.dx, closeTo(subject.center.dx, 12));
      expect(bounds.center.dy, closeTo(subject.center.dy, 12));
    });

    test('is unmoved by an off-centre subject', () {
      const subject = Rect.fromLTWH(40, 40, 160, 140);

      final bounds = detectSubjectBounds(
        _photo(width: 600, height: 480, subject: subject),
      );

      expect(bounds, isNotNull);
      expect(bounds!.center.dx, lessThan(300));
      expect(bounds.center.dy, lessThan(240));
    });

    test('tolerates sensor noise', () {
      const subject = Rect.fromLTWH(200, 150, 220, 180);

      final bounds = detectSubjectBounds(_photo(
        width: 600,
        height: 480,
        subject: subject,
        noise: 12,
      ));

      expect(bounds, isNotNull);
      expect(bounds!.center.dx, closeTo(subject.center.dx, 20));
    });

    test('rejects an empty frame rather than inventing a subject', () {
      final flat = img.Image(width: 400, height: 400);
      img.fill(flat, color: img.ColorRgb8(200, 200, 200));

      expect(detectSubjectBounds(flat), isNull);
    });

    test('rejects a speck too small to be a banana', () {
      // Under the 2% floor: a crumb, a sticker, a dead pixel cluster.
      const speck = Rect.fromLTWH(300, 240, 14, 14);

      expect(
        detectSubjectBounds(_photo(width: 600, height: 480, subject: speck)),
        isNull,
      );
    });

    test('rejects a subject covering most of the frame', () {
      // What a patterned cloth or wood grain produces: the background
      // estimate has failed, so the centred default is the better start.
      const huge = Rect.fromLTWH(20, 20, 560, 440);

      expect(
        detectSubjectBounds(_photo(width: 600, height: 480, subject: huge)),
        isNull,
      );
    });

    test('returns null for a degenerate image rather than throwing', () {
      expect(detectSubjectBounds(img.Image(width: 1, height: 1)), isNull);
    });

    test('ignores a smaller second object', () {
      // Largest region wins: a knife or a second fruit beside the banana must
      // not stretch the bounds across both.
      final image = _photo(
        width: 600,
        height: 480,
        subject: const Rect.fromLTWH(300, 200, 220, 160),
      );
      for (var y = 60; y < 100; y++) {
        for (var x = 40; x < 90; x++) {
          image.setPixelRgb(x, y, 40, 40, 40);
        }
      }

      final bounds = detectSubjectBounds(image);

      expect(bounds, isNotNull);
      // Anchored on the large object, not spanning from the small one.
      expect(bounds!.left, greaterThan(200));
    });
  });
}
