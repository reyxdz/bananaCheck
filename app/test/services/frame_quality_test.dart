import 'dart:typed_data';

import 'package:banana_classifier/services/frame_quality.dart';
import 'package:flutter_test/flutter_test.dart';

/// Typical YCbCr values (BT.601) for test frames.
const _yellowPeel = (y: 199, cb: 50, cr: 150);
const _greenPeel = (y: 140, cb: 81, cr: 112);
const _brownPeel = (y: 120, cb: 96, cr: 145);
const _whiteTable = (y: 235, cb: 128, cr: 128);
const _skin = (y: 180, cb: 105, cr: 155);

typedef _Pixel = ({int y, int cb, int cr});

/// Builds a 3-plane (Android-style) YUV420 frame of [background] with
/// [center] filling the middle half of the frame.
FrameStats _analyzeThreePlane(
  _Pixel background, {
  _Pixel? center,
  int uvPixelStride = 1,
}) {
  const width = 64, height = 48;
  const uvWidth = width ~/ 2, uvHeight = height ~/ 2;
  final y = Uint8List(width * height);
  final uvRowStride = uvWidth * uvPixelStride;
  final u = Uint8List(uvRowStride * uvHeight);
  final v = Uint8List(uvRowStride * uvHeight);

  bool inCenter(int col, int row) =>
      col >= width / 4 &&
      col < width * 3 / 4 &&
      row >= height / 4 &&
      row < height * 3 / 4;

  for (var row = 0; row < height; row++) {
    for (var col = 0; col < width; col++) {
      final p = center != null && inCenter(col, row) ? center : background;
      y[row * width + col] = p.y;
      final i = (row ~/ 2) * uvRowStride + (col ~/ 2) * uvPixelStride;
      u[i] = p.cb;
      v[i] = p.cr;
    }
  }

  return analyzeYuvFrame(
    width: width,
    height: height,
    y: y,
    yRowStride: width,
    u: u,
    v: v,
    uvRowStride: uvRowStride,
    uvPixelStride: uvPixelStride,
    step: 2,
  );
}

/// Same frame as [_analyzeThreePlane] but in iOS NV12 layout.
FrameStats _analyzeNv12(_Pixel background, {_Pixel? center}) {
  const width = 64, height = 48;
  final y = Uint8List(width * height);
  final uv = Uint8List(width * height ~/ 2);

  for (var row = 0; row < height; row++) {
    for (var col = 0; col < width; col++) {
      final inCenter = col >= width / 4 &&
          col < width * 3 / 4 &&
          row >= height / 4 &&
          row < height * 3 / 4;
      final p = center != null && inCenter ? center : background;
      y[row * width + col] = p.y;
      final i = (row ~/ 2) * width + (col ~/ 2) * 2;
      uv[i] = p.cb;
      uv[i + 1] = p.cr;
    }
  }

  return analyzeYuvFrame(
    width: width,
    height: height,
    y: y,
    yRowStride: width,
    u: uv,
    v: uv,
    uvRowStride: width,
    uvPixelStride: 2,
    vOffset: 1,
    step: 2,
  );
}

