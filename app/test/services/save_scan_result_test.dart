import 'dart:io';

import 'package:banana_classifier/models/classification_result.dart';
import 'package:banana_classifier/models/scan_record.dart';
import 'package:banana_classifier/services/inference_service.dart';
import 'package:banana_classifier/services/storage_service.dart';
import 'package:flutter_test/flutter_test.dart';

// ═══════════════════════════════════════════════════════════════════════
//  A12 — Save scan result to local storage
//
//  These tests verify the save-to-storage integration without any
//  platform channels, using in-memory fakes for both the inference
//  service and the storage service.
// ═══════════════════════════════════════════════════════════════════════

// ── Fakes ────────────────────────────────────────────────────────────

class _FakeInferenceService implements InferenceService {
  _FakeInferenceService({ClassificationResult? result})
      : result = result ??
            ClassificationResult(
              variety: 'Lakatan',
              ripeness: 'Ripe',
              confidence: 0.92,
            );

  final ClassificationResult result;
  int callCount = 0;

  @override
  Future<ClassificationResult> classify(File imageFile) async {
    callCount++;
    return result;
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
    records.removeWhere((r) => r.id == record.id);
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

// ── Helpers ──────────────────────────────────────────────────────────

/// Simulates the _handleScan flow from main.dart:
///   1. Call inferenceService.classify(imageFile)
///   2. Build a ScanRecord
///   3. Call storageService.saveRecord(record)
///
/// Extracted so it can be tested without Widget pumping or platform
/// channels — this is a pure-logic test.
Future<ScanRecord> simulateHandleScan({
  required InferenceService inferenceService,
  required StorageService storageService,
  required File capturedFile,
}) async {
  final result = await inferenceService.classify(capturedFile);

  final record = ScanRecord(
    id: 'test-${DateTime.now().microsecondsSinceEpoch}',
    imagePath: capturedFile.path,
    result: result,
    scannedAt: DateTime.now(),
  );

  await storageService.saveRecord(record);
  return record;
}

// ═══════════════════════════════════════════════════════════════════════

void main() {
  group('A12 — Save scan result to local storage', () {
    late _FakeInferenceService inference;
    late _FakeStorageService storage;
    late File fakeImageFile;

    setUp(() {
      inference = _FakeInferenceService();
      storage = _FakeStorageService();
      // A File object with a path — we never read the bytes in these tests.
      fakeImageFile = File('/data/user/0/com.example/files/scan_1.jpg');
    });

    test('classify + save round-trips the result to storage', () async {
      await simulateHandleScan(
        inferenceService: inference,
        storageService: storage,
        capturedFile: fakeImageFile,
      );

      expect(inference.callCount, 1);
      expect(storage.saveCallCount, 1);
      expect(storage.records, hasLength(1));

      final saved = storage.records.first;
      expect(saved.imagePath, fakeImageFile.path);
      expect(saved.result.variety, 'Lakatan');
      expect(saved.result.ripeness, 'Ripe');
      expect(saved.result.confidence, 0.92);
    });

    test('each scan creates a unique record id', () async {
      await simulateHandleScan(
        inferenceService: inference,
        storageService: storage,
        capturedFile: fakeImageFile,
      );
      // Small delay to ensure microsecond-based ids differ.
      await Future<void>.delayed(const Duration(milliseconds: 1));
      await simulateHandleScan(
        inferenceService: inference,
        storageService: storage,
        capturedFile: fakeImageFile,
      );

      expect(storage.records, hasLength(2));
      expect(storage.records[0].id, isNot(storage.records[1].id));
    });

    test('scannedAt is set to approximately now', () async {
      final before = DateTime.now();
      final record = await simulateHandleScan(
        inferenceService: inference,
        storageService: storage,
        capturedFile: fakeImageFile,
      );
      final after = DateTime.now();

      expect(
        record.scannedAt.millisecondsSinceEpoch,
        greaterThanOrEqualTo(before.millisecondsSinceEpoch),
      );
      expect(
        record.scannedAt.millisecondsSinceEpoch,
        lessThanOrEqualTo(after.millisecondsSinceEpoch),
      );
    });

    test('imagePath matches the captured file', () async {
      final record = await simulateHandleScan(
        inferenceService: inference,
        storageService: storage,
        capturedFile: fakeImageFile,
      );

      expect(record.imagePath, fakeImageFile.path);
    });

    test('classification result fields are preserved in storage', () async {
      final customResult = ClassificationResult(
        variety: 'Saba',
        ripeness: 'Overripe',
        confidence: 0.65,
      );
      final customInference = _FakeInferenceService(result: customResult);

      await simulateHandleScan(
        inferenceService: customInference,
        storageService: storage,
        capturedFile: fakeImageFile,
      );

      final saved = storage.records.first;
      expect(saved.result.variety, 'Saba');
      expect(saved.result.ripeness, 'Overripe');
      expect(saved.result.confidence, 0.65);
    });

    test('multiple scans accumulate in storage', () async {
      for (var i = 0; i < 5; i++) {
        await simulateHandleScan(
          inferenceService: inference,
          storageService: storage,
          capturedFile: File('/scan_$i.jpg'),
        );
        // Ensure unique microsecond-based ids.
        await Future<void>.delayed(const Duration(milliseconds: 1));
      }

      expect(storage.records, hasLength(5));
      expect(storage.saveCallCount, 5);
    });

    test('saved records are retrievable via getRecords', () async {
      await simulateHandleScan(
        inferenceService: inference,
        storageService: storage,
        capturedFile: fakeImageFile,
      );

      final retrieved = await storage.getRecords();
      expect(retrieved, hasLength(1));
      expect(retrieved.first.result.variety, 'Lakatan');
    });
  });
}
