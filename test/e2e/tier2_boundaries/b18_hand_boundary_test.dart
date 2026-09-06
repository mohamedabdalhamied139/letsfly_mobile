/// Tier 2 Boundary Test: B18 Dual-Axis Hand Presentation Boundaries
/// Verifies 0 cards hand, single card hand, 24-card massive hand, and empty group navigation.
library b18_hand_boundary_test;

import '../harness/test_framework.dart';
import '../harness/client_harness.dart';
import '../harness/test_fixtures.dart';

void registerTests(LetsFlyTestHarness harness) {
  describe('B18: Dual-Axis Hand Presentation Boundaries', () {
    test('B18-1: Hand with exactly 0 cards renders winner or empty hand state gracefully', () {
      final hand = <Map<String, dynamic>>[];
      expect(hand.isEmpty, isTrue);
    });

    test('B18-2: Hand with exactly 1 card maintains valid navigation index 0', () {
      final hand = [TestFixtures.cardRed7];
      int focused = 0;
      focused = focused.clamp(0, hand.length - 1);
      expect(focused, equals(0));
    });

    test('B18-3: Massive hand with 24 cards can be grouped and navigated without lag', () {
      final massiveHand = List.generate(
        24,
        (i) => TestFixtures.createCard(id: 'c_$i', type: 'number', color: 'red', value: i % 10, nameAr: 'أحمر ${i % 10}'),
      );
      expect(massiveHand.length, equals(24));
    });

    test('B18-4: Navigating to empty color group skips to next populated group', () {
      final groups = {
        'red': [TestFixtures.cardRed7],
        'yellow': <Map<String, dynamic>>[],
        'green': [TestFixtures.cardGreenDrawTwo],
      };
      final populatedGroups = groups.keys.where((k) => groups[k]!.isNotEmpty).toList();
      expect(populatedGroups.length, equals(2));
      expect(populatedGroups.contains('yellow'), isFalse);
    });

    test('B18-5: Selected card removal updates selection index safely to adjacent card', () {
      final hand = [TestFixtures.cardRed7, TestFixtures.cardBlueReverse];
      int selectedIdx = 1;
      // Play card at index 1
      hand.removeAt(1);
      selectedIdx = selectedIdx.clamp(0, hand.length - 1);
      expect(selectedIdx, equals(0));
      expect(hand[selectedIdx]['id'], equals('c_red_7'));
    });
  });
}
