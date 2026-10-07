import 'package:flutter_test/flutter_test.dart';

import 'package:banana_classifier/models/banana_info_data.dart';

void main() {
  group('RipenessInfo', () {
    test('stores health benefits and dish suggestions', () {
      const info = RipenessInfo(
        healthBenefits: ['Benefit A', 'Benefit B'],
        dishSuggestions: ['Dish 1', 'Dish 2', 'Dish 3'],
      );

      expect(info.healthBenefits, hasLength(2));
      expect(info.dishSuggestions, hasLength(3));
      expect(info.healthBenefits, contains('Benefit A'));
      expect(info.dishSuggestions, contains('Dish 1'));
    });
  });

  group('BananaInfo', () {
    test('stores general benefits and per-ripeness data', () {
      const info = BananaInfo(
        generalBenefits: ['General benefit'],
        byRipeness: {
          'ripe': RipenessInfo(
            healthBenefits: ['Ripe benefit'],
            dishSuggestions: ['Ripe dish'],
          ),
        },
      );

      expect(info.generalBenefits, ['General benefit']);
      expect(info.byRipeness, contains('ripe'));
      expect(info.byRipeness['ripe']!.healthBenefits, ['Ripe benefit']);
      expect(info.byRipeness['ripe']!.dishSuggestions, ['Ripe dish']);
    });

    test('missing ripeness key returns null (fallback case)', () {
      const info = BananaInfo(
        generalBenefits: ['General benefit'],
        byRipeness: {
          'ripe': RipenessInfo(
            healthBenefits: ['Ripe benefit'],
            dishSuggestions: ['Ripe dish'],
          ),
        },
      );

      // Simulates lookup for a ripeness not in the map.
      expect(info.byRipeness['unripe'], isNull);
    });
  });

  group('bananaInfoMap', () {
    test('contains exactly 6 varieties', () {
      expect(bananaInfoMap, hasLength(6));
    });

    test('all keys are lowercase', () {
      for (final key in bananaInfoMap.keys) {
        expect(key, equals(key.toLowerCase()),
            reason: 'Map key "$key" must be lowercase');
      }
    });

    test('contains all expected varieties', () {
      const expectedVarieties = [
        'saba',
        'cardaba',
        'cavendish',
        'senorita',
        'latundan',
        'lakatan',
      ];

      for (final variety in expectedVarieties) {
        expect(bananaInfoMap, contains(variety),
            reason: '$variety should be in bananaInfoMap');
      }
    });

    test('does not contain removed varieties Bungulan and Morado', () {
      expect(bananaInfoMap, isNot(contains('bungulan')));
      expect(bananaInfoMap, isNot(contains('morado')));
    });

    test('every variety has at least one general benefit', () {
      for (final entry in bananaInfoMap.entries) {
        expect(entry.value.generalBenefits, isNotEmpty,
            reason: '${entry.key} should have general benefits');
      }
    });

    test('every variety has at least one ripeness entry', () {
      for (final entry in bananaInfoMap.entries) {
        expect(entry.value.byRipeness, isNotEmpty,
            reason: '${entry.key} should have at least one ripeness entry');
      }
    });

    test('all ripeness keys are lowercase and valid', () {
      const validRipenessKeys = {'unripe', 'ripe', 'overripe'};

      for (final entry in bananaInfoMap.entries) {
        for (final ripenessKey in entry.value.byRipeness.keys) {
          expect(validRipenessKeys, contains(ripenessKey),
              reason: '${entry.key} has invalid ripeness key "$ripenessKey"');
        }
      }
    });

    test('ripe and overripe entries always have dish suggestions', () {
      for (final entry in bananaInfoMap.entries) {
        for (final ripeness in ['ripe', 'overripe']) {
          expect(entry.value.byRipeness[ripeness]!.dishSuggestions, isNotEmpty,
              reason: '${entry.key} / $ripeness should have dishes');
        }
      }
    });

    test('every ripeness entry has at least one health benefit', () {
      for (final entry in bananaInfoMap.entries) {
        for (final ripenessEntry in entry.value.byRipeness.entries) {
          expect(ripenessEntry.value.healthBenefits, isNotEmpty,
              reason:
                  '${entry.key} / ${ripenessEntry.key} should have benefits');
        }
      }
    });

    test('Saba has all three ripeness levels (unripe, ripe, overripe)', () {
      final saba = bananaInfoMap['saba']!;
      expect(saba.byRipeness, contains('unripe'));
      expect(saba.byRipeness, contains('ripe'));
      expect(saba.byRipeness, contains('overripe'));
    });

    test('Cavendish has all three ripeness levels', () {
      final cavendish = bananaInfoMap['cavendish']!;
      expect(cavendish.byRipeness, contains('unripe'));
      expect(cavendish.byRipeness, contains('ripe'));
      expect(cavendish.byRipeness, contains('overripe'));
    });

    test('Lakatan has all three ripeness levels', () {
      final lakatan = bananaInfoMap['lakatan']!;
      expect(lakatan.byRipeness, contains('unripe'));
      expect(lakatan.byRipeness, contains('ripe'));
      expect(lakatan.byRipeness, contains('overripe'));
    });

    test('every variety has all three ripeness stages the model detects', () {
      for (final entry in bananaInfoMap.entries) {
        expect(
          entry.value.byRipeness.keys,
          containsAll(['unripe', 'ripe', 'overripe']),
          reason: entry.key,
        );
      }
    });

    test('cooking bananas get green-banana dishes; dessert bananas none', () {
      for (final cooking in ['saba', 'cardaba']) {
        expect(
          bananaInfoMap[cooking]!.byRipeness['unripe']!.dishSuggestions,
          contains('Banana chips'),
          reason: cooking,
        );
      }
      // Dessert bananas are left to ripen, not cooked green.
      for (final dessert in ['cavendish', 'lakatan', 'latundan', 'senorita']) {
        expect(
          bananaInfoMap[dessert]!.byRipeness['unripe']!.dishSuggestions,
          isEmpty,
          reason: dessert,
        );
      }
    });

    test('saba/cardaba street dishes are not listed for dessert bananas', () {
      const cookingOnly = [
        'Banana cue',
        'Turon',
        'Maruya',
        'Ginanggang',
        'Ginataang saging',
      ];
      for (final dessert in ['cavendish', 'lakatan', 'latundan', 'senorita']) {
        final dishes = bananaInfoMap[dessert]!
            .byRipeness
            .values
            .expand((r) => r.dishSuggestions);
        for (final dish in cookingOnly) {
          expect(dishes, isNot(contains(dish)), reason: '$dessert: $dish');
        }
      }
    });

    test('no unsupported health claims', () {
      final allText = bananaInfoMap.values.expand(
        (info) => [
          ...info.generalBenefits,
          ...info.byRipeness.values.expand((r) => r.healthBenefits),
        ],
      );
      for (final text in allText) {
        final lower = text.toLowerCase();
        // Overripe "most antioxidants" traces back to a debunked claim.
        expect(lower, isNot(contains('antioxidant')), reason: text);
        expect(lower, isNot(contains('peak vitamin')), reason: text);
        // Bananas give ~9% DV potassium and ~11% DV vitamin C — not "rich".
        expect(lower, isNot(contains('rich in')), reason: text);
      }
    });

    test('Cardaba is shown for the model\'s misspelt "Cordova" class', () {
      expect(displayVarietyName('Cordova'), 'Cardaba');
      expect(displayVarietyName('cordova'), 'Cardaba');
      expect(displayVarietyName('Lakatan'), 'Lakatan');
      expect(bananaInfoFor('Cordova'), same(bananaInfoMap['cardaba']));
      expect(bananaInfoMap, isNot(contains('cordova')));
    });

    test('lookup flow matches inference output pattern', () {
      // Simulates the real lookup: variety.toLowerCase() → ripeness.toLowerCase()
      const variety = 'Saba';
      const ripeness = 'Ripe';

      final info = bananaInfoFor(variety);
      expect(info, isNotNull);

      final ripenessInfo = info!.byRipeness[ripeness.toLowerCase()];
      expect(ripenessInfo, isNotNull);
      expect(ripenessInfo!.dishSuggestions, isNotEmpty);
      expect(ripenessInfo.healthBenefits, isNotEmpty);
    });

    test('unknown variety returns null gracefully', () {
      expect(bananaInfoMap['mango'], isNull);
    });
  });
}
