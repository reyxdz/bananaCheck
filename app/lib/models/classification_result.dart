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

  /// Confidence below which a result is treated as unreliable.
  static const double lowConfidenceThreshold = 0.5;

  /// Minimum gap between the best and second-best class required to trust a
  /// result.
  ///
  /// Softmax always sums to 1, so a photo unlike anything in training can
  /// still produce a high top probability. A narrow gap to the runner-up is
  /// the clearer signal that the model is guessing.
  ///
  /// Set from the margin distribution measured on the held-out test set: real
  /// bananas clear this easily (median margin 0.996, 1st percentile 0.121), so
  /// the gate costs 0.6% of correct scans. It is a safety net rather than the
  /// main defence: the NotBanana class already rejects 100% of the negatives.
  static const double lowMarginThreshold = 0.10;

  /// Whether this is a banana the model is sure enough about to show.
  ///
  /// The Analyzing screen accepts a scan on this, and the live camera hint
  /// turns its corners blue on it, so the two always agree.
  bool get isConfidentBanana =>
      isBanana &&
      confidence >= lowConfidenceThreshold &&
      margin >= lowMarginThreshold;

  /// Serialise to a flat map suitable for sqflite insertion.
  Map<String, dynamic> toMap() => {
        'variety': variety,
        'ripeness': ripeness,
        'confidence': confidence,
      };
}
