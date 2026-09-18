import 'package:banana_classifier/models/banana_info_data.dart';
import 'package:banana_classifier/widgets/health_benefits_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('HealthBenefitsCard', () {
    Widget buildWidget({
      required BananaInfo info,
      required String ripeness,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: HealthBenefitsCard(info: info, ripeness: ripeness),
          ),
        ),
      );
    }

    testWidgets('shows section header', (tester) async {
      const info = BananaInfo(
        generalBenefits: ['General benefit'],
        byRipeness: {},
      );

      await tester.pumpWidget(buildWidget(info: info, ripeness: 'ripe'));

      expect(find.text('Health Benefits'), findsOneWidget);
      expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);
    });

    testWidgets('renders all general benefits', (tester) async {
      const info = BananaInfo(
        generalBenefits: ['Benefit A', 'Benefit B', 'Benefit C'],
        byRipeness: {},
      );

      await tester.pumpWidget(buildWidget(info: info, ripeness: 'ripe'));

      expect(find.text('Benefit A'), findsOneWidget);
      expect(find.text('Benefit B'), findsOneWidget);
      expect(find.text('Benefit C'), findsOneWidget);
    });

    testWidgets('renders ripeness-specific benefits when key exists',
        (tester) async {
      const info = BananaInfo(
        generalBenefits: ['General'],
        byRipeness: {
          'ripe': RipenessInfo(
            healthBenefits: ['Ripe benefit 1', 'Ripe benefit 2'],
            dishSuggestions: ['Dish'],
          ),
        },
      );

      await tester.pumpWidget(buildWidget(info: info, ripeness: 'ripe'));

      // General benefit present.
      expect(find.text('General'), findsOneWidget);
      // Ripeness-specific benefits present.
      expect(find.text('Ripe benefit 1'), findsOneWidget);
      expect(find.text('Ripe benefit 2'), findsOneWidget);
    });

    testWidgets('falls back to general only when ripeness key is missing',
        (tester) async {
      const info = BananaInfo(
        generalBenefits: ['General benefit'],
        byRipeness: {
          'ripe': RipenessInfo(
            healthBenefits: ['Ripe only'],
            dishSuggestions: ['Dish'],
          ),
        },
      );

      // Request an absent ripeness key.
      await tester.pumpWidget(buildWidget(info: info, ripeness: 'unripe'));

      expect(find.text('General benefit'), findsOneWidget);
      expect(find.text('Ripe only'), findsNothing);
    });

    testWidgets('works with real Saba data from bananaInfoMap', (tester) async {
      final saba = bananaInfoMap['saba']!;

      await tester.pumpWidget(buildWidget(info: saba, ripeness: 'ripe'));

      // General benefit visible.
      expect(find.text('Rich in potassium — good for heart health'),
          findsOneWidget);
      // Ripeness-specific benefit visible.
      expect(find.text('Natural sugars provide quick energy'), findsOneWidget);
    });

    testWidgets('works with Bungulan + unripe (fallback — no unripe key)',
        (tester) async {
      final bungulan = bananaInfoMap['bungulan']!;

      await tester.pumpWidget(buildWidget(info: bungulan, ripeness: 'unripe'));

      // General benefits still visible.
      expect(find.text('Good source of Vitamin C — supports immune health'),
          findsOneWidget);
    });
  });
}
