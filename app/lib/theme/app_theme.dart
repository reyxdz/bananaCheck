import 'package:flutter/material.dart';

import 'design_tokens.dart';

/// App-wide Material theme built entirely from [DesignTokens] (§7.5).
///
/// Visual identity: botanical green actions on warm ivory, charcoal text,
/// banana yellow used sparingly. One typeface (Plus Jakarta Sans), two
/// weights (§7.2).
abstract final class AppTheme {
  static ThemeData get light {
    const colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: DesignTokens.primary,
      onPrimary: DesignTokens.onPrimary,
      primaryContainer: DesignTokens.primaryLight,
      onPrimaryContainer: DesignTokens.primaryDark,
      secondary: DesignTokens.secondary,
      onSecondary: DesignTokens.onPrimary,
      secondaryContainer: DesignTokens.primaryLight,
      onSecondaryContainer: DesignTokens.primaryDark,
      tertiary: DesignTokens.accent,
      onTertiary: DesignTokens.textPrimary,
      tertiaryContainer: DesignTokens.accentLight,
      onTertiaryContainer: DesignTokens.textPrimary,
      error: DesignTokens.error,
      onError: DesignTokens.onPrimary,
      errorContainer: DesignTokens.errorBackground,
      onErrorContainer: DesignTokens.error,
      surface: DesignTokens.surface,
      onSurface: DesignTokens.textPrimary,
      onSurfaceVariant: DesignTokens.textSecondary,
      surfaceContainerHighest: DesignTokens.surfaceMuted,
      outline: DesignTokens.border,
      outlineVariant: DesignTokens.border,
      shadow: DesignTokens.shadow,
    );

