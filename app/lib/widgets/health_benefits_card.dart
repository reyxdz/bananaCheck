import 'package:flutter/material.dart';

import '../models/banana_info_data.dart';
import '../theme/design_tokens.dart';
import 'section_container.dart';

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

    return SectionContainer(
      title: 'Health Benefits',
      icon: Icons.favorite_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── General benefits (always shown) ──
          for (final benefit in info.generalBenefits)
            _BenefitRow(text: benefit),

          // ── Ripeness-specific benefits (when available) ──
          if (ripenessInfo != null &&
              ripenessInfo.healthBenefits.isNotEmpty) ...[
            const Padding(
              padding:
                  EdgeInsets.symmetric(vertical: DesignTokens.spacingSmall),
              child: Divider(height: 1),
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
      padding: const EdgeInsets.only(bottom: DesignTokens.spacingSmall),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 3),
            child: Icon(
              Icons.eco_rounded,
              color: DesignTokens.secondary,
              size: DesignTokens.iconSmall,
            ),
          ),
          const SizedBox(width: DesignTokens.spacingSmall),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
