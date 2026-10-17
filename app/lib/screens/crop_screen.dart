import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

import '../services/banana_detect.dart';
import '../services/inference_service.dart';
import '../services/upload_crop.dart';
import '../theme/design_tokens.dart';
import '../widgets/primary_button.dart';
import '../widgets/screen_header.dart';

/// Lets the user frame an uploaded photo before it is scanned.
///
/// Camera captures are cropped to the on-screen reticle, so the model always
/// sees a square with the banana filling it. Gallery uploads used to skip that
/// step and went in whole, which is why a banana sitting small on a busy table
/// came back as "Couldn't tell clearly" — the model reads a distant banana as
/// `NotBanana`.
///
/// The box here is the gallery's reticle. It is locked square to match the
/// model's input, but it can be moved and resized, because how much of a photo
/// a banana fills varies far more than it does through the viewfinder.
///
/// [detectSubjectBounds] positions the box on the banana to begin with, so for
/// most photos the user only has to confirm. When detection declines — roughly
/// one photo in three — the box starts centred and they place it themselves.
///
/// Pops with the cropped [File], or `null` if the user backs out.
class CropScreen extends StatefulWidget {
  const CropScreen({required this.photo, super.key});

  /// The photo the user picked from the gallery.
  final File photo;

  @override
  State<CropScreen> createState() => _CropScreenState();
}

class _CropScreenState extends State<CropScreen> {
  /// Decoded source photo — null until the first frame finishes loading it.
  img.Image? _decoded;

  /// `true` while the crop is being written, to block double-taps.
  bool _isCropping = false;

  /// The crop box in widget coordinates. Null until the photo is measured.
  Rect? _box;

  /// Where the photo is drawn inside [_viewportKey], from [fittedImageRect].
  Rect _imageRect = Rect.zero;

  /// The subject's bounds in photo pixels, or null when detection found
  /// nothing believable — the box then simply starts centred.
  Rect? _subject;

  /// Box and focal point when the current drag or pinch began.
  Rect? _gestureStartBox;
  Offset _gestureStartFocal = Offset.zero;

  final _viewportKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    img.Image? decoded;
    try {
      decoded = decodeUprightImage(await widget.photo.readAsBytes());
    } catch (_) {
      decoded = null;
    }

    if (!mounted) return;

    // Nothing to frame if it will not decode. Hand the photo on exactly as it
    // was picked: the analysing step reports the problem through the one error
    // path (§7.3), which beats stranding the user here with nothing to do.
    if (decoded == null) {
      Navigator.of(context).pop(widget.photo);
      return;
    }

    // Locate the banana so the box starts on it rather than in the middle of
    // the frame. Detection never blocks the screen: a null result is the
    // normal outcome for a busy background and just means the centred box.
    Rect? subject;
    try {
      subject = detectSubjectBounds(decoded);
    } catch (_) {
      subject = null;
    }

    if (!mounted) return;

