import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import '../services/frame_quality.dart';
import '../theme/design_tokens.dart';
import '../widgets/camera_controls.dart';
import '../widgets/primary_button.dart';
import '../widgets/scan_overlay.dart';

/// Camera permission status as seen by the screen UI.
///
/// Kept separate from the [PermissionStatus] enum so widget tests can drive
/// every branch without depending on platform channels.
enum CameraPermissionState {
  /// Initial state — still querying the OS.
  checking,

  /// Camera access was granted (either right now or previously).
  granted,

  /// The user tapped "Deny" (or similar). We can ask again.
  denied,

  /// The user denied with "Don't ask again" (Android) or the permission is
  /// restricted/permanently denied (iOS). We must direct them to Settings.
  permanentlyDenied,
}

/// Opens the device gallery and returns the chosen image, or `null` if the
/// user backed out without picking anything.
typedef GalleryPicker = Future<File?> Function();

/// Label for the gallery action.
const _uploadLabel = 'Upload a Photo';

/// Image types the model pipeline accepts from the gallery (§7.8).
const _supportedUploadExtensions = {'.jpg', '.jpeg', '.png'};

/// Largest gallery file we will try to analyze.
const _maxUploadBytes = 20 * 1024 * 1024;

/// Default [GalleryPicker] backed by the platform picker (`image_picker`).
///
/// Very large photos are scaled down on-device before we ever read them;
/// the model's own resize still happens in the inference preprocessing.
Future<File?> pickImageFromGallery() async {
  final picked = await ImagePicker().pickImage(
    source: ImageSource.gallery,
    maxWidth: 2048,
    maxHeight: 2048,
    imageQuality: 90,
  );
  return picked == null ? null : File(picked.path);
}

class CameraScreen extends StatefulWidget {
  const CameraScreen({
    required this.onScan,
    required this.onHistory,
    this.pickFromGallery = pickImageFromGallery,
    super.key,
  });

  /// Called with the image file when the user taps Scan or picks a photo
  /// with Upload a Photo — both feed the same analysis pipeline (§7.8).
  final ValueChanged<File> onScan;
  final VoidCallback onHistory;

  /// Injectable so widget tests can fake the platform gallery.
  final GalleryPicker pickFromGallery;

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with WidgetsBindingObserver {
  CameraPermissionState _permissionState = CameraPermissionState.checking;

  // ─────────────────────── camera controller ───────────────────────────
  CameraController? _cameraController;

  /// `true` while the camera is being set up (avoids duplicate init calls).
  bool _initialisingCamera = false;

  /// Non-null when camera initialisation fails — shown as a friendly message.
  String? _cameraError;

  // ─────────────────────── capture state ────────────────────────────────
  /// `true` while a photo capture is in progress — prevents double-taps.
  bool _isCapturing = false;

  /// `true` briefly during the shutter flash animation.
  bool _showShutterFlash = false;

  /// `true` while the gallery picker is open — prevents double-taps.
  bool _isPicking = false;

  // ─────────────────────── live hints & flash ──────────────────────────
  /// How often a preview frame is measured for the on-screen hint.
  static const _frameInterval = Duration(milliseconds: 300);

  final _conditionTracker = ScanConditionTracker();
  ScanCondition _condition = ScanCondition.searching;
  DateTime _lastFrameAt = DateTime.fromMillisecondsSinceEpoch(0);

  /// Torch (continuous flash) state. Reset whenever the camera restarts.
  bool _torchOn = false;

  /// Cleared once the camera refuses a flash mode (e.g. no flash unit).
  bool _hasTorch = true;

  // ───────────────────────────── lifecycle ──────────────────────────────

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermission();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _disposeCamera();
    super.dispose();
  }

