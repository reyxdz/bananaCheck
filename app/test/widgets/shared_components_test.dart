import 'package:banana_classifier/theme/app_theme.dart';
import 'package:banana_classifier/theme/design_tokens.dart';
import 'package:banana_classifier/widgets/empty_state.dart';
import 'package:banana_classifier/widgets/reveal.dart';
import 'package:banana_classifier/widgets/screen_header.dart';
import 'package:banana_classifier/widgets/secondary_button.dart';
import 'package:banana_classifier/widgets/section_container.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget child, {bool reduceMotion = false}) => MaterialApp(
      theme: AppTheme.light,
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduceMotion),
        child: Scaffold(body: child),
      ),
    );

void main() {
  group('ScreenHeader', () {
    testWidgets('brand variant shows the Bananalyze wordmark and actions',
        (tester) async {
      await tester.pumpWidget(_app(
        ScreenHeader.brand(
          actions: [
            IconButton(
              onPressed: () {},
              tooltip: 'History',
              icon: const Icon(Icons.history_rounded),
            ),
          ],
        ),
      ));
      expect(find.text('Bananalyze'), findsOneWidget);
      expect(find.byTooltip('History'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back_rounded), findsNothing);
    });

    testWidgets('title variant shows the title and a working back button',
        (tester) async {
      var backs = 0;
      await tester.pumpWidget(_app(
        ScreenHeader(title: 'Scan History', onBack: () => backs++),
      ));
      expect(find.text('Scan History'), findsOneWidget);
      await tester.tap(find.byTooltip('Go back'));
      expect(backs, 1);
      expect(
        tester.getSize(find.byType(IconButton)).height,
        greaterThanOrEqualTo(DesignTokens.minimumTouchTarget),
      );
    });

    testWidgets('long titles are truncated instead of overflowing',
        (tester) async {
      tester.view.physicalSize = const Size(640, 1280);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_app(
        ScreenHeader(
          title: 'A very long screen title that will not fit on a phone',
          onBack: () {},
        ),
      ));
      expect(tester.takeException(), isNull);
    });
  });

  group('SecondaryButton', () {
    testWidgets('is outlined, pairs icon with label, meets 48dp',
        (tester) async {
      var taps = 0;
      await tester.pumpWidget(_app(
        SecondaryButton(
          icon: Icons.photo_library_outlined,
          label: 'Upload a Photo',
          onPressed: () => taps++,
        ),
      ));
      expect(find.byIcon(Icons.photo_library_outlined), findsOneWidget);
      expect(find.text('Upload a Photo'), findsOneWidget);
      final button = find.ancestor(
        of: find.text('Upload a Photo'),
        matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
      );
      expect(tester.widget(button), isA<OutlinedButton>());
      expect(
        tester.getSize(button).height,
        greaterThanOrEqualTo(DesignTokens.minimumTouchTarget),
      );
      await tester.tap(button);
      expect(taps, 1);
    });
  });

  group('EmptyState', () {
    testWidgets('shows icon, title, message and actions', (tester) async {
      var primary = 0;
      await tester.pumpWidget(_app(
        EmptyState(
          icon: Icons.history_rounded,
          title: 'No Saved Scans Yet',
          message: 'Your scans will appear here.',
          primaryAction: FilledButton(
            onPressed: () => primary++,
            child: const Text('Scan a Banana Now'),
          ),
          secondaryAction:
              TextButton(onPressed: () {}, child: const Text('Later')),
        ),
      ));
      expect(find.byIcon(Icons.history_rounded), findsOneWidget);
      expect(find.text('No Saved Scans Yet'), findsOneWidget);
      expect(find.text('Your scans will appear here.'), findsOneWidget);
      expect(find.text('Later'), findsOneWidget);
      await tester.tap(find.text('Scan a Banana Now'));
      expect(primary, 1);
    });

    testWidgets('a custom illustration replaces the icon', (tester) async {
      await tester.pumpWidget(_app(
        const EmptyState(
          illustration: SizedBox(key: Key('art'), width: 10, height: 10),
          title: 'T',
          message: 'M',
        ),
      ));
      expect(find.byKey(const Key('art')), findsOneWidget);
      expect(find.byIcon(Icons.eco_rounded), findsNothing);
    });

    testWidgets('scrolls instead of overflowing on a short screen',
        (tester) async {
      tester.view.physicalSize = const Size(640, 600);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_app(
        EmptyState(
          icon: Icons.error_outline,
          title: 'Something went wrong with a fairly long title',
          message: 'A message ' * 20,
          primaryAction:
              FilledButton(onPressed: () {}, child: const Text('Try Again')),
        ),
      ));
      expect(tester.takeException(), isNull);
    });
  });

  group('SectionContainer', () {
    testWidgets('with a title shows a header row above the content',
        (tester) async {
      await tester.pumpWidget(_app(
        const SectionContainer(
          title: 'Handling tip',
          icon: Icons.tips_and_updates_outlined,
          child: Text('Store at room temperature.'),
        ),
      ));
      expect(find.text('Handling tip'), findsOneWidget);
      expect(find.byIcon(Icons.tips_and_updates_outlined), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Handling tip')).dy,
        lessThan(tester.getTopLeft(find.text('Store at room temperature.')).dy),
      );
    });

    testWidgets('without a title shows only the content', (tester) async {
      await tester.pumpWidget(_app(
        const SectionContainer(child: Text('Plain')),
      ));
      expect(find.text('Plain'), findsOneWidget);
      expect(find.byType(Row), findsNothing);
    });
  });

  group('Reveal', () {
    testWidgets('animates in, ending fully visible', (tester) async {
      await tester.pumpWidget(_app(const Reveal(child: Text('Hi'))));
      final start = tester.widget<Opacity>(find.byType(Opacity)).opacity;
      await tester.pumpAndSettle();
      final end = tester.widget<Opacity>(find.byType(Opacity)).opacity;
      expect(start, lessThan(1));
      expect(end, 1);
    });

    testWidgets('is skipped entirely when the OS asks to reduce motion',
        (tester) async {
      await tester.pumpWidget(
        _app(const Reveal(child: Text('Hi')), reduceMotion: true),
      );
      expect(find.text('Hi'), findsOneWidget);
      expect(find.byType(Opacity), findsNothing);
    });
  });
}
