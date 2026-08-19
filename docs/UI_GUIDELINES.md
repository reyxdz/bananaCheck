# UI Guidelines

The primary users are farmers and vendors who may have limited familiarity with
mobile applications and may use the app outdoors. These rules are functional
requirements, not optional polish.

## Interaction

- App open to result must require no more than two taps.
- Use one unmistakable primary action per screen.
- Keep History one visible tap from the camera screen.
- Do not add onboarding wizards, hamburger menus, nested navigation, or
  confirmation steps to the scan path.
- The camera action must be at least 64dp; all touch targets must be at least
  48x48dp.

## Visual system

All colors, spacing, radii, touch sizes, and type sizes come from
`lib/theme/design_tokens.dart`. Theme-wide component styling belongs in
`app_theme.dart`. Do not insert arbitrary visual values in individual screens.

The foundation uses a field-first visual direction: agricultural green,
high-contrast neutral surfaces, an amber accent, generous spacing, rounded
cards, and a clear field-of-view frame. Use Roboto Regular and Bold only. Body
copy is at least 16sp and headings are at least 20sp.

Never rely on color alone. Pair state and ripeness colors with text or an icon,
and verify contrast in bright outdoor light on a lower-cost physical device.

## Language

Use short, plain, actionable language.

- Prefer `Lakatan - Ripe` over a technical classification label.
- Prefer `We're pretty sure` over `confidence: 0.92`.
- Prefer `Couldn't tell clearly - move closer or improve the light` over an
  inference or tensor error.
- Critical icons always have a text label, such as camera plus `Scan`.

Do not expose stack traces, model vocabulary, database terms, class
probabilities, or raw exception messages. Decide Filipino/Bisaya support with
target users before finalizing production result copy.

## Required states and review

Every feature screen must cover loading, empty, success, recoverable error, and
permission-denied states that apply to it. A recoverable error needs one large,
obvious next action.

Widget tests should verify the primary action, navigation reachability, plain
language, and minimum touch targets. Camera changes also require a physical
Android device check, including outdoor readability. Review UI changes against
this file before treating them as ready.