  /// Re-check when the user comes back from the OS Settings app.
  /// Also handles camera lifecycle: pause → dispose, resume → re-init.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      // Release the camera so other apps (or the OS settings screen) can
      // use it.
      _disposeCamera();
    } else if (state == AppLifecycleState.resumed) {
      if (_permissionState == CameraPermissionState.permanentlyDenied ||
          _permissionState == CameraPermissionState.denied) {
        // The user may have just come back from OS Settings — re-query.
        _checkPermission();
      } else if (_permissionState == CameraPermissionState.granted) {
        // Re-open the camera after returning to the app.
        _initCamera();
      }
    }
  }

  // ──────────────────────── permission helpers ─────────────────────────

  Future<void> _checkPermission() async {
    setState(() => _permissionState = CameraPermissionState.checking);

    final status = await Permission.camera.status;
    _applyStatus(status);
  }

  Future<void> _requestPermission() async {
    setState(() => _permissionState = CameraPermissionState.checking);

    final status = await Permission.camera.request();
    _applyStatus(status);
  }

  void _applyStatus(PermissionStatus status) {
    if (!mounted) return;

    setState(() {
      if (status.isGranted || status.isLimited) {
        _permissionState = CameraPermissionState.granted;
      } else if (status.isPermanentlyDenied || status.isRestricted) {
        _permissionState = CameraPermissionState.permanentlyDenied;
      } else {
        // denied or undetermined — we can still ask
        _permissionState = CameraPermissionState.denied;
      }
    });

    // Kick off camera initialisation as soon as we know we have permission.
    if (_permissionState == CameraPermissionState.granted) {
      _initCamera();
    }
  }

  // ──────────────────────── camera helpers ──────────────────────────────

  Future<void> _initCamera() async {
    if (_initialisingCamera) return;
    _initialisingCamera = true;

    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (!mounted) return;
        setState(() {
          _cameraError = 'No camera found on this device.';
        });
        return;
      }

      // Prefer the back camera (index 0 is usually back).
      final selected = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      final controller = CameraController(
        selected,
        // Medium resolution balances quality and performance on low-end
        // devices common with our target users.
        ResolutionPreset.medium,
        enableAudio: false,
        // YUV lets the live hint read brightness/colour without decoding.
        imageFormatGroup: ImageFormatGroup.yuv420,
      );

      await controller.initialize();

      if (!mounted) {
        controller.dispose();
        return;
      }

      // Start with the flash off so it only fires when the user asks for it
      // (the plugin defaults to auto). A camera without a flash throws here.
      var hasTorch = true;
      try {
        await controller.setFlashMode(FlashMode.off);
      } catch (_) {
        hasTorch = false;
      }
      if (!mounted) {
        controller.dispose();
        return;
      }

      setState(() {
        _cameraController = controller;
        _cameraError = null;
        _hasTorch = hasTorch;
      });
      _startFrameAnalysis(controller);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cameraError = 'Could not start the camera. Please try again.';
      });
    } finally {
      _initialisingCamera = false;
    }
  }

  // ──────────────────────── capture logic ────────────────────────────────

  /// Takes a picture and passes the captured file to [widget.onScan].
  ///
  /// Per §7.1: one tap → capture → result appears automatically.
  /// No confirmation dialogs, no extra steps.
  Future<void> _capturePhoto() async {
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized || _isCapturing) {
      return;
    }

    setState(() => _isCapturing = true);

    try {
      // Pause the hint stream so it can't compete with the capture.
      await _stopFrameAnalysis(controller);

      // Brief shutter flash for tactile feedback.
      setState(() => _showShutterFlash = true);
      await Future<void>.delayed(const Duration(milliseconds: 120));
      if (mounted) setState(() => _showShutterFlash = false);

      final xFile = await controller.takePicture();
      final capturedFile = File(xFile.path);

      if (!mounted) return;

      // Hand off to the scan callback — result screen appears per §7.1.
      widget.onScan(capturedFile);
    } catch (e) {
      if (!mounted) return;
      // Plain-language error per §7.3.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not take the photo — please try again.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isCapturing = false);
        // Resume hints for when the user comes back to this screen.
        if (_cameraController == controller) _startFrameAnalysis(controller);
      }
    }
  }

  /// Toggles the torch so dark scenes can still be scanned.
  Future<void> _toggleFlash() async {
    final controller = _cameraController;
    if (controller == null) return;

    final turnOn = !_torchOn;
    try {
      await controller.setFlashMode(turnOn ? FlashMode.torch : FlashMode.off);
      if (!mounted) return;
      setState(() => _torchOn = turnOn);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _hasTorch = false;
        _torchOn = false;
      });
      _showMessage("This phone's flash can't be used — try brighter light.");
    }
  }

  // ──────────────────────── live frame hints ─────────────────────────────

  Future<void> _startFrameAnalysis(CameraController controller) async {
    if (controller.value.isStreamingImages) return;
    try {
      await controller.startImageStream(_onFrame);
    } catch (_) {
      // Some devices can't stream while previewing — the hint simply stays
      // on "Point at a banana" and scanning still works.
    }
  }

  Future<void> _stopFrameAnalysis(CameraController controller) async {
    if (!controller.value.isStreamingImages) return;
    try {
      await controller.stopImageStream();
    } catch (_) {
      // Already stopped.
    }
  }

  void _onFrame(CameraImage image) {
    final now = DateTime.now();
    if (now.difference(_lastFrameAt) < _frameInterval) return;
    _lastFrameAt = now;

    final stats = _statsFor(image);
    if (stats == null || !mounted) return;
    final condition = _conditionTracker.update(stats);
    if (condition != _condition) setState(() => _condition = condition);
  }

  /// Reads brightness and banana-colour coverage from a YUV preview frame.
  FrameStats? _statsFor(CameraImage image) {
    if (image.format.group != ImageFormatGroup.yuv420) return null;
    final planes = image.planes;

    try {
      if (planes.length >= 3) {
        // Android: separate Y, U and V planes (U/V may be interleaved).
        return analyzeYuvFrame(
          width: image.width,
          height: image.height,
          y: planes[0].bytes,
          yRowStride: planes[0].bytesPerRow,
          u: planes[1].bytes,
          v: planes[2].bytes,
          uvRowStride: planes[1].bytesPerRow,
          uvPixelStride: planes[1].bytesPerPixel ?? 1,
        );
      }
      if (planes.length == 2) {
        // iOS NV12: Y plane, then one interleaved CbCr plane.
        return analyzeYuvFrame(
          width: image.width,
          height: image.height,
          y: planes[0].bytes,
          yRowStride: planes[0].bytesPerRow,
          u: planes[1].bytes,
          v: planes[1].bytes,
          uvRowStride: planes[1].bytesPerRow,
          uvPixelStride: 2,
          vOffset: 1,
        );
      }
    } on RangeError {
      // Unexpected plane padding — skip this frame.
    }
    return null;
  }

  /// Lets the user pick an existing photo instead of taking one (§7.8).
  ///
  /// Cancelling the picker does nothing. Unsupported or oversized files get a
  /// plain-language message (§7.3); valid ones go to [widget.onScan] exactly
  /// like a camera capture.
  Future<void> _uploadPhoto() async {
    if (_isPicking || _isCapturing) return;
    setState(() => _isPicking = true);

    try {
      final file = await widget.pickFromGallery();
      if (!mounted || file == null) return;

      final name = file.path.toLowerCase();
      final supported = _supportedUploadExtensions.any(name.endsWith);
      if (!supported || await file.length() > _maxUploadBytes) {
        if (!mounted) return;
        _showMessage(
          "This photo can't be used. Please pick a clear JPG or PNG photo "
          'of a banana.',
        );
        return;
      }

      if (!mounted) return;
      widget.onScan(file);
    } catch (_) {
      if (!mounted) return;
      _showMessage('Could not open that photo — please try another one.');
    } finally {
      if (mounted) setState(() => _isPicking = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _disposeCamera() {
    _cameraController?.dispose();
    _cameraController = null;
    // A fresh camera starts with the torch off and no hint history.
    _torchOn = false;
    _conditionTracker.reset();
    _condition = ScanCondition.searching;
  }

  // ─────────────────────────── build ───────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cameraReady = _permissionState == CameraPermissionState.granted &&
        _cameraController != null &&
        _cameraController!.value.isInitialized;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // ── Enhanced top bar (Logo + Title + History) ──
            Padding(
              padding: const EdgeInsets.fromLTRB(
                DesignTokens.spacingLarge,
                DesignTokens.spacingMedium,
                DesignTokens.spacingLarge,
                DesignTokens.spacingSmall,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Logo + App Name
                  Row(
                    children: [
                      ClipRRect(
                        borderRadius:
                            BorderRadius.circular(DesignTokens.radiusSmall),
                        child: Image.asset(
                          'assets/images/logo.png',
                          width: DesignTokens.logoSmall,
                          height: DesignTokens.logoSmall,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(
                            Icons.center_focus_strong,
                            color: DesignTokens.primary,
                            size: DesignTokens.logoSmall,
                          ),
                        ),
                      ),
                      const SizedBox(width: DesignTokens.spacingSmall),
                      Text(
                        'Bananalyze',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: DesignTokens.primaryDark,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.5,
                            ),
                      ),
                    ],
                  ),
                  // Quiet History button — icon-only so it doesn't compete
                  // with Scan; the tooltip doubles as the
                  // screen-reader label.
                  IconButton(
                    onPressed: widget.onHistory,
                    tooltip: 'History',
                    iconSize: DesignTokens.iconMedium,
                    color: DesignTokens.textSecondary,
                    constraints: const BoxConstraints(
                      minWidth: DesignTokens.minimumTouchTarget,
                      minHeight: DesignTokens.minimumTouchTarget,
                    ),
                    icon: const Icon(Icons.history_rounded),
                  ),
                ],
              ),
            ),
            const SizedBox(height: DesignTokens.spacingSmall),

            // ── main area — depends on permission state ──
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: DesignTokens.spacingLarge,
                ),
                child: _buildBody(),
              ),
            ),

            const SizedBox(height: DesignTokens.spacingMedium),

            // ── bottom actions, in the thumb zone ──
            ..._buildActions(cameraReady),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    return switch (_permissionState) {
      CameraPermissionState.checking => const _CheckingIndicator(),
      CameraPermissionState.granted => _buildCameraArea(),
      CameraPermissionState.denied => const _PermissionDeniedView(),
      CameraPermissionState.permanentlyDenied => const _PermissionBlockedView(),
    };
  }

  /// With camera access: gallery · shutter · flash. Without it: a filled
  /// primary action (fix the camera) with an outlined "Upload a Photo" right
  /// below it — upload works either way per §7.8.
  List<Widget> _buildActions(bool cameraReady) {
    final onUpload = _isPicking || _isCapturing ? null : _uploadPhoto;

    return switch (_permissionState) {
      CameraPermissionState.checking => const [],
      // Shutter stays the single primary action (§7.1/§7.4); gallery still
      // works when the camera itself fails to start.
      CameraPermissionState.granted => [
          Padding(
            padding: const EdgeInsets.only(bottom: DesignTokens.spacingLarge),
            child: CameraControls(
              onGallery: onUpload,
              onShutter: cameraReady ? _capturePhoto : null,
              onFlash: cameraReady && _hasTorch && !_isCapturing
                  ? _toggleFlash
                  : null,
              flashOn: _torchOn,
              isCapturing: _isCapturing,
              shutterDimmed: _condition == ScanCondition.tooDark,
            ),
          ),
        ],
      CameraPermissionState.denied => [
          _PermissionActions(
            primaryIcon: Icons.camera_alt,
            primaryLabel: 'Allow Camera',
            onPrimary: _requestPermission,
            onUpload: onUpload,
          ),
        ],
      CameraPermissionState.permanentlyDenied => [
          _PermissionActions(
            primaryIcon: Icons.settings,
            primaryLabel: 'Open Settings',
            onPrimary: openAppSettings,
            onUpload: onUpload,
          ),
        ],
    };
  }

  /// Builds the camera preview area or a friendly error/loading state.
  Widget _buildCameraArea() {
    // Camera error — show a plain-language message with retry.
    if (_cameraError != null) {
      return _CameraErrorView(
        message: _cameraError!,
        onRetry: _initCamera,
      );
    }

    // Controller not ready yet — show a loading indicator.
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) {
      return const _CheckingIndicator();
    }

    // Live preview with scan frame, live hint + optional shutter flash.
    return _LivePreview(
      controller: controller,
      showShutterFlash: _showShutterFlash,
      overlay: ScanOverlay(
        condition: _condition,
        torchOn: _torchOn,
        hasTorch: _hasTorch,
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
//  Sub-widgets
// ═══════════════════════════════════════════════════════════════════════

/// Shown briefly while querying the OS for the current permission status.
class _CheckingIndicator extends StatelessWidget {
  const _CheckingIndicator();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(
        color: DesignTokens.primary,
      ),
    );
  }
}

