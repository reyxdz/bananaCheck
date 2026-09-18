import 'package:flutter/material.dart';

import '../models/banana_info_data.dart';
import '../theme/design_tokens.dart';

/// Displays health benefits for a scanned banana variety per §7.6.
///
/// Shows [BananaInfo.generalBenefits] (variety-wide) first, then any
/// ripeness-specific benefits from the matching [RipenessInfo]. If the
/// ripeness key is absent in [BananaInfo.byRipeness], only the general
/// benefits are shown — no crash, no empty section.
class HealthBenefitsCard extends StatelessWidget {
  const HealthBenefitsCard({
    required this.info,
    required this.ripeness,
    super.key,
  });

  /// Banana variety data containing general + per-ripeness benefits.
  final BananaInfo info;

  /// Lowercase ripeness key (e.g. `"unripe"`, `"ripe"`, `"overripe"`).
  final String ripeness;

  @override
  Widget build(BuildContext context) {
    final ripenessInfo = info.byRipeness[ripeness];

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
                Icons.favorite_rounded,
                color: DesignTokens.primary,
                size: 20,
              ),
              SizedBox(width: DesignTokens.spacingSmall),
              Text(
                'Health Benefits',
                style: TextStyle(
                  fontSize: DesignTokens.subheadingTextSize,
                  fontWeight: FontWeight.w700,
                  color: DesignTokens.textPrimary,
                ),
              ),
            ],
          ),

          const SizedBox(height: DesignTokens.spacingSmall),

          // ── General benefits (always shown) ──
          for (final benefit in info.generalBenefits)
            _BenefitRow(text: benefit),

          // ── Ripeness-specific benefits (when available) ──
          if (ripenessInfo != null &&
              ripenessInfo.healthBenefits.isNotEmpty) ...[
            const Padding(
              padding:
                  EdgeInsets.symmetric(vertical: DesignTokens.spacingSmall),
              child: Divider(color: DesignTokens.border, height: 1),
            ),
            for (final benefit in ripenessInfo.healthBenefits)
              _BenefitRow(text: benefit),
          ],
        ],
      ),
    );
  }
}

/// A single benefit line with a leaf bullet icon.
class _BenefitRow extends StatelessWidget {
  const _BenefitRow({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: DesignTokens.spacingExtraSmall),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(
              Icons.eco_rounded,
              color: DesignTokens.primary,
              size: 14,
            ),
          ),
          const SizedBox(width: DesignTokens.spacingSmall),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: DesignTokens.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
