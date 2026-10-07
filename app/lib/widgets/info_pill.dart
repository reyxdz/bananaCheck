import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';

/// Rounded status badge: icon + label, so meaning never relies on colour
/// alone (§7.4). Used for variety and ripeness on results and history.
///
/// * Filled (default): pale leaf background, botanical green text.
/// * [outlined]: tinted with [color] plus a thin border — used for ripeness,
///   whose colour changes per result.
class InfoPill extends StatelessWidget {
  const InfoPill({
    required this.icon,
    required this.label,
    required this.color,
    this.outlined = false,
    this.compact = false,
    super.key,
  });

  final IconData icon;
  final String label;
  final Color color;
  final bool outlined;

  /// Smaller padding for dense lists (history rows).
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final foreground = outlined ? color : DesignTokens.primaryDark;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact
            ? DesignTokens.badgePaddingHorizontal
            : DesignTokens.chipPaddingHorizontal,
        vertical: compact
            ? DesignTokens.badgePaddingVertical + 1
            : DesignTokens.chipPaddingVertical,
      ),
      decoration: BoxDecoration(
        color: outlined ? color.withOpacity(0.10) : DesignTokens.primaryLight,
        borderRadius: BorderRadius.circular(DesignTokens.radiusPill),
        border: outlined
            ? Border.all(
                color: color.withOpacity(0.35),
                width: DesignTokens.sectionBorderWidth,
              )
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: foreground, size: DesignTokens.iconSmall),
          const SizedBox(width: DesignTokens.pillIconGap),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: foreground,
                fontWeight: FontWeight.w700,
                fontSize: compact
                    ? DesignTokens.captionTextSize
                    : DesignTokens.pillTextSize,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
