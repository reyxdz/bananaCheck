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

  final String variety;
  final String ripeness;
  final double confidence;
}
