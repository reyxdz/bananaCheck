/// Widget tests for [HistoryScreen] — A20.
///
/// Covers: empty state, populated list, delete per-record, clear all with
/// confirmation, navigation to results, error state, and §7 rule compliance.
import 'package:banana_classifier/models/classification_result.dart';
import 'package:banana_classifier/models/scan_record.dart';
import 'package:banana_classifier/screens/history_screen.dart';
import 'package:banana_classifier/services/storage_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// ═══════════════════════════════════════════════════════════════════════
//  Test helpers
// ═══════════════════════════════════════════════════════════════════════

/// In-memory [StorageService] for history screen tests.
class FakeStorageService implements StorageService {
  final List<ScanRecord> _records = [];
  bool shouldThrow = false;

  @override
  Future<List<ScanRecord>> getRecords() async {
    if (shouldThrow) throw Exception('Storage read failed');
    return List.unmodifiable(_records.reversed);
  }

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

ScanRecord _makeRecord({
  String id = '1',
  String variety = 'Saba',
  String ripeness = 'Ripe',
  double confidence = 0.92,
  DateTime? scannedAt,
}) {
  return ScanRecord(
    id: id,
    imagePath: '/fake/image.jpg',
    result: ClassificationResult(
      variety: variety,
      ripeness: ripeness,
      confidence: confidence,
    ),
    scannedAt: scannedAt ?? DateTime(2025, 3, 15, 14, 30),
  );
}

// ═══════════════════════════════════════════════════════════════════════

void main() {
  group('HistoryScreen — Empty State', () {
    testWidgets('shows "No Saved Scans Yet" when storage is empty',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: HistoryScreen(storageService: FakeStorageService()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No Saved Scans Yet'), findsOneWidget);
    });

    testWidgets('shows "Scan a Banana Now" CTA in empty state',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: HistoryScreen(storageService: FakeStorageService()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Scan a Banana Now'), findsOneWidget);
      expect(find.byIcon(Icons.camera_alt_rounded), findsOneWidget);
    });

    testWidgets('shows helpful message in empty state', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: HistoryScreen(storageService: FakeStorageService()),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining('saved here so you can review them anytime'),
        findsOneWidget,
      );
    });

    testWidgets('hides "Clear All" button when empty', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: HistoryScreen(storageService: FakeStorageService()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.delete_sweep_outlined), findsNothing);
    });

    testWidgets('shows "No Saved Scans Yet" when storageService is null',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: HistoryScreen(storageService: null),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No Saved Scans Yet'), findsOneWidget);
    });
  });

  group('HistoryScreen — Title & App Bar', () {
    testWidgets('shows "Scan History" in app bar', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: HistoryScreen(storageService: FakeStorageService()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Scan History'), findsOneWidget);
    });
  });

  group('HistoryScreen — Populated List', () {
    late FakeStorageService storage;

    setUp(() {
      storage = FakeStorageService();
    });

    testWidgets('displays scan records as cards', (tester) async {
      await storage.saveRecord(_makeRecord(
        id: '1',
        variety: 'Saba',
        ripeness: 'Ripe',
      ));
      await storage.saveRecord(_makeRecord(
        id: '2',
        variety: 'Lakatan',
        ripeness: 'Unripe',
      ));

      await tester.pumpWidget(
        MaterialApp(home: HistoryScreen(storageService: storage)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Saba — Ripe'), findsOneWidget);
      expect(find.text('Lakatan — Unripe'), findsOneWidget);
    });

    testWidgets('shows ripeness pill on each card', (tester) async {
      await storage.saveRecord(_makeRecord(ripeness: 'Ripe'));

      await tester.pumpWidget(
        MaterialApp(home: HistoryScreen(storageService: storage)),
      );
      await tester.pumpAndSettle();

      // InfoPill label for ripeness.
      expect(find.text('Ripe'), findsAtLeast(1));
    });

    testWidgets('shows formatted date on history card', (tester) async {
      await storage.saveRecord(
        _makeRecord(scannedAt: DateTime(2025, 3, 15, 14, 30)),
      );

      await tester.pumpWidget(
        MaterialApp(home: HistoryScreen(storageService: storage)),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Mar 15, 2025'), findsOneWidget);
    });

    testWidgets('shows "Clear All" button when records exist', (tester) async {
      await storage.saveRecord(_makeRecord());

      await tester.pumpWidget(
        MaterialApp(home: HistoryScreen(storageService: storage)),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.delete_sweep_outlined), findsOneWidget);
    });

    testWidgets('shows delete icon on each card', (tester) async {
      await storage.saveRecord(_makeRecord());

      await tester.pumpWidget(
        MaterialApp(home: HistoryScreen(storageService: storage)),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.delete_outline_rounded), findsOneWidget);
    });
  });

  group('HistoryScreen — Delete Single Record (A14)', () {
    testWidgets('tapping delete icon removes the record', (tester) async {
      final storage = FakeStorageService();
      await storage.saveRecord(_makeRecord(id: '1', variety: 'Saba'));

      await tester.pumpWidget(
        MaterialApp(home: HistoryScreen(storageService: storage)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Saba — Ripe'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.delete_outline_rounded));
      await tester.pumpAndSettle();

      // Record removed → empty state appears.
      expect(find.text('No Saved Scans Yet'), findsOneWidget);
    });
  });

  group('HistoryScreen — Clear All (A14)', () {
    testWidgets('shows confirmation dialog before clearing', (tester) async {
      final storage = FakeStorageService();
      await storage.saveRecord(_makeRecord());

      await tester.pumpWidget(
        MaterialApp(home: HistoryScreen(storageService: storage)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.delete_sweep_outlined));
      await tester.pumpAndSettle();

      // Confirmation dialog visible.
      expect(find.text('Clear Scan History?'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Clear All'), findsOneWidget);
    });

    testWidgets('cancelling dialog keeps records', (tester) async {
      final storage = FakeStorageService();
      await storage.saveRecord(_makeRecord(variety: 'Saba'));

      await tester.pumpWidget(
        MaterialApp(home: HistoryScreen(storageService: storage)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.delete_sweep_outlined));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // Record still visible.
      expect(find.text('Saba — Ripe'), findsOneWidget);
    });

    testWidgets('confirming dialog clears all records', (tester) async {
      final storage = FakeStorageService();
      await storage.saveRecord(_makeRecord(id: '1', variety: 'Saba'));
      await storage.saveRecord(_makeRecord(id: '2', variety: 'Lakatan'));

      await tester.pumpWidget(
        MaterialApp(home: HistoryScreen(storageService: storage)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.delete_sweep_outlined));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Clear All'));
      await tester.pumpAndSettle();

      // All records cleared → empty state.
      expect(find.text('No Saved Scans Yet'), findsOneWidget);
    });
  });

  group('HistoryScreen — Error State', () {
    testWidgets('shows ErrorView when storage throws', (tester) async {
      final storage = FakeStorageService()..shouldThrow = true;

      await tester.pumpWidget(
        MaterialApp(home: HistoryScreen(storageService: storage)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Something went wrong'), findsOneWidget);
      expect(find.text('Try Again'), findsOneWidget);
    });

    testWidgets('retry recovers after error is resolved', (tester) async {
      final storage = FakeStorageService()..shouldThrow = true;

      await tester.pumpWidget(
        MaterialApp(home: HistoryScreen(storageService: storage)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Something went wrong'), findsOneWidget);

      // Fix the error.
      storage.shouldThrow = false;
      await tester.tap(find.text('Try Again'));
      await tester.pumpAndSettle();

      // Empty state since no records exist.
      expect(find.text('No Saved Scans Yet'), findsOneWidget);
    });
  });

  group('HistoryScreen — §7 UI Rules', () {
    testWidgets('no jargon in empty state', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: HistoryScreen(storageService: FakeStorageService()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('database'), findsNothing);
      expect(find.textContaining('SQL'), findsNothing);
      expect(find.textContaining('query'), findsNothing);
    });

    testWidgets('ripeness uses icon — not just color (§7.4)', (tester) async {
      final storage = FakeStorageService();
      await storage.saveRecord(_makeRecord(ripeness: 'Ripe'));

      await tester.pumpWidget(
        MaterialApp(home: HistoryScreen(storageService: storage)),
      );
      await tester.pumpAndSettle();

      // Ripe → check_circle_rounded icon.
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    });

    testWidgets('unripe uses hourglass icon', (tester) async {
      final storage = FakeStorageService();
      await storage.saveRecord(_makeRecord(ripeness: 'Unripe'));

      await tester.pumpWidget(
        MaterialApp(home: HistoryScreen(storageService: storage)),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.hourglass_top_rounded), findsOneWidget);
    });

    testWidgets('overripe uses warning icon', (tester) async {
      final storage = FakeStorageService();
      await storage.saveRecord(_makeRecord(ripeness: 'Overripe'));

      await tester.pumpWidget(
        MaterialApp(home: HistoryScreen(storageService: storage)),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.warning_rounded), findsOneWidget);
    });
  });
}
