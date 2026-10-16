import 'dart:io';

import 'package:flutter/material.dart';

import '../models/banana_info_data.dart';
import '../models/classification_result.dart';
import '../theme/design_tokens.dart';
import 'confidence_indicator.dart';
import 'section_container.dart';
import 'dish_suggestions_card.dart';
import 'health_benefits_card.dart';
import 'result_headline.dart';

/// Displays the classification result in a rich, card-based layout per §7.2.
///
/// Shows the captured image (if provided) in its own frame above the card,
/// then the variety & ripeness,
/// headline (§7.3: large, clear text like "Lakatan — Ripe"), plain-language
/// confidence indicator, and vendor advice tips.
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

  String get _vendorRecommendation {
    switch (result.ripeness.toLowerCase()) {
      case 'unripe':
        return 'Store at room temperature. Best for market sale in 2 to 4 days.';
      case 'ripe':
        return 'Ready for immediate consumption or market display today!';
      case 'overripe':
        return 'Best used immediately for baking, smoothies, or processing.';
      default:
        return 'Inspect fruit quality regularly for optimal handling.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── The scanned photo, in its own square-cornered frame ──
        if (imagePath != null) ...[
          ScanPhoto(file: File(imagePath!)),
          const SizedBox(height: DesignTokens.spacingMedium),
        ],

        // ── The result details ──
        Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.all(DesignTokens.spacingLarge),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ── Variety and ripeness side by side, then the ripening scale ──
                    ResultHeadline(
                      variety: displayVarietyName(result.variety),
                      ripeness: result.ripeness,
                    ),

                    const SizedBox(height: DesignTokens.spacingLarge),

                    // ── Plain-language confidence (§7.3) ──
                    SectionContainer(
                      child: ConfidenceIndicator(confidence: result.confidence),
                    ),

                    const SizedBox(height: DesignTokens.spacingSmall + 4),

                    // ── Farmer/vendor handling advice ──
                    SectionContainer(
                      title: 'Handling tip',
                      icon: Icons.tips_and_updates_outlined,
                      iconColor: DesignTokens.warning,
                      background: DesignTokens.accentLight,
                      child: Text(
                        _vendorRecommendation,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ),

                    // ── Health Benefits & Dish Suggestions ──
                    _buildInfoCards(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Builds [HealthBenefitsCard] and [DishSuggestionsCard] from
  /// [bananaInfoMap]. Returns an empty [SizedBox] when the variety is not
  /// found so the layout degrades gracefully.
  Widget _buildInfoCards() {
    final info = bananaInfoFor(result.variety);
    if (info == null) return const SizedBox.shrink();

    final lowerRipeness = result.ripeness.toLowerCase();
    final ripenessInfo = info.byRipeness[lowerRipeness];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: DesignTokens.spacingSmall + 4),
        HealthBenefitsCard(info: info, ripeness: lowerRipeness),
        // Unripe dessert bananas have no dishes — they should ripen first
        // (the handling tip says so), so skip the card rather than show it
        // empty.
        if (ripenessInfo != null &&
            ripenessInfo.dishSuggestions.isNotEmpty) ...[
          const SizedBox(height: DesignTokens.spacingSmall + 4),
          DishSuggestionsCard(ripenessInfo: ripenessInfo),
        ],
      ],
    );
  }
}

/// Size of a photo with [aspectRatio] (width / height) shown as large as it
/// fits in [maxWidth] x [maxHeight], keeping its shape exactly.
@visibleForTesting
Size fitPhotoSize({
  required double aspectRatio,
  required double maxWidth,
  required double maxHeight,
}) {
  var width = maxWidth;
  var height = width / aspectRatio;
  if (height > maxHeight) {
    height = maxHeight;
    width = height * aspectRatio;
  }
  return Size(width, height);
}

/// The scanned photo in a plain, square-cornered frame that hugs it exactly:
/// as wide as the screen allows, never taller than
/// [DesignTokens.resultHeroMaxHeight], never cropped.
///
/// The frame is sized from the photo's real dimensions once it has decoded;
/// until then a neutral placeholder holds the space.
class ScanPhoto extends StatefulWidget {
  const ScanPhoto({required this.file, super.key});

  final File file;

  @override
  State<ScanPhoto> createState() => _ScanPhotoState();
}

class _ScanPhotoState extends State<ScanPhoto> {
  ImageStream? _stream;
  late final ImageStreamListener _listener = ImageStreamListener(
    (info, _) {
      final ratio = info.image.width / info.image.height;
      info.dispose();
      if (mounted && ratio.isFinite && ratio > 0) {
        setState(() => _aspectRatio = ratio);
      }
    },
    onError: (_, __) {
      if (mounted) setState(() => _failed = true);
    },
  );

  /// Width / height of the photo, once known.
  double? _aspectRatio;
  bool _failed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolve();
  }

  @override
  void didUpdateWidget(ScanPhoto oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.file.path != widget.file.path) {
      _aspectRatio = null;
      _failed = false;
      _resolve();
    }
  }

  void _resolve() {
    final stream = FileImage(widget.file).resolve(
      createLocalImageConfiguration(context),
    );
    if (stream.key == _stream?.key) return;
    _stream?.removeListener(_listener);
    _stream = stream..addListener(_listener);
  }

  @override
  void dispose() {
    _stream?.removeListener(_listener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final ratio = _aspectRatio;
        final size = ratio == null || _failed
            ? Size(constraints.maxWidth, DesignTokens.resultHeroMinHeight)
            : fitPhotoSize(
                aspectRatio: ratio,
                maxWidth: constraints.maxWidth,
                maxHeight: DesignTokens.resultHeroMaxHeight,
              );

        return Center(
          child: Container(
            key: const ValueKey('scan-photo-frame'),
            width: size.width,
            height: size.height,
            // Square corners on purpose: a plain photo frame.
            decoration: BoxDecoration(
              color: DesignTokens.surfaceMuted,
              border: Border.all(
                color: DesignTokens.border,
                width: DesignTokens.sectionBorderWidth,
              ),
            ),
            child: _failed
                ? const _PhotoUnavailable()
                : Image.file(
                    widget.file,
                    fit: BoxFit.contain,
                    semanticLabel: 'Your scanned banana',
                    errorBuilder: (_, __, ___) => const _PhotoUnavailable(),
                  ),
          ),
        );
      },
    );
  }
}

class _PhotoUnavailable extends StatelessWidget {
  const _PhotoUnavailable();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Icon(
        Icons.image_not_supported_outlined,
        color: DesignTokens.textSecondary,
        size: DesignTokens.iconLarge,
      ),
    );
  }
}
