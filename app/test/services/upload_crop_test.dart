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
