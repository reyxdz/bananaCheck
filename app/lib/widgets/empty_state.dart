import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';

/// Centred illustration/icon, title, message and actions — used for empty
/// lists and full-screen errors so they all share one calm layout.
class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.title,
    required this.message,
    this.icon,
    this.illustration,
    this.iconColor = DesignTokens.primary,
    this.iconBackground = DesignTokens.primaryLight,
    this.primaryAction,
    this.secondaryAction,
    super.key,
  });

  final String title;
  final String message;

  /// Shown in a soft circle when no [illustration] is given.
  final IconData? icon;

  /// Custom artwork (e.g. the mascot); replaces [icon].
  final Widget? illustration;
  final Color iconColor;
  final Color iconBackground;

  /// Usually a full-width [PrimaryButton].
  final Widget? primaryAction;

  /// Usually a [TextButton] or [SecondaryButton].
  final Widget? secondaryAction;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(DesignTokens.spacingLarge),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            illustration ??
                Container(
                  width: DesignTokens.errorIconCircle,
                  height: DesignTokens.errorIconCircle,
                  decoration: BoxDecoration(
                    color: iconBackground,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon ?? Icons.eco_rounded,
                    color: iconColor,
                    size: DesignTokens.iconLarge * 0.8,
                  ),
                ),
            const SizedBox(height: DesignTokens.spacingLarge),
            Text(
              title,
              textAlign: TextAlign.center,
              style: textTheme.headlineSmall,
            ),
            const SizedBox(height: DesignTokens.spacingSmall),
            Text(
              message,
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium,
            ),
            if (primaryAction != null) ...[
              const SizedBox(height: DesignTokens.spacingExtraLarge),
              SizedBox(width: double.infinity, child: primaryAction),
            ],
            if (secondaryAction != null) ...[
              const SizedBox(height: DesignTokens.spacingSmall),
              secondaryAction!,
            ],
          ],
        ),
      ),
    );
  }
}
