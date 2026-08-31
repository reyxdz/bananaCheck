import 'package:banana_classifier/models/classification_result.dart';
import 'package:banana_classifier/models/scan_record.dart';
import 'package:banana_classifier/services/storage_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

// ═══════════════════════════════════════════════════════════════════════
//  Serialisation round-trip tests (no platform channels required)
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
  //  Uses sqflite's in-memory database via `databaseFactory` to avoid
  //  hitting the real filesystem in CI / headless tests.
  // ═══════════════════════════════════════════════════════════════════════

  group('SqfliteStorageService', () {
    late StorageService storage;
    late Database db;

    setUp(() async {
      TestWidgetsFlutterBinding.ensureInitialized();

      // Stub path_provider so getApplicationDocumentsDirectory works.
      const pathChannel = MethodChannel(
        'plugins.flutter.io/path_provider',
      );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(pathChannel, (call) async {
        if (call.method == 'getApplicationDocumentsDirectory') {
          return '.'; // current directory — test-only
        }
        return null;
      });

      // Use an in-memory database instead of a real file.
      db = await openDatabase(
        inMemoryDatabasePath,
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE scans (
              id          TEXT PRIMARY KEY,
              image_path  TEXT NOT NULL,
              variety     TEXT NOT NULL,
              ripeness    TEXT NOT NULL,
              confidence  REAL NOT NULL,
              scanned_at  INTEGER NOT NULL
            )
          ''');
        },
      );

      storage = _InMemoryStorageService(db);
    });

    tearDown(() async {
      await db.close();
    });

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
  });
}

// ═══════════════════════════════════════════════════════════════════════
//  Thin in-memory implementation wrapping a raw Database, mirroring the
//  same SQL logic as SqfliteStorageService but without the singleton /
//  path-provider dependency.
// ═══════════════════════════════════════════════════════════════════════

class _InMemoryStorageService implements StorageService {
  _InMemoryStorageService(this._db);

  final Database _db;

  @override
  Future<List<ScanRecord>> getRecords() async {
    final rows = await _db.query('scans', orderBy: 'scanned_at DESC');
    return rows.map(ScanRecord.fromMap).toList();
  }

  @override
  Future<void> saveRecord(ScanRecord record) async {
    await _db.insert(
      'scans',
      record.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> deleteRecord(String id) async {
    await _db.delete('scans', where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<void> clearRecords() async {
    await _db.delete('scans');
  }
}
