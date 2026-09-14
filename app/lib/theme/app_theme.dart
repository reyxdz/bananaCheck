import 'package:flutter/material.dart';

import 'design_tokens.dart';

abstract final class AppTheme {
  static ThemeData get light {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: DesignTokens.primary,
      primary: DesignTokens.primary,
      secondary: DesignTokens.accent,
      surface: DesignTokens.surface,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: DesignTokens.background,
      fontFamily: 'Roboto',
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(
          color: DesignTokens.textPrimary,
          fontSize: DesignTokens.headingTextSize,
          fontWeight: FontWeight.w700,
          fontFamily: 'Roboto',
        ),
        iconTheme: IconThemeData(
          color: DesignTokens.textPrimary,
          size: DesignTokens.iconMedium,
        ),
      ),
      textTheme: const TextTheme(
        bodyMedium: TextStyle(
          color: DesignTokens.textPrimary,
          fontSize: DesignTokens.bodyTextSize,
          fontWeight: FontWeight.w400,
        ),
        bodyLarge: TextStyle(
          color: DesignTokens.textPrimary,
          fontSize: DesignTokens.bodyTextSize,
          fontWeight: FontWeight.w400,
        ),
        titleMedium: TextStyle(
          color: DesignTokens.textPrimary,
          fontSize: DesignTokens.subheadingTextSize,
          fontWeight: FontWeight.w600,
        ),
        titleLarge: TextStyle(
          color: DesignTokens.textPrimary,
          fontSize: DesignTokens.headingTextSize,
          fontWeight: FontWeight.w700,
        ),
        labelLarge: TextStyle(
          fontSize: DesignTokens.bodyTextSize,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: const CardThemeData(
        color: DesignTokens.surface,
        elevation: 2,
        shadowColor: DesignTokens.shadow,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(
            Radius.circular(DesignTokens.radiusMedium),
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: DesignTokens.primaryLight,
        labelStyle: const TextStyle(
          color: DesignTokens.primaryDark,
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radiusSmall),
          side: BorderSide.none,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(
            DesignTokens.minimumTouchTarget,
            DesignTokens.minimumTouchTarget,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: DesignTokens.spacingLarge,
            vertical: DesignTokens.spacingMedium,
          ),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(
              Radius.circular(DesignTokens.radiusMedium),
            ),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: DesignTokens.primary,
          minimumSize: const Size(
            DesignTokens.minimumTouchTarget,
            DesignTokens.minimumTouchTarget,
          ),
          textStyle: const TextStyle(
            fontSize: DesignTokens.bodyTextSize,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
