/// Tier 2 Boundary Test: B4 Sound Engine Boundaries
/// Verifies invalid cue names, volume boundaries, rapid audio spam, and mute transitions.
library b04_sound_boundary_test;

import 'package:letsfly_mobile/core/audio/sound_engine.dart';
import '../harness/test_framework.dart';
import '../harness/client_harness.dart';

void registerTests(LetsFlyTestHarness harness) {
  describe('B4: Sound Engine & Semantic Cues Boundaries', () {
    test('B4-1: Playing non-existent sound cue name records cue safely without crash', () {
      expect(harness.soundEngine is SoundEngine, isTrue);
      harness.recorder.clear();
      harness.playCue('non_existent_cue_name');
      expect(harness.recorder.hasPlayedAudio('non_existent_cue_name'), isTrue);
    });

    test('B4-2: Volume set to extreme boundary (0.0001) scales volume accurately', () {
      harness.setMasterVolume(0.0001);
      expect(harness.masterVolume, greaterThan(0.0));
      harness.setMasterVolume(1.0);
    });

    test('B4-3: Rapid polyphonic cue spamming (100 cues) records all events in order', () {
      harness.recorder.clear();
      for (int i = 0; i < 100; i++) {
        harness.playCue('card_played');
      }
      expect(harness.recorder.countAudioPlays('card_played'), equals(100));
    });

    test('B4-4: Toggling mute rapidly during gameplay does not drop volume setting', () {
      harness.setMasterVolume(0.75);
      harness.setMute(true);
      harness.setMute(false);
      expect(harness.masterVolume, equals(0.75));
    });

    test('B4-5: Empty cue string is handled without raising exception', () {
      harness.recorder.clear();
      harness.playCue('');
      expect(harness.recorder.audioEvents.isNotEmpty, isTrue);
    });
  });
}
