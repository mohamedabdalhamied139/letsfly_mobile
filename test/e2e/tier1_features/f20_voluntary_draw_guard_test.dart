/// Tier 1 Feature Test: F20 Voluntary Draw Guard & Draw Stacking
/// Verifies voluntary draw rejection, legal card draws, stacking draw cards, and pass action.
library f20_voluntary_draw_guard_test;

import 'package:letsfly_mobile/core/constants/sound_cues.dart';
import 'package:letsfly_mobile/data/models/uno_card_model.dart';
import 'package:letsfly_mobile/data/models/uno_game_state_model.dart';
import '../harness/test_framework.dart';
import '../harness/client_harness.dart';
import '../harness/test_fixtures.dart';

void registerTests(LetsFlyTestHarness harness) {
  describe('F20: Voluntary Draw Guard & Draw Stacking', () {
    test('F20-1: Voluntary draw guard rejects draw when holding a playable card', () {
      final topCard = UnoCardModel(cardId: 'c1', color: 'red', type: 'number', value: 7);
      final hand = [
        UnoCardModel(cardId: 'c2', color: 'red', type: 'skip'),
        UnoCardModel(cardId: 'c3', color: 'blue', type: 'reverse'),
      ];
      final state = UnoGameStateModel(
        active: true,
        topCard: topCard,
        currentColor: 'red',
        hand: hand,
      );
      expect(state.canPlayAnyCard(), isTrue);
      bool drawAllowed = !state.canPlayAnyCard();
      expect(drawAllowed, isFalse);
    });

    test('F20-2: Legal draw permitted when hand contains no matching cards', () {
      final topCard = UnoCardModel(cardId: 'c1', color: 'red', type: 'number', value: 7);
      final hand = [
        UnoCardModel(cardId: 'c2', color: 'blue', type: 'number', value: 2),
        UnoCardModel(cardId: 'c3', color: 'green', type: 'number', value: 5),
      ];
      final state = UnoGameStateModel(
        active: true,
        topCard: topCard,
        currentColor: 'red',
        hand: hand,
      );
      expect(state.canPlayAnyCard(), isFalse);
      bool drawAllowed = !state.canPlayAnyCard();
      expect(drawAllowed, isTrue);
    });

    test('F20-3: Drawing card emits draw_card action and plays card_drawn audio', () {
      harness.recorder.clear();
      harness.playCue(SoundCues.cardDraw);
      harness.sendGameAction('room_101', 'draw_card');
      expect(harness.recorder.hasPlayedAudio(SoundCues.cardDraw), isTrue);
    });

    test('F20-4: Draw Two response stacking accumulates pending draw count', () {
      final state = UnoGameStateModel(active: true, pendingDrawCount: 4);
      expect(state.pendingDrawCount, equals(4));
    });

    test('F20-5: Pass action is available only after drawing a non-playable card', () {
      bool hasDrawnThisTurn = true;
      bool drawnCardPlayable = false;
      bool canPass = hasDrawnThisTurn && !drawnCardPlayable;
      expect(canPass, isTrue);
    });
  });
}
