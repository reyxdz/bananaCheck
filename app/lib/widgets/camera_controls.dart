import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';

/// Standard camera control row: gallery on the left, shutter in the centre,
/// flash on the right.
///
/// The side buttons are icon-only with tooltips; the tooltip text doubles as
/// the screen-reader label, and the shutter is announced as "Scan".
class CameraControls extends StatelessWidget {
  const CameraControls({
    required this.onGallery,
    required this.onShutter,
    required this.onFlash,
    required this.flashOn,
    this.isCapturing = false,
    this.shutterDimmed = false,
    this.highlightGallery = false,
    super.key,
  });

  /// Opens the gallery (§7.8). Null while the picker or a capture is busy.
  final VoidCallback? onGallery;

  /// Takes the photo. Null while the camera is not ready.
  final VoidCallback? onShutter;

  /// Toggles the torch. Null when the camera is not ready or has no flash.
  final VoidCallback? onFlash;

  final bool flashOn;
  final bool isCapturing;

  /// Fades the shutter when conditions are poor (e.g. too dark) to
  /// discourage a bad scan. It still works if tapped.
  final bool shutterDimmed;

  /// Draws attention to the gallery button — used when no banana has been
  /// found for a while, as uploading a photo is the fallback.
  final bool highlightGallery;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Center(
            child: _SideButton(
              tooltip: 'Upload a Photo',
              icon: Icons.photo_library_outlined,
              onPressed: onGallery,
              highlighted: highlightGallery,
            ),
          ),
        ),
        ShutterButton(
          onPressed: onShutter,
          isCapturing: isCapturing,
          dimmed: shutterDimmed,
        ),
        Expanded(
          child: Center(
            child: _SideButton(
              tooltip: flashOn ? 'Turn flash off' : 'Turn flash on',
              icon: flashOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
              onPressed: onFlash,
              selected: flashOn,
            ),
          ),
        ),
      ],
    );
  }
}

/// The large, circular capture button — the single primary action on the
/// camera screen per §7.1.
///
/// 80dp outer diameter (exceeds the 64dp minimum from §7.4), primary-green
/// fill with a white camera icon.
class ShutterButton extends StatelessWidget {
  const ShutterButton({
    required this.onPressed,
    this.isCapturing = false,
    this.dimmed = false,
    super.key,
  });

  final VoidCallback? onPressed;
  final bool isCapturing;
  final bool dimmed;

  /// Diameter of the outer ring — exceeds §7.4 minimum of 64dp.
  static const double outerSize = 80;

  /// Diameter of the filled inner circle.
  static const double _innerSize = 68;

  @override
  Widget build(BuildContext context) {
    final faded = dimmed || onPressed == null;

    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: 'Scan',
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: faded ? DesignTokens.shutterDimmedOpacity : 1,
        child: GestureDetector(
          onTap: onPressed,
          child: SizedBox(
            width: outerSize,
            height: outerSize,
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: DesignTokens.primary, width: 3),
              ),
              child: Center(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 100),
                  width: isCapturing ? _innerSize - 8 : _innerSize,
                  height: isCapturing ? _innerSize - 8 : _innerSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isCapturing
                        ? DesignTokens.primaryDark
                        : DesignTokens.primary,
                    boxShadow: const [
                      BoxShadow(
                        color: DesignTokens.shadow,
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: isCapturing
                      ? const Padding(
                          padding: EdgeInsets.all(18),
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            color: DesignTokens.onCamera,
                          ),
                        )
                      : const Icon(
                          Icons.camera_alt_rounded,
                          color: DesignTokens.onCamera,
                          size: DesignTokens.iconMedium,
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 56dp round outlined icon button used for gallery and flash.
class _SideButton extends StatelessWidget {
  const _SideButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.selected = false,
    this.highlighted = false,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool selected;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      isSelected: selected,
      iconSize: DesignTokens.iconMedium,
      icon: Icon(icon),
      style: IconButton.styleFrom(
        fixedSize: const Size.square(DesignTokens.secondaryActionSize),
        foregroundColor: DesignTokens.primaryDark,
        backgroundColor: selected
            ? DesignTokens.accent
            : highlighted
                ? DesignTokens.primaryLight
                : DesignTokens.surface,
        disabledForegroundColor: DesignTokens.border,
        disabledBackgroundColor: DesignTokens.surface,
        side: BorderSide(
          color: onPressed == null ? DesignTokens.border : DesignTokens.primary,
          width: highlighted && onPressed != null
              ? DesignTokens.highlightBorderWidth
              : DesignTokens.borderWidth,
        ),
      ),
    );
  }
}
