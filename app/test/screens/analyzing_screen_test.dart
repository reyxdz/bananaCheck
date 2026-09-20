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
  });
}
