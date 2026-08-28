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
    super.dispose();
  }

  /// Re-check when the user comes back from the OS Settings app.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        _permissionState == CameraPermissionState.permanentlyDenied) {
      _checkPermission();
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
      CameraPermissionState.granted => const _FieldOfViewFrame(),
      CameraPermissionState.denied => _PermissionDeniedView(
          onAllow: _requestPermission,
        ),
      CameraPermissionState.permanentlyDenied => const _PermissionBlockedView(),
    };
  }
}

// ═══════════════════════════════════════════════════════════════════════
//  Sub-widgets — one per permission state
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

/// Placeholder camera viewport (will be replaced with a live preview in A6).
class _FieldOfViewFrame extends StatelessWidget {
  const _FieldOfViewFrame();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: DesignTokens.surface,
        border: Border.all(
          color: DesignTokens.border,
          width: DesignTokens.borderWidth,
        ),
        borderRadius: BorderRadius.circular(DesignTokens.radiusMedium),
        boxShadow: const [
          BoxShadow(
            color: DesignTokens.shadow,
            blurRadius: DesignTokens.spacingMedium,
            offset: Offset(
              DesignTokens.spacingExtraSmall,
              DesignTokens.spacingSmall,
            ),
          ),
        ],
      ),
      child: const Center(
        child: Padding(
          padding: EdgeInsets.all(DesignTokens.spacingLarge),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.center_focus_strong,
                color: DesignTokens.primary,
                size: DesignTokens.iconLarge,
              ),
              SizedBox(height: DesignTokens.spacingMedium),
              Text(
                'Point at a banana and tap Scan.',
                textAlign: TextAlign.center,
              ),
              SizedBox(height: DesignTokens.spacingSmall),
              Text(
                'Camera view will appear here.',
                textAlign: TextAlign.center,
                style: TextStyle(color: DesignTokens.textSecondary),
              ),
            ],
          ),
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
