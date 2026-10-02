import 'package:banana_classifier/services/frame_quality.dart';
import 'package:banana_classifier/theme/design_tokens.dart';
import 'package:banana_classifier/widgets/scan_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ScanHint', () {
    ScanHint hint(
      ScanCondition c, {
      bool torchOn = false,
      bool hasTorch = true,
    }) =>
        ScanHint.forCondition(c, torchOn: torchOn, hasTorch: hasTorch);

    test('says what to do in each state', () {
      expect(hint(ScanCondition.searching).text, 'Point at a banana');
      expect(hint(ScanCondition.ready).text, 'Looks good, tap Scan');
      expect(hint(ScanCondition.tooDark).text, 'Too dark, turn on flash');
    });

    test('does not suggest the flash when it is on or missing', () {
      expect(
        hint(ScanCondition.tooDark, torchOn: true).text,
        'Too dark, move to brighter light',
      );
      expect(
        hint(ScanCondition.tooDark, hasTorch: false).text,
        'Too dark, move to brighter light',
      );
    });

    test('detected is blue, dark is amber, and each has its own icon', () {
      final searching = hint(ScanCondition.searching);
      final ready = hint(ScanCondition.ready);
      final dark = hint(ScanCondition.tooDark);
      final notFound = hint(ScanCondition.notFound);

      expect(ready.color, DesignTokens.scanDetected);
      // Blue: the blue channel clearly dominates.
      expect(
        DesignTokens.scanDetected.blue,
        greaterThan(DesignTokens.scanDetected.red),
      );
      expect(dark.color, DesignTokens.scanWarning);
      // Colour is never the only cue (§7.4).
      expect(
        {searching.icon, ready.icon, dark.icon, notFound.icon},
        hasLength(4),
      );
    });

    test('fallback tip offers moving closer or uploading', () {
      expect(
        hint(ScanCondition.notFound).text,
        "Can't find a banana? Move closer or upload a photo",
      );
    });
  });

  group('ScanOverlay', () {
    Future<void> pumpOverlay(
      WidgetTester tester,
      ScanCondition condition, {
      Size size = const Size(320, 480),
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox.fromSize(
                size: size,
                child: ScanOverlay(
                  condition: condition,
                  torchOn: false,
                  hasTorch: true,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('shows a single hint pill with an icon', (tester) async {
      await pumpOverlay(tester, ScanCondition.searching);

      expect(find.text('Point at a banana'), findsOneWidget);
      expect(find.byIcon(Icons.center_focus_weak_rounded), findsOneWidget);
    });

    testWidgets('hint updates with the condition', (tester) async {
      await pumpOverlay(tester, ScanCondition.searching);
      await pumpOverlay(tester, ScanCondition.ready);
      expect(find.text('Looks good, tap Scan'), findsOneWidget);
      expect(find.text('Point at a banana'), findsNothing);

      await pumpOverlay(tester, ScanCondition.tooDark);
      expect(find.text('Too dark, turn on flash'), findsOneWidget);
    });

    testWidgets('hint sits above the frame, not on its border', (tester) async {
      const size = Size(320, 480);
      await pumpOverlay(tester, ScanCondition.ready, size: size);

      final overlayTop = tester.getTopLeft(find.byType(ScanOverlay)).dy;
      final frame = ScanOverlay.frameFor(size);
      final pill = tester.getRect(
        find
            .ancestor(
              of: find.text('Looks good, tap Scan'),
              matching: find.byType(Container),
            )
            .first,
      );
      expect(pill.bottom, lessThanOrEqualTo(overlayTop + frame.top));
      expect(pill.top, greaterThanOrEqualTo(overlayTop));
    });

    testWidgets('hint is announced to screen readers when it changes',
        (tester) async {
      await pumpOverlay(tester, ScanCondition.searching);
      expect(
        tester.getSemantics(find.text('Point at a banana')),
        matchesSemantics(isLiveRegion: true, label: 'Point at a banana'),
      );
    });

    test('frame is centred and fits small previews', () {
      const small = Size(200, 260);
      final frame = ScanOverlay.frameFor(small);
      expect(frame.center.dx, 100);
      expect(frame.left, greaterThanOrEqualTo(0));
      expect(frame.right, lessThanOrEqualTo(small.width));
      expect(frame.top, greaterThan(0));
      expect(frame.bottom, lessThanOrEqualTo(small.height));
    });

    test('frame uses the reticle size on a normal preview', () {
      final frame = ScanOverlay.frameFor(const Size(400, 600));
      expect(frame.width, DesignTokens.reticleWidth);
      expect(frame.height, DesignTokens.reticleHeight);
    });

    testWidgets('fallback tip replaces the searching hint', (tester) async {
      await pumpOverlay(tester, ScanCondition.notFound);
      expect(
        find.text("Can't find a banana? Move closer or upload a photo"),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.search_off_rounded), findsOneWidget);
      expect(find.text('Point at a banana'), findsNothing);
    });
  });
}
