/// Widget tests for [CameraScreen] — A18.
///
/// Tests are run against the full [BananaClassifierApp] since [CameraScreen]
/// is tightly coupled with platform channels (permission_handler, camera).
/// The channel stubs from the shared `widget_test.dart` helpers are reused
/// via copy because dart test files cannot import from sibling test files
/// without a package.
library;

import 'dart:async';
import 'dart:io';

import 'package:banana_classifier/main.dart';
import 'package:banana_classifier/models/scan_record.dart';
import 'package:banana_classifier/screens/camera_screen.dart';
import 'package:banana_classifier/services/mock_inference_service.dart';
import 'package:banana_classifier/services/storage_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// ═══════════════════════════════════════════════════════════════════════
//  Test helpers — duplicated from widget_test.dart because Dart test
//  files can't cross-import without a package.
// ═══════════════════════════════════════════════════════════════════════

class FakeStorageService implements StorageService {
  final List<ScanRecord> _records = [];

  @override
  Future<List<ScanRecord>> getRecords() async =>
      List.unmodifiable(_records.reversed);

  @override
  Future<void> saveRecord(ScanRecord record) async {
    _records.removeWhere((r) => r.id == record.id);
    _records.add(record);
  }

  @override
  Future<void> deleteRecord(String id) async {
    _records.removeWhere((r) => r.id == id);
  }

  @override
  Future<void> clearRecords() async {
    _records.clear();
  }
}

void stubPermissionHandler({int cameraStatus = 1}) {
  const methodChannel = MethodChannel(
    'flutter.baseflow.com/permissions/methods',
  );
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(methodChannel, (call) async {
    switch (call.method) {
      case 'checkPermissionStatus':
        return cameraStatus;
      case 'requestPermissions':
        return <int, int>{call.arguments as int: cameraStatus};
      default:
        return null;
    }
  });
}

void stubCameraChannels() {
  const cameraChannel = MethodChannel('plugins.flutter.io/camera');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(cameraChannel, (call) async {
    switch (call.method) {
      case 'availableCameras':
        return <Map<String, dynamic>>[];
      default:
        return null;
    }
  });

  const cameraxChannel = MethodChannel(
    'plugins.flutter.io/camera_android_camerax',
  );
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(cameraxChannel, (call) async {
    switch (call.method) {
      case 'availableCameras':
        return <Map<String, dynamic>>[];
      default:
        return null;
    }
  });
}

void _clearChannelStub(String name) {
  final channel = MethodChannel(name);
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, null);
}

// ═══════════════════════════════════════════════════════════════════════

