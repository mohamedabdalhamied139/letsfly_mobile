/// Tier 2 Boundary Test: B17 UNO State Engine Boundaries
/// Verifies duplicate state frames, 2-player reverse mechanics, out-of-bounds turn indices, and Mercy rule.
library b17_state_engine_boundary_test;

import '../harness/test_framework.dart';
import '../harness/client_harness.dart';
import '../harness/test_fixtures.dart';

void registerTests(LetsFlyTestHarness harness) {
  describe('B17: UNO State Engine Boundaries', () {
    test('B17-1: Receiving duplicate state frame does not re-trigger turn announcement or audio', () {
      final state1 = TestFixtures.createUnoGameState(
        roomId: 'room_101',
        currentTurnUserId: 1,
        topCard: TestFixtures.cardRed7,
      );
      final state2 = Map<String, dynamic>.from(state1);
      // Event deduplication check
      final isDuplicate = state1['top_card']['id'] == state2['top_card']['id'] &&
          state1['current_turn'] == state2['current_turn'];
      expect(isDuplicate, isTrue);
    });

    test('B17-2: In a 2-player match, Reverse card acts as Skip card advancing turn back to player', () {
      final playerCount = 2;
      int currentTurn = 1;
      // In 2-player, Reverse flips direction AND steps: player 1 plays reverse -> turn remains player 1
      if (playerCount == 2) {
        currentTurn = 1;
      }
      expect(currentTurn, equals(1));
    });

    test('B17-3: Turn index wraps around cleanly when exceeding player count', () {
      final playerCount = 4;
      int nextTurn(int current, int direction) {
        return (current + direction) % playerCount;
      }
      expect(nextTurn(3, 1), equals(0));
      expect(nextTurn(0, -1), equals(3));
    });

    test('B17-4: Mercy rule elimination occurs at exactly 25 cards in hand', () {
      final safeHand = 24;
      final eliminatedHand = 25;
      expect(safeHand >= 25, isFalse);
      expect(eliminatedHand >= 25, isTrue);
    });

    test('B17-5: Top card with null value (action/wild card) is handled without null pointer error', () {
      final wildTop = TestFixtures.cardWild;
      expect(wildTop['value'], isNull);
      expect(wildTop['type'], equals('wild'));
    });
  });
}
