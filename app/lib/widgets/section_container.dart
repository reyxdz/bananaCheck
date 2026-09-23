import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';

/// Reusable bordered section container used for info cards within results.
///
/// Provides a consistent background, border, and border-radius per §7.2/§7.5.
/// Used by [HealthBenefitsCard], [DishSuggestionsCard], and the vendor-advice
/// section in [ResultCard] — avoids repeating the same [BoxDecoration] three
/// times.
class SectionContainer extends StatelessWidget {
  const SectionContainer({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(DesignTokens.spacingMedium),
      decoration: BoxDecoration(
        color: DesignTokens.background,
        borderRadius: BorderRadius.circular(DesignTokens.radiusSmall),
        border: Border.all(
          color: DesignTokens.border,
          width: DesignTokens.sectionBorderWidth,
        ),
      ),
      child: child,
    );
  }
}
