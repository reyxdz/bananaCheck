import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/frame_quality.dart';
import '../theme/design_tokens.dart';

/// The one-line hint shown above the scan frame for a [ScanCondition].
///
/// Every hint has an icon as well as a colour, so colour is never the only
/// cue (§7.4).
class ScanHint {
  const ScanHint(this.icon, this.color, this.text);

  factory ScanHint.forCondition(
    ScanCondition condition, {
    required bool torchOn,
    required bool hasTorch,
  }) {
    return switch (condition) {
      ScanCondition.searching => const ScanHint(
          Icons.center_focus_weak_rounded,
          DesignTokens.onCamera,
          'Point at a banana',
        ),
      ScanCondition.ready => const ScanHint(
          Icons.check_circle_rounded,
          DesignTokens.scanDetected,
          'Looks good, tap Scan',
        ),
      // Fallback after searching for a while: never blocks Scan (§7.1).
      ScanCondition.notFound => const ScanHint(
          Icons.search_off_rounded,
          DesignTokens.scanWarning,
          "Can't find a banana? Move closer or upload a photo",
        ),
      // Only suggest the flash when it would actually help.
      ScanCondition.tooDark when hasTorch && !torchOn => const ScanHint(
          Icons.flash_on_rounded,
          DesignTokens.scanWarning,
          'Too dark, turn on flash',
        ),
      ScanCondition.tooDark => const ScanHint(
          Icons.wb_sunny_rounded,
          DesignTokens.scanWarning,
          'Too dark, move to brighter light',
        ),
    };
  }

  final IconData icon;
  final Color color;
  final String text;
}

/// Live-preview overlay: dims everything outside the scan frame, draws corner
/// brackets around it, and shows a single hint pill above it.
///
/// Brackets are white while searching, blue when a banana is in frame and
/// amber when the light is poor.
class ScanOverlay extends StatelessWidget {
  const ScanOverlay({
    required this.condition,
    required this.torchOn,
    required this.hasTorch,
    super.key,
  });

  final ScanCondition condition;
  final bool torchOn;
  final bool hasTorch;

  static const _colorDuration = Duration(milliseconds: 250);

  /// Scan frame for a preview of [size]: the reticle size from the tokens,
  /// shrunk to fit small previews, centred slightly below the middle so the
  /// hint pill has room above it.
  static Rect frameFor(Size size) {
    final width = math.min(DesignTokens.reticleWidth, size.width * 0.75);
    final height = math.min(DesignTokens.reticleHeight, size.height * 0.65);
    return Rect.fromCenter(
      center: Offset(size.width / 2, size.height * 0.54),
      width: width,
      height: height,
    );
  }

  @override
  Widget build(BuildContext context) {
    final hint = ScanHint.forCondition(
      condition,
      torchOn: torchOn,
      hasTorch: hasTorch,
    );
    final bracketColor = switch (condition) {
      ScanCondition.searching ||
      ScanCondition.notFound =>
        DesignTokens.onCamera,
      ScanCondition.ready => DesignTokens.scanDetected,
      ScanCondition.tooDark => DesignTokens.scanWarning,
    };

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        final frame = frameFor(size);

        return Stack(
          children: [
            Positioned.fill(
              child: TweenAnimationBuilder<Color?>(
                tween: ColorTween(end: bracketColor),
                duration: _colorDuration,
                builder: (context, color, _) => CustomPaint(
                  painter: _FramePainter(frame: frame, bracketColor: color!),
                ),
              ),
            ),
            Positioned(
              left: DesignTokens.spacingMedium,
              right: DesignTokens.spacingMedium,
              bottom: size.height - frame.top + DesignTokens.hintGap,
              child: Center(child: _HintPill(hint: hint)),
            ),
          ],
        );
      },
    );
  }
}

class _HintPill extends StatelessWidget {
  const _HintPill({required this.hint});

  final ScanHint hint;

  @override
  Widget build(BuildContext context) {
    // liveRegion: screen readers announce the hint whenever it changes.
    return Semantics(
      liveRegion: true,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: Container(
          key: ValueKey(hint.text),
          padding: const EdgeInsets.symmetric(
            horizontal: DesignTokens.spacingMedium,
            vertical: DesignTokens.spacingSmall,
          ),
          decoration: BoxDecoration(
            color: DesignTokens.cameraPill,
            borderRadius: BorderRadius.circular(DesignTokens.radiusLarge),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(hint.icon,
                  color: hint.color, size: DesignTokens.iconDefault),
              const SizedBox(width: DesignTokens.spacingSmall),
              Flexible(
                child: Text(
                  hint.text,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: DesignTokens.onCamera,
                    fontSize: DesignTokens.bodyTextSize,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Dims outside [frame] and draws four corner brackets on its edges.
class _FramePainter extends CustomPainter {
  const _FramePainter({required this.frame, required this.bracketColor});

  final Rect frame;
  final Color bracketColor;

  @override
  void paint(Canvas canvas, Size size) {
    final hole = RRect.fromRectAndRadius(
      frame,
      const Radius.circular(DesignTokens.radiusMedium),
    );
    canvas.drawPath(
      Path()
        ..fillType = PathFillType.evenOdd
        ..addRect(Offset.zero & size)
        ..addRRect(hole),
      Paint()..color = DesignTokens.cameraDim,
    );

    final paint = Paint()
      ..color = bracketColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = DesignTokens.bracketStroke
      ..strokeCap = StrokeCap.round;
    const arm = DesignTokens.bracketArm;
    const r = DesignTokens.radiusMedium;

    // Each bracket: straight arm, rounded corner, straight arm.
    void bracket(Offset corner, double dx, double dy) {
      canvas.drawPath(
        Path()
          ..moveTo(corner.dx, corner.dy + dy * arm)
          ..lineTo(corner.dx, corner.dy + dy * r)
          ..quadraticBezierTo(
            corner.dx,
            corner.dy,
            corner.dx + dx * r,
            corner.dy,
          )
          ..lineTo(corner.dx + dx * arm, corner.dy),
        paint,
      );
    }

    bracket(frame.topLeft, 1, 1);
    bracket(frame.topRight, -1, 1);
    bracket(frame.bottomLeft, 1, -1);
    bracket(frame.bottomRight, -1, -1);
  }

  @override
  bool shouldRepaint(_FramePainter old) =>
      old.frame != frame || old.bracketColor != bracketColor;
}