    setState(() {
      _decoded = decoded;
      _subject = subject;
    });
  }

  /// Where the photo sits and where the box goes, for a viewport of
  /// [containerSize].
  ///
  /// Derived during layout rather than stored through a post-frame callback:
  /// the box is a function of the photo and the viewport, so computing it here
  /// means it is ready on the first frame the photo is visible, instead of one
  /// frame later with the confirm button inert in between.
  Rect _measure(Size containerSize) {
    final decoded = _decoded;
    if (decoded == null) return Rect.zero;

    _imageRect = fittedImageRect(
      containerSize: containerSize,
      imageWidth: decoded.width,
      imageHeight: decoded.height,
    );

    final box = _box;
    _box = box == null
        ? _startingBox(decoded)
        : clampCropBox(box: box, bounds: _imageRect);
    return _box!;
  }

  /// Where the box sits before the user touches it: on the detected subject
  /// when there is one, centred otherwise.
  Rect _startingBox(img.Image decoded) {
    final subject = _subject;
    if (subject == null) return initialCropBox(_imageRect);

    return cropBoxForSubject(
      subject: widgetRectForImageCrop(
        imageRect: _imageRect,
        crop: subject,
        imageWidth: decoded.width,
        imageHeight: decoded.height,
      ),
      imageRect: _imageRect,
    );
  }

  void _onScaleStart(ScaleStartDetails details) {
    _gestureStartBox = _box;
    _gestureStartFocal = details.focalPoint;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    final start = _gestureStartBox;
    if (start == null || _imageRect.isEmpty) return;

    // One gesture carries both: `scale` resizes, the focal point moves.
    final extent = start.width * details.scale;
    final moved = Rect.fromCenter(
      center: start.center + (details.focalPoint - _gestureStartFocal),
      width: extent,
      height: extent,
    );

    setState(() {
      _box = clampCropBox(box: moved, bounds: _imageRect);
    });
  }

  Future<void> _confirm() async {
    final decoded = _decoded;
    final box = _box;
    if (decoded == null || _isCropping) return;

    // The box is derived during layout. If the viewport has not been measured
    // yet there is nothing to crop to, so send the photo on as picked.
    if (box == null) {
      Navigator.of(context).pop(widget.photo);
      return;
    }

    setState(() => _isCropping = true);
    final navigator = Navigator.of(context);

    try {
      final crop = imageCropForBox(
        imageRect: _imageRect,
        box: box,
        imageWidth: decoded.width,
        imageHeight: decoded.height,
      );

      // No workable crop means scanning the photo as picked — a worse scan,
      // never a broken one, matching the camera path's fallback.
      if (crop == null) {
        navigator.pop(widget.photo);
        return;
      }

      final cropped = img.copyCrop(
        decoded,
        x: crop.left.round(),
        y: crop.top.round(),
        width: crop.width.round(),
        height: crop.height.round(),
      );

      final target = File('${widget.photo.path}.crop.jpg');
      await target.writeAsBytes(img.encodeJpg(cropped, quality: 95));

      if (kDebugMode) {
        debugPrint('\u{2702} crop: wrote ${cropped.width}x${cropped.height} '
            'to ${target.path}');
      }

      navigator.pop(target);
    } catch (e) {
      if (kDebugMode) debugPrint('\u{2702} crop: threw $e -> whole photo');
      navigator.pop(widget.photo);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DesignTokens.background,
      body: SafeArea(
        child: Column(
          children: [
            ScreenHeader(
              title: 'Frame the banana',
              onBack: () => Navigator.of(context).pop(),
              backTooltip: 'Cancel and pick another photo',
            ),
            Expanded(child: _buildViewport()),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildViewport() {
    final decoded = _decoded;
    if (decoded == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final box = _measure(constraints.biggest);

        return GestureDetector(
          onScaleStart: _onScaleStart,
          onScaleUpdate: _onScaleUpdate,
          child: Stack(
            key: _viewportKey,
            fit: StackFit.expand,
            children: [
              Image.file(widget.photo, fit: BoxFit.contain),
              CustomPaint(
                painter: _CropBoxPainter(box: box),
                size: constraints.biggest,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        DesignTokens.spacingMedium,
        DesignTokens.spacingMedium,
        DesignTokens.spacingMedium,
        DesignTokens.spacingLarge,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Check the box is on the banana. Drag it to move, pinch to make '
            'it bigger or smaller.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: DesignTokens.textSecondary,
                ),
          ),
          const SizedBox(height: DesignTokens.spacingMedium),
          PrimaryButton(
            icon: Icons.check,
            label: 'Use this photo',
            onPressed: _isCropping || _decoded == null ? null : _confirm,
          ),
        ],
      ),
    );
  }
}

/// Dims everything outside the box and draws the same corner brackets the
/// camera reticle uses, so both framing steps read as one idea.
class _CropBoxPainter extends CustomPainter {
  const _CropBoxPainter({required this.box});

  final Rect box;

  @override
  void paint(Canvas canvas, Size size) {
    final hole = RRect.fromRectAndRadius(
      box,
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
      ..color = DesignTokens.onCamera
      ..style = PaintingStyle.stroke
      ..strokeWidth = DesignTokens.bracketStroke
      ..strokeCap = StrokeCap.round;
    const arm = DesignTokens.bracketArm;
    const r = DesignTokens.radiusMedium;

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

    bracket(box.topLeft, 1, 1);
    bracket(box.topRight, -1, 1);
    bracket(box.bottomLeft, 1, -1);
    bracket(box.bottomRight, -1, -1);
  }

  @override
  bool shouldRepaint(_CropBoxPainter old) => old.box != box;
}