    const buttonShape = RoundedRectangleBorder(
      borderRadius:
          BorderRadius.all(Radius.circular(DesignTokens.radiusMedium)),
    );
    const buttonText = TextStyle(
      fontFamily: DesignTokens.fontFamily,
      fontSize: DesignTokens.bodyTextSize,
      fontWeight: FontWeight.w700,
    );
    const minButton = Size(
      DesignTokens.minimumTouchTarget,
      DesignTokens.minimumTouchTarget,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: DesignTokens.background,
      fontFamily: DesignTokens.fontFamily,
      textTheme: _textTheme,
      // Consistent, platform-appropriate transitions between screens.
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: ZoomPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: DesignTokens.background,
        surfaceTintColor: Colors.transparent,
        foregroundColor: DesignTokens.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: DesignTokens.fontFamily,
          color: DesignTokens.textPrimary,
          fontSize: DesignTokens.titleTextSize,
          fontWeight: FontWeight.w700,
          letterSpacing: DesignTokens.headingLetterSpacing,
        ),
        iconTheme: IconThemeData(
          color: DesignTokens.textPrimary,
          size: DesignTokens.iconAppBar,
        ),
      ),
      cardTheme: const CardTheme(
        color: DesignTokens.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius:
              BorderRadius.all(Radius.circular(DesignTokens.radiusLarge)),
          side: BorderSide(
            color: DesignTokens.border,
            width: DesignTokens.sectionBorderWidth,
          ),
        ),
      ),
      chipTheme: const ChipThemeData(
        backgroundColor: DesignTokens.primaryLight,
        labelStyle: TextStyle(
          fontFamily: DesignTokens.fontFamily,
          color: DesignTokens.primaryDark,
          fontSize: DesignTokens.pillTextSize,
          fontWeight: FontWeight.w700,
        ),
        padding: EdgeInsets.symmetric(
          horizontal: DesignTokens.chipPaddingHorizontal,
          vertical: DesignTokens.chipPaddingVertical,
        ),
        shape: StadiumBorder(),
        side: BorderSide.none,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: DesignTokens.primary,
          foregroundColor: DesignTokens.onPrimary,
          disabledBackgroundColor: DesignTokens.border,
          disabledForegroundColor: DesignTokens.textSecondary,
          minimumSize: minButton,
          padding: const EdgeInsets.symmetric(
            horizontal: DesignTokens.spacingLarge,
            vertical: DesignTokens.spacingMedium,
          ),
          shape: buttonShape,
          textStyle: buttonText,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: DesignTokens.primary,
          foregroundColor: DesignTokens.onPrimary,
          elevation: 0,
          minimumSize: minButton,
          shape: buttonShape,
          textStyle: buttonText,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: DesignTokens.primary,
          backgroundColor: DesignTokens.surface,
          minimumSize: minButton,
          padding: const EdgeInsets.symmetric(
            horizontal: DesignTokens.spacingLarge,
            vertical: DesignTokens.spacingMedium,
          ),
          side: const BorderSide(
            color: DesignTokens.primary,
            width: DesignTokens.sectionBorderWidth * 1.5,
          ),
          shape: buttonShape,
          textStyle: buttonText,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: DesignTokens.primary,
          minimumSize: minButton,
          textStyle: buttonText,
          shape: buttonShape,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: minButton,
          foregroundColor: DesignTokens.textPrimary,
        ),
      ),
      dialogTheme: const DialogTheme(
        backgroundColor: DesignTokens.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius:
              BorderRadius.all(Radius.circular(DesignTokens.radiusLarge)),
        ),
        titleTextStyle: TextStyle(
          fontFamily: DesignTokens.fontFamily,
          color: DesignTokens.textPrimary,
          fontSize: DesignTokens.titleTextSize,
          fontWeight: FontWeight.w700,
        ),
        contentTextStyle: TextStyle(
          fontFamily: DesignTokens.fontFamily,
          color: DesignTokens.textSecondary,
          fontSize: DesignTokens.bodyTextSize,
          height: DesignTokens.bodyLineHeight,
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: DesignTokens.textPrimary,
        contentTextStyle: TextStyle(
          fontFamily: DesignTokens.fontFamily,
          color: DesignTokens.onPrimary,
          fontSize: DesignTokens.bodyTextSize,
        ),
        shape: RoundedRectangleBorder(
          borderRadius:
              BorderRadius.all(Radius.circular(DesignTokens.radiusSmall)),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: DesignTokens.primary,
        linearTrackColor: DesignTokens.primaryLight,
        circularTrackColor: DesignTokens.primaryLight,
      ),
      dividerTheme: const DividerThemeData(
        color: DesignTokens.border,
        thickness: DesignTokens.sectionBorderWidth,
        space: DesignTokens.spacingLarge,
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: DesignTokens.textSecondary,
        textColor: DesignTokens.textPrimary,
      ),
      tooltipTheme: const TooltipThemeData(
        decoration: BoxDecoration(
          color: DesignTokens.textPrimary,
          borderRadius:
              BorderRadius.all(Radius.circular(DesignTokens.radiusXSmall)),
        ),
        textStyle: TextStyle(
          fontFamily: DesignTokens.fontFamily,
          color: DesignTokens.onPrimary,
          fontSize: DesignTokens.pillTextSize,
        ),
      ),
    );
  }

  /// Type scale: confident headings, highly readable body (≥16sp).
  static const TextTheme _textTheme = TextTheme(
    displaySmall: TextStyle(
      fontSize: DesignTokens.displayTextSize,
      fontWeight: FontWeight.w700,
      color: DesignTokens.textPrimary,
      height: DesignTokens.headingLineHeight,
      letterSpacing: DesignTokens.headingLetterSpacing,
    ),
    headlineSmall: TextStyle(
      fontSize: DesignTokens.headingTextSize,
      fontWeight: FontWeight.w700,
      color: DesignTokens.textPrimary,
      height: DesignTokens.headingLineHeight,
      letterSpacing: DesignTokens.headingLetterSpacing,
    ),
    titleLarge: TextStyle(
      fontSize: DesignTokens.titleTextSize,
      fontWeight: FontWeight.w700,
      color: DesignTokens.textPrimary,
      height: DesignTokens.headingLineHeight,
    ),
    titleMedium: TextStyle(
      fontSize: DesignTokens.subheadingTextSize,
      fontWeight: FontWeight.w700,
      color: DesignTokens.textPrimary,
    ),
    bodyLarge: TextStyle(
      fontSize: DesignTokens.bodyTextSize,
      fontWeight: FontWeight.w400,
      color: DesignTokens.textPrimary,
      height: DesignTokens.bodyLineHeight,
    ),
    bodyMedium: TextStyle(
      fontSize: DesignTokens.bodyTextSize,
      fontWeight: FontWeight.w400,
      color: DesignTokens.textSecondary,
      height: DesignTokens.bodyLineHeight,
    ),
    labelLarge: TextStyle(
      fontSize: DesignTokens.bodyTextSize,
      fontWeight: FontWeight.w700,
    ),
    labelMedium: TextStyle(
      fontSize: DesignTokens.pillTextSize,
      fontWeight: FontWeight.w700,
      color: DesignTokens.textSecondary,
    ),
    bodySmall: TextStyle(
      fontSize: DesignTokens.captionTextSize,
      fontWeight: FontWeight.w400,
      color: DesignTokens.textSecondary,
    ),
  );
}
