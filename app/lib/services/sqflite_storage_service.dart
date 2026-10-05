import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../models/scan_record.dart';
import 'scan_photo_store.dart';
import 'storage_service.dart';

/// Concrete [StorageService] backed by a local sqflite database.
///
/// The database lives in the app-specific documents directory and contains a
/// single `scans` table whose columns match [ScanRecord.toMap].
///
/// Scan photos are **not** stored in the database: each one is copied into a
/// [ScanPhotoStore] next to it (also in the documents folder, so Android
/// never clears it) and only that path is saved in `image_path`. Deleting a
/// record deletes its photo too.
class SqfliteStorageService implements StorageService {
  SqfliteStorageService._();

  /// Builds a service around an already-open [database] and [photos] store,
  /// so tests can use an in-memory database and a temporary folder.
  @visibleForTesting
  SqfliteStorageService.withDatabase(Database database, ScanPhotoStore photos)
      : _db = database,
        _photos = photos;

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
  ScanPhotoStore? _photos;

  // ──────────────────────── database setup ──────────────────────────────

  Future<void> _open() async {
    final dir = await getApplicationDocumentsDirectory();
    final dbPath = join(dir.path, 'banana_check.db');

    _db = await openDatabase(
      dbPath,
      version: 1,
      onCreate: createTables,
    );
    _photos = ScanPhotoStore(Directory(join(dir.path, 'scan_photos')));
  }

  /// Creates the schema. Public so tests open a database identical to the
  /// app's instead of re-typing the SQL.
  @visibleForTesting
  static Future<void> createTables(Database db, int version) async {
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

  /// Saves [record], first moving its photo out of the cache into permanent
  /// storage. If the photo can't be copied, the record is still saved with
  /// its original path — a scan is never lost because of its picture.
  @override
  Future<void> saveRecord(ScanRecord record) async {
    var imagePath = record.imagePath;
    final photos = _photos;
    if (photos != null) {
      try {
        imagePath = await photos.persist(record.imagePath, record.id);
      } catch (error) {
        debugPrint('Could not keep scan photo ($error); using original path.');
      }
    }

    await _database.insert(
      'scans',
      ScanRecord(
        id: record.id,
        imagePath: imagePath,
        result: record.result,
        scannedAt: record.scannedAt,
      ).toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Deletes the record and its stored photo.
  @override
  Future<void> deleteRecord(String id) async {
    final rows = await _database.query(
      'scans',
      columns: ['image_path'],
      where: 'id = ?',
      whereArgs: [id],
    );
    await _database.delete(
      'scans',
      where: 'id = ?',
      whereArgs: [id],
    );
    for (final row in rows) {
      await _photos?.delete(row['image_path']! as String);
    }
  }

  /// Deletes every record and every stored photo.
  @override
  Future<void> clearRecords() async {
    await _database.delete('scans');
    await _photos?.clear();
  }
}
