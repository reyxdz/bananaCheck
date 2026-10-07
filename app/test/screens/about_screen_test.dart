import 'dart:io';

import 'package:banana_classifier/screens/about_screen.dart';
import 'package:banana_classifier/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light, home: const AboutScreen()),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows the logo, name and version', (tester) async {
    await pump(tester);
    expect(find.bySemanticsLabel('Bananalyze logo'), findsOneWidget);
    expect(find.text('Bananalyze'), findsOneWidget);
    expect(find.text('Version ${AboutScreen.appVersion}'), findsOneWidget);
  });

  testWidgets('lists every variety and ripeness stage', (tester) async {
    await pump(tester);
    for (final v in AboutScreen.varieties) {
      await tester.scrollUntilVisible(find.text(v), 200);
      expect(find.text(v), findsOneWidget);
    }
    for (final r in ['Unripe', 'Ripe', 'Overripe']) {
      await tester.scrollUntilVisible(find.text(r), 200);
      expect(find.text(r), findsOneWidget);
    }
  });

  testWidgets('back button closes the page', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const AboutScreen()),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byType(AboutScreen), findsOneWidget);

    await tester.tap(find.byTooltip('Go back'));
    await tester.pumpAndSettle();
    expect(find.byType(AboutScreen), findsNothing);
  });

  test('version matches pubspec', () {
    // Guards the hard-coded version from drifting.
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, contains('version: ${AboutScreen.appVersion}+'));
  });
}
