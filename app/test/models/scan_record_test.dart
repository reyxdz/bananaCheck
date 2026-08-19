import 'package:banana_classifier/models/classification_result.dart';
import 'package:banana_classifier/models/scan_record.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('keeps the agreed scan persistence fields', () {
    final scannedAt = DateTime.utc(2026, 8, 19);
    final result = ClassificationResult(
      variety: 'Lakatan',
      ripeness: 'Ripe',
      confidence: 0.92,
    );

    final record = ScanRecord(
      id: 'scan-1',
      imagePath: 'images/scan-1.jpg',
      result: result,
      scannedAt: scannedAt,
    );

    expect(record.id, 'scan-1');
    expect(record.imagePath, 'images/scan-1.jpg');
    expect(record.result, same(result));
    expect(record.scannedAt, scannedAt);
  });
}
