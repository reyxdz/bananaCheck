import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';

/// Soft ivory section used inside result cards (handling tip, health
/// benefits, dishes).
///
/// Give it a [title] (and optional [icon]) to get a consistent section
/// header; leave them out for a plain container.
class SectionContainer extends StatelessWidget {
  const SectionContainer({
    required this.child,
    this.title,
    this.icon,
    this.iconColor = DesignTokens.primary,
    this.background = DesignTokens.surfaceMuted,
    super.key,
  });

  final Widget child;
  final String? title;
  final IconData? icon;
  final Color iconColor;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(DesignTokens.spacingMedium),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(DesignTokens.radiusMedium),
      ),
      child: title == null
          ? child
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    if (icon != null) ...[
                      Icon(
                        icon,
                        color: iconColor,
                        size: DesignTokens.iconDefault,
                      ),
                      const SizedBox(width: DesignTokens.spacingSmall),
                    ],
                    Expanded(
                      child: Text(
                        title!,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: DesignTokens.spacingSmall + 4),
                child,
              ],
            ),
    );
  }
}
