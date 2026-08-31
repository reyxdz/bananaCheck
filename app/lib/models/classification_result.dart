class ClassificationResult {
  ClassificationResult({
    required this.variety,
    required this.ripeness,
    required this.confidence,
  }) {
    if (confidence < 0 || confidence > 1) {
      throw ArgumentError.value(
        confidence,
        'confidence',
        'must be between 0.0 and 1.0',
      );
    }
  }

  /// Deserialise from a flat map (e.g. an sqflite row).
  factory ClassificationResult.fromMap(Map<String, dynamic> map) {
    return ClassificationResult(
      variety: map['variety'] as String,
      ripeness: map['ripeness'] as String,
      confidence: (map['confidence'] as num).toDouble(),
    );
  }

  final String variety;
  final String ripeness;
  final double confidence;

  /// Serialise to a flat map suitable for sqflite insertion.
  Map<String, dynamic> toMap() => {
        'variety': variety,
        'ripeness': ripeness,
        'confidence': confidence,
      };
}
