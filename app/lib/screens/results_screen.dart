import 'package:flutter/material.dart';

import '../models/classification_result.dart';
import '../theme/design_tokens.dart';
import '../widgets/primary_button.dart';
import '../widgets/result_card.dart';

/// Displays the classification result after a scan.
///
/// Layout per §7.1 / §7.2 / §7.3:
/// - One primary action: **Scan Again** (large button with icon + label).
/// - Card-based design with the scanned image, variety–ripeness headline,
///   and a plain-language confidence indicator.
/// - No jargon — confidence is shown as a friendly label + filled bars.
/// - Uses only design tokens (§7.5) — no hardcoded colors or sizes.
class ResultsScreen extends StatelessWidget {
  const ResultsScreen({
    required this.result,
    required this.onScanAgain,
    this.imagePath,
    super.key,
  });

  /// The classification result from the inference service.
  final ClassificationResult result;

  /// Called when the user taps "Scan Again" — navigates back to camera.
  final VoidCallback onScanAgain;

  /// Path to the captured image file. Null in widget tests.
  final String? imagePath;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DesignTokens.background,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top bar ──
            Padding(
              padding: const EdgeInsets.fromLTRB(
                DesignTokens.spacingLarge,
                DesignTokens.spacingLarge,
                DesignTokens.spacingLarge,
                0,
              ),
              child: Row(
                children: [
                  // Back arrow for system navigation (accessibility).
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    iconSize: DesignTokens.iconMedium,
                    onPressed: onScanAgain,
                    tooltip: 'Go back',
                  ),
                  const SizedBox(width: DesignTokens.spacingSmall),
                  Text(
                    'Your Result',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ],
              ),
            ),

            const SizedBox(height: DesignTokens.spacingMedium),

            // ── Main content — scrollable for small screens ──
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: DesignTokens.spacingLarge,
                ),
                child: Column(
                  children: [
                    // The main result card (image + headline + confidence).
                    ResultCard(
                      result: result,
                      imagePath: imagePath,
                    ),

                    const SizedBox(height: DesignTokens.spacingLarge),

                    // ── Helpful context line ──
                    const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: DesignTokens.spacingSmall,
                      ),
                      child: Text(
                        'Point at a different banana and scan again '
                        'if you want to check another one.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: DesignTokens.bodyTextSize,
                          color: DesignTokens.textSecondary,
                        ),
                      ),
                    ),

                    const SizedBox(height: DesignTokens.spacingExtraLarge),
                  ],
                ),
              ),
            ),

            // ── Scan Again button — single primary action (§7.1) ──
            Padding(
              padding: const EdgeInsets.fromLTRB(
                DesignTokens.spacingLarge,
                0,
                DesignTokens.spacingLarge,
                DesignTokens.spacingLarge,
              ),
              child: SizedBox(
                width: double.infinity,
                height: DesignTokens.primaryActionSize,
                child: PrimaryButton(
                  icon: Icons.camera_alt,
                  label: 'Scan Again',
                  onPressed: onScanAgain,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
