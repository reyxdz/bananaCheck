import 'dart:io';

import 'package:banana_classifier/models/app_exception.dart';
import 'package:banana_classifier/models/classification_result.dart';
import 'package:banana_classifier/models/scan_record.dart';
import 'package:banana_classifier/screens/analyzing_screen.dart';
import 'package:banana_classifier/services/inference_service.dart';
import 'package:banana_classifier/services/storage_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// ═══════════════════════════════════════════════════════════════════════
//  A15 — AnalyzingScreen widget tests
// ═══════════════════════════════════════════════════════════════════════

// ── Fakes ────────────────────────────────────────────────────────────

/// An inference service that completes immediately with a fixed result.
class _InstantInferenceService implements InferenceService {
  _InstantInferenceService({required this.result});

  final ClassificationResult result;

  @override
  Future<ClassificationResult> classify(File imageFile) async => result;
}

/// An inference service that throws a *structured* error, to check it is
/// surfaced as-is rather than flattened into a generic one.
class _StructuredFailureService implements InferenceService {
  _StructuredFailureService(this.error);

  final AppException error;

  @override
  Future<ClassificationResult> classify(File imageFile) async => throw error;
}

/// Fails the first call and succeeds afterwards, so retry can be exercised.
class _FailsOnceService implements InferenceService {
  _FailsOnceService(this.result);

  final ClassificationResult result;
  int calls = 0;

  @override
  Future<ClassificationResult> classify(File imageFile) async {
    calls++;
    if (calls == 1) throw Exception('transient');
    return result;
  }
}

/// Storage that refuses to save, to check a scan still reaches the results.
class _FailingStorageService extends _FakeStorageService {
  @override
  Future<void> saveRecord(ScanRecord record) async {
    throw Exception('disk full');
  }
}

/// An inference service that always throws.
class _FailingInferenceService implements InferenceService {
  @override
  Future<ClassificationResult> classify(File imageFile) async {
    throw Exception('Model failed');
  }
}

class _FakeStorageService implements StorageService {
  final List<ScanRecord> records = [];
  int saveCallCount = 0;

  @override
  Future<List<ScanRecord>> getRecords() async =>
      List.unmodifiable(records.reversed);

  @override
  Future<void> saveRecord(ScanRecord record) async {
    saveCallCount++;
    records.add(record);
  }

  @override
  Future<void> deleteRecord(String id) async {
    records.removeWhere((r) => r.id == id);
  }

  @override
  Future<void> clearRecords() async {
    records.clear();
  }
}

// ── Tests ────────────────────────────────────────────────────────────

