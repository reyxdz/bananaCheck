import 'package:flutter/material.dart';

import '../models/banana_info_data.dart';
import '../theme/design_tokens.dart';

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
    return Container(
      padding: const EdgeInsets.all(DesignTokens.spacingMedium),
      decoration: BoxDecoration(
        color: DesignTokens.background,
        borderRadius: BorderRadius.circular(DesignTokens.radiusSmall),
        border: Border.all(color: DesignTokens.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Section header ──
          const Row(
            children: [
              Icon(
                Icons.restaurant_rounded,
                color: DesignTokens.accent,
                size: 20,
              ),
              SizedBox(width: DesignTokens.spacingSmall),
              Text(
                'Suggested Dishes',
                style: TextStyle(
                  fontSize: DesignTokens.subheadingTextSize,
                  fontWeight: FontWeight.w700,
                  color: DesignTokens.textPrimary,
                ),
              ),
            ],
          ),

          const SizedBox(height: DesignTokens.spacingSmall),

          // ── Dish chips ──
          Wrap(
            spacing: DesignTokens.spacingSmall,
            runSpacing: DesignTokens.spacingSmall,
            children: [
              for (final dish in ripenessInfo.dishSuggestions)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: DesignTokens.primaryLight,
                    borderRadius:
                        BorderRadius.circular(DesignTokens.radiusSmall),
                  ),
                  child: Text(
                    dish,
                    style: const TextStyle(
                      color: DesignTokens.primaryDark,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
