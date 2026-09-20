import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:banana_classifier/models/app_exception.dart';
import 'package:banana_classifier/widgets/error_view.dart';

void main() {
  Widget buildTestWidget({
    required AppException exception,
    VoidCallback? onRetry,
    String retryLabel = 'Try Again',
    String? secondaryLabel,
    VoidCallback? onSecondary,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: ErrorView(
          exception: exception,
          onRetry: onRetry ?? () {},
          retryLabel: retryLabel,
          secondaryLabel: secondaryLabel,
          onSecondary: onSecondary,
        ),
      ),
    );
  }

  group('ErrorView', () {
    testWidgets('displays user message and action hint', (tester) async {
      const exception = LowConfidenceException();

      await tester.pumpWidget(buildTestWidget(exception: exception));

      expect(find.text(exception.userMessage), findsOneWidget);
      expect(find.text(exception.actionHint), findsOneWidget);
    });

    testWidgets('displays the exception icon', (tester) async {
      const exception = AppCameraException();

      await tester.pumpWidget(buildTestWidget(exception: exception));

      expect(find.byIcon(exception.icon), findsOneWidget);
    });

    testWidgets('displays retry button with correct label', (tester) async {
      await tester.pumpWidget(buildTestWidget(
        exception: const UnknownException(),
        retryLabel: 'Try Again',
      ));

      expect(find.text('Try Again'), findsOneWidget);
      expect(find.byIcon(Icons.refresh_rounded), findsOneWidget);
    });

    testWidgets('retry button triggers onRetry callback', (tester) async {
      var retryCount = 0;

      await tester.pumpWidget(buildTestWidget(
        exception: const UnknownException(),
        onRetry: () => retryCount++,
      ));

      await tester.tap(find.text('Try Again'));
      await tester.pump();

      expect(retryCount, 1);
    });

    testWidgets('shows secondary action when provided', (tester) async {
      var secondaryTapped = false;

      await tester.pumpWidget(buildTestWidget(
        exception: const UnknownException(),
        secondaryLabel: 'Go back to camera',
        onSecondary: () => secondaryTapped = true,
      ));

      expect(find.text('Go back to camera'), findsOneWidget);

      await tester.tap(find.text('Go back to camera'));
      await tester.pump();

      expect(secondaryTapped, isTrue);
    });

    testWidgets('hides secondary action when not provided', (tester) async {
      await tester.pumpWidget(buildTestWidget(
        exception: const UnknownException(),
      ));

      expect(find.text('Go back to camera'), findsNothing);
    });

    testWidgets('custom retry label is used', (tester) async {
      await tester.pumpWidget(buildTestWidget(
        exception: const StorageException(),
        retryLabel: 'Reload',
      ));

      expect(find.text('Reload'), findsOneWidget);
      expect(find.text('Try Again'), findsNothing);
    });

    testWidgets('renders for every AppException subtype', (tester) async {
      // Ensure the widget can render every error type without crashing.
      const exceptions = <AppException>[
        LowConfidenceException(),
        ImageProcessingException(),
        AppCameraException(),
        StorageException(),
        NetworkException(),
        UnknownException(),
      ];

      for (final ex in exceptions) {
        await tester.pumpWidget(buildTestWidget(exception: ex));
        expect(find.text(ex.userMessage), findsOneWidget);
        expect(find.text(ex.actionHint), findsOneWidget);
      }
    });
  });
}
