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
        'bungulan',
        'cavendish',
        'senorita',
        'latundan',
        'morado',
      ];

      for (final variety in expectedVarieties) {
        expect(bananaInfoMap, contains(variety),
            reason: '$variety should be in bananaInfoMap');
      }
    });

    test('does not contain removed variety Lakatan', () {
      expect(bananaInfoMap, isNot(contains('lakatan')));
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
              reason:
                  '${entry.key} has invalid ripeness key "$ripenessKey"');
        }
      }
    });

    test('every ripeness entry has at least one dish suggestion', () {
      for (final entry in bananaInfoMap.entries) {
        for (final ripenessEntry in entry.value.byRipeness.entries) {
          expect(ripenessEntry.value.dishSuggestions, isNotEmpty,
              reason:
                  '${entry.key} / ${ripenessEntry.key} should have dishes');
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

    test('varieties not typically eaten unripe omit the unripe key', () {
      // Per §7.6 table: Bungulan, Senorita, Latundan, Morado are not
      // typically eaten unripe — their 'unripe' key should be absent so
      // the widget layer falls back to generalBenefits only.
      const noUnripeVarieties = ['bungulan', 'senorita', 'latundan', 'morado'];

      for (final variety in noUnripeVarieties) {
        expect(bananaInfoMap[variety]!.byRipeness, isNot(contains('unripe')),
            reason: '$variety should not have an unripe entry');
      }
    });

    test('lookup flow matches inference output pattern', () {
      // Simulates the real lookup: variety.toLowerCase() → ripeness.toLowerCase()
      const variety = 'Saba';
      const ripeness = 'Ripe';

      final info = bananaInfoMap[variety.toLowerCase()];
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
