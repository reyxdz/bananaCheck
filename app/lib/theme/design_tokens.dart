import 'package:flutter/material.dart';

/// Central repository of design system values (colors, typography, spacing, dimensions).
///
/// Per §7.5 of PROJECT_PLAN.md: All visual styles must originate from this file.
abstract final class DesignTokens {
  // ── Brand identity: botanical green · warm ivory · charcoal · banana ──
  /// Typeface bundled in assets/fonts (SIL OFL). Regular 400 + Bold 700 only.
  static const String fontFamily = 'PlusJakartaSans';

  /// Deep botanical green — primary actions, brand text.
  static const Color primary = Color(0xFF1F5C3B);
  static const Color primaryDark = Color(0xFF14402A);

  /// Pale leaf tint for selected/soft surfaces.
  static const Color primaryLight = Color(0xFFE7EFE3);

  /// Fresh banana-leaf green — secondary accents, eyebrows.
  static const Color secondary = Color(0xFF4F8A43);

  /// Restrained banana yellow — highlights and tips only, never large fills.
  static const Color accent = Color(0xFFE9B730);
  static const Color accentLight = Color(0xFFFBF1D3);

  /// Warm ivory app background; white cards sit on top of it.
  static const Color background = Color(0xFFFAF7EF);
  static const Color surface = Colors.white;

  /// Slightly deeper ivory for sections inside cards.
  static const Color surfaceMuted = Color(0xFFF4F0E5);

  /// Charcoal text and its muted gray-green companion.
  static const Color textPrimary = Color(0xFF23271F);
  static const Color textSecondary = Color(0xFF5C6B5F);
  static const Color onPrimary = Colors.white;

  /// Warm hairline for borders and dividers.
  static const Color border = Color(0xFFE3DECF);
  static const Color shadow = Color(0x1A23271F);

  // Status — chosen to stay readable (≥4.5:1) on white and ivory.
  static const Color success = Color(0xFF2F7D4A);
  static const Color warning = Color(0xFF8F5E0F);
  static const Color error = Color(0xFFB3261E);

  // Ripeness & Variety status colors (always paired with an icon + text).
  static const Color ripenessUnripe = Color(0xFF3D7A3A); // Leaf green
  static const Color ripenessRipe = Color(0xFF8F5E0F); // Deep banana gold
  static const Color ripenessOverripe = Color(0xFF7A4E2D); // Brown

  // Peel colours for the ripening scale on the results screen. Decorative
  // fills only — the stage is always named in text beside them.
  static const Color peelGreen = Color(0xFF7FA33A);
  static const Color peelYellow = Color(0xFFEBC13A);
  static const Color peelBrown = Color(0xFF8A5A2B);
  static const double ripenessScaleHeight = 10;
  static const double ripenessScaleActiveHeight = 16;
  static const Color confidenceHigh = success;
  static const Color confidenceMedium = warning;
  static const Color confidenceLow = error;

  // Spacing Tokens
  static const double spacingExtraSmall = 4;
  static const double pillIconGap = 6;
  static const double spacingSmall = 8;
  static const double spacingMedium = 16;
  static const double spacingLarge = 24;
  static const double spacingExtraLarge = 32;
  static const double spacingHuge = 48;

  // Corner Radii Tokens
  static const double radiusXSmall = 8;
  static const double radiusSmall = 12;
  static const double radiusMedium = 16;
  static const double radiusLarge = 24;
  static const double radiusPill = 999;

  // Elevation — one soft, warm shadow instead of Material grey elevation.
  static const List<BoxShadow> softShadow = [
    BoxShadow(color: shadow, blurRadius: 24, offset: Offset(0, 8)),
  ];

  // Borders & Touches
  static const double borderWidth = 2;
  static const double minimumTouchTarget = 48;
  static const double primaryActionSize = 64;
  static const double secondaryActionSize = 56;

  // Icon & Image Sizes
  static const double logoSmall = 36;
  static const double logoMedium = 48;
  static const double iconSmall = 16;
  static const double iconDefault = 20;
  static const double iconSectionHeader = 22;
  static const double iconAppBar = 24;
  static const double iconMedium = 28;
  static const double iconHistoryFallback = 32;
  static const double iconLarge = 48;
  static const double iconEmptyState = 64;
  static const double imageThumbnailSize = 200;
  static const double logoTiny = 28;
  static const double historyThumbnailSize = 64;
  static const double resultHeroHeight = 240;
  static const double analyzingPhotoSize = 220;
  static const double errorIconCircle = 80;
  static const double mascotSize = 180;

  // Chip / Pill Spacing
  static const double chipPaddingHorizontal = 12;
  static const double chipPaddingVertical = 6;

  // Badge Spacing (smaller inline labels)
  static const double badgePaddingHorizontal = 8;
  static const double badgePaddingVertical = 2;
  static const double badgeRadius = 4;

  // Section borders
  static const double sectionBorderWidth = 1;

  // Overlay
  static const double analyzingOverlayOpacity = 0.75;
  static const Color overlayGradientEnd = Color(0x7D000000);

  // Camera Reticle Dimensions
  static const double reticleWidth = 250;
  static const double reticleHeight = 330;

  // Live camera overlay — brackets, dimmed surround, hint pill
  static const Color cameraDim = Color(0x8C000000);
  static const Color cameraPill = Color(0xB3000000);
  static const Color onCamera = Colors.white;
  // Bright tones so they read on a live video feed: blue = banana detected.
  static const Color scanDetected = Color(0xFF42A5F5);
  static const Color scanWarning = Color(0xFFFFB300);
  static const double bracketArm = 32;
  static const double bracketStroke = 4;
  static const double hintGap = 12;
  static const double shutterDimmedOpacity = 0.45;
  static const double highlightBorderWidth = 3;

  // Onboarding (§7.7) — same identity: ivory, botanical green, banana yellow
  static const Color onboardingBackground = background;
  static const Color onboardingAccentText = secondary;
  static const Color onboardingHighlight = Color(0xFFF2D58A);
  static const Color onboardingPanel = primaryLight;
  static const Color onboardingScrim = Color(0xFF102E1E);
  static const Color onboardingOnDark = Colors.white;
  static const Color onboardingOnDarkMuted = Color(0xB3FFFFFF);
  static const double onboardingHeadlineSize = 32;
  static const double onboardingDotSize = 8;
  static const double onboardingActiveDotWidth = 24;
  static const double onboardingStepBadgeSize = 36;
  static const double onboardingButtonHeight = 56;
  static const double onboardingMinImageHeight = 160;

  // Debug-only "DEMO" ribbon shown when the real model isn't loaded.
  static const Color demoBanner = Color(0xFFD84315);

  // Semantic Colors
  static const Color errorBackground = Color(0xFFFBEAE8);

  // Type Scale (Plus Jakarta Sans; body never below 16 per §7.2)
  static const double captionTextSize = 13;
  static const double chipTextSize = 14;
  static const double pillTextSize = 14;
  static const double bodyTextSize = 16;
  static const double subheadingTextSize = 18;
  static const double titleTextSize = 20;
  static const double headingTextSize = 24;
  static const double resultHeadlineSize = 30;
  static const double displayTextSize = 32;
  static const double varietyHeadlineSize = 40;

  /// Side-by-side Variety / Ripeness facts on the results screen.
  static const double resultFactValueSize = titleTextSize;
  static const double resultFactLabelSize = bodyTextSize;

  /// Line heights / tracking for the scale.
  static const double bodyLineHeight = 1.45;
  static const double headingLineHeight = 1.2;
  static const double headingLetterSpacing = -0.4;
}
