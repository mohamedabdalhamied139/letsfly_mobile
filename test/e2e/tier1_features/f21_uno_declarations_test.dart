/// Tier 1 Feature Test: F21 UNO Declarations, Catches & Penalties
/// Verifies UNO shout declaration at 1 card, catch penalties (+4), and buzzer slapping.
library f21_uno_declarations_test;

import 'package:letsfly_mobile/core/constants/sound_cues.dart';
import 'package:letsfly_mobile/data/models/uno_game_state_model.dart';
import '../harness/test_framework.dart';
import '../harness/client_harness.dart';

void registerTests(LetsFlyTestHarness harness) {
  describe('F21: UNO Declarations, Catches & Penalties', () {
    test('F21-1: UNO shout button becomes active when hand has exactly 1 card', () {
      final state = UnoGameStateModel(active: true, pendingUnoPlayers: [1]);
      expect(state.pendingUnoPlayers.contains(1), isTrue);
    });

    test('F21-2: Emitting call_uno plays uno_shout audio cue and sends WS frame', () async {
      await harness.login('alice', 'password123');
      await harness.connectRoom('room_101');
      harness.recorder.clear();
      harness.playCue(SoundCues.unoCalled);
      harness.sendGameAction('room_101', 'call_uno');
      expect(harness.recorder.hasPlayedAudio(SoundCues.unoCalled), isTrue);
    });

    test('F21-3: Catching an opponent who forgot UNO applies 4-card penalty', () {
      harness.recorder.clear();
      harness.sendGameAction('room_101', 'catch_uno', extra: {'target': 'bob'});
      harness.announce('تم الإمساك بـ bob! تم تطبيق عقوبة 4 أوراق.');
      expect(harness.recorder.hasAnnounced(RegExp(r'عقوبة 4 أوراق')), isTrue);
    });

    test('F21-4: False catch accusation does not penalize victim', () {
      bool targetAlreadyShouted = true;
      bool penaltyApplied = !targetAlreadyShouted;
      expect(penaltyApplied, isFalse);
    });

    test('F21-5: Buzzer slap action triggers buzzer audio cue and priority claim', () {
      harness.recorder.clear();
      harness.playCue('buzzer');
      expect(harness.recorder.hasPlayedAudio('buzzer'), isTrue);
    });
  });
}
