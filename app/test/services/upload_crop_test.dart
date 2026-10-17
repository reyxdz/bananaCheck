import 'dart:ui';

import 'package:banana_classifier/services/upload_crop.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('initialCropBox', () {
    test('is square, centred, and two-thirds of the shortest side', () {
      const imageRect = Rect.fromLTWH(0, 100, 400, 300);

      final box = initialCropBox(imageRect);

      // 0.65 of the 300 height — the framing that classified the real uploads.
      expect(box.width, closeTo(195, 0.01));
      expect(box.height, closeTo(195, 0.01));
      expect(box.center, imageRect.center);
    });
  });

  group('clampCropBox', () {
    const bounds = Rect.fromLTWH(0, 0, 400, 300);

    test('keeps a box that is already inside untouched', () {
      const box = Rect.fromLTWH(100, 50, 200, 200);

      expect(clampCropBox(box: box, bounds: bounds), box);
    });

    test('pushes a box dragged off the edge back onto the photo', () {
      const box = Rect.fromLTWH(-80, -60, 200, 200);

      final clamped = clampCropBox(box: box, bounds: bounds);

      expect(clamped.left, 0);
      expect(clamped.top, 0);
      expect(clamped.width, 200);
      expect(clamped.height, 200);
    });

    test('caps a box pinched larger than the photo at the shortest side', () {
      const box = Rect.fromLTWH(0, 0, 900, 900);

      final clamped = clampCropBox(box: box, bounds: bounds);

      // 300 is the height; a square cannot exceed it without leaving the photo.
      expect(clamped.width, 300);
      expect(clamped.height, 300);
      expect(bounds.contains(clamped.topLeft), isTrue);
      expect(bounds.contains(clamped.bottomRight - const Offset(0.01, 0.01)),
          isTrue);
    });

    test('stops a box pinched smaller than the minimum', () {
      const box = Rect.fromLTWH(180, 130, 10, 10);

      final clamped = clampCropBox(box: box, bounds: bounds);

      // Too tight and the model sees bare peel with no shape: NotBanana.
      expect(clamped.width, closeTo(300 * minimumCropFraction, 0.01));
    });

    test('stays square even when handed a rectangle', () {
      const box = Rect.fromLTWH(50, 50, 200, 80);

      final clamped = clampCropBox(box: box, bounds: bounds);

      expect(clamped.width, clamped.height);
    });
  });

  group('fittedImageRect', () {
    test('letterboxes top and bottom for a photo wider than the viewport', () {
      // 800x530 photo (the stock-photo upload) in a 400x600 viewport: it
      // scales to the full width and leaves bars above and below.
      final rect = fittedImageRect(
        containerSize: const Size(400, 600),
        imageWidth: 800,
        imageHeight: 530,
      );

      expect(rect.width, 400);
      expect(rect.height, closeTo(265, 0.01));
      expect(rect.left, 0);
      expect(rect.top, closeTo(167.5, 0.01));
    });

    test('pillarboxes left and right for a photo taller than the viewport', () {
      final rect = fittedImageRect(
        containerSize: const Size(400, 600),
        imageWidth: 300,
        imageHeight: 600,
      );

      expect(rect.width, 300);
      expect(rect.height, 600);
      expect(rect.left, 50);
      expect(rect.top, 0);
    });

    test('returns zero rather than a rect when the geometry is unusable', () {
      expect(
        fittedImageRect(
          containerSize: Size.zero,
          imageWidth: 800,
          imageHeight: 600,
        ),
        Rect.zero,
      );
    });
  });

  group('imageCropForBox', () {
    test('scales the box up to the photo pixels it covers', () {
      // 800x530 photo drawn 400 wide, so every widget pixel is two real ones.
      const imageRect = Rect.fromLTWH(0, 167.5, 400, 265);
      const box = Rect.fromLTWH(100, 200, 200, 200);

      final crop = imageCropForBox(
        imageRect: imageRect,
        box: box,
        imageWidth: 800,
        imageHeight: 530,
      );

      expect(crop, isNotNull);
      expect(crop!.left.round(), 200);
      expect(crop.width.round(), 400);
    });

    test('subtracts the letterbox offset', () {
      // The photo starts 100px down the viewport, so a box at y=100 is the
      // very top of the image, not 100px into it.
      final crop = imageCropForBox(
        imageRect: const Rect.fromLTWH(0, 100, 400, 400),
        box: const Rect.fromLTWH(0, 100, 200, 200),
        imageWidth: 400,
        imageHeight: 400,
      );

      expect(crop!.top.round(), 0);
    });

    test('clamps a box hanging off the edge of the photo', () {
      final crop = imageCropForBox(
        imageRect: const Rect.fromLTWH(0, 0, 400, 400),
        box: const Rect.fromLTRB(300, 300, 500, 500),
        imageWidth: 400,
        imageHeight: 400,
      );

      expect(crop!.right, 400);
      expect(crop.bottom, 400);
    });

    test('returns null when the box lands entirely off the photo', () {
      expect(
        imageCropForBox(
          imageRect: const Rect.fromLTWH(0, 0, 400, 400),
          box: const Rect.fromLTWH(900, 900, 100, 100),
          imageWidth: 400,
          imageHeight: 400,
        ),
        isNull,
      );
    });
  });

  group('widgetRectForImageCrop', () {
    test('is the inverse of imageCropForBox', () {
      const imageRect = Rect.fromLTWH(0, 167.5, 400, 265);
      const box = Rect.fromLTWH(100, 200, 200, 200);

      final crop = imageCropForBox(
        imageRect: imageRect,
        box: box,
        imageWidth: 800,
        imageHeight: 530,
      );
      final back = widgetRectForImageCrop(
        imageRect: imageRect,
        crop: crop!,
        imageWidth: 800,
        imageHeight: 530,
      );

      expect(back.left, closeTo(box.left, 0.01));
      expect(back.width, closeTo(box.width, 0.01));
    });
  });

  group('cropBoxForSubject', () {
    const imageRect = Rect.fromLTWH(0, 100, 400, 400);

    test('squares a wide subject on its longer side', () {
      // A banana lying flat is far wider than it is tall. Sizing the box to
      // its height would cut both ends off — the shape cue that separates
      // Lakatan from Latundan.
      const subject = Rect.fromLTWH(100, 220, 200, 60);

      final box = cropBoxForSubject(subject: subject, imageRect: imageRect);

      expect(box.width, box.height);
      expect(box.width, greaterThanOrEqualTo(subject.width));
    });

    test('pads out to the framing the classifier was trained on', () {
      const subject = Rect.fromLTWH(150, 250, 100, 100);

      final box = cropBoxForSubject(subject: subject, imageRect: imageRect);

      expect(box.width, closeTo(100 * subjectPadding, 0.01));
      expect(box.center, subject.center);
    });

    test('keeps the box on the photo for a subject near the edge', () {
      const subject = Rect.fromLTWH(0, 100, 120, 120);

      final box = cropBoxForSubject(subject: subject, imageRect: imageRect);

      expect(box.left, greaterThanOrEqualTo(imageRect.left - 0.01));
      expect(box.top, greaterThanOrEqualTo(imageRect.top - 0.01));
    });

    test('falls back to the centred box for an empty subject', () {
      final box = cropBoxForSubject(subject: Rect.zero, imageRect: imageRect);

      expect(box, initialCropBox(imageRect));
    });
  });

}
