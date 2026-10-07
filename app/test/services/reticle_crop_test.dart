import 'dart:ui';

import 'package:banana_classifier/services/reticle_crop.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('imageCropForReticle', () {
    test('undoes the cover crop on the overflowing axis', () {
      // The real case measured on a 1080x2400 device: a 480x720 capture shown
      // in a 360.7x672 preview, so the photo is scaled to fill the height and
      // loses pixels off the left and right.
      const previewSize = Size(360.7, 672);
      const reticle = Rect.fromLTRB(55.35, 197.88, 305.35, 527.88);

      final crop = imageCropForReticle(
        previewSize: previewSize,
        reticle: reticle,
        imageWidth: 480,
        imageHeight: 720,
      );

      expect(crop, isNotNull);
      // Matches the crop that turned NotBanana 98.7% into Lakatan_Ripe 99.4%.
      expect(crop!.left.round(), 106);
      expect(crop.top.round(), 212);
      expect(crop.width.round(), 268);
      expect(crop.height.round(), 354);
    });

    test('maps one-to-one when the preview matches the photo exactly', () {
      final crop = imageCropForReticle(
        previewSize: const Size(400, 600),
        reticle: const Rect.fromLTRB(100, 150, 300, 450),
        imageWidth: 400,
        imageHeight: 600,
      );

      expect(crop, const Rect.fromLTRB(100, 150, 300, 450));
    });

    test('clamps a reticle that hangs off the edge of the photo', () {
      final crop = imageCropForReticle(
        previewSize: const Size(400, 600),
        reticle: const Rect.fromLTRB(-50, -50, 300, 450),
        imageWidth: 400,
        imageHeight: 600,
      );

      expect(crop, isNotNull);
      expect(crop!.left, 0);
      expect(crop.top, 0);
      expect(crop.right, 300);
    });

    test('returns null rather than a crop when the geometry is unusable', () {
      expect(
        imageCropForReticle(
          previewSize: Size.zero,
          reticle: const Rect.fromLTRB(0, 0, 10, 10),
          imageWidth: 480,
          imageHeight: 720,
        ),
        isNull,
      );
      expect(
        imageCropForReticle(
          previewSize: const Size(400, 600),
          reticle: const Rect.fromLTRB(0, 0, 10, 10),
          imageWidth: 0,
          imageHeight: 0,
        ),
        isNull,
      );
    });

    test('returns null when the reticle lands entirely off the photo', () {
      final crop = imageCropForReticle(
        previewSize: const Size(400, 600),
        reticle: const Rect.fromLTRB(900, 900, 1000, 1000),
        imageWidth: 400,
        imageHeight: 600,
      );

      expect(crop, isNull);
    });
  });
}
