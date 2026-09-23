import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';

/// Small pill-shaped tag displaying an icon + label.
///
/// Used for variety and ripeness badges across the result card and history
/// cards. Supports two visual modes:
/// - **Filled** (default): light background tint, no border.
/// - **Outlined** (`outlined: true`): transparent-ish background with a
///   visible border — used for the ripeness pill whose color is dynamic.
///
/// All sizing comes from [DesignTokens] (§7.5).
class InfoPill extends StatelessWidget {
  const InfoPill({
    required this.icon,
    required this.label,
    required this.color,
    this.outlined = false,
    super.key,
  });

  /// Leading icon shown before the label.
  final IconData icon;

  /// Human-readable label text.
  final String label;

  /// The colour used for icon, text, and background tint.
  final Color color;

  /// When `true`, renders a border + translucent fill instead of a solid fill.
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DesignTokens.chipPaddingHorizontal,
        vertical: DesignTokens.chipPaddingVertical,
      ),
      decoration: BoxDecoration(
        color: outlined
            ? color.withOpacity(0.12)
            : DesignTokens.primaryLight,
        borderRadius: BorderRadius.circular(DesignTokens.radiusSmall),
        border: outlined
            ? Border.all(
                color: color.withOpacity(0.4),
                width: DesignTokens.sectionBorderWidth,
              )
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: outlined ? color : DesignTokens.primaryDark,
            size: DesignTokens.iconSmall,
          ),
          const SizedBox(width: DesignTokens.spacingExtraSmall + 2),
          Text(
            label,
            style: TextStyle(
              color: outlined ? color : DesignTokens.primaryDark,
              fontWeight: FontWeight.w700,
              fontSize: DesignTokens.pillTextSize,
            ),
          ),
        ],
      ),
    );
  }
}
