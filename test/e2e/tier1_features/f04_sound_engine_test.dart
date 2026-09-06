/// Tier 1 Feature Test: F4 Sound Engine & Audio Cues
/// Verifies polyphonic sound cues, volume adjustments, mute toggling, and cue tracking.
library f04_sound_engine_test;

import 'package:letsfly_mobile/core/audio/sound_engine.dart';
import 'package:letsfly_mobile/core/audio/tennis_sound_engine.dart';
import 'package:letsfly_mobile/core/constants/sound_cues.dart';
import '../harness/test_framework.dart';
import '../harness/client_harness.dart';

void registerTests(LetsFlyTestHarness harness) {
  describe('F4: Sound Engine & Semantic Cues', () {
    test('F4-1: Playing sound cue records playback event', () {
      harness.recorder.clear();
      harness.playCue('card_played');
      expect(harness.recorder.hasPlayedAudio('card_played'), isTrue);
      expect(SoundEngine.soundRegistry.containsKey(SoundCues.cardPlayed), isTrue);
      expect(harness.soundEngine.determineCategory(SoundCues.cardPlayed), equals('game'));
    });

    test('F4-2: Volume adjustment scales master volume properly', () {
      harness.setMasterVolume(0.5);
      expect(harness.masterVolume, equals(0.5));
      expect(harness.soundEngine.masterVolume, equals(0.5));
      expect(harness.tennisSoundEngine.effectiveVolume, equals(0.5));
      harness.playCue('turn_start');
      final lastEvent = harness.recorder.audioEvents.last;
      expect(lastEvent.volume, equals(0.5));
    });

    test('F4-3: Mute toggle suppresses audio playback events', () {
      harness.recorder.clear();
      harness.setMute(true);
      expect(harness.soundEngine.isMuted, isTrue);
      expect(harness.tennisSoundEngine.isMuted, isTrue);
      harness.playCue('uno_shout');
      expect(harness.recorder.hasPlayedAudio('uno_shout'), isFalse);
      harness.setMute(false);
      expect(harness.soundEngine.isMuted, isFalse);
    });

    test('F4-4: Multiple distinct sound cues can be queued sequentially', () {
      harness.recorder.clear();
      harness.playCue('join_room');
      harness.playCue('card_played');
      harness.playCue('round_win');
      expect(harness.recorder.audioEvents.length, equals(3));
      expect(harness.recorder.audioEvents[0].cueName, equals('join_room'));
      expect(harness.recorder.audioEvents[1].cueName, equals('card_played'));
      expect(harness.recorder.audioEvents[2].cueName, equals('round_win'));
      expect(harness.soundEngine.voicePool.length, equals(8));
      expect(SoundEngine.soundRegistry.length, greaterThanOrEqualTo(115));
    });

    test('F4-5: Volume bounds are clamped between 0.0 and 1.0', () {
      harness.setMasterVolume(1.5);
      expect(harness.masterVolume, equals(1.0));
      expect(harness.soundEngine.masterVolume, equals(1.0));
      harness.setMasterVolume(-0.5);
      expect(harness.masterVolume, equals(0.0));
      expect(harness.soundEngine.masterVolume, equals(0.0));
      harness.setMasterVolume(1.0);
    });
  });
}
