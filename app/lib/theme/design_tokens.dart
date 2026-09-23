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

  // Error colors
  static const Color errorBackground = Color(0xFFFFF3F0); // Soft warm tint

  // Overlays & Opacities
  static const Color overlayDark = Color(0x7D000000); // Camera bottom gradient
  static const Color overlayWhite = Color(0xD9FFFFFF); // 85% white for reticle
  static const Color shutterFlash = Color(0xB3FFFFFF); // 70% white
  static const double badgeBgOpacity = 0.12;
  static const double badgeBorderOpacity = 0.40;
  static const double reticleBgOpacity = 0.60;
  static const double analyzingOverlayOpacity = 0.75;

  // Spacing Tokens
  static const double spacingExtraSmall = 4;
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

  // Icon & Image Sizes
  static const double logoSmall = 36;
  static const double logoMedium = 48;
  static const double iconMedium = 28;
  static const double iconLarge = 48;
  static const double imageThumbnailSize = 200;

  // Type Scale
  static const double bodyTextSize = 16;
  static const double subheadingTextSize = 18;
  static const double headingTextSize = 24;
  static const double resultHeadlineSize = 28;
}
