import 'dart:io';
import 'dart:typed_data';

import 'package:banana_classifier/models/classification_result.dart';
import 'package:banana_classifier/models/scan_record.dart';
import 'package:banana_classifier/services/scan_photo_store.dart';
import 'package:banana_classifier/services/sqflite_storage_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

// ═══════════════════════════════════════════════════════════════════════
//  Serialisation round-trip tests (no database required)
// ═══════════════════════════════════════════════════════════════════════

void main() {
  group('ClassificationResult serialisation', () {
    test('toMap → fromMap round-trips correctly', () {
      final original = ClassificationResult(
        variety: 'Lakatan',
        ripeness: 'Ripe',
        confidence: 0.92,
      );

      final map = original.toMap();
      final restored = ClassificationResult.fromMap(map);

      expect(restored.variety, original.variety);
      expect(restored.ripeness, original.ripeness);
      expect(restored.confidence, original.confidence);
    });
  });

  group('ScanRecord serialisation', () {
    test('toMap → fromMap round-trips correctly', () {
      final now = DateTime(2026, 8, 31, 12, 0);
      final original = ScanRecord(
        id: 'abc-123',
        imagePath: '/data/user/0/com.example/files/scan_1.jpg',
        result: ClassificationResult(
          variety: 'Saba',
          ripeness: 'Unripe',
          confidence: 0.78,
        ),
        scannedAt: now,
      );

      final map = original.toMap();
      final restored = ScanRecord.fromMap(map);

      expect(restored.id, original.id);
      expect(restored.imagePath, original.imagePath);
      expect(restored.result.variety, original.result.variety);
      expect(restored.result.ripeness, original.result.ripeness);
      expect(restored.result.confidence, original.result.confidence);
      expect(
        restored.scannedAt.millisecondsSinceEpoch,
        original.scannedAt.millisecondsSinceEpoch,
      );
    });

    test('toMap flattens ClassificationResult into same row', () {
      final record = ScanRecord(
        id: 'test-1',
        imagePath: '/path/to/image.jpg',
        result: ClassificationResult(
          variety: 'Lakatan',
          ripeness: 'Ripe',
          confidence: 0.92,
        ),
        scannedAt: DateTime(2026),
      );

      final map = record.toMap();

      // All fields should be top-level keys (no nested maps).
      expect(map['id'], 'test-1');
      expect(map['image_path'], '/path/to/image.jpg');
      expect(map['variety'], 'Lakatan');
      expect(map['ripeness'], 'Ripe');
      expect(map['confidence'], 0.92);
      expect(map['scanned_at'], isA<int>());
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  //  SqfliteStorageService integration tests
  //
  //  Uses sqflite_common_ffi for an in-memory database that works in
  //  headless CI / test environments without platform channels.
  // ═══════════════════════════════════════════════════════════════════════

  group('SqfliteStorageService', () {
    late SqfliteStorageService storage;
    late Database db;
    late Directory tempDir;
    late ScanPhotoStore photos;

    setUpAll(() {
      // Initialise the FFI-based database factory once for all tests.
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    setUp(() async {
      // Each test gets a fresh in-memory database with the app's real schema,
      // and its own temporary photo folder.
      db = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: SqfliteStorageService.createTables,
        ),
      );
      tempDir = Directory.systemTemp.createTempSync('scan_photos_test');
      photos = ScanPhotoStore(Directory('${tempDir.path}/scan_photos'));
      storage = SqfliteStorageService.withDatabase(db, photos);
    });

    tearDown(() async {
      await db.close();
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });

    /// Writes a real JPEG of [width]×[height] where the camera would (cache).
    File cachePhoto(String name, {int width = 40, int height = 30}) {
      final image = img.Image(width: width, height: height);
      img.fill(image, color: img.ColorRgb8(230, 200, 60));
      final cache = Directory('${tempDir.path}/cache')..createSync();
      return File('${cache.path}/$name')
        ..writeAsBytesSync(img.encodeJpg(image));
    }

    ScanRecord makeRecord({
      String id = 'r1',
      String variety = 'Lakatan',
      String ripeness = 'Ripe',
      double confidence = 0.92,
      DateTime? scannedAt,
    }) {
      return ScanRecord(
        id: id,
        imagePath: '/path/$id.jpg',
        result: ClassificationResult(
          variety: variety,
          ripeness: ripeness,
          confidence: confidence,
        ),
        scannedAt: scannedAt ?? DateTime(2026, 8, 31),
      );
    }

    test('starts with no records', () async {
      expect(await storage.getRecords(), isEmpty);
    });

    test('saveRecord + getRecords round-trips', () async {
      final record = makeRecord();
      await storage.saveRecord(record);

      final records = await storage.getRecords();
      expect(records, hasLength(1));
      expect(records.first.id, record.id);
      expect(records.first.result.variety, 'Lakatan');
    });

    test('getRecords returns newest first', () async {
      await storage.saveRecord(makeRecord(
        id: 'old',
        scannedAt: DateTime(2026, 1, 1),
      ));
      await storage.saveRecord(makeRecord(
        id: 'new',
        scannedAt: DateTime(2026, 12, 31),
      ));

      final records = await storage.getRecords();
      expect(records.first.id, 'new');
      expect(records.last.id, 'old');
    });

    test('deleteRecord removes only the targeted record', () async {
      await storage.saveRecord(makeRecord(id: 'a'));
      await storage.saveRecord(makeRecord(id: 'b'));

      await storage.deleteRecord('a');

      final records = await storage.getRecords();
      expect(records, hasLength(1));
      expect(records.first.id, 'b');
    });

    test('clearRecords removes everything', () async {
      await storage.saveRecord(makeRecord(id: 'x'));
      await storage.saveRecord(makeRecord(id: 'y'));

      await storage.clearRecords();

      expect(await storage.getRecords(), isEmpty);
    });

    test('saveRecord with same id replaces existing', () async {
      await storage.saveRecord(makeRecord(id: 'dup', variety: 'Saba'));
      await storage.saveRecord(makeRecord(id: 'dup', variety: 'Lakatan'));

      final records = await storage.getRecords();
      expect(records, hasLength(1));
      expect(records.first.result.variety, 'Lakatan');
    });

    // ── Photos are kept out of the cache (Fix_image) ──

    group('scan photos', () {
      ScanRecord recordFor(File photo, {String id = 'p1'}) => ScanRecord(
            id: id,
            imagePath: photo.path,
            result: ClassificationResult(
              variety: 'Lakatan',
              ripeness: 'Ripe',
              confidence: 0.9,
            ),
            scannedAt: DateTime(2026, 10, 5),
          );

      test('saving copies the photo into permanent storage', () async {
        final photo = cachePhoto('CAP001.jpg');
        await storage.saveRecord(recordFor(photo));

        final saved = (await storage.getRecords()).single;
        expect(saved.imagePath, '${photos.directory.path}/p1.jpg');
        expect(File(saved.imagePath).existsSync(), isTrue);
      });

      test('history keeps its photo after the cache is cleared', () async {
        final photo = cachePhoto('CAP002.jpg');
        await storage.saveRecord(recordFor(photo));

        // Android clears the cache folder.
        photo.parent.deleteSync(recursive: true);

        final saved = (await storage.getRecords()).single;
        expect(File(saved.imagePath).existsSync(), isTrue);
        expect(
          img.decodeJpg(File(saved.imagePath).readAsBytesSync()),
          isNotNull,
        );
      });

      test('large photos are scaled down, small ones keep their size',
          () async {
        await storage.saveRecord(
          recordFor(cachePhoto('big.jpg', width: 3000, height: 2000),
              id: 'big'),
        );
        await storage.saveRecord(
          recordFor(cachePhoto('small.jpg', width: 400, height: 300),
              id: 'small'),
        );

        final big = img.decodeJpg(
          File('${photos.directory.path}/big.jpg').readAsBytesSync(),
        )!;
        expect(big.width, ScanPhotoStore.maxDimension);
        expect(big.height, closeTo(ScanPhotoStore.maxDimension * 2 / 3, 1));

        final small = img.decodeJpg(
          File('${photos.directory.path}/small.jpg').readAsBytesSync(),
        )!;
        expect(small.width, 400);
        expect(small.height, 300);
      });

      test('a missing photo still saves the scan with its original path',
          () async {
        await storage.saveRecord(
          recordFor(File('${tempDir.path}/gone.jpg'), id: 'gone'),
        );

        final saved = (await storage.getRecords()).single;
        expect(saved.id, 'gone');
        expect(saved.imagePath, '${tempDir.path}/gone.jpg');
      });

      test('deleting a record deletes its photo, not others', () async {
        await storage.saveRecord(recordFor(cachePhoto('a.jpg'), id: 'a'));
        await storage.saveRecord(recordFor(cachePhoto('b.jpg'), id: 'b'));

        await storage.deleteRecord('a');

        expect(File('${photos.directory.path}/a.jpg').existsSync(), isFalse);
        expect(File('${photos.directory.path}/b.jpg').existsSync(), isTrue);
      });

      test('clearing history deletes all stored photos', () async {
        await storage.saveRecord(recordFor(cachePhoto('a.jpg'), id: 'a'));
        await storage.saveRecord(recordFor(cachePhoto('b.jpg'), id: 'b'));

        await storage.clearRecords();

        expect(await storage.getRecords(), isEmpty);
        expect(photos.directory.existsSync(), isFalse);
      });

      test('never deletes files outside its own folder', () async {
        // An old record saved before this fix, still pointing at the cache.
        final old = cachePhoto('old.jpg');
        await db.insert('scans', recordFor(old, id: 'old').toMap());

        await storage.deleteRecord('old');

        expect(await storage.getRecords(), isEmpty);
        expect(old.existsSync(), isTrue);
      });
    });

    test('shrinkToJpeg returns null for bytes that are not an image', () {
      expect(
        ScanPhotoStore.shrinkToJpeg(Uint8List.fromList([1, 2, 3])),
        isNull,
      );
    });
  });
}
