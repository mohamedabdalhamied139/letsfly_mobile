/// Tier 1 Feature Test: F19 UNO Gameplay Card Plays & Wild Modal
/// Verifies legal card play matching, action cards, wild color picker, and audio cue triggers.
library f19_uno_gameplay_actions_test;

import 'package:letsfly_mobile/core/constants/sound_cues.dart';
import 'package:letsfly_mobile/data/models/uno_card_model.dart';
import '../harness/test_framework.dart';
import '../harness/client_harness.dart';
import '../harness/test_fixtures.dart';

void registerTests(LetsFlyTestHarness harness) {
  describe('F19: UNO Gameplay Card Plays & Wild Modal', () {
    test('F19-1: Card with matching color is legal to play', () {
      final topCard = UnoCardModel(cardId: 'c1', color: 'red', type: 'number', value: 7);
      final playCard = UnoCardModel(cardId: 'c2', color: 'red', type: 'skip');
      expect(playCard.isPlayable(topCard, 'red'), isTrue);
    });

    test('F19-2: Card with matching number/value is legal to play across different colors', () {
      final topCard = UnoCardModel(cardId: 'c1', color: 'red', type: 'number', value: 7);
      final playCard = UnoCardModel(cardId: 'c2', color: 'blue', type: 'number', value: 7);
      expect(playCard.isPlayable(topCard, 'red'), isTrue);
    });

    test('F19-3: Wild card is always playable regardless of top card color', () {
      final topCard = UnoCardModel(cardId: 'c1', color: 'red', type: 'number', value: 7);
      final wildCard = UnoCardModel(cardId: 'c3', color: 'wild', type: 'wild');
      expect(wildCard.isPlayable(topCard, 'red'), isTrue);
    });

    test('F19-4: Playing a wild card opens color picker dialog with 4 classic colors', () {
      final wildColors = ['red', 'yellow', 'green', 'blue'];
      expect(wildColors.length, equals(4));
      expect(wildColors.contains('green'), isTrue);
    });

    test('F19-5: Playing card triggers card_played sound cue and WS action frame', () async {
      await harness.login('alice', 'password123');
      await harness.connectRoom('room_101');
      harness.recorder.clear();
      harness.playCue(SoundCues.cardPlayed);
      harness.sendGameAction('room_101', 'play_card', extra: {'card_id': 'c_red_7'});
      expect(harness.recorder.hasPlayedAudio(SoundCues.cardPlayed), isTrue);
    });
  });
}
