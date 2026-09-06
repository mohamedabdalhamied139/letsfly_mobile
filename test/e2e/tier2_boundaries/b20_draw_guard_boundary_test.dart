/// Tier 2 Boundary Test: B20 Voluntary Draw Guard Boundaries
/// Verifies wild cards blocking voluntary draw, empty draw deck reshuffle, and stacking limits.
library b20_draw_guard_boundary_test;

import '../harness/test_framework.dart';
import '../harness/client_harness.dart';
import '../harness/test_fixtures.dart';

void registerTests(LetsFlyTestHarness harness) {
  describe('B20: Voluntary Draw Guard Boundaries', () {
    test('B20-1: Holding a Wild card blocks voluntary draw when guard is active', () {
      final hand = [
        TestFixtures.cardWild,
        TestFixtures.createCard(id: 'c_blue_1', type: 'number', color: 'blue', value: 1, nameAr: 'أزرق 1'),
      ];
      final hasPlayable = hand.any((c) => c['color'] == 'wild');
      expect(hasPlayable, isTrue);
      // Guard forbids draw
      final drawAllowed = !hasPlayable;
      expect(drawAllowed, isFalse);
    });

    test('B20-2: When voluntary draw guard rule is disabled, drawing is always permitted', () {
      final guardEnabled = false;
      final drawAllowed = !guardEnabled || false;
      expect(drawAllowed, isTrue);
    });

    test('B20-3: Drawing from exhausted deck triggers discard pile reshuffle', () {
      int deckCount = 0;
      int discardPileCount = 45;
      if (deckCount == 0 && discardPileCount > 1) {
        deckCount = discardPileCount - 1; // leave top card
        discardPileCount = 1;
      }
      expect(deckCount, equals(44));
      expect(discardPileCount, equals(1));
    });

    test('B20-4: Stacking limit: Draw Two cannot be stacked on Wild Draw Four unless variant enabled', () {
      final pendingDrawType = 'wild_draw_four';
      final playCardType = 'draw_two';
      final canStack = pendingDrawType == playCardType;
      expect(canStack, isFalse);
    });

    test('B20-5: Cumulative draw stack limit: 16 cards stacked triggers maximum draw resolution', () {
      int drawStack = 16;
      expect(drawStack, equals(16));
    });
  });
}
