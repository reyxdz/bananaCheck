import 'package:banana_classifier/main.dart';
import 'package:banana_classifier/services/mock_inference_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('starts with one clear scan action and visible history',
      (tester) async {
    await tester.pumpWidget(
      BananaClassifierApp(inferenceService: MockInferenceService()),
    );

    expect(find.text('Banana Check'), findsOneWidget);
    expect(find.text('Point at a banana and tap Scan.'), findsOneWidget);
    expect(find.text('Scan'), findsOneWidget);
    expect(find.text('History'), findsOneWidget);
  });

  testWidgets('scan action shows the deterministic development result',
      (tester) async {
    await tester.pumpWidget(
      BananaClassifierApp(inferenceService: MockInferenceService()),
    );

    await tester.tap(find.text('Scan'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Mock ready: Lakatan — Ripe'), findsOneWidget);
  });

  testWidgets('history remains one tap from the scan screen', (tester) async {
    await tester.pumpWidget(
      BananaClassifierApp(inferenceService: MockInferenceService()),
    );

    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();

    expect(find.text('Your past scans will appear here.'), findsOneWidget);
  });
}
