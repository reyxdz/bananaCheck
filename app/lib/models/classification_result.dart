class ClassificationResult {
  ClassificationResult({
    required this.variety,
    required this.ripeness,
    required this.confidence,
    this.margin = 1.0,
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

  /// Variety label of the rejection class — the model's way of saying the
  /// photo is not a banana at all. Must match `NOT_BANANA_LABEL` in
  /// `ml/classes.py`, which has no underscore so it survives the
  /// `Variety_Ripeness` split.
  static const String notBananaVariety = 'NotBanana';

  final String variety;
  final String ripeness;
  final double confidence;

  /// Gap between the best and second-best class probabilities.
  ///
  /// A high [confidence] with a *low* margin means the model is torn between
  /// two classes, which is typical of photos unlike anything it trained on.
  /// Defaults to 1.0 (no contest) so results restored from storage, where the
  /// margin is not persisted, are never gated on it.
  final double margin;

  /// Whether this result names a banana, as opposed to the rejection class.
  bool get isBanana => variety != notBananaVariety;

  /// Serialise to a flat map suitable for sqflite insertion.
  Map<String, dynamic> toMap() => {
        'variety': variety,
        'ripeness': ripeness,
        'confidence': confidence,
      };
}
