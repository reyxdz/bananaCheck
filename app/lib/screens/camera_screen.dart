import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../theme/design_tokens.dart';
import '../widgets/primary_button.dart';

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

class CameraScreen extends StatefulWidget {
  const CameraScreen({
    required this.onScan,
    required this.onHistory,
    super.key,
  });

  final VoidCallback onScan;
  final VoidCallback onHistory;

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
      );

      await controller.initialize();

      if (!mounted) {
        controller.dispose();
        return;
      }

      setState(() {
        _cameraController = controller;
        _cameraError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cameraError = 'Could not start the camera. Please try again.';
      });
    } finally {
      _initialisingCamera = false;
    }
  }

  void _disposeCamera() {
    _cameraController?.dispose();
    _cameraController = null;
  }

  // ─────────────────────────── build ───────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(DesignTokens.spacingLarge),
          child: Column(
            children: [
              // ── top bar (title + history) ──
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Banana Check',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  TextButton.icon(
                    onPressed: widget.onHistory,
                    icon: const Icon(Icons.history),
                    label: const Text('History'),
                  ),
                ],
              ),
              const SizedBox(height: DesignTokens.spacingMedium),

              // ── main area — depends on permission state ──
              Expanded(child: _buildBody()),

              const SizedBox(height: DesignTokens.spacingLarge),

              // ── scan button (only when camera is ready) ──
              if (_permissionState == CameraPermissionState.granted)
                SizedBox(
                  width: double.infinity,
                  height: DesignTokens.primaryActionSize,
                  child: PrimaryButton(
                    icon: Icons.camera_alt,
                    label: 'Scan',
                    onPressed: widget.onScan,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    return switch (_permissionState) {
      CameraPermissionState.checking => const _CheckingIndicator(),
      CameraPermissionState.granted => _buildCameraArea(),
      CameraPermissionState.denied => _PermissionDeniedView(
          onAllow: _requestPermission,
        ),
      CameraPermissionState.permanentlyDenied => const _PermissionBlockedView(),
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

    // Live preview with hint overlay.
    return _LivePreview(controller: controller);
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
      child: CircularProgressIndicator(),
    );
  }
}

/// Live camera preview with a translucent hint overlay.
class _LivePreview extends StatelessWidget {
  const _LivePreview({required this.controller});

  final CameraController controller;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(DesignTokens.radiusMedium),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Camera feed — fill the available space while keeping the native
          // aspect ratio (letterboxed with black bars via ColoredBox).
          ColoredBox(
            color: Colors.black,
            child: Center(
              child: AspectRatio(
                aspectRatio: controller.value.aspectRatio,
                child: CameraPreview(controller),
              ),
            ),
          ),

          // Hint overlay at the bottom — sits on top of the live feed.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black54],
                ),
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: DesignTokens.spacingLarge,
                vertical: DesignTokens.spacingMedium,
              ),
              child: const Text(
                'Point at a banana and tap Scan.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: DesignTokens.bodyTextSize,
                  fontWeight: FontWeight.w500,
                ),
              ),
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
  const _PermissionDeniedView({required this.onAllow});

  final VoidCallback onAllow;

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
              Icons.camera_alt_outlined,
              color: DesignTokens.textSecondary,
              size: DesignTokens.iconLarge,
            ),
            const SizedBox(height: DesignTokens.spacingLarge),
            Text(
              'Camera access needed',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: DesignTokens.spacingSmall),
            const Text(
              'To check your bananas, the app needs to use your camera.\n'
              'Tap the button below to allow access.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: DesignTokens.spacingExtraLarge),
            SizedBox(
              width: double.infinity,
              height: DesignTokens.primaryActionSize,
              child: PrimaryButton(
                icon: Icons.camera_alt,
                label: 'Allow Camera',
                onPressed: onAllow,
              ),
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
              'so the app can check your bananas.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: DesignTokens.spacingExtraLarge),
            const SizedBox(
              width: double.infinity,
              height: DesignTokens.primaryActionSize,
              child: PrimaryButton(
                icon: Icons.settings,
                label: 'Open Settings',
                onPressed: openAppSettings,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
