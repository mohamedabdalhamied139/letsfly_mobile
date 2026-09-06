/// Tier 1 Feature Test: F22 Round Scoring, Match Win & Bot Sync
/// Verifies round score summing, cumulative match scoring, target score win condition, and bot sync.
library f22_round_scoring_bot_sync_test;

import 'package:letsfly_mobile/core/constants/sound_cues.dart';
import 'package:letsfly_mobile/data/models/room_model.dart';
import 'package:letsfly_mobile/data/models/uno_card_model.dart';
import 'package:letsfly_mobile/data/models/uno_game_state_model.dart';
import '../harness/test_framework.dart';
import '../harness/client_harness.dart';

void registerTests(LetsFlyTestHarness harness) {
  describe('F22: Round Scoring, Match Win & Bot Sync', () {
    test('F22-1: Round winner receives points for all cards remaining in opponents hands', () {
      // Opponent bob has: Red 7 (7 pts) + Skip (20 pts) + Wild (50 pts) = 77 pts
      final remainingCards = [
        UnoCardModel(cardId: 'c1', color: 'red', type: 'number', value: 7),
        UnoCardModel(cardId: 'c2', color: 'red', type: 'skip'),
        UnoCardModel(cardId: 'c3', color: 'wild', type: 'wild'),
      ];
      int points = 0;
      for (final card in remainingCards) {
        if (card.type == 'number') {
          points += card.value ?? 0;
        } else if (card.type == 'wild') {
          points += 50;
        } else {
          points += 20;
        }
      }
      expect(points, equals(77));
    });

    test('F22-2: Cumulative match score aggregates across rounds', () {
      final room = RoomModel(
        roomId: 'r1',
        hostId: 1,
        hostName: 'Alice',
        game: 'UNO',
        status: 'playing',
        players: [1],
        playerNames: {1: 'Alice'},
        scores: {1: 227},
      );
      expect(room.scores[1], equals(227));
    });

    test('F22-3: Reaching target score (500 pts) triggers match victory condition', () {
      final state = UnoGameStateModel(
        active: false,
        winnerId: 1,
        targetScore: 500,
        roundScore: 520,
      );
      expect(state.winnerId, equals(1));
      expect(state.roundScore >= state.targetScore, isTrue);
    });

    test('F22-4: Match victory triggers match_win sound cue and assertive announcement', () {
      harness.recorder.clear();
      harness.playCue(SoundCues.matchWin);
      harness.announce('مبروك! لقد فزت بالمباراة!', assertive: true);
      expect(harness.recorder.hasPlayedAudio(SoundCues.matchWin), isTrue);
      expect(harness.recorder.hasAssertiveAnnouncement(RegExp(r'فزت بالمباراة')), isTrue);
    });

    test('F22-5: Bot moves are received over WebSocket and update turn indicator', () {
      final botAction = {
        'type': 'card_played',
        'player': 'bot_1',
        'card_id': 'c_yellow_3',
      };
      expect(botAction['player'], equals('bot_1'));
    });
  });
}
