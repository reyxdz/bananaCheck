import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../models/app_exception.dart';
import '../models/classification_result.dart';
import '../models/scan_record.dart';
import '../services/inference_service.dart';
import '../services/storage_service.dart';
import '../theme/design_tokens.dart';
import '../widgets/error_view.dart';

/// Confidence threshold below which the result is treated as unreliable
/// and the user is shown a "Couldn't tell clearly" error instead.
const double _lowConfidenceThreshold = 0.5;

/// Full-screen "Analyzing…" state shown between capture and results (A15).
///
/// Immediately kicks off [InferenceService.classify] + [StorageService.saveRecord]
/// on creation. Displays a friendly loading UI while the work happens, then
/// calls [onComplete] with the result. On failure, shows a plain-language
/// error with a large "Try Again" button (A16).
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
  /// Non-null when the async pipeline failed — determines the error UI.
  AppException? _error;

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
      // 1. Run inference.
      final ClassificationResult result;
      try {
        result = await widget.inferenceService.classify(widget.capturedFile);
      } on AppException catch (e) {
        // The service threw a structured error — use it directly.
        if (!mounted) return;
        setState(() => _error = e);
        return;
      } catch (_) {
        // Unknown inference failure — classify as image processing issue.
        if (!mounted) return;
        setState(() => _error = const ImageProcessingException());
        return;
      }

      if (!mounted) return;

      // 2. Low-confidence gate — treat as an error per §7.3.
      if (result.confidence < _lowConfidenceThreshold) {
        setState(() => _error = const LowConfidenceException());
        return;
      }

      // 3. Persist the scan record (A12).
      try {
        final record = ScanRecord(
          id: const Uuid().v4(),
          imagePath: widget.capturedFile.path,
          result: result,
          scannedAt: DateTime.now(),
        );
        await widget.storageService.saveRecord(record);
      } catch (_) {
        // Storage failed but classification succeeded — still show results,
        // just notify the user that saving didn't work.
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Your result is ready, but we couldn\'t save it to history.',
              ),
              duration: Duration(seconds: 4),
            ),
          );
        }
      }

      if (!mounted) return;

      widget.onComplete(result, widget.capturedFile.path);
    } catch (e) {
      // Catch-all for anything unexpected.
      if (!mounted) return;
      setState(() => _error = AppException.from(e));
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
            color: DesignTokens.background.withOpacity(DesignTokens.analyzingOverlayOpacity),
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
                  width: 64,
                  height: 64,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.eco_rounded,
                    color: DesignTokens.primary,
                    size: 64,
                  ),
                ),
              ),

              const SizedBox(height: DesignTokens.spacingExtraLarge),

              // Spinner.
              const SizedBox(
                width: 48,
                height: 48,
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

  // ── Error state (A16) ─────────────────────────────────────────────────

  Widget _buildError() {
    return ErrorView(
      exception: _error!,
      onRetry: _runClassification,
      secondaryLabel: 'Go back to camera',
      onSecondary: () => Navigator.of(context).pop(),
    );
  }
}
