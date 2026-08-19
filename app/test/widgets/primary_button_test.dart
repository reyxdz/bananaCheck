import 'package:banana_classifier/theme/design_tokens.dart';
import 'package:banana_classifier/widgets/primary_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('pairs its icon with a label and meets the touch target',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PrimaryButton(
            icon: Icons.camera_alt,
            label: 'Scan',
            onPressed: () {},
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.camera_alt), findsOneWidget);
    expect(find.text('Scan'), findsOneWidget);
    expect(
      tester.getSize(find.byType(PrimaryButton)).height,
      greaterThanOrEqualTo(DesignTokens.minimumTouchTarget),
    );
  });
}
