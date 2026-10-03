import 'classification_result.dart';

/// One banana found inside a bundle photo.
///
/// The box is in source-image pixels, so the UI can draw it over the photo
/// without knowing anything about how the scan was performed.
class BundleRegion {
  BundleRegion({
    required this.left,
    required this.top,
    required this.size,
    required this.result,
  }) {
    if (size <= 0) {
      throw ArgumentError.value(size, 'size', 'must be positive');
    }
  }

  final int left;
  final int top;

  /// Regions are square — the scan window is square so the crop matches the
  /// model's square input without distorting the fruit.
  final int size;

  final ClassificationResult result;

  int get right => left + size;
  int get bottom => top + size;

  /// Overlap with [other] as intersection-over-union, 0.0–1.0.
  ///
  /// Used to collapse the many overlapping windows that land on one banana.
  double overlapWith(BundleRegion other) {
    final overlapWidth = _span(left, right, other.left, other.right);
    final overlapHeight = _span(top, bottom, other.top, other.bottom);
    final intersection = overlapWidth * overlapHeight;
    if (intersection == 0) return 0;

    final union = size * size + other.size * other.size - intersection;
    return intersection / union;
  }

  static int _span(int aStart, int aEnd, int bStart, int bEnd) {
    final start = aStart > bStart ? aStart : bStart;
    final end = aEnd < bEnd ? aEnd : bEnd;
    return end > start ? end - start : 0;
  }
}

/// What a bundle scan found: which variety, and the spread of ripeness across
/// the bananas in the photo.
///
/// Deliberately has no exact count. Overlapping scan windows mean the number
/// of regions is an estimate, so the UI must present it as "about N" and lead
/// with the ripeness mix, which is the part a farmer acts on (§7.3).
class BundleScanResult {
  BundleScanResult({required this.regions});

  /// Every banana-like region kept after overlapping windows were merged.
  final List<BundleRegion> regions;

  /// No banana was found anywhere in the photo.
  bool get isEmpty => regions.isEmpty;

  /// More than one banana was found, so a single variety/ripeness headline
  /// would be misleading.
  bool get isBundle => regions.length > 1;

  /// Approximate number of bananas. Never show this without hedging — see the
  /// class doc.
  int get approximateCount => regions.length;

  /// The variety most regions agreed on, or `null` when nothing was found.
  String? get dominantVariety => _mostCommon(
        regions.map((region) => region.result.variety),
      );

  /// How many bananas fall into each ripeness stage, e.g.
  /// `{'Ripe': 3, 'Overripe': 2}`.
  Map<String, int> get ripenessCounts {
    final counts = <String, int>{};
    for (final region in regions) {
      final ripeness = region.result.ripeness;
      if (ripeness.isEmpty) continue;
      counts[ripeness] = (counts[ripeness] ?? 0) + 1;
    }
    return counts;
  }

  /// The ripeness stage most bananas are at, or `null` when nothing was found.
  String? get dominantRipeness =>
      _mostCommon(regions.map((region) => region.result.ripeness));

  /// Whether the bundle holds bananas at more than one ripeness stage — the
  /// case worth telling the user about, since the bundle needs sorting.
  bool get hasMixedRipeness => ripenessCounts.length > 1;

  static String? _mostCommon(Iterable<String> values) {
    final counts = <String, int>{};
    for (final value in values) {
      if (value.isEmpty) continue;
      counts[value] = (counts[value] ?? 0) + 1;
    }
    if (counts.isEmpty) return null;

    return counts.entries
        .reduce((a, b) => b.value > a.value ? b : a)
        .key;
  }
}
