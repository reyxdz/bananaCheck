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
///
/// ## Sources and how claims were checked (reviewed 2026-10)
///
/// * Nutrients — USDA FoodData Central, "Bananas, raw" (FDC 173944), per
///   100 g: potassium 358 mg, vitamin B6 0.37 mg, vitamin C 8.7 mg, fiber
///   2.6 g. For a medium banana (118 g) vs. FDA Daily Values that is ≈25% B6
///   ("good source"), ≈11% vitamin C and fiber, ≈9% potassium. So potassium
///   and vitamin C are worded "contains", never "rich in".
/// * Ripening — green bananas hold more resistant starch, which is digested
///   slowly (gentler rise in blood sugar) and fermented by gut bacteria;
///   ripening converts that starch into sugars and softens the fruit.
/// * Deliberately NOT claimed: "overripe bananas have the most
///   antioxidants" / cancer-fighting "TNF" (a debunked viral claim) and
///   "peak vitamin content when ripe" (unsupported).
/// * Varieties — Saba and Cardaba (ABB) are cooking bananas eaten
///   boiled, grilled or fried, often green; banana chips are made from
///   unripe saba/cardaba. Lakatan, Latundan, Señorita and Cavendish are
///   dessert bananas eaten ripe, so their "unripe" entries carry no dishes —
///   the results screen's handling tip tells the user to let them ripen.
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

/// Model/dataset class names that differ from the variety's real name.
///
/// The model was trained with the class folder `Cordova_*`, a misspelling
/// of **Cardaba**. The class name stays "Cordova" inside the model and
/// `labels.txt` (renaming it would re-sort the alphabetical output order
/// and needs a retrain), so the app maps it to the real name here.
const _varietyAliases = {'cordova': 'Cardaba'};

/// The name to show users for a model [variety] label, e.g. "Cordova" →
/// "Cardaba". Unknown names are returned unchanged.
String displayVarietyName(String variety) =>
    _varietyAliases[variety.trim().toLowerCase()] ?? variety;

/// Info for a model [variety] label (aliases resolved), or `null` if the
/// variety isn't in [bananaInfoMap].
BananaInfo? bananaInfoFor(String variety) =>
    bananaInfoMap[displayVarietyName(variety).toLowerCase()];

