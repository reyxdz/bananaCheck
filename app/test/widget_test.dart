import 'package:banana_classifier/main.dart';
import 'package:banana_classifier/services/mock_inference_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Stubs the [permission_handler] platform channel so that
/// `Permission.camera.status` and `Permission.camera.request()` return
/// [PermissionStatus.granted] without hitting real platform code.
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

void main() {
  setUp(() {
    // Default: camera permission granted.
    stubPermissionHandler(cameraStatus: 1);
  });

  tearDown(() {
    const methodChannel = MethodChannel(
      'flutter.baseflow.com/permissions/methods',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(methodChannel, null);
  });

  testWidgets('starts with one clear scan action and visible history',
      (tester) async {
    await tester.pumpWidget(
      BananaClassifierApp(inferenceService: MockInferenceService()),
    );
    // Let the permission check future resolve.
    await tester.pumpAndSettle();

    expect(find.text('Banana Check'), findsOneWidget);
    expect(find.text('Point at a banana and tap Scan.'), findsOneWidget);
    expect(find.text('Scan'), findsOneWidget);
    expect(find.text('History'), findsOneWidget);
  });

  testWidgets('scan action shows the deterministic development result',
      (tester) async {
    await tester.pumpWidget(
      BananaClassifierApp(inferenceService: MockInferenceService()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Scan'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Mock ready: Lakatan — Ripe'), findsOneWidget);
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
}
