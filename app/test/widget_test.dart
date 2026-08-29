import 'package:banana_classifier/main.dart';
import 'package:banana_classifier/services/mock_inference_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// ═══════════════════════════════════════════════════════════════════════
//  Platform-channel stubs
// ═══════════════════════════════════════════════════════════════════════

/// Stubs the [permission_handler] platform channel so that
/// `Permission.camera.status` and `Permission.camera.request()` return
/// the requested status without hitting real platform code.
///
/// Pass a different [cameraStatus] to simulate denied / permanentlyDenied.
void stubPermissionHandler({int cameraStatus = 1}) {
  const methodChannel = MethodChannel(
    'flutter.baseflow.com/permissions/methods',
  );

  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(methodChannel, (call) async {
    switch (call.method) {
      case 'checkPermissionStatus':
        // permission_handler sends the permission index; camera == 0.
        // Return an int matching PermissionStatus (0=denied, 1=granted, …).
        return cameraStatus;
      case 'requestPermissions':
        // Returns Map<int, int> — permission index → status.
        return <int, int>{call.arguments as int: cameraStatus};
      default:
        return null;
    }
  });
}

/// Stubs the camera plugin platform channels so that [availableCameras] and
/// [CameraController.initialize] don't crash in the test environment.
///
/// Returns an empty camera list which makes the screen show its camera-error
/// view ("No camera found on this device.") — this is the expected behavior
/// in the headless test environment.
void stubCameraChannels() {
  // camera plugin method channel
  const cameraChannel = MethodChannel('plugins.flutter.io/camera');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(cameraChannel, (call) async {
    switch (call.method) {
      case 'availableCameras':
        // Return empty list — no hardware camera in test.
        return <Map<String, dynamic>>[];
      default:
        return null;
    }
  });

  // camera_android_camerax uses its own channel
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
    // Default: camera permission granted + camera channels stubbed.
    stubPermissionHandler(cameraStatus: 1);
    stubCameraChannels();
  });

  tearDown(() {
    _clearChannelStub('flutter.baseflow.com/permissions/methods');
    _clearChannelStub('plugins.flutter.io/camera');
    _clearChannelStub('plugins.flutter.io/camera_android_camerax');
  });

  // ── Existing A5 core tests ──

  testWidgets('starts with one clear scan action and visible history',
      (tester) async {
    await tester.pumpWidget(
      BananaClassifierApp(inferenceService: MockInferenceService()),
    );
    // Let the permission check and camera init futures resolve.
    await tester.pumpAndSettle();

    expect(find.text('Banana Check'), findsOneWidget);
    // The capture button shows the "Scan" label below the circular button.
    expect(find.text('Scan'), findsOneWidget);
    expect(find.text('History'), findsOneWidget);
  });

  testWidgets('history remains one tap from the scan screen', (tester) async {
    await tester.pumpWidget(
      BananaClassifierApp(inferenceService: MockInferenceService()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();

    expect(find.text('Your past scans will appear here.'), findsOneWidget);
  });

  // ── A5-specific: permission handling UI tests ──

  testWidgets('shows allow-camera view when permission is denied',
      (tester) async {
    stubPermissionHandler(cameraStatus: 0); // 0 = denied

    await tester.pumpWidget(
      BananaClassifierApp(inferenceService: MockInferenceService()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Camera access needed'), findsOneWidget);
    expect(find.text('Allow Camera'), findsOneWidget);
    // The Scan button should NOT be visible when denied.
    expect(find.text('Scan'), findsNothing);
  });

  testWidgets('shows open-settings view when permission is permanently denied',
      (tester) async {
    stubPermissionHandler(cameraStatus: 4); // 4 = permanentlyDenied

    await tester.pumpWidget(
      BananaClassifierApp(inferenceService: MockInferenceService()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Camera is turned off'), findsOneWidget);
    expect(find.text('Open Settings'), findsOneWidget);
    // The Scan button should NOT be visible.
    expect(find.text('Scan'), findsNothing);
  });

  // ── A6-specific: camera error fallback in test environment ──

  testWidgets(
      'shows camera error view when no cameras are available (test env)',
      (tester) async {
    // Permission granted but stubCameraChannels returns empty list.
    stubPermissionHandler(cameraStatus: 1);

    await tester.pumpWidget(
      BananaClassifierApp(inferenceService: MockInferenceService()),
    );
    await tester.pumpAndSettle();

    // The error view should show a friendly message and a retry button.
    expect(find.text('No camera found on this device.'), findsOneWidget);
    expect(find.text('Try Again'), findsOneWidget);
    // Capture button with "Scan" label is still visible (permission granted).
    expect(find.text('Scan'), findsOneWidget);
  });

  // ── A7-specific: capture button tests ──

  testWidgets(
      'capture button is present but disabled when camera is not ready',
      (tester) async {
    // Permission granted, but no camera hardware → controller never
    // initialises → cameraReady is false → onPressed is null.
    stubPermissionHandler(cameraStatus: 1);

    await tester.pumpWidget(
      BananaClassifierApp(inferenceService: MockInferenceService()),
    );
    await tester.pumpAndSettle();

    // Capture button is rendered (label visible).
    expect(find.text('Scan'), findsOneWidget);

    // The camera icon is present inside the circular button.
    expect(find.byIcon(Icons.camera_alt), findsOneWidget);

    // Tapping does nothing because the camera isn't ready — no snackbar,
    // no navigation, no crash.
    await tester.tap(find.text('Scan'));
    await tester.pumpAndSettle();

    // Still on the camera screen, no crash or navigation occurred.
    expect(find.text('Banana Check'), findsOneWidget);
    expect(find.text('No camera found on this device.'), findsOneWidget);
  });

  testWidgets('capture button is hidden when permission is not granted',
      (tester) async {
    stubPermissionHandler(cameraStatus: 0); // denied

    await tester.pumpWidget(
      BananaClassifierApp(inferenceService: MockInferenceService()),
    );
    await tester.pumpAndSettle();

    // Capture button should not appear at all.
    expect(find.text('Scan'), findsNothing);
    expect(find.byIcon(Icons.camera_alt_outlined), findsOneWidget);
    expect(find.text('Camera access needed'), findsOneWidget);
  });

  testWidgets(
      'capture button pairs icon with label per §7.2 (no icon-only actions)',
      (tester) async {
    stubPermissionHandler(cameraStatus: 1);

    await tester.pumpWidget(
      BananaClassifierApp(inferenceService: MockInferenceService()),
    );
    await tester.pumpAndSettle();

    // Per §7.2: "never icon-only for critical actions — always pair an icon
    // with a short, plain-language label".
    // Both the camera icon and the "Scan" text label must be present.
    expect(find.byIcon(Icons.camera_alt), findsOneWidget);
    expect(find.text('Scan'), findsOneWidget);
  });
}