/// Live camera preview with the scan overlay and shutter flash on top.
class _LivePreview extends StatelessWidget {
  const _LivePreview({
    required this.controller,
    required this.overlay,
    this.showShutterFlash = false,
  });

  final CameraController controller;
  final Widget overlay;
  final bool showShutterFlash;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(DesignTokens.radiusMedium),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Camera feed — fill the entire container, cropping any overflow
          // so there are no black bars.
          SizedBox.expand(
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: controller.value.previewSize!.height,
                height: controller.value.previewSize!.width,
                child: CameraPreview(controller),
              ),
            ),
          ),

          overlay,

          // Shutter flash — white overlay that appears briefly on capture.
          if (showShutterFlash)
            const Positioned.fill(
              child: ColoredBox(color: Colors.white70),
            ),
        ],
      ),
    );
  }
}

/// Bottom action pair shown when the camera can't be used: a full-width
/// filled primary button with an outlined upload button directly below.
class _PermissionActions extends StatelessWidget {
  const _PermissionActions({
    required this.primaryIcon,
    required this.primaryLabel,
    required this.onPrimary,
    required this.onUpload,
  });

  final IconData primaryIcon;
  final String primaryLabel;
  final VoidCallback onPrimary;
  final VoidCallback? onUpload;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        DesignTokens.spacingLarge,
        0,
        DesignTokens.spacingLarge,
        DesignTokens.spacingLarge,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            height: DesignTokens.primaryActionSize,
            child: PrimaryButton(
              icon: primaryIcon,
              label: primaryLabel,
              onPressed: onPrimary,
            ),
          ),
          const SizedBox(height: DesignTokens.spacingSmall),
          SizedBox(
            width: double.infinity,
            height: DesignTokens.secondaryActionSize,
            child: OutlinedButton.icon(
              onPressed: onUpload,
              style: OutlinedButton.styleFrom(
                foregroundColor: DesignTokens.primaryDark,
                side: const BorderSide(
                  color: DesignTokens.primary,
                  width: DesignTokens.borderWidth,
                ),
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(
                    Radius.circular(DesignTokens.radiusMedium),
                  ),
                ),
                textStyle: const TextStyle(
                  fontSize: DesignTokens.bodyTextSize,
                  fontWeight: FontWeight.w700,
                ),
              ),
              icon: const Icon(
                Icons.photo_library_outlined,
                size: DesignTokens.iconAppBar,
              ),
              label: const Text(_uploadLabel),
            ),
          ),
        ],
      ),
    );
  }
}

