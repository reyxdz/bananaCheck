import 'dart:io';

import 'package:flutter/material.dart';

import '../models/banana_info_data.dart';
import '../models/classification_result.dart';
import '../theme/design_tokens.dart';
import 'confidence_indicator.dart';
import 'section_container.dart';
import 'dish_suggestions_card.dart';
import 'health_benefits_card.dart';
import 'result_headline.dart';
import 'reveal.dart';

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
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── The scanned photo as the hero ──
          if (imagePath != null)
            SizedBox(
              height: DesignTokens.resultHeroHeight,
              child: Image.file(
                File(imagePath!),
                fit: BoxFit.cover,
                semanticLabel: 'Your scanned banana',
                errorBuilder: (_, __, ___) => const ColoredBox(
                  color: DesignTokens.surfaceMuted,
                  child: Center(
                    child: Icon(
                      Icons.image_not_supported_outlined,
                      color: DesignTokens.textSecondary,
                      size: DesignTokens.iconLarge,
                    ),
                  ),
                ),
              ),
            ),

          Padding(
            padding: const EdgeInsets.all(DesignTokens.spacingLarge),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Headline: variety large, ripeness badge + meaning ──
                Reveal(
                  child: ResultHeadline(
                    variety: result.variety,
                    ripeness: result.ripeness,
                  ),
                ),

                const SizedBox(height: DesignTokens.spacingLarge),

                // ── Plain-language confidence (§7.3) ──
                Reveal(
                  order: 2,
                  child: SectionContainer(
                    child: ConfidenceIndicator(confidence: result.confidence),
                  ),
                ),

                const SizedBox(height: DesignTokens.spacingSmall + 4),

                // ── Farmer/vendor handling advice ──
                Reveal(
                  order: 3,
                  child: SectionContainer(
                    title: 'Handling tip',
                    icon: Icons.tips_and_updates_outlined,
                    iconColor: DesignTokens.warning,
                    background: DesignTokens.accentLight,
                    child: Text(
                      _vendorRecommendation,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ),
                ),

                // ── Health Benefits & Dish Suggestions ──
                _buildInfoCards(),
              ],
            ),
          ),
        ],
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
        const SizedBox(height: DesignTokens.spacingSmall + 4),
        Reveal(
          order: 4,
          child: HealthBenefitsCard(info: info, ripeness: lowerRipeness),
        ),
        if (ripenessInfo != null) ...[
          const SizedBox(height: DesignTokens.spacingSmall + 4),
          Reveal(
            order: 5,
            child: DishSuggestionsCard(ripenessInfo: ripenessInfo),
          ),
        ],
      ],
    );
  }
}
