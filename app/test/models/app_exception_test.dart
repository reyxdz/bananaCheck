import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:banana_classifier/models/app_exception.dart';

void main() {
  group('AppException sealed hierarchy', () {
    test('LowConfidenceException has correct user-facing fields', () {
      const ex = LowConfidenceException();
      expect(ex.userMessage, "Couldn't tell clearly");
      expect(ex.actionHint, contains('closer'));
      expect(ex.icon, Icons.visibility_off_rounded);
    });

    test('ImageProcessingException has correct user-facing fields', () {
      const ex = ImageProcessingException();
      expect(ex.userMessage, "Couldn't read the photo");
      expect(ex.actionHint, contains('another picture'));
      expect(ex.icon, Icons.broken_image_rounded);
    });

    test('AppCameraException has correct user-facing fields', () {
      const ex = AppCameraException();
      expect(ex.userMessage, "Camera isn't working right now");
      expect(ex.actionHint, contains('closing other apps'));
      expect(ex.icon, Icons.no_photography_rounded);
    });

    test('StorageException has correct user-facing fields', () {
      const ex = StorageException();
      expect(ex.userMessage, "Couldn't save your result");
      expect(ex.actionHint, contains('still analyzed'));
      expect(ex.icon, Icons.save_rounded);
    });

    test('NetworkException has correct user-facing fields', () {
      const ex = NetworkException();
      expect(ex.userMessage, 'No internet connection');
      expect(ex.actionHint, contains('connection'));
      expect(ex.icon, Icons.wifi_off_rounded);
    });

    test('UnknownException has correct user-facing fields', () {
      const ex = UnknownException();
      expect(ex.userMessage, 'Something went wrong');
      expect(ex.actionHint, 'Please try again.');
      expect(ex.icon, Icons.error_outline_rounded);
    });
  });

  group('AppException.from factory', () {
    test('returns same instance when given an AppException', () {
      const original = LowConfidenceException();
      final result = AppException.from(original);
      expect(result, same(original));
    });

    test('wraps non-AppException into UnknownException', () {
      final result = AppException.from(Exception('raw error'));
      expect(result, isA<UnknownException>());
    });

    test('wraps arbitrary Object into UnknownException', () {
      final result = AppException.from('string error');
      expect(result, isA<UnknownException>());
    });
  });

  group('AppException implements Exception', () {
    test('every subtype is an Exception', () {
      expect(const LowConfidenceException(), isA<Exception>());
      expect(const ImageProcessingException(), isA<Exception>());
      expect(const AppCameraException(), isA<Exception>());
      expect(const StorageException(), isA<Exception>());
      expect(const NetworkException(), isA<Exception>());
      expect(const UnknownException(), isA<Exception>());
    });
  });

  group('Exhaustive matching', () {
    test('switch covers all AppException subtypes', () {
      const exceptions = <AppException>[
        LowConfidenceException(),
        ImageProcessingException(),
        AppCameraException(),
        StorageException(),
        NetworkException(),
        UnknownException(),
      ];

      // Verifies that every subtype is matchable via sealed-class exhaustive
      // switch — this would fail to compile if a subtype were missing.
      for (final ex in exceptions) {
        final label = switch (ex) {
          LowConfidenceException() => 'low',
          ImageProcessingException() => 'image',
          AppCameraException() => 'camera',
          StorageException() => 'storage',
          NetworkException() => 'network',
          UnknownException() => 'unknown',
        };
        expect(label, isNotEmpty);
      }
    });
  });
}