/// Shown when the camera could not be initialised.
class _CameraErrorView extends StatelessWidget {
  const _CameraErrorView({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

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
            const Icon(
              Icons.error_outline,
              color: DesignTokens.textSecondary,
              size: DesignTokens.iconLarge,
            ),
            const SizedBox(height: DesignTokens.spacingLarge),
            Text(
              message,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: DesignTokens.spacingExtraLarge),
            SizedBox(
              width: double.infinity,
              height: DesignTokens.primaryActionSize,
              child: PrimaryButton(
                icon: Icons.refresh,
                label: 'Try Again',
                onPressed: onRetry,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shown when the user tapped "Deny" but can still be asked again.
class _PermissionDeniedView extends StatelessWidget {
  const _PermissionDeniedView();

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
            // Mascot — shifted down so it overlaps the text card below.
            Transform.translate(
              offset: const Offset(0, 24),
              child: SizedBox(
                width: 200,
                height: 200,
                child: Image.asset(
                  'assets/images/banana_mascot.gif',
                  fit: BoxFit.contain,
                ),
              ),
            ),
            // Text + button card that the mascot "sits on"
            Text(
              'Camera access needed',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: DesignTokens.spacingSmall),
            const Text(
              'To analyze your bananas, Bananalyze needs to use your camera.\n'
              'Tap the button below to allow access.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Shown when the permission is permanently denied / restricted.
/// Directs the user to the OS Settings app.
class _PermissionBlockedView extends StatelessWidget {
  const _PermissionBlockedView();

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
            const Icon(
              Icons.no_photography_outlined,
              color: DesignTokens.textSecondary,
              size: DesignTokens.iconLarge,
            ),
            const SizedBox(height: DesignTokens.spacingLarge),
            Text(
              'Camera is turned off',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: DesignTokens.spacingSmall),
            const Text(
              'You previously turned off camera access.\n'
              'Open your phone\'s Settings and turn it back on '
              'so Bananalyze can inspect your bananas.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
