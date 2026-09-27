/// Widget tests for [CameraScreen] — A18.
///
/// Tests are run against the full [BananaClassifierApp] since [CameraScreen]
/// is tightly coupled with platform channels (permission_handler, camera).
/// The channel stubs from the shared `widget_test.dart` helpers are reused
/// via copy because dart test files cannot import from sibling test files
/// without a package.
import 'package:banana_classifier/main.dart';
import 'package:banana_classifier/models/scan_record.dart';
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

    testWidgets('shows History button with icon + label per §7.2',
        (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      expect(find.text('History'), findsOneWidget);
      expect(find.byIcon(Icons.history_rounded), findsOneWidget);
    });

    testWidgets('History button navigates to Scan History screen',
        (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('History'));
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

      expect(find.text('Scan'), findsNothing);
    });

    testWidgets('hide capture button when permanently denied', (tester) async {
      await tester.pumpWidget(buildApp(cameraStatus: 4));
      await tester.pumpAndSettle();

      expect(find.text('Scan'), findsNothing);
    });

    testWidgets(
        'denied view shows "Allow Camera" button per §7.2 (icon + label)',
        (tester) async {
      await tester.pumpWidget(buildApp(cameraStatus: 0));
      await tester.pumpAndSettle();

      expect(find.text('Allow Camera'), findsOneWidget);
      expect(find.byIcon(Icons.camera_alt), findsOneWidget);
    });

    testWidgets(
        'permanently denied view shows "Open Settings" button per §7.2',
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

      expect(find.text('Scan'), findsOneWidget);
    });

    testWidgets('Scan button pairs icon with label per §7.2', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.camera_alt_rounded), findsOneWidget);
      expect(find.text('Scan'), findsOneWidget);
    });

    testWidgets('tapping disabled Scan does not navigate away', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      // Camera not ready → button disabled, tap does nothing.
      await tester.tap(find.text('Scan'));
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
}
