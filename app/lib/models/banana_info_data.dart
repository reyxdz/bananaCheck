/// Hardcoded banana variety data — health benefits and dish suggestions
/// keyed by variety and ripeness level.
///
/// Per §7.6 of PROJECT_PLAN.md:
/// - All variety data lives in this single file.
/// - Widgets receive a [BananaInfo] + detected ripeness string — they never
///   construct data themselves.
/// - Lookup is by lowercase variety name, then lowercase ripeness key.
/// - Health benefit statements are general and informational (USDA / FNRI).
///   The app is not a dietary or medical tool.
library;

/// Health benefits and dish suggestions for a single ripeness level.
class RipenessInfo {
  const RipenessInfo({
    required this.healthBenefits,
    required this.dishSuggestions,
  });

  /// Ripeness-specific health facts shown alongside [BananaInfo.generalBenefits].
  final List<String> healthBenefits;

  /// Dishes appropriate for this ripeness stage, displayed as styled chips.
  final List<String> dishSuggestions;
}

/// Nutritional info and cooking suggestions for one banana variety.
class BananaInfo {
  const BananaInfo({
    required this.generalBenefits,
    required this.byRipeness,
  });

  /// Variety-wide health facts shown regardless of ripeness.
  final List<String> generalBenefits;

  /// Per-ripeness data keyed by lowercase ripeness: `"unripe"`, `"ripe"`,
  /// `"overripe"`. If a key is absent, widgets fall back to showing only
  /// [generalBenefits] and hide the dish suggestions card.
  final Map<String, RipenessInfo> byRipeness;
}