void main() {
  group('isBananaColor', () {
    test('accepts yellow, green and brown peel', () {
      for (final p in [_yellowPeel, _greenPeel, _brownPeel]) {
        expect(isBananaColor(p.y, p.cb, p.cr), isTrue, reason: '$p');
      }
    });

    test('rejects white/grey backgrounds and skin', () {
      for (final p in [_whiteTable, _skin]) {
        expect(isBananaColor(p.y, p.cb, p.cr), isFalse, reason: '$p');
      }
    });

    test('ignores very dark pixels, whose colour is unreliable', () {
      expect(isBananaColor(20, _yellowPeel.cb, _yellowPeel.cr), isFalse);
    });
  });

  group('analyzeYuvFrame', () {
    test('banana in the middle of a white table is found', () {
      final stats = _analyzeThreePlane(_whiteTable, center: _yellowPeel);
      // The banana covers most of the centre region…
      expect(stats.bananaCoverage, greaterThan(0.5));
      // …and the scene is bright.
      expect(stats.brightness, greaterThan(0.7));
    });

    test('empty white table has no banana coverage', () {
      final stats = _analyzeThreePlane(_whiteTable);
      expect(stats.bananaCoverage, 0);
    });

    test('a hand in frame is not mistaken for a banana', () {
      final stats = _analyzeThreePlane(_whiteTable, center: _skin);
      expect(stats.bananaCoverage, 0);
    });

    test('dark scene has low brightness', () {
      final stats = _analyzeThreePlane((y: 25, cb: 128, cr: 128));
      expect(stats.brightness, lessThan(0.15));
    });

    test('bananas only at the edges do not count', () {
      // Banana-coloured border, neutral centre.
      final stats = _analyzeThreePlane(_yellowPeel, center: _whiteTable);
      expect(stats.bananaCoverage, lessThan(0.5));
    });

    test('handles interleaved U/V planes (Android pixel stride 2)', () {
      final planar = _analyzeThreePlane(_whiteTable, center: _yellowPeel);
      final interleaved = _analyzeThreePlane(
        _whiteTable,
        center: _yellowPeel,
        uvPixelStride: 2,
      );
      expect(interleaved.bananaCoverage, planar.bananaCoverage);
      expect(interleaved.brightness, planar.brightness);
    });

    test('iOS NV12 layout gives the same answer as Android planes', () {
      final android = _analyzeThreePlane(_whiteTable, center: _greenPeel);
      final ios = _analyzeNv12(_whiteTable, center: _greenPeel);
      expect(ios.bananaCoverage, android.bananaCoverage);
      expect(ios.brightness, android.brightness);
    });
  });

  group('ScanConditionTracker', () {
    const bananaInView = FrameStats(brightness: 0.6, bananaCoverage: 0.5);
    const nothingInView = FrameStats(brightness: 0.6, bananaCoverage: 0);
    const darkRoom = FrameStats(brightness: 0.1, bananaCoverage: 0.5);

    test('starts by searching', () {
      expect(ScanConditionTracker().condition, ScanCondition.searching);
    });

    test('banana in good light is ready', () {
      final tracker = ScanConditionTracker();
      expect(tracker.update(bananaInView), ScanCondition.ready);
    });

    test('nothing banana-like keeps searching', () {
      final tracker = ScanConditionTracker();
      expect(tracker.update(nothingInView), ScanCondition.searching);
    });

    test('dark scene is too dark even with a banana in view', () {
      final tracker = ScanConditionTracker();
      expect(tracker.update(darkRoom), ScanCondition.tooDark);
    });

    test('a single odd frame does not flip the hint', () {
      final tracker = ScanConditionTracker();
      for (var i = 0; i < 5; i++) {
        tracker.update(bananaInView);
      }
      // One frame with the banana out of view (e.g. a shake)…
      expect(tracker.update(nothingInView), ScanCondition.ready);
      // …but if it stays out of view, the hint follows.
      for (var i = 0; i < 5; i++) {
        tracker.update(nothingInView);
      }
      expect(tracker.condition, ScanCondition.searching);
    });

    test('dark has hysteresis: stays dark until clearly brighter', () {
      final tracker = ScanConditionTracker();
      tracker.update(darkRoom);

      // Between the enter and exit thresholds: still too dark.
      const inBetween = FrameStats(brightness: 0.25, bananaCoverage: 0.5);
      for (var i = 0; i < 10; i++) {
        tracker.update(inBetween);
      }
      expect(tracker.condition, ScanCondition.tooDark);

      // Clearly brighter: back to ready.
      for (var i = 0; i < 10; i++) {
        tracker.update(bananaInView);
      }
      expect(tracker.condition, ScanCondition.ready);
    });

    test('a fresh tracker would not be dark at the in-between brightness', () {
      final tracker = ScanConditionTracker();
      const inBetween = FrameStats(brightness: 0.25, bananaCoverage: 0.5);
      expect(tracker.update(inBetween), ScanCondition.ready);
    });

    test('reset forgets history', () {
      final tracker = ScanConditionTracker()..update(darkRoom);
      tracker.reset();
      expect(tracker.condition, ScanCondition.searching);
      expect(tracker.update(bananaInView), ScanCondition.ready);
    });
  });
}
