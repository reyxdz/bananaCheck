import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';

/// Translates a raw confidence value (0.0–1.0) into a user-friendly visual
/// indicator per §7.3.
///
/// Never shows raw numbers like "0.92" or jargon like "confidence score."
/// Instead combines a plain-language label with a filled bar so the meaning
/// is clear without relying on color alone (§7.4).
class ConfidenceIndicator extends StatelessWidget {
  const ConfidenceIndicator({required this.confidence, super.key});

  /// Confidence score in the range [0.0, 1.0].
  final double confidence;

  /// Returns a farmer-friendly label and an associated icon.
  _ConfidenceLevel get _level {
    if (confidence >= 0.85) {
      return const _ConfidenceLevel(
        label: "We're pretty sure",
        icon: Icons.check_circle,
        color: DesignTokens.primary,
        bars: 3,
      );
    }
    if (confidence >= 0.65) {
      return const _ConfidenceLevel(
        label: 'This looks likely',
        icon: Icons.info,
        color: DesignTokens.accent,
        bars: 2,
      );
    }
    return const _ConfidenceLevel(
      label: 'Not very clear — try another photo',
      icon: Icons.help_outline,
      color: DesignTokens.textSecondary,
      bars: 1,
    );
  }

  @override
  Widget build(BuildContext context) {
    final level = _level;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Friendly label + icon (§7.2: pair icon with text, §7.4: never
        // rely on color alone).
        Row(
          children: [
            Icon(level.icon, color: level.color, size: 20),
            const SizedBox(width: DesignTokens.spacingSmall),
            Flexible(
              child: Text(
                level.label,
                style: TextStyle(
                  fontSize: DesignTokens.bodyTextSize,
                  fontWeight: FontWeight.w700,
                  color: level.color,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: DesignTokens.spacingSmall),

        // Simple filled-bar indicator (3 bars max).
        _ConfidenceBars(filledCount: level.bars, color: level.color),
      ],
    );
  }
}

/// Internal model for mapping confidence ranges to UI properties.
class _ConfidenceLevel {
  const _ConfidenceLevel({
    required this.label,
    required this.icon,
    required this.color,
    required this.bars,
  });

  final String label;
  final IconData icon;
  final Color color;

  /// How many of the 3 bars should be filled.
  final int bars;
}

/// Three small rounded bars — filled bars use the given [color], unfilled
/// bars are a light neutral.
class _ConfidenceBars extends StatelessWidget {
  const _ConfidenceBars({required this.filledCount, required this.color});

  final int filledCount;
  final Color color;

  static const int _totalBars = 3;
  static const double _barHeight = 6;
  static const double _barSpacing = 4;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(_totalBars, (index) {
        final isFilled = index < filledCount;
        return Expanded(
          child: Container(
            height: _barHeight,
            margin: EdgeInsets.only(
              right: index < _totalBars - 1 ? _barSpacing : 0,
            ),
            decoration: BoxDecoration(
              color: isFilled ? color : DesignTokens.border,
              borderRadius: BorderRadius.circular(_barHeight / 2),
            ),
          ),
        );
      }),
    );
  }
}