/// Master lookup map — keyed by **lowercase** real variety name.
///
/// Look entries up with [bananaInfoFor] so model aliases are resolved:
/// ```dart
/// final info = bananaInfoFor(result.variety);
/// final ripeness = info?.byRipeness[result.ripeness.toLowerCase()];
/// ```
const bananaInfoMap = <String, BananaInfo>{
  // ── Saba (cooking banana) ─────────────────────────────────────────────
  'saba': BananaInfo(
    generalBenefits: [
      _starchyCooking,
      _b6,
      _potassium,
      _fiber,
    ],
    byRipeness: {
      'unripe': RipenessInfo(
        healthBenefits: [_resistantStarch, _gutBacteria],
        dishSuggestions: [
          'Nilagang saging (boiled saba)',
          'Banana chips',
          'Nilupak',
        ],
      ),
      'ripe': RipenessInfo(
        healthBenefits: [_naturalSugars, _easierToDigest],
        dishSuggestions: [
          'Banana cue',
          'Turon',
          'Maruya',
          'Ginanggang',
          'Minatamis na saging',
        ],
      ),
      'overripe': RipenessInfo(
        healthBenefits: [_sweetest, _verySoft],
        dishSuggestions: [
          'Maruya',
          'Minatamis na saging',
        ],
      ),
    },
  ),

  // ── Cardaba (cooking banana; model class "Cordova") ──────────────────
  'cardaba': BananaInfo(
    generalBenefits: [
      _starchyCooking,
      _b6,
      _potassium,
      _fiber,
    ],
    byRipeness: {
      'unripe': RipenessInfo(
        healthBenefits: [_resistantStarch, _gutBacteria],
        dishSuggestions: [
          'Nilagang saging (boiled)',
          'Banana chips',
        ],
      ),
      'ripe': RipenessInfo(
        healthBenefits: [_naturalSugars, _easierToDigest],
        dishSuggestions: [
          'Banana cue',
          'Turon',
          'Maruya',
          'Minatamis na saging',
        ],
      ),
      'overripe': RipenessInfo(
        healthBenefits: [_sweetest, _verySoft],
        dishSuggestions: [
          'Maruya',
          'Minatamis na saging',
        ],
      ),
    },
  ),

  // ── Cavendish (dessert banana) ────────────────────────────────────────
  'cavendish': BananaInfo(
    generalBenefits: [_b6, _potassium, _vitaminC, _fiber],
    byRipeness: {
      'unripe': RipenessInfo(
        healthBenefits: [_resistantStarch, _gutBacteria],
        dishSuggestions: [],
      ),
      'ripe': RipenessInfo(
        healthBenefits: [_naturalSugars, _easierToDigest],
        dishSuggestions: [
          'Eaten fresh',
          'Banana shake',
          'Fruit salad',
          'Banana pancakes',
        ],
      ),
      'overripe': RipenessInfo(
        healthBenefits: [_sweetest, _verySoft],
        dishSuggestions: [
          'Banana bread',
          'Banana muffins',
          'Smoothie',
          'Banana ice cream',
        ],
      ),
    },
  ),

  // ── Señorita (dessert banana, small) ──────────────────────────────────
  'senorita': BananaInfo(
    generalBenefits: [
      'Small and very sweet — a ready-made snack portion',
      _b6,
      _potassium,
      _vitaminC,
    ],
    byRipeness: {
      'unripe': RipenessInfo(
        healthBenefits: [_resistantStarch, _gutBacteria],
        dishSuggestions: [],
      ),
      'ripe': RipenessInfo(
        healthBenefits: [_naturalSugars, _easierToDigest],
        dishSuggestions: [
          'Eaten fresh',
          'Fruit platter',
          'Dessert topping',
        ],
      ),
      'overripe': RipenessInfo(
        healthBenefits: [_sweetest, _verySoft],
        dishSuggestions: [
          'Smoothie',
          'Mashed for baby food',
        ],
      ),
    },
  ),

  // ── Latundan (dessert banana) ─────────────────────────────────────────
  'latundan': BananaInfo(
    generalBenefits: [_b6, _potassium, _vitaminC, _fiber],
    byRipeness: {
      'unripe': RipenessInfo(
        healthBenefits: [_resistantStarch, _gutBacteria],
        dishSuggestions: [],
      ),
      'ripe': RipenessInfo(
        healthBenefits: [_naturalSugars, _easierToDigest],
        dishSuggestions: [
          'Eaten fresh',
          'Fruit salad',
          'Banana shake',
        ],
      ),
      'overripe': RipenessInfo(
        healthBenefits: [_sweetest, _verySoft],
        dishSuggestions: [
          'Banana bread',
          'Smoothie',
          'Mashed for baby food',
        ],
      ),
    },
  ),

  // ── Lakatan (dessert banana) ──────────────────────────────────────────
  'lakatan': BananaInfo(
    generalBenefits: [_b6, _potassium, _vitaminC, _fiber],
    byRipeness: {
      'unripe': RipenessInfo(
        healthBenefits: [_resistantStarch, _gutBacteria],
        dishSuggestions: [],
      ),
      'ripe': RipenessInfo(
        healthBenefits: [_naturalSugars, _easierToDigest],
        dishSuggestions: [
          'Eaten fresh',
          'Banana shake',
          'Fruit salad',
        ],
      ),
      'overripe': RipenessInfo(
        healthBenefits: [_sweetest, _verySoft],
        dishSuggestions: [
          'Banana bread',
          'Banana pancakes',
          'Smoothie',
        ],
      ),
    },
  ),
};

// ── Shared, source-checked statements (see library doc) ────────────────

// Variety-wide (USDA, medium banana vs. FDA Daily Values).
const _b6 = 'Good source of vitamin B6 — helps the body turn food into energy';
const _potassium = 'Contains potassium — helps the heart and muscles work';
const _vitaminC = 'Contains vitamin C — supports the immune system';
const _fiber = 'Provides dietary fiber — supports healthy digestion';
const _starchyCooking =
    'Starchy cooking banana — filling and energy-giving when cooked';

// Per ripeness stage.
const _resistantStarch =
    'More resistant starch — digested slowly, for a gentler rise in blood sugar';
const _gutBacteria = 'Its resistant starch feeds the good bacteria in your gut';
const _naturalSugars = 'Starch has turned into natural sugars — quick energy';
const _easierToDigest = 'Softer and easier to digest than when green';
const _sweetest = 'Sweetest stage — most of the starch is now sugar';
const _verySoft = 'Very soft — easy to mash, ideal for cooking and baking';