void main() {
  final defaultResult = ClassificationResult(
    variety: 'Saba',
    ripeness: 'Ripe',
    confidence: 0.92,
  );

  group('AnalyzingScreen', () {
    testWidgets('shows "Analyzing your banana…" text immediately',
        (tester) async {
      final inferenceService = _InstantInferenceService(result: defaultResult);
      final storageService = _FakeStorageService();

      await tester.pumpWidget(
        MaterialApp(
          home: AnalyzingScreen(
            inferenceService: inferenceService,
            storageService: storageService,
            capturedFile: File('test/fixtures/fake_image.jpg'),
            onComplete: (_, __) {},
          ),
        ),
      );

      // The analyzing text should be visible on the first frame.
      expect(find.text('Analyzing your banana…'), findsOneWidget);
      expect(find.text('This will only take a moment'), findsOneWidget);

      // Let microtasks settle (instant service completes on next microtask).
      await tester.pump();
    });

    testWidgets('shows a CircularProgressIndicator while classifying',
        (tester) async {
      final inferenceService = _InstantInferenceService(result: defaultResult);
      final storageService = _FakeStorageService();

      await tester.pumpWidget(
        MaterialApp(
          home: AnalyzingScreen(
            inferenceService: inferenceService,
            storageService: storageService,
            capturedFile: File('test/fixtures/fake_image.jpg'),
            onComplete: (_, __) {},
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Let microtasks settle.
      await tester.pump();
    });

    testWidgets('calls onComplete after successful classification',
        (tester) async {
      final inferenceService = _InstantInferenceService(result: defaultResult);
      final storageService = _FakeStorageService();

      ClassificationResult? receivedResult;
      String? receivedPath;

      await tester.pumpWidget(
        MaterialApp(
          home: AnalyzingScreen(
            inferenceService: inferenceService,
            storageService: storageService,
            capturedFile: File('test/fixtures/fake_image.jpg'),
            onComplete: (result, imagePath) {
              receivedResult = result;
              receivedPath = imagePath;
            },
          ),
        ),
      );

      // Pump once to let the async classify + save microtasks complete.
      await tester.pump();

      expect(receivedResult, isNotNull);
      expect(receivedResult!.variety, 'Saba');
      expect(receivedResult!.ripeness, 'Ripe');
      expect(receivedPath, 'test/fixtures/fake_image.jpg');
    });

    testWidgets('saves a record to storage on success', (tester) async {
      final inferenceService = _InstantInferenceService(result: defaultResult);
      final storageService = _FakeStorageService();

      await tester.pumpWidget(
        MaterialApp(
          home: AnalyzingScreen(
            inferenceService: inferenceService,
            storageService: storageService,
            capturedFile: File('test/fixtures/fake_image.jpg'),
            onComplete: (_, __) {},
          ),
        ),
      );

      // Pump once to let the async pipeline complete.
      await tester.pump();

      expect(storageService.saveCallCount, 1);
      expect(storageService.records, hasLength(1));
      expect(storageService.records.first.result.variety, 'Saba');
    });

    testWidgets('shows error state when classification fails', (tester) async {
      final inferenceService = _FailingInferenceService();
      final storageService = _FakeStorageService();

      await tester.pumpWidget(
        MaterialApp(
          home: AnalyzingScreen(
            inferenceService: inferenceService,
            storageService: storageService,
            capturedFile: File('test/fixtures/fake_image.jpg'),
            onComplete: (_, __) {},
          ),
        ),
      );

      // Pump once to let the failing future complete and setState fire.
      await tester.pump();

      // Error message should appear (ImageProcessingException per A16).
      expect(
        find.text(const ImageProcessingException().userMessage),
        findsOneWidget,
      );
      expect(
        find.text(const ImageProcessingException().actionHint),
        findsOneWidget,
      );
      // Try Again button should be visible.
      expect(find.text('Try Again'), findsOneWidget);
      // Go back link should be visible.
      expect(find.text('Go back to camera'), findsOneWidget);
    });

    testWidgets('error state shows error icon', (tester) async {
      final inferenceService = _FailingInferenceService();
      final storageService = _FakeStorageService();

      await tester.pumpWidget(
        MaterialApp(
          home: AnalyzingScreen(
            inferenceService: inferenceService,
            storageService: storageService,
            capturedFile: File('test/fixtures/fake_image.jpg'),
            onComplete: (_, __) {},
          ),
        ),
      );

      // Pump once to let the failing future complete.
      await tester.pump();

      expect(find.byIcon(Icons.broken_image_rounded), findsOneWidget);
    });

    testWidgets('shows low-confidence error when confidence < 0.5',
        (tester) async {
      final lowConfidenceResult = ClassificationResult(
        variety: 'Saba',
        ripeness: 'Ripe',
        confidence: 0.3, // Below 0.5 threshold
      );
      final inferenceService =
          _InstantInferenceService(result: lowConfidenceResult);
      final storageService = _FakeStorageService();

      await tester.pumpWidget(
        MaterialApp(
          home: AnalyzingScreen(
            inferenceService: inferenceService,
            storageService: storageService,
            capturedFile: File('test/fixtures/fake_image.jpg'),
            onComplete: (_, __) {},
          ),
        ),
      );

      await tester.pump();

      // Should show the low-confidence error, not the result.
      expect(
        find.text(const LowConfidenceException().userMessage),
        findsOneWidget,
      );
      expect(
        find.text(const LowConfidenceException().actionHint),
        findsOneWidget,
      );
      expect(find.text('Try Again'), findsOneWidget);
      // Storage should NOT have been called.
      expect(storageService.saveCallCount, 0);
    });

    testWidgets('shows the same error when the photo is not a banana',
        (tester) async {
      // The rejection class can win with high confidence — the model is sure
      // it is looking at something that is not a banana. Confidence alone
      // would wave it through.
      final notBanana = ClassificationResult(
        variety: ClassificationResult.notBananaVariety,
        ripeness: '',
        confidence: 0.97,
      );
      final storageService = _FakeStorageService();

      await tester.pumpWidget(
        MaterialApp(
          home: AnalyzingScreen(
            inferenceService: _InstantInferenceService(result: notBanana),
            storageService: storageService,
            capturedFile: File('test/fixtures/fake_image.jpg'),
            onComplete: (_, __) {},
          ),
        ),
      );

      await tester.pump();

      expect(
        find.text(const LowConfidenceException().userMessage),
        findsOneWidget,
      );
      expect(find.text('Try Again'), findsOneWidget);
      // A non-banana must never reach History.
      expect(storageService.saveCallCount, 0);
    });

    testWidgets('shows low-confidence error when the top two classes are close',
        (tester) async {
      final torn = ClassificationResult(
        variety: 'Saba',
        ripeness: 'Ripe',
        confidence: 0.55,
        margin: 0.04, // runner-up at 0.51 — effectively a coin toss
      );
      final storageService = _FakeStorageService();

      await tester.pumpWidget(
        MaterialApp(
          home: AnalyzingScreen(
            inferenceService: _InstantInferenceService(result: torn),
            storageService: storageService,
            capturedFile: File('test/fixtures/fake_image.jpg'),
            onComplete: (_, __) {},
          ),
        ),
      );

      await tester.pump();

      expect(
        find.text(const LowConfidenceException().userMessage),
        findsOneWidget,
      );
      expect(storageService.saveCallCount, 0);
    });

    testWidgets('rejects a scan whose margin sits just under the threshold',
        (tester) async {
      // Pins the tuned 0.20 gate (B18): 0.19 must be refused, and the test
      // below shows 0.80 is not. Without this, raising or lowering the
      // constant would pass silently.
      final borderline = ClassificationResult(
        variety: 'Saba',
        ripeness: 'Overripe',
        confidence: 0.70,
        margin: 0.19,
      );
      final storageService = _FakeStorageService();

      await tester.pumpWidget(
        MaterialApp(
          home: AnalyzingScreen(
            inferenceService: _InstantInferenceService(result: borderline),
            storageService: storageService,
            capturedFile: File('test/fixtures/fake_image.jpg'),
            onComplete: (_, __) {},
          ),
        ),
      );

      await tester.pump();

      expect(
        find.text(const LowConfidenceException().userMessage),
        findsOneWidget,
      );
      expect(storageService.saveCallCount, 0);
    });

    testWidgets('a confident banana with a clear margin still shows results',
        (tester) async {
      final good = ClassificationResult(
        variety: 'Lakatan',
        ripeness: 'Ripe',
        confidence: 0.91,
        margin: 0.80,
      );
      final storageService = _FakeStorageService();
      ClassificationResult? delivered;

      await tester.pumpWidget(
        MaterialApp(
          home: AnalyzingScreen(
            inferenceService: _InstantInferenceService(result: good),
            storageService: storageService,
            capturedFile: File('test/fixtures/fake_image.jpg'),
            onComplete: (result, __) => delivered = result,
          ),
        ),
      );

      // One pump lets the classify + save microtasks complete; the screen's
      // spinner animates forever, so pumpAndSettle would never return.
      await tester.pump();

      expect(
          find.text(const LowConfidenceException().userMessage), findsNothing);
      expect(delivered?.variety, 'Lakatan');
      expect(storageService.saveCallCount, 1);
    });

    testWidgets('surfaces a structured error from the service unchanged',
        (tester) async {
      // AppExceptions carry their own plain-language text; flattening them to
      // "Something went wrong" would lose the actionable part (§7.3).
      await tester.pumpWidget(
        MaterialApp(
          home: AnalyzingScreen(
            inferenceService:
                _StructuredFailureService(const AppCameraException()),
            storageService: _FakeStorageService(),
            capturedFile: File('test/fixtures/fake_image.jpg'),
            onComplete: (_, __) {},
          ),
        ),
      );

      await tester.pump();

      expect(
        find.text(const AppCameraException().userMessage),
        findsOneWidget,
      );
      expect(find.text(const UnknownException().userMessage), findsNothing);
    });

    testWidgets('a storage failure still delivers the result', (tester) async {
      ClassificationResult? delivered;

      await tester.pumpWidget(
        MaterialApp(
          home: AnalyzingScreen(
            inferenceService: _InstantInferenceService(result: defaultResult),
            storageService: _FailingStorageService(),
            capturedFile: File('test/fixtures/fake_image.jpg'),
            onComplete: (result, __) => delivered = result,
          ),
        ),
      );

      await tester.pump();

      // Classification succeeded, so the user must still see their result —
      // only the saving failed, and that is reported separately.
      expect(delivered, isNotNull);
      expect(find.byType(SnackBar), findsOneWidget);
    });

    testWidgets('retry clears the error and re-runs the scan', (tester) async {
      final service = _FailsOnceService(defaultResult);
      ClassificationResult? delivered;

      await tester.pumpWidget(
        MaterialApp(
          home: AnalyzingScreen(
            inferenceService: service,
            storageService: _FakeStorageService(),
            capturedFile: File('test/fixtures/fake_image.jpg'),
            onComplete: (result, __) => delivered = result,
          ),
        ),
      );

      await tester.pump();
      expect(find.text('Try Again'), findsOneWidget);
      expect(delivered, isNull);

      await tester.tap(find.text('Try Again'));
      await tester.pump();

      expect(service.calls, 2);
      expect(delivered, isNotNull);
    });
  });
}
