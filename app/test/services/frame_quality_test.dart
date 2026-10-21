import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:banana_classifier/models/classification_result.dart';
import 'package:banana_classifier/services/frame_quality.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

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

    group('fallback when no banana is found', () {
      final start = DateTime(2026);
      DateTime after(Duration d) => start.add(d);

      test('keeps searching for the first few seconds', () {
        final tracker = ScanConditionTracker();
        tracker.update(nothingInView, at: start);
        expect(
          tracker.update(nothingInView, at: after(const Duration(seconds: 4))),
          ScanCondition.searching,
        );
      });

      test('switches to notFound after searching for 5 seconds', () {
        final tracker = ScanConditionTracker();
        tracker.update(nothingInView, at: start);
        expect(
          tracker.update(
            nothingInView,
            at: after(ScanConditionTracker.notFoundAfter),
          ),
          ScanCondition.notFound,
        );
      });

      test('finding a banana clears the tip and restarts the clock', () {
        final tracker = ScanConditionTracker();
        tracker.update(nothingInView, at: start);
        tracker.update(nothingInView, at: after(const Duration(seconds: 6)));
        expect(tracker.condition, ScanCondition.notFound);

        for (var i = 0; i < 6; i++) {
          tracker.update(bananaInView, at: after(Duration(seconds: 7 + i)));
        }
        expect(tracker.condition, ScanCondition.ready);

        // Banana leaves the frame: back to plain searching, not straight to
        // the tip.
        for (var i = 0; i < 6; i++) {
          tracker.update(nothingInView, at: after(Duration(seconds: 13 + i)));
        }
        expect(tracker.condition, ScanCondition.searching);
      });

      test('too dark wins over the tip', () {
        final tracker = ScanConditionTracker();
        tracker.update(nothingInView, at: start);
        // Brightness is smoothed, so the room has to stay dark a moment.
        for (var i = 0; i < 6; i++) {
          tracker.update(darkRoom, at: after(Duration(seconds: 6 + i)));
        }
        expect(tracker.condition, ScanCondition.tooDark);
      });

      test('reset restarts the clock', () {
        final tracker = ScanConditionTracker();
        tracker.update(nothingInView, at: start);
        tracker.reset();
        expect(
          tracker.update(nothingInView, at: after(const Duration(seconds: 6))),
          ScanCondition.searching,
        );
      });
    });
  });

  group('yuvRegionToRgb', () {
    // An 8x4 landscape sensor frame: white, with a yellow top-left quadrant
    // (sensor columns 0-3, rows 0-1). Planes are Android 3-plane, stride 1.
    const sensorW = 8, sensorH = 4;

    ({Uint8List y, Uint8List u, Uint8List v}) frame() {
      final y = Uint8List(sensorW * sensorH);
      final u = Uint8List((sensorW ~/ 2) * (sensorH ~/ 2));
      final v = Uint8List((sensorW ~/ 2) * (sensorH ~/ 2));
      for (var row = 0; row < sensorH; row++) {
        for (var col = 0; col < sensorW; col++) {
          final p = col < 4 && row < 2 ? _yellowPeel : _whiteTable;
          y[row * sensorW + col] = p.y;
          final i = (row ~/ 2) * (sensorW ~/ 2) + (col ~/ 2);
          u[i] = p.cb;
          v[i] = p.cr;
        }
      }
      return (y: y, u: u, v: v);
    }

    img.Image? convert({
      required int rotation,
      Rect? crop,
      int outputSize = 8,
    }) {
      final f = frame();
      final quarter = rotation == 90 || rotation == 270;
      return yuvRegionToRgb(
        width: sensorW,
        height: sensorH,
        y: f.y,
        yRowStride: sensorW,
        u: f.u,
        v: f.v,
        uvRowStride: sensorW ~/ 2,
        uvPixelStride: 1,
        rotation: rotation,
        uprightCrop: crop ??
            Rect.fromLTWH(
              0,
              0,
              (quarter ? sensorH : sensorW).toDouble(),
              (quarter ? sensorW : sensorH).toDouble(),
            ),
        outputSize: outputSize,
      );
    }

    bool isYellow(img.Pixel p) => p.r > 200 && p.g > 180 && p.b < 100;
    bool isWhite(img.Pixel p) => p.r > 225 && p.g > 225 && p.b > 225;

    test('converts a known yellow and white with BT.601', () {
      final out = convert(rotation: 0)!;
      final yellow = out.getPixel(0, 0);
      expect(yellow.r, 230);
      expect(yellow.g, 210);
      expect(yellow.b, 61);
      final white = out.getPixel(7, 7);
      expect([white.r, white.g, white.b], [235, 235, 235]);
    });

    test('output is the requested square size', () {
      final out = convert(rotation: 90, outputSize: 16)!;
      expect(out.width, 16);
      expect(out.height, 16);
    });

    test('rotation 0 keeps the yellow quadrant top-left', () {
      final out = convert(rotation: 0)!;
      expect(isYellow(out.getPixel(0, 0)), isTrue);
      expect(isWhite(out.getPixel(7, 0)), isTrue);
      expect(isWhite(out.getPixel(0, 7)), isTrue);
    });

    test('rotation 90 (Android back camera) turns it to the top-right', () {
      final out = convert(rotation: 90)!;
      expect(isYellow(out.getPixel(7, 0)), isTrue);
      expect(isWhite(out.getPixel(0, 0)), isTrue);
      expect(isWhite(out.getPixel(7, 7)), isTrue);
    });

    test('rotation 270 turns it to the bottom-left', () {
      final out = convert(rotation: 270)!;
      expect(isYellow(out.getPixel(0, 7)), isTrue);
      expect(isWhite(out.getPixel(0, 0)), isTrue);
      expect(isWhite(out.getPixel(7, 7)), isTrue);
    });

    test('rotation 180 turns it to the bottom-right', () {
      final out = convert(rotation: 180)!;
      expect(isYellow(out.getPixel(7, 7)), isTrue);
      expect(isWhite(out.getPixel(0, 0)), isTrue);
    });

    test('a crop picks out only that region', () {
      final out = convert(
        rotation: 0,
        crop: const Rect.fromLTWH(0, 0, 4, 2),
        outputSize: 4,
      )!;
      for (var oy = 0; oy < 4; oy++) {
        for (var ox = 0; ox < 4; ox++) {
          expect(isYellow(out.getPixel(ox, oy)), isTrue);
        }
      }
    });

    test('returns null for a crop off the frame', () {
      expect(
        convert(rotation: 0, crop: const Rect.fromLTWH(100, 100, 10, 10)),
        isNull,
      );
    });

    test('returns null for an unsupported rotation', () {
      expect(convert(rotation: 45), isNull);
    });

    test('returns null when the planes are shorter than the strides say', () {
      expect(
        yuvRegionToRgb(
          width: sensorW,
          height: sensorH,
          y: Uint8List(4),
          yRowStride: sensorW,
          u: Uint8List(1),
          v: Uint8List(1),
          uvRowStride: sensorW ~/ 2,
          uvPixelStride: 1,
          rotation: 0,
          uprightCrop: const Rect.fromLTWH(0, 0, 8, 4),
        ),
        isNull,
      );
    });
  });

  group('ScanConditionTracker with the model', () {
    const bananaColours = FrameStats(brightness: 0.6, bananaCoverage: 0.5);
    const noBananaColours = FrameStats(brightness: 0.6, bananaCoverage: 0);
    const darkRoom = FrameStats(brightness: 0.1, bananaCoverage: 0.5);
    final start = DateTime(2026);
    DateTime at(int ms) => start.add(Duration(milliseconds: ms));

    ClassificationResult hit() => ClassificationResult(
          variety: 'Saba',
          ripeness: 'Overripe',
          confidence: 0.9,
          margin: 0.8,
        );
    ClassificationResult miss() => ClassificationResult(
          variety: ClassificationResult.notBananaVariety,
          ripeness: '',
          confidence: 0.95,
          margin: 0.9,
        );

    test('a confident banana is ready even when colours say no', () {
      // A dark, spotted banana: the colour check misses it, the model doesn't.
      final tracker = ScanConditionTracker()
        ..update(noBananaColours, at: at(0));
      expect(tracker.reportModel(hit(), at: at(10)), ScanCondition.ready);
      expect(tracker.update(noBananaColours, at: at(300)), ScanCondition.ready);
    });

    test('the model overrides banana-like colours that are not a banana', () {
      final tracker = ScanConditionTracker()..update(bananaColours, at: at(0));
      expect(tracker.condition, ScanCondition.ready);
      expect(tracker.reportModel(miss(), at: at(10)), ScanCondition.searching);
    });

    test('one miss keeps ready; two in a row clear it', () {
      final tracker = ScanConditionTracker()
        ..update(noBananaColours, at: at(0))
        ..reportModel(hit(), at: at(10));
      expect(tracker.reportModel(miss(), at: at(500)), ScanCondition.ready);
      expect(
        tracker.reportModel(miss(), at: at(1000)),
        ScanCondition.searching,
      );
    });

    test('a hit between misses resets the count', () {
      final tracker = ScanConditionTracker()
        ..update(noBananaColours, at: at(0))
        ..reportModel(hit(), at: at(10))
        ..reportModel(miss(), at: at(500))
        ..reportModel(hit(), at: at(1000));
      expect(tracker.reportModel(miss(), at: at(1500)), ScanCondition.ready);
    });

    test('unsure or torn results never turn ready', () {
      final unsure = ClassificationResult(
        variety: 'Saba',
        ripeness: 'Ripe',
        confidence: 0.4,
        margin: 0.3,
      );
      final torn = ClassificationResult(
        variety: 'Saba',
        ripeness: 'Ripe',
        confidence: 0.55,
        margin: 0.05,
      );
      final tracker = ScanConditionTracker()
        ..update(noBananaColours, at: at(0));
      expect(tracker.reportModel(unsure, at: at(10)), ScanCondition.searching);
      expect(tracker.reportModel(torn, at: at(20)), ScanCondition.searching);
    });

    test('too dark still wins over a banana', () {
      final tracker = ScanConditionTracker()..update(darkRoom, at: at(0));
      expect(tracker.reportModel(hit(), at: at(10)), ScanCondition.tooDark);
    });

    test('a stale verdict hands back to the colour check', () {
      final tracker = ScanConditionTracker()
        ..update(noBananaColours, at: at(0))
        ..reportModel(hit(), at: at(10));
      final later = at(10).add(ScanConditionTracker.defaultModelStaleAfter);
      expect(
        tracker.update(noBananaColours, at: later),
        ScanCondition.searching,
      );
    });

    test('a verdict before any frame stats is used once stats arrive', () {
      final tracker = ScanConditionTracker();
      expect(tracker.reportModel(hit(), at: at(0)), ScanCondition.searching);
      expect(tracker.update(noBananaColours, at: at(100)), ScanCondition.ready);
    });

    test('reset forgets the model verdict', () {
      final tracker = ScanConditionTracker()
        ..update(noBananaColours, at: at(0))
        ..reportModel(hit(), at: at(10))
        ..reset();
      expect(
        tracker.update(noBananaColours, at: at(100)),
        ScanCondition.searching,
      );
    });

    test('notFound tip still appears while the model sees nothing', () {
      final tracker = ScanConditionTracker()
        ..update(noBananaColours, at: at(0))
        ..reportModel(miss(), at: at(10));
      tracker.reportModel(miss(), at: at(1000));
      final fiveSecondsOn = at(0).add(ScanConditionTracker.notFoundAfter);
      tracker.reportModel(miss(), at: fiveSecondsOn);
      expect(tracker.condition, ScanCondition.notFound);
    });
  });

  group('ScanConditionTracker model-only mode', () {
    const bananaColours = FrameStats(brightness: 0.6, bananaCoverage: 0.5);
    const noBananaColours = FrameStats(brightness: 0.6, bananaCoverage: 0);
    const darkRoom = FrameStats(brightness: 0.1, bananaCoverage: 0.5);
    final start = DateTime(2026);
    DateTime at(int ms) => start.add(Duration(milliseconds: ms));

    ClassificationResult hit() => ClassificationResult(
          variety: 'Saba',
          ripeness: 'Ripe',
          confidence: 0.9,
          margin: 0.8,
        );

    test('banana colours alone never turn the corners blue', () {
      final tracker = ScanConditionTracker()..modelOnly = true;
      expect(tracker.update(bananaColours, at: at(0)), ScanCondition.searching);
    });

    test('a model hit does', () {
      final tracker = ScanConditionTracker()
        ..modelOnly = true
        ..update(noBananaColours, at: at(0));
      expect(tracker.reportModel(hit(), at: at(10)), ScanCondition.ready);
    });

    test('a stale hit goes back to searching, not to the colour check', () {
      final tracker = ScanConditionTracker()
        ..modelOnly = true
        ..update(bananaColours, at: at(0))
        ..reportModel(hit(), at: at(10));
      final later = at(10).add(tracker.modelStaleAfter);
      expect(tracker.update(bananaColours, at: later), ScanCondition.searching);
    });

    test('a wider stale window keeps a slow phone\'s verdict', () {
      final tracker = ScanConditionTracker()
        ..modelOnly = true
        ..modelStaleAfter = const Duration(seconds: 6)
        ..update(noBananaColours, at: at(0))
        ..reportModel(hit(), at: at(10));
      expect(
        tracker.update(noBananaColours, at: at(4000)),
        ScanCondition.ready,
      );
    });

    test('too dark is still reported', () {
      final tracker = ScanConditionTracker()..modelOnly = true;
      expect(tracker.update(darkRoom, at: at(0)), ScanCondition.tooDark);
    });

    test('turning model-only off lets the colour check fill in again', () {
      final tracker = ScanConditionTracker()..modelOnly = true;
      tracker.update(bananaColours, at: at(0));
      tracker.modelOnly = false;
      expect(tracker.update(bananaColours, at: at(300)), ScanCondition.ready);
    });
  });

  group('LiveCheckPacer', () {
    test('starts at the fastest pace', () {
      expect(LiveCheckPacer().interval, LiveCheckPacer.minInterval);
    });

    test('a fast phone stays at the fastest pace', () {
      final pacer = LiveCheckPacer()..record(const Duration(milliseconds: 80));
      expect(pacer.interval, LiveCheckPacer.minInterval);
    });

    test('waits twice the run time on a slower phone', () {
      final pacer = LiveCheckPacer()..record(const Duration(milliseconds: 400));
      expect(pacer.interval, const Duration(milliseconds: 800));
    });

    test('never slower than the max interval', () {
      final pacer = LiveCheckPacer()..record(const Duration(seconds: 3));
      expect(pacer.interval, LiveCheckPacer.maxInterval);
    });

    test('smooths out a single slow run', () {
      final pacer = LiveCheckPacer()
        ..record(const Duration(milliseconds: 300))
        ..record(const Duration(milliseconds: 1300));
      // Average 300 + 0.3 * 1000 = 600 ms, so 1200 ms, not 2600 ms.
      expect(pacer.interval, const Duration(milliseconds: 1200));
    });

    test('verdicts stay valid across three runs, never under the default', () {
      expect(
        LiveCheckPacer().staleAfter,
        ScanConditionTracker.defaultModelStaleAfter,
      );
      final slow = LiveCheckPacer()..record(const Duration(seconds: 1));
      expect(slow.interval, const Duration(seconds: 2));
      expect(slow.staleAfter, const Duration(seconds: 6));
    });

    test('reset forgets the timing', () {
      final pacer = LiveCheckPacer()
        ..record(const Duration(seconds: 1))
        ..reset();
      expect(pacer.interval, LiveCheckPacer.minInterval);
    });
  });
}
