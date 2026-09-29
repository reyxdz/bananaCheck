import 'package:banana_classifier/screens/onboarding_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pump(
    WidgetTester tester, {
    VoidCallback? onFinished,
    Size size = const Size(1080, 2400),
    double textScale = 1,
    double dpr = 3,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = dpr;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery.withClampedTextScaling(
          minScaleFactor: textScale,
          maxScaleFactor: textScale,
          child: OnboardingScreen(onFinished: onFinished ?? () {}),
        ),
      ),
    );
  }

  Future<void> tapAndSettle(WidgetTester tester, String label) async {
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  testWidgets('first page shows the welcome copy, Skip and Next',
      (tester) async {
    await pump(tester);
    expect(find.text('Know your bananas.'), findsOneWidget);
    expect(find.text('Skip'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);
    // Nothing to go back to on the first page.
    expect(find.text('Back'), findsNothing);
    expect(find.text('Get Started'), findsNothing);
  });

  testWidgets('swiping moves to the next page', (tester) async {
    await pump(tester);
    await tester.drag(find.byType(PageView), const Offset(-300, 0));
    await tester.pumpAndSettle();
    expect(find.text('3 easy steps'), findsOneWidget);
    expect(find.text('Take a photo'), findsOneWidget);
  });

  testWidgets('Next and Back step through all three pages', (tester) async {
    await pump(tester);
    await tapAndSettle(tester, 'Next');
    expect(find.text('3 easy steps'), findsOneWidget);
    expect(find.text('Back'), findsOneWidget);

    await tapAndSettle(tester, 'Next');
    expect(find.text('Smarter farming starts with a scan.'), findsOneWidget);
    expect(find.text('Get Started'), findsOneWidget);
    expect(find.text('Next'), findsNothing);
    // Skip stays available on every page (§7.7).
    expect(find.text('Skip'), findsOneWidget);

    await tapAndSettle(tester, 'Back');
    expect(find.text('3 easy steps'), findsOneWidget);
  });

  testWidgets('Skip calls onFinished', (tester) async {
    var finished = 0;
    await pump(tester, onFinished: () => finished++);
    await tester.tap(find.text('Skip'));
    expect(finished, 1);
  });

  testWidgets('Get Started on the last page calls onFinished', (tester) async {
    var finished = 0;
    await pump(tester, onFinished: () => finished++);
    await tapAndSettle(tester, 'Next');
    await tapAndSettle(tester, 'Next');
    await tester.tap(find.text('Get Started'));
    expect(finished, 1);
  });

  testWidgets('buttons pair an icon with a label and meet touch targets',
      (tester) async {
    await pump(tester);
    expect(find.byIcon(Icons.arrow_forward_rounded), findsOneWidget);
    final next = find.ancestor(
      of: find.text('Next'),
      matching: find.byType(FilledButton),
    );
    expect(tester.getSize(next).height, greaterThanOrEqualTo(48));
  });

  testWidgets('every page fits a small phone with large text', (tester) async {
    // 360 x 640 dp — a small budget Android phone.
    await pump(tester, size: const Size(720, 1280), dpr: 2, textScale: 1.3);
    for (var i = 0; i < 2; i++) {
      await tapAndSettle(tester, 'Next');
    }
    // Any RenderFlex overflow would have failed the test by now.
    expect(tester.takeException(), isNull);
    expect(find.text('Get Started'), findsOneWidget);
  });
}
