import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../models/scan_record.dart';
import 'storage_service.dart';

/// Concrete [StorageService] backed by a local sqflite database.
///
/// The database lives in the app-specific documents directory and contains a
/// single `scans` table whose columns match [ScanRecord.toMap].
class SqfliteStorageService implements StorageService {
  SqfliteStorageService._();

  /// Singleton — the database is opened once and reused.
  static SqfliteStorageService? _instance;

  /// Returns the shared instance, opening the database on first call.
  static Future<SqfliteStorageService> instance() async {
    if (_instance != null) return _instance!;

    final service = SqfliteStorageService._();
    await service._open();
    _instance = service;
    return service;
  }

  /// Visible for testing: resets the singleton so the next [instance()] call
  /// creates a fresh service.  Call this in test tearDown to avoid leaking
  /// state between tests.
  static void resetForTesting() {
    _instance?._db?.close();
    _instance = null;
  }

  Database? _db;

  // ──────────────────────── database setup ──────────────────────────────

  Future<void> _open() async {
    final dir = await getApplicationDocumentsDirectory();
    final dbPath = join(dir.path, 'banana_check.db');

    _db = await openDatabase(
      dbPath,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
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
  }

  Database get _database {
    final db = _db;
    if (db == null) {
      throw StateError(
        'SqfliteStorageService has not been initialised. '
        'Call SqfliteStorageService.instance() first.',
      );
    }
    return db;
  }

  // ──────────────────────── StorageService API ─────────────────────────

  @override
  Future<List<ScanRecord>> getRecords() async {
    final rows = await _database.query(
      'scans',
      orderBy: 'scanned_at DESC',
    );
    return rows.map(ScanRecord.fromMap).toList();
  }

  @override
  Future<void> saveRecord(ScanRecord record) async {
    await _database.insert(
      'scans',
      record.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> deleteRecord(String id) async {
    await _database.delete(
      'scans',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<void> clearRecords() async {
    await _database.delete('scans');
  }
}
