import 'package:banana_classifier/models/banana_info_data.dart';
import 'package:banana_classifier/widgets/dish_suggestions_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DishSuggestionsCard', () {
    Widget buildWidget({required RipenessInfo ripenessInfo}) {
      return MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: DishSuggestionsCard(ripenessInfo: ripenessInfo),
          ),
        ),
      );
    }

    testWidgets('shows section header', (tester) async {
      const info = RipenessInfo(
        healthBenefits: ['Benefit'],
        dishSuggestions: ['Dish A'],
      );

      await tester.pumpWidget(buildWidget(ripenessInfo: info));

      expect(find.text('Suggested Dishes'), findsOneWidget);
      expect(find.byIcon(Icons.restaurant_rounded), findsOneWidget);
    });

    testWidgets('renders all dish suggestions as chips', (tester) async {
      const info = RipenessInfo(
        healthBenefits: ['Benefit'],
        dishSuggestions: ['Banana cue', 'Turon', 'Maruya'],
      );

      await tester.pumpWidget(buildWidget(ripenessInfo: info));

      expect(find.text('Banana cue'), findsOneWidget);
      expect(find.text('Turon'), findsOneWidget);
      expect(find.text('Maruya'), findsOneWidget);
    });

    testWidgets('renders correctly with a single dish', (tester) async {
      const info = RipenessInfo(
        healthBenefits: ['Benefit'],
        dishSuggestions: ['Eaten fresh'],
      );

      await tester.pumpWidget(buildWidget(ripenessInfo: info));

      expect(find.text('Eaten fresh'), findsOneWidget);
    });

    testWidgets('renders real Saba ripe dishes from bananaInfoMap',
        (tester) async {
      final sabaRipe = bananaInfoMap['saba']!.byRipeness['ripe']!;

      await tester.pumpWidget(buildWidget(ripenessInfo: sabaRipe));

      expect(find.text('Banana cue'), findsOneWidget);
      expect(find.text('Turon'), findsOneWidget);
      expect(find.text('Maruya'), findsOneWidget);
      expect(find.text('Saba con yelo'), findsOneWidget);
    });

    testWidgets('does not show dishes from other ripeness levels',
        (tester) async {
      final sabaRipe = bananaInfoMap['saba']!.byRipeness['ripe']!;

      await tester.pumpWidget(buildWidget(ripenessInfo: sabaRipe));

      // Unripe dish should not appear.
      expect(find.text('Nilupak'), findsNothing);
      // Overripe dish should not appear.
      expect(find.text('Banana bread'), findsNothing);
    });
  });
}
