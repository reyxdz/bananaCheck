import 'dart:io';

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

/// Minimum gap between the best and second-best class required to trust a
/// result.
///
/// Softmax always sums to 1, so a photo unlike anything in training can still
/// produce a high top probability. A narrow gap to the runner-up is the
/// clearer signal that the model is guessing.
///
/// Set from the margin distribution measured on the held-out test set: real
/// bananas clear this easily (median margin 0.996, 1st percentile 0.121), so
/// the gate costs 0.6% of correct scans. It is a safety net rather than the
/// main defence — the NotBanana class already rejects 100% of the negatives.
const double _lowMarginThreshold = 0.10;

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
    this.minimumDisplayDuration = defaultMinimumDisplayDuration,
    super.key,
  });

  /// How long the analyzing screen stays up at minimum.
  static const defaultMinimumDisplayDuration = Duration(milliseconds: 1500);

  final InferenceService inferenceService;
  final StorageService storageService;
  final File capturedFile;

  /// Called when classification and storage succeed. Receives the
  /// [ClassificationResult] and the image path so the caller can navigate
  /// to the results screen.
  final void Function(ClassificationResult result, String imagePath) onComplete;

  /// Shortest time the "Analyzing…" state is shown, so a fast scan doesn't
  /// flash past and look broken. It runs *alongside* the analysis — a scan
  /// that already takes longer is never slowed down. Tests pass
  /// [Duration.zero].
  final Duration minimumDisplayDuration;

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

    // Start the minimum-display clock together with the analysis.
    final minimumWait = widget.minimumDisplayDuration == Duration.zero
        ? Future<void>.value()
        : Future<void>.delayed(widget.minimumDisplayDuration);

    try {
      // 1. Run inference — and wait for the minimum display time too, so both
      //    a result and an error appear no sooner than that.
      final ClassificationResult result;
      try {
        final classifying =
            widget.inferenceService.classify(widget.capturedFile);
        await Future.wait<void>([classifying, minimumWait]);
        result = await classifying;
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

      // 2. Unreliable-result gate — treat as an error per §7.3.
      //
      // Three ways a scan is not worth showing, all of which mean the same
      // thing to the user ("Couldn't tell clearly"), so they share one path:
      //   - the model is unsure,
      //   - it is torn between two classes, or
      //   - it says the photo is not a banana at all.
      if (result.confidence < _lowConfidenceThreshold ||
          result.margin < _lowMarginThreshold ||
          !result.isBanana) {
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
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(DesignTokens.spacingLarge),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // The photo being analyzed, with a gentle scanning sweep.
            _ScanningPhoto(file: widget.capturedFile),

            const SizedBox(height: DesignTokens.spacingExtraLarge),

            // Primary message — plain language per §7.3.
            Text(
              'Analyzing your banana…',
              textAlign: TextAlign.center,
              style: textTheme.headlineSmall,
            ),

            const SizedBox(height: DesignTokens.spacingSmall),

            // Secondary message.
            Text(
              'This will only take a moment',
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium,
            ),

            const SizedBox(height: DesignTokens.spacingLarge),

            // Indeterminate — no fake percentages or stages.
            SizedBox(
              width: DesignTokens.analyzingPhotoSize * 0.7,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(DesignTokens.radiusPill),
                child: const LinearProgressIndicator(
                  minHeight: DesignTokens.spacingSmall - 2,
                  semanticsLabel: 'Analyzing your banana',
                ),
              ),
            ),
          ],
        ),
      ),
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

/// The captured photo in a rounded frame with a soft light band sweeping
/// over it while the scan runs. Static when the OS asks to reduce motion.
class _ScanningPhoto extends StatefulWidget {
  const _ScanningPhoto({required this.file});

  final File file;

  @override
  State<_ScanningPhoto> createState() => _ScanningPhotoState();
}

class _ScanningPhotoState extends State<_ScanningPhoto>
    with SingleTickerProviderStateMixin {
  late final AnimationController _sweep = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (reduceMotion) {
      _sweep.stop();
    } else if (!_sweep.isAnimating) {
      _sweep.repeat();
    }
  }

  @override
  void dispose() {
    _sweep.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const size = DesignTokens.analyzingPhotoSize;
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: DesignTokens.surfaceMuted,
        borderRadius: BorderRadius.circular(DesignTokens.radiusLarge),
        boxShadow: DesignTokens.softShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.file(
            widget.file,
            fit: BoxFit.cover,
            excludeFromSemantics: true,
            errorBuilder: (_, __, ___) => const Center(
              child: Icon(
                Icons.eco_rounded,
                color: DesignTokens.primary,
                size: DesignTokens.iconLarge,
              ),
            ),
          ),
          if (!reduceMotion)
            AnimatedBuilder(
              animation: _sweep,
              builder: (context, _) {
                const band = size * 0.35;
                final top = -band + (size + band) * _sweep.value;
                return Positioned(
                  left: 0,
                  right: 0,
                  top: top,
                  height: band,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          DesignTokens.accent.withOpacity(0),
                          DesignTokens.accent.withOpacity(0.35),
                          DesignTokens.accent.withOpacity(0),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
