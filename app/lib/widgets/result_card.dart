import 'dart:io';

import 'package:flutter/material.dart';

import '../models/classification_result.dart';
import '../theme/design_tokens.dart';
import 'confidence_indicator.dart';

/// Displays the classification result in a rich, card-based layout per §7.2.
///
/// Shows the captured image (if provided), the variety–ripeness headline
/// (§7.3: large, clear text like "Lakatan — Ripe"), and a plain-language
/// confidence indicator (no jargon).
///
/// The ripeness stage is also communicated with an icon (never color alone
/// per §7.4).
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

  /// Maps a ripeness label to a corresponding icon so meaning is never
  /// conveyed by color alone (§7.4).
  IconData get _ripenessIcon {
    switch (result.ripeness.toLowerCase()) {
      case 'unripe':
        return Icons.hourglass_empty;
      case 'ripe':
        return Icons.check_circle_outline;
      case 'overripe':
        return Icons.warning_amber_rounded;
      default:
        return Icons.eco;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DesignTokens.radiusLarge),
      ),
      child: Padding(
        padding: const EdgeInsets.all(DesignTokens.spacingLarge),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Image thumbnail (if available) ──
            if (imagePath != null) ...[
              ClipRRect(
                borderRadius:
                    BorderRadius.circular(DesignTokens.radiusMedium),
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

            // ── Variety — Ripeness headline (§7.3) ──
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _ripenessIcon,
                  color: DesignTokens.primary,
                  size: DesignTokens.iconMedium,
                ),
                const SizedBox(width: DesignTokens.spacingSmall),
                Flexible(
                  child: Text(
                    '${result.variety} — ${result.ripeness}',
                    style: const TextStyle(
                      fontSize: DesignTokens.resultHeadlineSize,
                      fontWeight: FontWeight.w700,
                      color: DesignTokens.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),

            const SizedBox(height: DesignTokens.spacingMedium),

            // ── Divider ──
            const Divider(color: DesignTokens.border, height: 1),

            const SizedBox(height: DesignTokens.spacingMedium),

            // ── Plain-language confidence (§7.3) ──
            ConfidenceIndicator(confidence: result.confidence),
          ],
        ),
      ),
    );
  }
}
