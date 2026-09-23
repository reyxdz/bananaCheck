import 'dart:io';

import 'package:flutter/material.dart';

import '../models/banana_info_data.dart';
import '../models/classification_result.dart';
import '../theme/design_tokens.dart';
import '../theme/ripeness_helpers.dart';
import 'confidence_indicator.dart';
import 'dish_suggestions_card.dart';
import 'health_benefits_card.dart';
import 'info_pill.dart';
import 'section_container.dart';

/// Displays the classification result in a rich, card-based layout per §7.2.
///
/// Shows the captured image (if provided), variety & ripeness pill tags,
/// headline (§7.3: large, clear text like "Lakatan — Ripe"), plain-language
/// confidence indicator, and vendor advice tips.
class ResultCard extends StatelessWidget {
  const ResultCard({
    required this.result,
    this.imagePath,
    super.key,
  });

  final ClassificationResult result;

  /// Path to the captured image to display as a thumbnail.
  /// Null in widget tests where no actual file exists.
  final String? imagePath;

  String get _vendorRecommendation {
    switch (result.ripeness.toLowerCase()) {
      case 'unripe':
        return 'Store at room temperature. Best for market sale in 2 to 4 days.';
      case 'ripe':
        return 'Ready for immediate consumption or market display today!';
      case 'overripe':
        return 'Best used immediately for baking, smoothies, or processing.';
      default:
        return 'Inspect fruit quality regularly for optimal handling.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final ripenessColor = RipenessHelpers.colorFor(result.ripeness);
    final ripenessIcon = RipenessHelpers.iconFor(result.ripeness);

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DesignTokens.radiusLarge),
      ),
      child: Padding(
        padding: const EdgeInsets.all(DesignTokens.spacingLarge),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Image thumbnail (if available) ──
            if (imagePath != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(DesignTokens.radiusMedium),
                child: SizedBox(
                  width: double.infinity,
                  height: DesignTokens.imageThumbnailSize,
                  child: Image.file(
                    File(imagePath!),
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: DesignTokens.background,
                      child: const Center(
                        child: Icon(
                          Icons.image_not_supported_outlined,
                          color: DesignTokens.textSecondary,
                          size: DesignTokens.iconLarge,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: DesignTokens.spacingLarge),
            ],

            // ── Pill Badges (Variety + Ripeness) ──
            Wrap(
              alignment: WrapAlignment.center,
              spacing: DesignTokens.spacingSmall,
              runSpacing: DesignTokens.spacingSmall,
              children: [
                InfoPill(
                  icon: Icons.eco,
                  label: result.variety,
                  color: DesignTokens.primary,
                ),
                InfoPill(
                  icon: ripenessIcon,
                  label: result.ripeness,
                  color: ripenessColor,
                  outlined: true,
                ),
              ],
            ),

            const SizedBox(height: DesignTokens.spacingMedium),

            // ── Variety — Ripeness headline (§7.3) ──
            Text(
              '${result.variety} — ${result.ripeness}',
              style: const TextStyle(
                fontSize: DesignTokens.resultHeadlineSize,
                fontWeight: FontWeight.w800,
                color: DesignTokens.textPrimary,
                height: 1.2,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: DesignTokens.spacingMedium),

            // ── Divider ──
            const Divider(color: DesignTokens.border, height: 1),

            const SizedBox(height: DesignTokens.spacingMedium),

            // ── Plain-language confidence (§7.3) ──
            ConfidenceIndicator(confidence: result.confidence),

            const SizedBox(height: DesignTokens.spacingMedium),

            // ── Farmer/Vendor Handling Advice Card ──
            SectionContainer(
              child: Row(
                children: [
                  const Icon(
                    Icons.tips_and_updates_outlined,
                    color: DesignTokens.accent,
                    size: DesignTokens.iconTip,
                  ),
                  const SizedBox(width: DesignTokens.spacingSmall),
                  Expanded(
                    child: Text(
                      _vendorRecommendation,
                      style: const TextStyle(
                        fontSize: DesignTokens.chipTextSize,
                        fontWeight: FontWeight.w500,
                        color: DesignTokens.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Health Benefits & Dish Suggestions (§7.6) ──
            _buildInfoCards(),
          ],
        ),
      ),
    );
  }

  /// Builds [HealthBenefitsCard] and [DishSuggestionsCard] from
  /// [bananaInfoMap]. Returns an empty [SizedBox] when the variety is not
  /// found so the layout degrades gracefully.
  Widget _buildInfoCards() {
    final info = bananaInfoMap[result.variety.toLowerCase()];
    if (info == null) return const SizedBox.shrink();

    final lowerRipeness = result.ripeness.toLowerCase();
    final ripenessInfo = info.byRipeness[lowerRipeness];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: DesignTokens.spacingMedium),
        HealthBenefitsCard(info: info, ripeness: lowerRipeness),
        if (ripenessInfo != null) ...[
          const SizedBox(height: DesignTokens.spacingMedium),
          DishSuggestionsCard(ripenessInfo: ripenessInfo),
        ],
      ],
    );
  }
}
