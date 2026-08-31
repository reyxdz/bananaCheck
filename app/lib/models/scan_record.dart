import 'classification_result.dart';

class ScanRecord {
  ScanRecord({
    required this.id,
    required this.imagePath,
    required this.result,
    required this.scannedAt,
  });

  /// Deserialise from a flat sqflite row.
  factory ScanRecord.fromMap(Map<String, dynamic> map) {
    return ScanRecord(
      id: map['id'] as String,
      imagePath: map['image_path'] as String,
      result: ClassificationResult.fromMap(map),
      scannedAt: DateTime.fromMillisecondsSinceEpoch(
        map['scanned_at'] as int,
      ),
    );
  }

  final String id;
  final String imagePath;
  final ClassificationResult result;
  final DateTime scannedAt;

  /// Serialise to a flat map suitable for sqflite insertion.
  ///
  /// The [ClassificationResult] fields are flattened into the same row rather
  /// than stored in a separate table, keeping the schema simple.
  Map<String, dynamic> toMap() => {
        'id': id,
        'image_path': imagePath,
        ...result.toMap(),
        'scanned_at': scannedAt.millisecondsSinceEpoch,
      };
}