void main() {
  setUp(() {
    stubPermissionHandler(cameraStatus: 1);
    stubCameraChannels();
  });

  tearDown(() {
    _clearChannelStub('flutter.baseflow.com/permissions/methods');
    _clearChannelStub('plugins.flutter.io/camera');
    _clearChannelStub('plugins.flutter.io/camera_android_camerax');
  });

  Widget buildApp({int cameraStatus = 1}) {
    stubPermissionHandler(cameraStatus: cameraStatus);
    return BananaClassifierApp(
      inferenceService: MockInferenceService(),
      storageService: FakeStorageService(),
    );
  }

  group('CameraScreen — Layout & Branding', () {
    testWidgets('shows app title "Bananalyze" in top bar', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      expect(find.text('Bananalyze'), findsOneWidget);
    });

    testWidgets('History is a quiet icon button with an accessible label',
        (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.history_rounded), findsOneWidget);
      // No visible text label competing with Scan…
      expect(find.text('History'), findsNothing);
      // …but screen readers and long-press still get "History".
      expect(find.byTooltip('History'), findsOneWidget);
      final size = tester.getSize(
        find.ancestor(
          of: find.byIcon(Icons.history_rounded),
          matching: find.byType(IconButton),
        ),
      );
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
    });

    testWidgets('History button navigates to Scan History screen',
        (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('History'));
      await tester.pumpAndSettle();

      expect(find.text('Scan History'), findsOneWidget);
    });
  });

  group('CameraScreen — Permission Handling (A5)', () {
    testWidgets('shows "Camera access needed" when denied', (tester) async {
      await tester.pumpWidget(buildApp(cameraStatus: 0));
      await tester.pumpAndSettle();

      expect(find.text('Camera access needed'), findsOneWidget);
      expect(find.text('Allow Camera'), findsOneWidget);
    });

    testWidgets('shows "Camera is turned off" when permanently denied',
        (tester) async {
      await tester.pumpWidget(buildApp(cameraStatus: 4));
      await tester.pumpAndSettle();

      expect(find.text('Camera is turned off'), findsOneWidget);
      expect(find.text('Open Settings'), findsOneWidget);
    });

    testWidgets('hide capture button when permission denied', (tester) async {
      await tester.pumpWidget(buildApp(cameraStatus: 0));
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('Scan'), findsNothing);
    });

    testWidgets('hide capture button when permanently denied', (tester) async {
      await tester.pumpWidget(buildApp(cameraStatus: 4));
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('Scan'), findsNothing);
    });

    testWidgets(
        'denied view shows "Allow Camera" button per §7.2 (icon + label)',
        (tester) async {
      await tester.pumpWidget(buildApp(cameraStatus: 0));
      await tester.pumpAndSettle();

      expect(find.text('Allow Camera'), findsOneWidget);
      expect(find.byIcon(Icons.camera_alt), findsOneWidget);
    });

    testWidgets('permanently denied view shows "Open Settings" button per §7.2',
        (tester) async {
      await tester.pumpWidget(buildApp(cameraStatus: 4));
      await tester.pumpAndSettle();

      expect(find.text('Open Settings'), findsOneWidget);
      expect(find.byIcon(Icons.settings), findsOneWidget);
    });
  });

  group('CameraScreen — Camera Error (A6)', () {
    testWidgets('shows friendly error when no cameras available',
        (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      expect(find.text('No camera found on this device.'), findsOneWidget);
    });

    testWidgets('shows Try Again button on camera error', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      expect(find.text('Try Again'), findsOneWidget);
      expect(find.byIcon(Icons.refresh), findsOneWidget);
    });

    testWidgets('error view uses error_outline icon', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });
  });

  group('CameraScreen — Capture Button (A7)', () {
    testWidgets('shows Scan button when permission granted', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('Scan'), findsOneWidget);
    });

    testWidgets('Scan button pairs icon with label per §7.2', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.camera_alt_rounded), findsOneWidget);
      expect(find.bySemanticsLabel('Scan'), findsOneWidget);
    });

    testWidgets('tapping disabled Scan does not navigate away', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      // Camera not ready → button disabled, tap does nothing.
      await tester.tap(find.bySemanticsLabel('Scan'));
      await tester.pumpAndSettle();

      // Still on camera screen.
      expect(find.text('Bananalyze'), findsOneWidget);
    });
  });

  group('CameraScreen — §7 UI Rules', () {
    testWidgets('no jargon visible on any camera state', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      expect(find.textContaining('exception'), findsNothing);
      expect(find.textContaining('error code'), findsNothing);
      expect(find.textContaining('permission_handler'), findsNothing);
    });

    testWidgets('denied view explains purpose in plain language',
        (tester) async {
      await tester.pumpWidget(buildApp(cameraStatus: 0));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Bananalyze needs to use your camera'),
        findsOneWidget,
      );
    });

    testWidgets('permanently denied view directs user to Settings',
        (tester) async {
      await tester.pumpWidget(buildApp(cameraStatus: 4));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Settings'),
        findsWidgets,
      );
    });
  });

  // ── A33: upload image from gallery (§7.8) ──

  group('CameraScreen — Upload Photo', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('upload_test');
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    File tempImage(String name, {int bytes = 16}) =>
        File('${tempDir.path}/$name')..writeAsBytesSync(List.filled(bytes, 0));

    /// Pumps [CameraScreen] on its own with a fake gallery. Defaults to
    /// camera permission denied, since that is where Upload a Photo lives.
    Future<List<File>> pumpScreen(
      WidgetTester tester, {
      required GalleryPicker picker,
      int cameraStatus = 0,
    }) async {
      stubPermissionHandler(cameraStatus: cameraStatus);
      final scanned = <File>[];
      await tester.pumpWidget(
        MaterialApp(
          home: CameraScreen(
            onScan: scanned.add,
            onHistory: () {},
            pickFromGallery: picker,
          ),
        ),
      );
      await tester.pumpAndSettle();
      return scanned;
    }

    /// Taps Upload a Photo and lets the real file-system checks finish.
    Future<void> tapUpload(WidgetTester tester) async {
      await tester.tap(find.text('Upload a Photo'));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('shows Upload a Photo with icon + label per §7.2',
        (tester) async {
      await pumpScreen(tester, picker: () async => null);

      expect(find.text('Upload a Photo'), findsOneWidget);
      expect(find.byIcon(Icons.photo_library_outlined), findsOneWidget);
      expect(
        tester
            .getSize(
              find.ancestor(
                of: find.text('Upload a Photo'),
                matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
              ),
            )
            .height,
        greaterThanOrEqualTo(48),
      );
    });

    testWidgets('with camera: gallery · shutter · flash control row',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await pumpScreen(tester, picker: () async => null, cameraStatus: 1);

      Rect buttonRect(String tooltip) => tester.getRect(
            find.ancestor(
              of: find.byTooltip(tooltip),
              matching: find.byType(IconButton),
            ),
          );
      final gallery = buttonRect('Upload a Photo');
      final shutter = tester.getRect(find.bySemanticsLabel('Scan'));
      final flash = buttonRect('Turn flash on');

      // Left · centre · right, all on one row.
      expect(gallery.right, lessThan(shutter.left));
      expect(flash.left, greaterThan(shutter.right));
      expect(shutter.center.dx, closeTo(180, 1));
      expect((gallery.center.dy - shutter.center.dy).abs(), lessThan(1));
      expect((flash.center.dy - shutter.center.dy).abs(), lessThan(1));

      // The shutter is the biggest target; side buttons still meet 48dp.
      expect(shutter.width, greaterThan(gallery.width));
      expect(gallery.width, greaterThanOrEqualTo(48));
      expect(flash.width, greaterThanOrEqualTo(48));

      // No separate text labels any more — tooltips/semantics carry them.
      expect(find.text('Scan'), findsNothing);
      expect(find.text('Upload a Photo'), findsNothing);
    });

    testWidgets('with camera: gallery works even when the camera fails',
        (tester) async {
      final photo = tempImage('banana.jpg');
      final scanned = await pumpScreen(
        tester,
        picker: () async => photo,
        cameraStatus: 1,
      );
      // The test stubs report no camera hardware.
      expect(find.text('No camera found on this device.'), findsOneWidget);

      await tester.tap(find.byTooltip('Upload a Photo'));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pumpAndSettle();

      expect(scanned, [photo]);
    });

    testWidgets('with camera: flash and shutter are off until camera is ready',
        (tester) async {
      await pumpScreen(tester, picker: () async => null, cameraStatus: 1);

      final flash = tester.widget<IconButton>(
        find.ancestor(
          of: find.byIcon(Icons.flash_off_rounded),
          matching: find.byType(IconButton),
        ),
      );
      expect(flash.onPressed, isNull);
      expect(
        tester.getSemantics(find.bySemanticsLabel('Scan')),
        isNot(matchesSemantics(isEnabled: true)),
      );
    });

    /// Finds the button that renders [label], whatever its concrete type.
    Finder buttonFor(String label) => find.ancestor(
          of: find.text(label),
          matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
        );

    for (final (status, primary) in [
      (0, 'Allow Camera'),
      (4, 'Open Settings')
    ]) {
      testWidgets(
          'without camera: filled "$primary" with outlined upload below it, '
          'both in the thumb zone', (tester) async {
        await pumpScreen(
          tester,
          picker: () async => null,
          cameraStatus: status,
        );

        final primaryButton = buttonFor(primary);
        final uploadButton = buttonFor('Upload a Photo');
        expect(tester.widget(primaryButton), isA<FilledButton>());
        expect(tester.widget(uploadButton), isA<OutlinedButton>());

        // Upload sits directly below the primary action…
        final primaryRect = tester.getRect(primaryButton);
        final uploadRect = tester.getRect(uploadButton);
        expect(uploadRect.top, greaterThan(primaryRect.bottom));
        expect(uploadRect.top - primaryRect.bottom, lessThanOrEqualTo(16));

        // …and both are in the lower third of the screen, easy to reach
        // with a thumb.
        final screenHeight =
            tester.view.physicalSize.height / tester.view.devicePixelRatio;
        expect(primaryRect.top, greaterThan(screenHeight * 2 / 3));
        expect(uploadRect.bottom, lessThanOrEqualTo(screenHeight));
        expect(uploadRect.height, greaterThanOrEqualTo(48));
      });
    }

    testWidgets('upload works when the camera is turned off in Settings',
        (tester) async {
      final photo = tempImage('banana.jpg');
      final scanned = await pumpScreen(
        tester,
        picker: () async => photo,
        cameraStatus: 4,
      );

      await tapUpload(tester);

      expect(scanned, [photo]);
    });

    testWidgets('picked JPG goes to the same onScan callback as capture',
        (tester) async {
      final photo = tempImage('banana.jpg');
      final scanned = await pumpScreen(tester, picker: () async => photo);

      await tapUpload(tester);

      expect(scanned, [photo]);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('accepts PNG regardless of extension case', (tester) async {
      final photo = tempImage('banana.PNG');
      final scanned = await pumpScreen(tester, picker: () async => photo);

      await tapUpload(tester);

      expect(scanned, [photo]);
    });

    testWidgets('cancelling the picker does nothing', (tester) async {
      final scanned = await pumpScreen(tester, picker: () async => null);

      await tapUpload(tester);

      expect(scanned, isEmpty);
      expect(find.byType(SnackBar), findsNothing);
      expect(find.text('Upload a Photo'), findsOneWidget);
    });

    testWidgets('unsupported file shows a plain-language error',
        (tester) async {
      final gif = tempImage('banana.gif');
      final scanned = await pumpScreen(tester, picker: () async => gif);

      await tapUpload(tester);

      expect(scanned, isEmpty);
      expect(find.textContaining('JPG or PNG'), findsOneWidget);
    });

    testWidgets('picker failure shows a plain-language error', (tester) async {
      final scanned = await pumpScreen(
        tester,
        picker: () async => throw Exception('picker crashed'),
      );

      await tapUpload(tester);

      expect(scanned, isEmpty);
      expect(find.textContaining('Could not open that photo'), findsOneWidget);
    });

    testWidgets('files over 20 MB show a plain-language error', (tester) async {
      final huge = tempImage('huge.jpg', bytes: 20 * 1024 * 1024 + 1);
      final scanned = await pumpScreen(tester, picker: () async => huge);

      await tapUpload(tester);

      expect(scanned, isEmpty);
      expect(find.textContaining('JPG or PNG'), findsOneWidget);
    });

    testWidgets('is disabled while the picker is open (no double-open)',
        (tester) async {
      var opened = 0;
      final pending = Completer<File?>();
      await pumpScreen(
        tester,
        picker: () {
          opened++;
          return pending.future;
        },
      );

      await tester.tap(find.text('Upload a Photo'));
      await tester.pump();
      expect(
        tester.widget<ButtonStyleButton>(buttonFor('Upload a Photo')).enabled,
        isFalse,
      );

      await tester.tap(find.text('Upload a Photo'), warnIfMissed: false);
      await tester.pump();
      expect(opened, 1);

      // User backs out — the button comes back.
      pending.complete(null);
      await tester.pumpAndSettle();
      expect(
        tester.widget<ButtonStyleButton>(buttonFor('Upload a Photo')).enabled,
        isTrue,
      );
    });
  });
}
