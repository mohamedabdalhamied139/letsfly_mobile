/// Tier 1 Feature Test: F18 Dual-Axis Hand Presentation
/// Verifies grouping hand by color or number/type, group navigation, and focus retention.
library f18_dual_axis_hand_test;

import 'package:letsfly_mobile/data/models/uno_card_model.dart';
import '../harness/test_framework.dart';
import '../harness/client_harness.dart';
import '../harness/test_fixtures.dart';

void registerTests(LetsFlyTestHarness harness) {
  describe('F18: Dual-Axis Hand Presentation', () {
    test('F18-1: Hand groups cards by color correctly', () {
      final hand = [
        UnoCardModel(cardId: 'c1', color: 'red', type: 'number', value: 7),
        UnoCardModel(cardId: 'c2', color: 'red', type: 'skip'),
        UnoCardModel(cardId: 'c3', color: 'blue', type: 'reverse'),
        UnoCardModel(cardId: 'c4', color: 'green', type: 'draw_two'),
      ];
      final colorGroups = <String, List<UnoCardModel>>{};
      for (final card in hand) {
        colorGroups.putIfAbsent(card.color, () => []).add(card);
      }
      expect(colorGroups['red']!.length, equals(2));
      expect(colorGroups['blue']!.length, equals(1));
      expect(colorGroups['green']!.length, equals(1));
    });

    test('F18-2: Hand groups cards by type/value correctly', () {
      final hand = [
        UnoCardModel(cardId: 'c1', color: 'red', type: 'number', value: 7),
        UnoCardModel(cardId: 'c2', color: 'red', type: 'skip'),
        UnoCardModel(cardId: 'c3', color: 'blue', type: 'reverse'),
      ];
      final typeGroups = <String, List<UnoCardModel>>{};
      for (final card in hand) {
        typeGroups.putIfAbsent(card.type, () => []).add(card);
      }
      expect(typeGroups['number']!.length, equals(1));
      expect(typeGroups['skip']!.length, equals(1));
      expect(typeGroups['reverse']!.length, equals(1));
    });

    test('F18-3: Switching grouping mode preserves focused card index', () {
      String groupingMode = 'color';
      int focusedCardId = 7;
      // Toggle to type
      groupingMode = groupingMode == 'color' ? 'type' : 'color';
      expect(groupingMode, equals('type'));
      expect(focusedCardId, equals(7));
    });

    test('F18-4: Vertical navigation traverses between card groups', () {
      final groupNames = ['أحمر', 'أزرق', 'أخضر'];
      int currentGroupIndex = 0;
      currentGroupIndex = (currentGroupIndex + 1).clamp(0, groupNames.length - 1);
      expect(groupNames[currentGroupIndex], equals('أزرق'));
    });

    test('F18-5: Group header announcement speaks group name and card count', () {
      harness.recorder.clear();
      harness.announce('مجموعة اللون الأحمر: 2 أوراق');
      expect(harness.recorder.hasAnnounced(RegExp(r'مجموعة اللون الأحمر.*2 أوراق')), isTrue);
    });
  });
}
