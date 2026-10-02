import 'package:banana_classifier/theme/design_tokens.dart';
import 'package:banana_classifier/widgets/camera_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<List<String>> pumpControls(
    WidgetTester tester, {
    bool flashOn = false,
    bool shutterDimmed = false,
    bool shutterEnabled = true,
    bool flashEnabled = true,
    bool galleryEnabled = true,
  }) async {
    final taps = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 360,
              child: CameraControls(
                onGallery: galleryEnabled ? () => taps.add('gallery') : null,
                onShutter: shutterEnabled ? () => taps.add('shutter') : null,
                onFlash: flashEnabled ? () => taps.add('flash') : null,
                flashOn: flashOn,
                shutterDimmed: shutterDimmed,
              ),
            ),
          ),
        ),
      ),
    );
    return taps;
  }

  double shutterOpacity(WidgetTester tester) => tester
      .widget<AnimatedOpacity>(
        find.descendant(
          of: find.byType(ShutterButton),
          matching: find.byType(AnimatedOpacity),
        ),
      )
      .opacity;

  testWidgets('each button triggers its own action', (tester) async {
    final taps = await pumpControls(tester);

    await tester.tap(find.byTooltip('Upload a Photo'));
    await tester.tap(find.bySemanticsLabel('Scan'));
    await tester.tap(find.byTooltip('Turn flash on'));

    expect(taps, ['gallery', 'shutter', 'flash']);
  });

  testWidgets('flash icon and label reflect its state', (tester) async {
    await pumpControls(tester);
    expect(find.byIcon(Icons.flash_off_rounded), findsOneWidget);
    expect(find.byTooltip('Turn flash on'), findsOneWidget);

    await pumpControls(tester, flashOn: true);
    expect(find.byIcon(Icons.flash_on_rounded), findsOneWidget);
    expect(find.byTooltip('Turn flash off'), findsOneWidget);
  });

  testWidgets('shutter dims in poor conditions but still works',
      (tester) async {
    final taps = await pumpControls(tester, shutterDimmed: true);
    await tester.pumpAndSettle();

    expect(shutterOpacity(tester), DesignTokens.shutterDimmedOpacity);

    await tester.tap(find.bySemanticsLabel('Scan'));
    expect(taps, ['shutter']);
  });

  testWidgets('shutter is fully opaque in good conditions', (tester) async {
    await pumpControls(tester);
    await tester.pumpAndSettle();
    expect(shutterOpacity(tester), 1);
  });

  testWidgets('disabled shutter and flash do nothing', (tester) async {
    final taps = await pumpControls(
      tester,
      shutterEnabled: false,
      flashEnabled: false,
    );

    await tester.tap(find.bySemanticsLabel('Scan'));
    await tester.tap(find.byTooltip('Turn flash on'), warnIfMissed: false);

    expect(taps, isEmpty);
    expect(
      tester.getSemantics(find.bySemanticsLabel('Scan')),
      isNot(matchesSemantics(isEnabled: true)),
    );
  });

  testWidgets('shutter is the biggest target and all meet 48dp',
      (tester) async {
    await pumpControls(tester);

    Size buttonSize(String tooltip) => tester.getSize(
          find.ancestor(
            of: find.byTooltip(tooltip),
            matching: find.byType(IconButton),
          ),
        );
    final shutter = tester.getSize(find.bySemanticsLabel('Scan'));
    final gallery = buttonSize('Upload a Photo');
    final flash = buttonSize('Turn flash on');

    expect(shutter.width, ShutterButton.outerSize);
    expect(shutter.width, greaterThan(gallery.width));
    for (final size in [gallery, flash]) {
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
    }
  });

  // ── A34: upload (gallery) button ──

  testWidgets('gallery button is announced as "Upload a Photo"',
      (tester) async {
    await pumpControls(tester);
    expect(find.byIcon(Icons.photo_library_outlined), findsOneWidget);
    // Screen readers read the tooltip on an enabled button.
    expect(
      tester.getSemantics(find.byIcon(Icons.photo_library_outlined)),
      containsSemantics(
        tooltip: 'Upload a Photo',
        isButton: true,
        isEnabled: true,
      ),
    );
  });

  testWidgets('disabled gallery button ignores taps', (tester) async {
    final taps = await pumpControls(tester, galleryEnabled: false);

    await tester.tap(find.byTooltip('Upload a Photo'), warnIfMissed: false);

    expect(taps, isEmpty);
    final gallery = tester.widget<IconButton>(
      find.ancestor(
        of: find.byTooltip('Upload a Photo'),
        matching: find.byType(IconButton),
      ),
    );
    expect(gallery.onPressed, isNull);
  });

  testWidgets('gallery can be highlighted as the no-banana fallback',
      (tester) async {
    Future<ButtonStyle> galleryStyle({required bool highlight}) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CameraControls(
              onGallery: () {},
              onShutter: () {},
              onFlash: () {},
              flashOn: false,
              highlightGallery: highlight,
            ),
          ),
        ),
      );
      return tester
          .widget<IconButton>(
            find.ancestor(
              of: find.byTooltip('Upload a Photo'),
              matching: find.byType(IconButton),
            ),
          )
          .style!;
    }

    final normal = await galleryStyle(highlight: false);
    final highlighted = await galleryStyle(highlight: true);

    expect(
      normal.backgroundColor!.resolve({}),
      DesignTokens.surface,
    );
    expect(
      highlighted.backgroundColor!.resolve({}),
      DesignTokens.primaryLight,
    );
    expect(
      highlighted.side!.resolve({})!.width,
      DesignTokens.highlightBorderWidth,
    );
  });
}