/// Master lookup map — keyed by **lowercase** variety name.
///
/// After inference, use:
/// ```dart
/// final info = bananaInfoMap[result.variety.toLowerCase()];
/// final ripeness = info?.byRipeness[result.ripeness.toLowerCase()];
/// ```
const bananaInfoMap = <String, BananaInfo>{
  // ── Saba ──────────────────────────────────────────────────────────────
  'saba': BananaInfo(
    generalBenefits: [
      'Rich in potassium — good for heart health',
      'High in dietary fiber — aids digestion',
      'Good source of Vitamin B6',
    ],
    byRipeness: {
      'unripe': RipenessInfo(
        healthBenefits: [
          'Higher resistant starch — helps manage blood sugar',
          'Lower sugar content compared to ripe',
        ],
        dishSuggestions: [
          'Nilupak',
          'Ginanggang',
          'Boiled saba',
        ],
      ),
      'ripe': RipenessInfo(
        healthBenefits: [
          'Natural sugars provide quick energy',
          'Easier to digest than unripe',
        ],
        dishSuggestions: [
          'Banana cue',
          'Turon',
          'Maruya',
          'Saba con yelo',
        ],
      ),
      'overripe': RipenessInfo(
        healthBenefits: [
          'Highest antioxidant content',
          'Easiest to digest',
        ],
        dishSuggestions: [
          'Maruya (sweeter batter)',
          'Banana bread',
          'Sweetened mashed saba',
        ],
      ),
    },
  ),

  // ── Bungulan ──────────────────────────────────────────────────────────
  'bungulan': BananaInfo(
    generalBenefits: [
      'Good source of Vitamin C — supports immune health',
      'Contains potassium — helps regulate blood pressure',
      'Light and easy to digest',
    ],
    byRipeness: {
      // Bungulan is not typically eaten unripe — key omitted intentionally.
      // Widgets fall back to generalBenefits only (§7.6 fallback rule).
      'ripe': RipenessInfo(
        healthBenefits: [
          'Natural sugars provide a quick energy boost',
        ],
        dishSuggestions: [
          'Eaten fresh',
          'Banana shake',
          'Fruit salad',
        ],
      ),
      'overripe': RipenessInfo(
        healthBenefits: [
          'Higher antioxidant levels',
          'Softer texture — great for blending',
        ],
        dishSuggestions: [
          'Banana bread',
          'Smoothie',
        ],
      ),
    },
  ),

  // ── Cavendish ─────────────────────────────────────────────────────────
  'cavendish': BananaInfo(
    generalBenefits: [
      'Rich in potassium — supports heart and muscle function',
      'Good source of Vitamin B6 — helps the body use energy from food',
      'Contains Vitamin C — supports immune health',
    ],
    byRipeness: {
      'unripe': RipenessInfo(
        healthBenefits: [
          'Higher resistant starch — helps manage blood sugar',
          'Lower sugar content — suitable for controlled diets',
        ],
        dishSuggestions: [
          'Green smoothie (blended)',
          'Banana chips (fried)',
        ],
      ),
      'ripe': RipenessInfo(
        healthBenefits: [
          'Natural sugars provide quick energy',
          'Peak vitamin content',
        ],
        dishSuggestions: [
          'Eaten fresh',
          'Banana pancakes',
          'Smoothie bowl',
          'Banana split',
        ],
      ),
      'overripe': RipenessInfo(
        healthBenefits: [
          'Highest antioxidant content',
          'Easiest to digest — gentle on the stomach',
        ],
        dishSuggestions: [
          'Banana bread',
          'Banana muffins',
          'Banana ice cream',
        ],
      ),
    },
  ),

  // ── Senorita ──────────────────────────────────────────────────────────
  'senorita': BananaInfo(
    generalBenefits: [
      'Good source of quick energy — great as a snack',
      'Contains potassium and Vitamin C',
      'Easy to digest — gentle on the stomach',
    ],
    byRipeness: {
      // Senorita is not typically eaten unripe — key omitted intentionally.
      'ripe': RipenessInfo(
        healthBenefits: [
          'Sweet and nutrient-dense for its small size',
        ],
        dishSuggestions: [
          'Eaten fresh (snack banana)',
          'Dessert garnish',
          'Fruit platter',
        ],
      ),
      'overripe': RipenessInfo(
        healthBenefits: [
          'Higher antioxidant levels',
          'Very soft — easy to mash and blend',
        ],
        dishSuggestions: [
          'Smoothie',
          'Mashed for baby food',
        ],
      ),
    },
  ),

  // ── Latundan ──────────────────────────────────────────────────────────
  'latundan': BananaInfo(
    generalBenefits: [
      'Rich in Vitamin C — supports immune health',
      'Good source of potassium — helps regulate blood pressure',
      'Contains dietary fiber — aids digestion',
    ],
    byRipeness: {
      // Latundan is not typically eaten unripe — key omitted intentionally.
      'ripe': RipenessInfo(
        healthBenefits: [
          'Natural sugars provide quick energy',
          'Pleasant mild sweetness — easy to eat',
        ],
        dishSuggestions: [
          'Eaten fresh',
          'Banana fritter',
          'Ginataang saging',
        ],
      ),
      'overripe': RipenessInfo(
        healthBenefits: [
          'Higher antioxidant levels',
          'Very soft texture — ideal for cooking and baking',
        ],
        dishSuggestions: [
          'Banana ice cream',
          'Banana jam',
          'Overripe banana bread',
        ],
      ),
    },
  ),

  // ── Morado ────────────────────────────────────────────────────────────
  'morado': BananaInfo(
    generalBenefits: [
      'Rich in antioxidants — the purple skin contains anthocyanins',
      'Good source of potassium — supports heart health',
      'Contains Vitamin C and B6',
    ],
    byRipeness: {
      // Morado is not typically eaten unripe — key omitted intentionally.
      'ripe': RipenessInfo(
        healthBenefits: [
          'Peak anthocyanin content — powerful antioxidants',
          'Natural sugars provide quick energy',
        ],
        dishSuggestions: [
          'Eaten fresh',
          'Banana flambe',
          'Purple banana bread',
        ],
      ),
      'overripe': RipenessInfo(
        healthBenefits: [
          'Highest antioxidant levels',
          'Softer texture — perfect for blending',
        ],
        dishSuggestions: [
          'Smoothies',
          'Purple banana jam',
          'Frozen banana pops',
        ],
      ),
    },
  ),
};
