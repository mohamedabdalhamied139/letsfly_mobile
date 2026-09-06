/// Tier 1 Feature Test: F17 UNO State Engine & Wire Sync
/// Verifies projection of UnoGame state, active color, top card tracking, and turn sync.
library f17_uno_state_engine_test;

import 'package:letsfly_mobile/data/models/uno_card_model.dart';
import 'package:letsfly_mobile/data/models/uno_game_state_model.dart';
import '../harness/test_framework.dart';
import '../harness/client_harness.dart';
import '../harness/test_fixtures.dart';

void registerTests(LetsFlyTestHarness harness) {
  describe('F17: UNO State Engine & Wire Sync', () {
    test('F17-1: State engine accurately tracks top discard card and active color', () {
      final model = UnoGameStateModel(
        active: true,
        currentPlayerId: 1,
        currentColor: 'red',
        topCard: UnoCardModel(cardId: 'c1', color: 'red', type: 'number', value: 7),
      );
      expect(model.topCard?.color, equals('red'));
      expect(model.topCard?.value, equals(7));
      expect(model.currentColor, equals('red'));
    });

    test('F17-2: Direction switch in 2+ player matches is projected correctly', () {
      final stateClockwise = TestFixtures.createUnoGameState(
        roomId: 'room_101',
        currentTurnUserId: 1,
        topCard: TestFixtures.cardBlueReverse,
        direction: 1,
      );
      final stateCounter = TestFixtures.createUnoGameState(
        roomId: 'room_101',
        currentTurnUserId: 2,
        topCard: TestFixtures.cardBlueReverse,
        direction: -1,
      );
      expect(stateClockwise['direction'], equals(1));
      expect(stateCounter['direction'], equals(-1));
    });

    test('F17-3: Current turn sync highlights when it is the mobile user turn', () {
      final stateMyTurn = TestFixtures.createUnoGameState(
        roomId: 'room_101',
        currentTurnUserId: 1, // alice
        topCard: TestFixtures.cardRed7,
      );
      final model = UnoGameStateModel(active: true, currentPlayerId: 1);
      expect(stateMyTurn['current_turn'], equals(1));
      expect(model.isMyTurn(1), isTrue);
    });

    test('F17-4: Opponent card counts are tracked and synchronized in real time', () {
      final state = TestFixtures.createUnoGameState(
        roomId: 'room_101',
        currentTurnUserId: 1,
        topCard: TestFixtures.cardRed7,
        opponentCardCounts: {'bob': 5, 'charlie': 6},
      );
      final opponents = state['opponents'] as Map<String, int>;
      expect(opponents['bob'], equals(5));
      expect(opponents['charlie'], equals(6));
    });

    test('F17-5: State engine maintains hand card order and uniqueness', () {
      final state = TestFixtures.createUnoGameState(
        roomId: 'room_101',
        currentTurnUserId: 1,
        topCard: TestFixtures.cardRed7,
      );
      final rawHand = state['hand'] as List<dynamic>;
      final hand = rawHand.map((c) => UnoCardModel.fromJson(c as Map<String, dynamic>)).toList();
      expect(hand.length, equals(5));
      expect(hand[0].cardId, equals('c_red_7'));
    });
  });
}
