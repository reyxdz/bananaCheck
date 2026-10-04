import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';
import '../theme/ripeness_helpers.dart';
import 'info_pill.dart';

/// The scan result as a headline: a quiet "Your banana" label, the variety
/// set large, then a coloured ripeness badge (icon + word, never colour
/// alone — §7.4) with a plain-language note on what that ripeness means.
///
/// Read by screen readers as one phrase, e.g. "Your banana, Lakatan, Ripe,
/// Ready to eat today".
class ResultHeadline extends StatelessWidget {
  const ResultHeadline({
    required this.variety,
    required this.ripeness,
    super.key,
  });

  final String variety;
  final String ripeness;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final summary = RipenessHelpers.summaryFor(ripeness);

    return MergeSemantics(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Your banana', style: textTheme.labelMedium),
          const SizedBox(height: DesignTokens.spacingExtraSmall),
          Text(
            variety,
            style: const TextStyle(
              fontSize: DesignTokens.displayTextSize,
              fontWeight: FontWeight.w700,
              color: DesignTokens.textPrimary,
              height: DesignTokens.headingLineHeight,
              letterSpacing: DesignTokens.headingLetterSpacing,
            ),
          ),
          const SizedBox(height: DesignTokens.spacingSmall + 2),
          Wrap(
            spacing: DesignTokens.spacingSmall + 2,
            runSpacing: DesignTokens.spacingExtraSmall,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              InfoPill(
                icon: RipenessHelpers.iconFor(ripeness),
                label: ripeness,
                color: RipenessHelpers.colorFor(ripeness),
                outlined: true,
              ),
              if (summary.isNotEmpty)
                Text(summary, style: textTheme.bodyMedium),
            ],
          ),
        ],
      ),
    );
  }
}
