import 'classification_result.dart';

class ScanRecord {
  ScanRecord({
    required this.id,
    required this.imagePath,
    required this.result,
    required this.scannedAt,
  });

  final String id;
  final String imagePath;
  final ClassificationResult result;
  final DateTime scannedAt;
}
