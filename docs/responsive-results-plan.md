# Responsive Results Screen — Plan

## Context

The banana variety result screen stretches as one tall single-column on tablets/desktop and cramps on narrow phones: the Variety | Ripeness facts are a hardcoded 2-up `Row` where long variety names wrap awkwardly at 360dp, and nothing caps content width on wide screens. Goal: stack facts on narrow screens, center content with a max width on wide ones — with minimal, token-driven changes.

## Changes

### 1. `app/lib/theme/design_tokens.dart`
Add constants near the result tokens (~line 180):

- `contentMaxWidth = 480.0`
- `resultFactsRowMinWidth = 360.0`

### 2. New helper — `app/lib/widgets/responsive_constraints.dart`
`ContentWidthBox`: a `LayoutBuilder` that passes the child through at widths ≤ `contentMaxWidth`, and otherwise centers it via `Align(alignment: Alignment.topCenter)` + `ConstrainedBox(maxWidth: DesignTokens.contentMaxWidth)`. ~40 lines, matches the project's token idiom.

### 3. `app/lib/widgets/result_headline.dart` (the real fix)
Lines 50–71: hardcoded `Row` of two `Expanded _Fact`s (Variety | Ripeness). Wrap in a `LayoutBuilder`:

- Below `DesignTokens.resultFactsRowMinWidth`: stack the two facts vertically in a `Column` so long variety names wrap naturally at full width.
- At/above the breakpoint: keep the existing `Row` exactly.
- Keep the `Semantics`/`ExcludeSemantics` wrapper and the `spoken` label untouched — `app/test/widgets/result_headline_test.dart` asserts on them.

### 4. `app/lib/screens/results_screen.dart`

- Wrap the inner scroll `Column` (lines 55–75) in `ContentWidthBox` so the card + help text center together on wide screens.
- Wrap the pinned bottom-bar `Padding` (lines 90–96) so the "Scan Again" button is capped at `contentMaxWidth` and centered instead of stretching edge-to-edge.

## Deliberately unchanged

- `ScanPhoto`/`fitPhotoSize` in `result_card.dart` (already responsive via `LayoutBuilder`, capped at `resultHeroMaxHeight`).
- `RipeningScale`, confidence/health-benefits/dish-suggestion cards.
- TextScaler clamping in `main.dart` — noted as a follow-up only.

## Verification

- `cd app && flutter analyze` clean.
- `flutter test` — existing `test/widgets/result_headline_test.dart` and `test/screens/results_screen_test.dart` pass unchanged.
- New tests using the `tester.view.physicalSize` idiom: headline stacked at width 320, 2-up at 640; at 1200×800 the card content is centered and the bottom button width ≤ `contentMaxWidth`.