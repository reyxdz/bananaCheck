import 'package:flutter/material.dart';

import '../models/app_exception.dart';
import '../theme/design_tokens.dart';
import 'empty_state.dart';
import 'primary_button.dart';

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
    return EmptyState(
      icon: exception.icon,
      iconColor: DesignTokens.error,
      iconBackground: DesignTokens.errorBackground,
      title: exception.userMessage,
      message: exception.actionHint,
      // Large retry button — single primary action per §7.1 / §7.4.
      primaryAction: SizedBox(
        height: DesignTokens.primaryActionSize,
        child: PrimaryButton(
          icon: Icons.refresh_rounded,
          label: retryLabel,
          onPressed: onRetry,
        ),
      ),
      secondaryAction: secondaryLabel != null && onSecondary != null
          ? TextButton(
              onPressed: onSecondary,
              style: TextButton.styleFrom(
                foregroundColor: DesignTokens.textSecondary,
              ),
              child: Text(secondaryLabel!),
            )
          : null,
    );
  }
}
