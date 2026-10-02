import 'package:flutter/material.dart';

/// Central repository of design system values (colors, typography, spacing, dimensions).
///
/// Per §7.5 of PROJECT_PLAN.md: All visual styles must originate from this file.
abstract final class DesignTokens {
  // Brand colors
  static const Color primary = Color(0xFF2E7D32);
  static const Color primaryDark = Color(0xFF1B5E20);
  static const Color primaryLight = Color(0xFFE8F5E9);
  static const Color accent = Color(0xFFF9A825);
  static const Color background = Color(0xFFF4F6F0);
  static const Color surface = Colors.white;
  static const Color textPrimary = Color(0xFF1F2A1F);
  static const Color textSecondary = Color(0xFF526052);
  static const Color border = Color(0xFFC8D6C5);
  static const Color shadow = Color(0x1F1F2A1F);

  // Ripeness & Variety status colors
  static const Color ripenessUnripe = Color(0xFF2E7D32); // Fresh Green
  static const Color ripenessRipe = Color(0xFFE65100); // Rich Amber / Gold
  static const Color ripenessOverripe = Color(0xFF6D4C41); // Brown / Auburn
  static const Color confidenceHigh = Color(0xFF2E7D32); // Green
  static const Color confidenceMedium = Color(0xFFF57F17); // Amber
  static const Color confidenceLow = Color(0xFFD32F2F); // Red

  // Spacing Tokens
  static const double spacingExtraSmall = 4;
  static const double pillIconGap = 6;
  static const double spacingSmall = 8;
  static const double spacingMedium = 16;
  static const double spacingLarge = 24;
  static const double spacingExtraLarge = 32;

  // Corner Radii Tokens
  static const double radiusSmall = 12;
  static const double radiusMedium = 16;
  static const double radiusLarge = 20;

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
  // Brighter than primary/amber tokens so they read on a live video feed.
  static const Color scanReady = Color(0xFF66BB6A);
  static const Color scanWarning = Color(0xFFFFB300);
  static const double bracketArm = 32;
  static const double bracketStroke = 4;
  static const double hintGap = 12;
  static const double shutterDimmedOpacity = 0.45;

  // Onboarding (§7.7) — natural green, warm cream, muted yellow
  static const Color onboardingBackground = Color(0xFFF7F5EF);
  static const Color onboardingAccentText = Color(0xFF5E8F55);
  static const Color onboardingHighlight = Color(0xFFE9D48A);
  static const Color onboardingPanel = Color(0xFFE6ECDD);
  static const Color onboardingScrim = Color(0xFF16301A);
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
  static const Color errorBackground = Color(0xFFFDECEC);

  // Type Scale
  static const double captionTextSize = 12;
  static const double chipTextSize = 13;
  static const double pillTextSize = 14;
  static const double bodyTextSize = 16;
  static const double subheadingTextSize = 18;
  static const double headingTextSize = 24;
  static const double resultHeadlineSize = 28;
}
