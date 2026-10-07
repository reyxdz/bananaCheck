import 'package:flutter/material.dart';

import '../models/classification_result.dart';
import '../theme/design_tokens.dart';
import '../widgets/primary_button.dart';
import '../widgets/result_card.dart';
import '../widgets/screen_header.dart';

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
      body: SafeArea(
        child: Column(
          children: [
            ScreenHeader(
              title: 'Scan Result',
              // Back arrow for system navigation (accessibility).
              onBack: onScanAgain,
            ),

            // ── Main content — scrollable for small screens ──
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  DesignTokens.spacingMedium,
                  DesignTokens.spacingSmall,
                  DesignTokens.spacingMedium,
                  DesignTokens.spacingLarge,
                ),
                child: Column(
                  children: [
                    // Image + headline + confidence + advice + info.
                    ResultCard(result: result, imagePath: imagePath),

                    const SizedBox(height: DesignTokens.spacingLarge),

                    // ── Helpful context line ──
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: DesignTokens.spacingMedium,
                      ),
                      child: Text(
                        'Point at a different banana and scan again '
                        'if you want to check another one.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Scan Again — single primary action (§7.1), always visible ──
            DecoratedBox(
              decoration: const BoxDecoration(
                color: DesignTokens.background,
                border: Border(
                  top: BorderSide(
                    color: DesignTokens.border,
                    width: DesignTokens.sectionBorderWidth,
                  ),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  DesignTokens.spacingMedium,
                  DesignTokens.spacingSmall + 4,
                  DesignTokens.spacingMedium,
                  DesignTokens.spacingMedium,
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: DesignTokens.primaryActionSize,
                  child: PrimaryButton(
                    icon: Icons.camera_alt_rounded,
                    label: 'Scan Again',
                    onPressed: onScanAgain,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
