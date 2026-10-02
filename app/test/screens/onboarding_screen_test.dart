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

  testWidgets('Skip is on every page and works from the last one',
      (tester) async {
    var finished = 0;
    await pump(tester, onFinished: () => finished++);
    for (var i = 0; i < 2; i++) {
      expect(find.text('Skip'), findsOneWidget);
      await tapAndSettle(tester, 'Next');
    }
    expect(find.text('Skip'), findsOneWidget);

    await tester.tap(find.text('Skip'));
    expect(finished, 1);
  });

  testWidgets('swiping right goes back a page', (tester) async {
    await pump(tester);
    await tapAndSettle(tester, 'Next');
    expect(find.text('3 easy steps'), findsOneWidget);

    await tester.drag(find.byType(PageView), const Offset(300, 0));
    await tester.pumpAndSettle();
    expect(find.text('Know your bananas.'), findsOneWidget);
  });

  testWidgets('swiping past the last page stays put and does not finish',
      (tester) async {
    var finished = 0;
    await pump(tester, onFinished: () => finished++);
    await tapAndSettle(tester, 'Next');
    await tapAndSettle(tester, 'Next');

    await tester.drag(find.byType(PageView), const Offset(-300, 0));
    await tester.pumpAndSettle();

    expect(find.text('Get Started'), findsOneWidget);
    expect(finished, 0);
  });

  testWidgets('dot indicator announces the current page', (tester) async {
    await pump(tester);
    expect(find.bySemanticsLabel('Page 1 of 3'), findsOneWidget);

    await tapAndSettle(tester, 'Next');
    expect(find.bySemanticsLabel('Page 2 of 3'), findsOneWidget);

    await tapAndSettle(tester, 'Next');
    expect(find.bySemanticsLabel('Page 3 of 3'), findsOneWidget);
  });

  testWidgets('each page shows its own image asset', (tester) async {
    bool showsAsset(String name) => find
        .byWidgetPredicate(
          (w) =>
              w is Image &&
              w.image is AssetImage &&
              (w.image as AssetImage).assetName == 'assets/images/$name',
        )
        .evaluate()
        .isNotEmpty;

    await pump(tester);
    expect(showsAsset('page1.png'), isTrue);

    await tapAndSettle(tester, 'Next');
    expect(showsAsset('page2.png'), isTrue);

    await tapAndSettle(tester, 'Next');
    expect(showsAsset('page3.png'), isTrue);
  });

  testWidgets('copy stays jargon-free on every page (§7.3)', (tester) async {
    const banned = ['confidence', 'inference', 'probability', 'classif'];
    await pump(tester);
    for (var page = 0; page < 3; page++) {
      for (final text in tester.widgetList<Text>(find.byType(Text))) {
        final value = (text.data ?? '').toLowerCase();
        for (final word in banned) {
          expect(value.contains(word), isFalse, reason: '"$value" has $word');
        }
      }
      if (page < 2) await tapAndSettle(tester, 'Next');
    }
  });
}
