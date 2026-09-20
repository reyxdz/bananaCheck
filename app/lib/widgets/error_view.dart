import 'package:flutter/material.dart';

import '../models/app_exception.dart';
import '../theme/design_tokens.dart';

/// Reusable, full-screen-safe error display widget (A16).
///
/// Shows a plain-language error message with an actionable hint and a large
/// "Try Again" button — per §7.3 and §7.4. Used by [AnalyzingScreen],
/// [CameraScreen], [HistoryScreen], and any future screen that needs to
/// communicate an error to the user.
///
/// Layout:
/// - Icon (48dp, from [AppException.icon])
/// - User message (bold, centered)
/// - Action hint (secondary text)
/// - Large "Try Again" button (full-width, 64dp min height)
/// - Optional secondary action as a [TextButton]
class ErrorView extends StatelessWidget {
  const ErrorView({
    required this.exception,
    required this.onRetry,
    this.retryLabel = 'Try Again',
    this.secondaryLabel,
    this.onSecondary,
    super.key,
  });

  /// The structured error to display.
  final AppException exception;

  /// Called when the user taps the primary retry button.
  final VoidCallback onRetry;

  /// Label for the retry button. Defaults to "Try Again".
  final String retryLabel;

  /// Optional label for a secondary text button (e.g. "Go back to camera").
  final String? secondaryLabel;

  /// Called when the user taps the secondary action.
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: DesignTokens.spacingLarge,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Error icon ──
            Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(
                color: DesignTokens.errorBackground,
                shape: BoxShape.circle,
              ),
              child: Icon(
                exception.icon,
                color: DesignTokens.confidenceLow,
                size: DesignTokens.iconLarge,
              ),
            ),

            const SizedBox(height: DesignTokens.spacingLarge),

            // ── User message — plain language per §7.3 ──
            Text(
              exception.userMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: DesignTokens.headingTextSize,
                fontWeight: FontWeight.w700,
                color: DesignTokens.textPrimary,
              ),
            ),

            const SizedBox(height: DesignTokens.spacingSmall),

            // ── Actionable hint ──
            Text(
              exception.actionHint,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: DesignTokens.bodyTextSize,
                color: DesignTokens.textSecondary,
              ),
            ),

            const SizedBox(height: DesignTokens.spacingExtraLarge),

            // ── Large retry button — single primary action per §7.1 / §7.4 ──
            SizedBox(
              width: double.infinity,
              height: DesignTokens.primaryActionSize,
              child: ElevatedButton.icon(
                onPressed: onRetry,
                style: ElevatedButton.styleFrom(
                  backgroundColor: DesignTokens.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(DesignTokens.radiusMedium),
                  ),
                  textStyle: const TextStyle(
                    fontSize: DesignTokens.bodyTextSize,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                icon: const Icon(Icons.refresh_rounded),
                label: Text(retryLabel),
              ),
            ),

            // ── Optional secondary action ──
            if (secondaryLabel != null && onSecondary != null) ...[
              const SizedBox(height: DesignTokens.spacingMedium),
              TextButton(
                onPressed: onSecondary,
                child: Text(
                  secondaryLabel!,
                  style: const TextStyle(
                    fontSize: DesignTokens.bodyTextSize,
                    color: DesignTokens.textSecondary,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
