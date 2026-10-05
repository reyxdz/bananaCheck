import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';
import '../theme/ripeness_helpers.dart';

/// The two answers a scan gives, as large as the screen allows:
///
/// * **Variety** — set big, straight under the photo.
/// * **Ripeness** — the stage word with its icon, what it means in plain
///   language, and a ripening scale (green → yellow → brown) that shows
///   where this banana sits. Colour is never the only cue (§7.4): the stage
///   is always written out.
///
/// Read by screen readers as one phrase, e.g. "Lakatan. Ripe, stage 2 of 3.
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
    final color = RipenessHelpers.colorFor(ripeness);
    final stage = RipeningScale.stageIndexOf(ripeness);

    final spoken = [
      variety,
      stage == null
          ? ripeness
          : '$ripeness, stage ${stage + 1} of ${RipeningScale.stages.length}',
      if (summary.isNotEmpty) summary,
    ].join('. ');

    return Semantics(
      container: true,
      label: spoken,
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Variety ──
            Text(
              variety,
              style: const TextStyle(
                fontSize: DesignTokens.varietyHeadlineSize,
                fontWeight: FontWeight.w700,
                color: DesignTokens.textPrimary,
                height: 1.05,
                letterSpacing: -1,
              ),
            ),

            const SizedBox(height: DesignTokens.spacingMedium),

            // ── Ripeness statement ──
            Row(
              children: [
                Icon(
                  RipenessHelpers.iconFor(ripeness),
                  color: color,
                  size: DesignTokens.iconMedium,
                ),
                const SizedBox(width: DesignTokens.spacingSmall),
                Flexible(
                  child: Text(
                    ripeness,
                    style: TextStyle(
                      fontSize: DesignTokens.headingTextSize,
                      fontWeight: FontWeight.w700,
                      color: color,
                      height: DesignTokens.headingLineHeight,
                    ),
                  ),
                ),
              ],
            ),
            if (summary.isNotEmpty) ...[
              const SizedBox(height: DesignTokens.spacingExtraSmall),
              Text(summary, style: textTheme.bodyLarge),
            ],

            // ── Where it sits on the ripening scale ──
            if (stage != null) ...[
              const SizedBox(height: DesignTokens.spacingMedium),
              RipeningScale(activeIndex: stage),
            ],
          ],
        ),
      ),
    );
  }
}

/// Three peel-coloured segments — Unripe, Ripe, Overripe — with the
/// detected stage in full colour, taller, and labelled in bold. The active
/// segment fills in once when it appears (skipped under reduce-motion).
class RipeningScale extends StatelessWidget {
  const RipeningScale({required this.activeIndex, super.key});

  /// Index into [stages] of the detected ripeness.
  final int activeIndex;

  static const stages = ['Unripe', 'Ripe', 'Overripe'];
  static const _colors = [
    DesignTokens.peelGreen,
    DesignTokens.peelYellow,
    DesignTokens.peelBrown,
  ];

  /// Position of [ripeness] on the scale, or `null` if it isn't one of the
  /// three known stages.
  static int? stageIndexOf(String ripeness) {
    final index = stages.indexWhere(
      (s) => s.toLowerCase() == ripeness.trim().toLowerCase(),
    );
    return index < 0 ? null : index;
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < stages.length; i++) ...[
          if (i > 0) const SizedBox(width: DesignTokens.spacingExtraSmall + 2),
          Expanded(
            child: _Segment(
              label: stages[i],
              color: _colors[i],
              active: i == activeIndex,
              animate: !reduceMotion,
            ),
          ),
        ],
      ],
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.color,
    required this.active,
    required this.animate,
  });

  final String label;
  final Color color;
  final bool active;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    const radius = BorderRadius.all(
      Radius.circular(DesignTokens.ripenessScaleActiveHeight),
    );

    final bar = active
        ? TweenAnimationBuilder<double>(
            tween: Tween(begin: animate ? 0 : 1, end: 1),
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOutCubic,
            builder: (context, t, _) => Container(
              height: DesignTokens.ripenessScaleActiveHeight,
              decoration: BoxDecoration(
                color: color.withOpacity(0.18),
                borderRadius: radius,
              ),
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: t,
                heightFactor: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(color: color, borderRadius: radius),
                ),
              ),
            ),
          )
        : Container(
            height: DesignTokens.ripenessScaleHeight,
            margin: const EdgeInsets.symmetric(
              vertical: (DesignTokens.ripenessScaleActiveHeight -
                      DesignTokens.ripenessScaleHeight) /
                  2,
            ),
            decoration: BoxDecoration(
              color: color.withOpacity(0.28),
              borderRadius: radius,
            ),
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        bar,
        const SizedBox(height: DesignTokens.spacingSmall - 2),
        Text(
          label,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: DesignTokens.captionTextSize,
            fontWeight: active ? FontWeight.w700 : FontWeight.w400,
            color:
                active ? DesignTokens.textPrimary : DesignTokens.textSecondary,
          ),
        ),
      ],
    );
  }
}
