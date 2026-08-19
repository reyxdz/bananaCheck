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
      cardTheme: const CardTheme(
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
          minimumSize: const Size(
            DesignTokens.minimumTouchTarget,
            DesignTokens.minimumTouchTarget,
          ),
        ),
      ),
    );
  }
}
