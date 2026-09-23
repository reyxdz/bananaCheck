import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../models/classification_result.dart';
import '../models/scan_record.dart';
import '../services/inference_service.dart';
import '../services/storage_service.dart';
import '../theme/design_tokens.dart';

/// Full-screen "Analyzing…" state shown between capture and results (A15).
///
/// Immediately kicks off [InferenceService.classify] + [StorageService.saveRecord]
/// on creation. Displays a friendly loading UI while the work happens, then
/// calls [onComplete] with the result. On failure, shows a plain-language
/// error with a large "Try Again" button.
class AnalyzingScreen extends StatefulWidget {
  const AnalyzingScreen({
    required this.inferenceService,
    required this.storageService,
    required this.capturedFile,
    required this.onComplete,
    super.key,
  });

  final InferenceService inferenceService;
  final StorageService storageService;
  final File capturedFile;

  /// Called when classification and storage succeed. Receives the
  /// [ClassificationResult] and the image path so the caller can navigate
  /// to the results screen.
  final void Function(ClassificationResult result, String imagePath) onComplete;

  @override
  State<AnalyzingScreen> createState() => _AnalyzingScreenState();
}

class _AnalyzingScreenState extends State<AnalyzingScreen> {
  /// Non-null when the async pipeline failed — shown as a friendly message.
  String? _error;

  @override
  void initState() {
    super.initState();
    _runClassification();
  }

  Future<void> _runClassification() async {
    // Reset any previous error on retry.
    if (_error != null && mounted) {
      setState(() => _error = null);
    }

    try {
      final result =
          await widget.inferenceService.classify(widget.capturedFile);
      if (!mounted) return;

      // Persist the scan record (A12).
      final record = ScanRecord(
        id: const Uuid().v4(),
        imagePath: widget.capturedFile.path,
        result: result,
        scannedAt: DateTime.now(),
      );
      await widget.storageService.saveRecord(record);

      if (!mounted) return;

      widget.onComplete(result, widget.capturedFile.path);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Something went wrong while analyzing your banana. '
            'Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DesignTokens.background,
      body: SafeArea(
        child: _error != null ? _buildError() : _buildAnalyzing(),
      ),
    );
  }

  // ── Loading state ──────────────────────────────────────────────────────

  Widget _buildAnalyzing() {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Blurred captured image as background.
        Positioned.fill(
          child: ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Image.file(
              widget.capturedFile,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const ColoredBox(
                color: DesignTokens.background,
              ),
            ),
          ),
        ),

        // Semi-transparent overlay.
        Positioned.fill(
          child: ColoredBox(
            color: DesignTokens.background.withOpacity(0.75),
          ),
        ),

        // Centered content.
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // App logo.
              ClipRRect(
                borderRadius: BorderRadius.circular(DesignTokens.radiusMedium),
                child: Image.asset(
                  'assets/images/logo.png',
                  width: DesignTokens.primaryActionSize,
                  height: DesignTokens.primaryActionSize,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.eco_rounded,
                    color: DesignTokens.primary,
                    size: DesignTokens.primaryActionSize,
                  ),
                ),
              ),

              const SizedBox(height: DesignTokens.spacingExtraLarge),

              // Spinner.
              const SizedBox(
                width: DesignTokens.minimumTouchTarget,
                height: DesignTokens.minimumTouchTarget,
                child: CircularProgressIndicator(
                  strokeWidth: 4,
                  color: DesignTokens.primary,
                ),
              ),

              const SizedBox(height: DesignTokens.spacingLarge),

              // Primary message — plain language per §7.3.
              const Text(
                'Analyzing your banana…',
                style: TextStyle(
                  fontSize: DesignTokens.headingTextSize,
                  fontWeight: FontWeight.w700,
                  color: DesignTokens.textPrimary,
                ),
              ),

              const SizedBox(height: DesignTokens.spacingSmall),

              // Secondary message.
              const Text(
                'This will only take a moment',
                style: TextStyle(
                  fontSize: DesignTokens.bodyTextSize,
                  color: DesignTokens.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Error state ────────────────────────────────────────────────────────

  Widget _buildError() {
    return Center(
      child: Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: DesignTokens.spacingLarge),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: DesignTokens.confidenceLow,
              size: DesignTokens.iconLarge,
            ),

            const SizedBox(height: DesignTokens.spacingLarge),

            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: DesignTokens.bodyTextSize,
                fontWeight: FontWeight.w600,
                color: DesignTokens.textPrimary,
              ),
            ),

            const SizedBox(height: DesignTokens.spacingExtraLarge),

            // Large retry button — per §7.1 single primary action.
            SizedBox(
              width: double.infinity,
              height: DesignTokens.primaryActionSize,
              child: ElevatedButton.icon(
                onPressed: _runClassification,
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
                label: const Text('Try Again'),
              ),
            ),

            const SizedBox(height: DesignTokens.spacingMedium),

            // Back to camera.
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Go back to camera',
                style: TextStyle(
                  fontSize: DesignTokens.bodyTextSize,
                  color: DesignTokens.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
