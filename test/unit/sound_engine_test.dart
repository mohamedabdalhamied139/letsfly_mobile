import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:letsfly_mobile/core/audio/sound_engine.dart';
import 'package:letsfly_mobile/core/audio/audio_cubit.dart';
import 'package:letsfly_mobile/core/constants/sound_cues.dart';

void main() {
  group('SoundEngine Asset Registration & File Integrity', () {
    test('all registered sound cues point to physical files that exist on disk', () {
      for (final entry in SoundEngine.soundRegistry.entries) {
        final cue = entry.key;
        final relPath = entry.value;
        final file = File('assets/$relPath');
        expect(
          file.existsSync(),
          isTrue,
          reason: 'Physical file missing for cue $cue at path assets/$relPath',
        );
        expect(
          file.lengthSync(),
          greaterThan(0),
          reason: 'Audio file is empty for cue $cue at path assets/$relPath',
        );
      }
    });

    test('covers all SoundCues constants in registry', () {
      for (final cue in SoundCues.all) {
        expect(
          SoundEngine.soundRegistry.containsKey(cue),
          isTrue,
          reason: 'SoundEngine registry missing cue: $cue',
        );
      }
    });
  });

  group('SoundEngine Volume and Category Calculation', () {
    late SoundEngine engine;

    setUp(() {
      engine = SoundEngine();
    });

    test('category categorization logic', () {
      expect(engine.determineCategory(SoundCues.unoPlace), equals('game'));
      expect(engine.determineCategory(SoundCues.cardDraw), equals('game'));
      expect(engine.determineCategory(SoundCues.cardWildColor), equals('game'));
      expect(engine.determineCategory(SoundCues.bluffChallenge), equals('game'));
      expect(engine.determineCategory(SoundCues.turnStart), equals('effects'));
      expect(engine.determineCategory(SoundCues.playerJoined), equals('effects'));
      expect(engine.determineCategory(SoundCues.matchWin), equals('effects'));
    });

    test('effective volume computation with category scaling and mute toggle', () {
      // Default: master = 1.0, game = 1.0, effects = 1.0, not muted
      expect(engine.getEffectiveVolume(SoundCues.turnStart), closeTo(1.0, 0.001));
      expect(engine.getEffectiveVolume(SoundCues.unoPlace), closeTo(1.0, 0.001));

      // Scale master volume
      engine.setMasterVolume(0.5);
      expect(engine.getEffectiveVolume(SoundCues.turnStart), closeTo(0.5, 0.001));
      expect(engine.getEffectiveVolume(SoundCues.unoPlace), closeTo(0.5, 0.001));

      // Scale game volume specifically
      engine.setCategoryVolume('game', 0.8);
      expect(engine.getEffectiveVolume(SoundCues.unoPlace), closeTo(0.4, 0.001));
      expect(engine.getEffectiveVolume(SoundCues.turnStart), closeTo(0.5, 0.001));

      // Mute audio
      engine.setMute(true);
      expect(engine.isMuted, isTrue);
      expect(engine.getEffectiveVolume(SoundCues.unoPlace), equals(0.0));
      expect(engine.getEffectiveVolume(SoundCues.turnStart), equals(0.0));

      // Unmute restores calculated levels
      engine.setMute(false);
      expect(engine.isMuted, isFalse);
      expect(engine.getEffectiveVolume(SoundCues.unoPlace), closeTo(0.4, 0.001));
      expect(engine.getEffectiveVolume(SoundCues.turnStart), closeTo(0.5, 0.001));
    });
  });

  group('AudioCubit State Management', () {
    late SoundEngine engine;
    late AudioCubit cubit;

    setUp(() {
      engine = SoundEngine();
      cubit = AudioCubit(engine);
    });

    tearDown(() {
      cubit.close();
    });

    test('initial state matches default settings', () {
      expect(cubit.state.masterVolume, equals(1.0));
      expect(cubit.state.effectsVolume, equals(1.0));
      expect(cubit.state.gameVolume, equals(1.0));
      expect(cubit.state.isMuted, isFalse);
    });

    test('updating volume emits new state and updates engine', () {
      cubit.setMasterVolume(0.7);
      expect(cubit.state.masterVolume, closeTo(0.7, 0.001));
      expect(engine.masterVolume, closeTo(0.7, 0.001));

      cubit.setGameVolume(0.5);
      expect(cubit.state.gameVolume, closeTo(0.5, 0.001));

      cubit.toggleMute();
      expect(cubit.state.isMuted, isTrue);
      expect(engine.isMuted, isTrue);

      cubit.toggleMute();
      expect(cubit.state.isMuted, isFalse);
      expect(engine.isMuted, isFalse);
    });
  });
}
