import 'package:flutter/material.dart';

/// User-facing error categories with plain-language messages per §7.3.
///
/// Every error the app shows to the user must go through this hierarchy so
/// that raw technical details are never exposed. Each subclass provides:
/// - [userMessage] — a short, friendly headline ("Couldn't tell clearly")
/// - [actionHint] — what the user should do next
/// - [icon] — an icon for the error UI
sealed class AppException implements Exception {
  const AppException();

  /// Classify a raw exception into the appropriate [AppException] subtype.
  ///
  /// Use this in catch blocks instead of showing raw error strings.
  factory AppException.from(Object error) {
    if (error is AppException) return error;
    return const UnknownException();
  }

  /// Short, plain-language headline shown to the user.
  String get userMessage;

  /// Actionable advice for the user.
  String get actionHint;

  /// Icon displayed alongside the error.
  IconData get icon;
}

/// The model couldn't identify the banana clearly enough.
class LowConfidenceException extends AppException {
  const LowConfidenceException();

  @override
  String get userMessage => "Couldn't tell clearly";

  @override
  String get actionHint =>
      'Try moving closer to the banana or find better lighting.';

  @override
  IconData get icon => Icons.visibility_off_rounded;
}

/// The captured image couldn't be read or decoded.
class ImageProcessingException extends AppException {
  const ImageProcessingException();

  @override
  String get userMessage => "Couldn't read the photo";

  @override
  String get actionHint => 'Try taking another picture.';

  @override
  IconData get icon => Icons.broken_image_rounded;
}

/// The camera failed to initialise or capture.
///
/// Named `AppCameraException` to avoid collision with the `camera` package's
/// `CameraException`.
class AppCameraException extends AppException {
  const AppCameraException();

  @override
  String get userMessage => "Camera isn't working right now";

  @override
  String get actionHint =>
      'Try closing other apps that might be using the camera.';

  @override
  IconData get icon => Icons.no_photography_rounded;
}

/// Local storage read/write failure.
class StorageException extends AppException {
  const StorageException();

  @override
  String get userMessage => "Couldn't save your result";

  @override
  String get actionHint =>
      'Your scan was still analyzed — try again to save it.';

  @override
  IconData get icon => Icons.save_rounded;
}

/// Network connectivity issues (future-proofing for model downloads).
class NetworkException extends AppException {
  const NetworkException();

  @override
  String get userMessage => 'No internet connection';

  @override
  String get actionHint => 'Check your connection and try again.';

  @override
  IconData get icon => Icons.wifi_off_rounded;
}

/// Catch-all fallback for unclassified errors.
class UnknownException extends AppException {
  const UnknownException();

  @override
  String get userMessage => 'Something went wrong';

  @override
  String get actionHint => 'Please try again.';

  @override
  IconData get icon => Icons.error_outline_rounded;
}
