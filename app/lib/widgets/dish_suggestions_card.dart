import 'package:flutter/material.dart';

import '../models/banana_info_data.dart';
import '../theme/design_tokens.dart';
import 'section_container.dart';

/// Displays ripeness-aware dish suggestions as styled chips per §7.6.
///
/// Shows **only** the dishes for the detected ripeness level — never the
/// full list across all ripeness levels. Informational only — no interaction.
class DishSuggestionsCard extends StatelessWidget {
  const DishSuggestionsCard({required this.ripenessInfo, super.key});

  /// The per-ripeness data whose [RipenessInfo.dishSuggestions] are displayed.
  final RipenessInfo ripenessInfo;

  @override
  Widget build(BuildContext context) {
    return SectionContainer(
      title: 'Suggested Dishes',
      icon: Icons.restaurant_rounded,
      iconColor: DesignTokens.warning,
      child: Wrap(
        spacing: DesignTokens.spacingSmall,
        runSpacing: DesignTokens.spacingSmall,
        children: [
          for (final dish in ripenessInfo.dishSuggestions)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: DesignTokens.chipPaddingHorizontal + 2,
                vertical: DesignTokens.chipPaddingVertical + 2,
              ),
              decoration: BoxDecoration(
                color: DesignTokens.surface,
                borderRadius: BorderRadius.circular(DesignTokens.radiusPill),
                border: Border.all(
                  color: DesignTokens.border,
                  width: DesignTokens.sectionBorderWidth,
                ),
              ),
              child: Text(
                dish,
                style: const TextStyle(
                  color: DesignTokens.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: DesignTokens.chipTextSize,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
