import 'dart:async';
import 'dart:math';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'audio_voice.dart';

/// Dedicated Tennis Sound Engine featuring 3-lane stereo spatialization
/// and sequential Arabic umpire voice announcements.
///
/// Spatial Panning:
///   - Lane -1 (Left):   Plays *_left.wav   (95% Left channel, pan = -1.0)
///   - Lane  0 (Center): Plays *_center.wav (50/50 Balanced Center, pan = 0.0)
///   - Lane +1 (Right):  Plays *_right.wav  (95% Right channel, pan = +1.0)
///
/// Conforms to PROJECT.md interface:
///   - Future<void> playSpatialSfx(String sfxName, double pan)
///   - Future<void> playUmpireCall(String callName)
class TennisSoundEngine {
  static const int sfxPoolSize = 4;
  static const String prefMasterVolume = 'sound_master_volume';
  static const String prefGameVolume = 'sound_game_volume';
  static const String prefMuted = 'sound_muted';

  final List<AudioVoice> _sfxVoicePool = [];
  late final AudioPlayer _umpirePlayer;
  final AudioPlayer Function()? _playerFactory;
  bool _initialized = false;
  int _roundRobinIndex = 0;

  double _masterVolume = 1.0;
  double _gameVolume = 1.0;
  bool _muted = false;

  final List<String> _umpireQueue = [];
  bool _isUmpirePlaying = false;
  StreamSubscription? _umpireCompleteSub;
  Timer? _umpireSafetyTimer;

  static const List<String> gameplaySfxFilenames = [
    'jm_left.wav', 'jm_center.wav', 'jm_right.wav',
    'hit_1_left.wav', 'hit_1_center.wav', 'hit_1_right.wav',
    'hit_2_left.wav', 'hit_2_center.wav', 'hit_2_right.wav',
    'air_left.wav', 'air_center.wav', 'air_right.wav',
    'bounce_left.wav', 'bounce_center.wav', 'bounce_right.wav',
    'claps_1.wav', 'claps_2.wav',
  ];

  static const List<String> umpireFilenames = [
    'advantage_receiver.wav', 'advantage_server.wav', 'deuce.wav',
    'fault.wav', 'game_won.wav', 'match_won.wav', 'set_won.wav',
    'score_0_15.wav', 'score_0_30.wav', 'score_0_40.wav',
    'score_15_0.wav', 'score_15_30.wav', 'score_15_40.wav', 'score_15_all.wav',
    'score_30_0.wav', 'score_30_15.wav', 'score_30_40.wav', 'score_30_all.wav',
    'score_40_0.wav', 'score_40_15.wav', 'score_40_30.wav',
  ];

  final Map<String, AssetSource> _cachedSfxSources = {};
  final Map<String, AssetSource> _cachedUmpireSources = {};

  TennisSoundEngine({AudioPlayer Function()? playerFactory})
      : _playerFactory = playerFactory {
    _initSources();
  }

  void _initSources() {
    for (final fname in gameplaySfxFilenames) {
      _cachedSfxSources[fname] = AssetSource('audio/tennis/$fname');
    }
    for (final fname in umpireFilenames) {
      _cachedUmpireSources[fname] = AssetSource('audio/tennis/arabic_umpire/$fname');
    }
  }

  bool get isInitialized => _initialized;
  bool get isMuted => _muted;
  double get effectiveVolume => _muted ? 0.0 : max(0.0, min(1.0, _masterVolume * _gameVolume));

  Future<void> initialize({SharedPreferences? prefs}) async {
    if (_initialized) return;

    try {
      await AudioPlayer.global.setAudioContext(
        AudioContext(
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.ambient,
            options: const {AVAudioSessionOptions.mixWithOthers},
          ),
          android: AudioContextAndroid(
            isSpeakerphoneOn: prefs?.getString('settings.audio.speaker') == 'speaker' ||
                prefs?.getString('settings.audio.speaker') == null ||
                prefs?.getString('settings.audio.speaker') == 'default',
            stayAwake: false,
            contentType: AndroidContentType.sonification,
            usageType: AndroidUsageType.game,
            audioFocus: AndroidAudioFocus.gainTransientMayDuck,
          ),
        ),
      );
    } catch (e) {
      debugPrint('[TennisSoundEngine] AudioContext init warning: $e');
    }

    for (var i = 0; i < sfxPoolSize; i++) {
      final p = _playerFactory != null ? _playerFactory() : AudioPlayer();
      _sfxVoicePool.add(AudioVoice(id: i, player: p));
    }

    _umpirePlayer = _playerFactory != null ? _playerFactory() : AudioPlayer();
    _umpireCompleteSub = _umpirePlayer.onPlayerComplete.listen((_) {
      _umpireSafetyTimer?.cancel();
      _isUmpirePlaying = false;
      _playNextUmpire();
    });

    if (prefs != null) {
      _masterVolume = prefs.getDouble(prefMasterVolume) ?? 1.0;
      _gameVolume = prefs.getDouble(prefGameVolume) ?? 1.0;
      _muted = prefs.getBool(prefMuted) ?? false;
    }

    _initialized = true;
  }

  static String laneSuffix(int lane) {
    if (lane < 0) return 'left';
    if (lane > 0) return 'right';
    return 'center';
  }

  static String laneSuffixFromPan(double pan) {
    if (pan < -0.33) return 'left';
    if (pan > 0.33) return 'right';
    return 'center';
  }

  static double lanePan(int lane) {
    if (lane < 0) return -1.0;
    if (lane > 0) return 1.0;
    return 0.0;
  }

  Future<void> playSpatialSfx(String sfxName, double pan, {double volumeScale = 1.0}) async {
    if (!_initialized) await initialize();
    if (_muted || effectiveVolume <= 0.0) return;

    final suffix = laneSuffixFromPan(pan);
    String filename = sfxName;

    if (!filename.endsWith('.wav')) {
      if (filename.contains('_left') || filename.contains('_right') || filename.contains('_center')) {
        filename = '$filename.wav';
      } else {
        filename = '${filename}_$suffix.wav';
      }
    }

    var source = _cachedSfxSources[filename];
    if (source == null) {
      final alt = '${sfxName.replaceAll(RegExp(r'_(left|center|right)\.wav$'), '')}_$suffix.wav';
      source = _cachedSfxSources[alt];
      if (source == null) {
        debugPrint('[TennisSoundEngine] Unknown SFX asset: $filename (ignored)');
        return;
      }
    }

    final targetVol = max(0.0, min(1.0, effectiveVolume * volumeScale));

    AudioVoice? candidate;
    for (final voice in _sfxVoicePool) {
      if (!voice.isPlaying) {
        candidate = voice;
        break;
      }
    }

    if (candidate == null && _sfxVoicePool.isNotEmpty) {
      candidate = _sfxVoicePool[_roundRobinIndex];
      _roundRobinIndex = (_roundRobinIndex + 1) % _sfxVoicePool.length;
    }

    if (candidate != null) {
      try {
        await candidate.player.setBalance(pan);
      } catch (_) {}
      await candidate.play(source, volume: targetVol, cue: filename, category: 'game');
    }
  }

  Future<void> _playSfxFile(String filename, {double volumeScale = 1.0, double pan = 0.0}) async {
    if (!_initialized) await initialize();
    if (_muted || effectiveVolume <= 0.0) return;

    final source = _cachedSfxSources[filename];
    if (source == null) return;

    final targetVol = max(0.0, min(1.0, effectiveVolume * volumeScale));

    AudioVoice? candidate;
    for (final voice in _sfxVoicePool) {
      if (!voice.isPlaying) {
        candidate = voice;
        break;
      }
    }
    if (candidate == null && _sfxVoicePool.isNotEmpty) {
      candidate = _sfxVoicePool[_roundRobinIndex];
      _roundRobinIndex = (_roundRobinIndex + 1) % _sfxVoicePool.length;
    }

    if (candidate != null) {
      try {
        await candidate.player.setBalance(pan);
      } catch (_) {}
      await candidate.play(source, volume: targetVol, cue: filename, category: 'game');
    }
  }

  // High-Level Gameplay Methods (1:1 with Python reference)
  Future<void> playMove(int lane) async {
    final suffix = laneSuffix(lane);
    await _playSfxFile('jm_$suffix.wav', volumeScale: 0.75, pan: lanePan(lane));
  }

  Future<void> playRacketHit([int lane = 0]) async {
    final suffix = laneSuffix(lane);
    await _playSfxFile('hit_1_$suffix.wav', volumeScale: 1.0, pan: lanePan(lane));
  }

  Future<void> playOpponentHit([int lane = 0]) async {
    final suffix = laneSuffix(lane);
    await _playSfxFile('hit_2_$suffix.wav', volumeScale: 1.0, pan: lanePan(lane));
  }

  Future<void> playNetPass([int lane = 0]) async {
    final suffix = laneSuffix(lane);
    await _playSfxFile('air_$suffix.wav', volumeScale: 0.80, pan: lanePan(lane));
  }

  Future<void> playFloorHit([int lane = 0, double volume = 1.0]) async {
    final suffix = laneSuffix(lane);
    await _playSfxFile('bounce_$suffix.wav', volumeScale: volume, pan: lanePan(lane));
  }

  Future<void> playCrowd({int variant = 0, double volume = 1.0}) async {
    final String fname;
    if (variant == 1) {
      fname = 'claps_1.wav';
    } else if (variant == 2) {
      fname = 'claps_2.wav';
    } else {
      fname = Random().nextBool() ? 'claps_1.wav' : 'claps_2.wav';
    }
    await _playSfxFile(fname, volumeScale: volume, pan: 0.0);
  }

  Future<void> playPointScored({bool isLocalWinner = true}) async {
    await playCrowd(variant: isLocalWinner ? 2 : 1, volume: 1.0);
  }

  Future<void> playMiss() async {
    await playCrowd(variant: 1, volume: 1.0);
  }

  Future<void> playWin() async {
    await playCrowd(variant: 2, volume: 1.0);
  }

  // Sequential Arabic Umpire Voice Calls
  Future<void> playUmpireCall(String callName) async {
    var fname = callName.trim();
    if (!fname.endsWith('.wav')) {
      fname = '$fname.wav';
    }
    _umpireQueue.add(fname);
    if (!_isUmpirePlaying) {
      _playNextUmpire();
    }
  }

  Future<void> _playNextUmpire() async {
    if (_umpireQueue.isEmpty) {
      _umpireSafetyTimer?.cancel();
      _isUmpirePlaying = false;
      return;
    }

    if (!_initialized) await initialize();
    if (_muted || effectiveVolume <= 0.0) {
      _umpireSafetyTimer?.cancel();
      _umpireQueue.clear();
      _isUmpirePlaying = false;
      return;
    }

    final fname = _umpireQueue.removeAt(0);
    final source = _cachedUmpireSources[fname];
    if (source == null) {
      debugPrint('[TennisSoundEngine] Unknown umpire file: $fname');
      _playNextUmpire();
      return;
    }

    _umpireSafetyTimer?.cancel();
    _isUmpirePlaying = true;
    _umpireSafetyTimer = Timer(const Duration(seconds: 10), () {
      _isUmpirePlaying = false;
      _playNextUmpire();
    });

    try {
      await _umpirePlayer.stop();
      await _umpirePlayer.setVolume(effectiveVolume);
      await _umpirePlayer.play(source, mode: PlayerMode.mediaPlayer);
    } catch (_) {
      _umpireSafetyTimer?.cancel();
      _isUmpirePlaying = false;
      _playNextUmpire();
    }
  }

  Future<void> playScoreAnnouncement(
    String p0Pts,
    String p1Pts, {
    int serverIdx = 0,
    bool isTiebreak = false,
    Map<dynamic, dynamic>? tiebreakPoints,
    void Function(String)? speak,
  }) async {
    final p0 = p0Pts.trim().toUpperCase();
    final p1 = p1Pts.trim().toUpperCase();

    if (isTiebreak || (tiebreakPoints != null && (p0 == '0' && p1 == '0'))) {
      if (tiebreakPoints != null) {
        final tb0 = tiebreakPoints[0] ?? tiebreakPoints['0'] ?? 0;
        final tb1 = tiebreakPoints[1] ?? tiebreakPoints['1'] ?? 0;
        final text = '$tb0 - $tb1';
        if (speak != null) {
          speak(text);
        } else {
          try {
            SemanticsService.announce(text, TextDirection.rtl);
          } catch (_) {}
        }
      }
      return;
    }

    if (p0 == '0' && p1 == '0') {
      return;
    }

    final String fname;
    if (p0 == 'AD' && p1 == '40') {
      fname = serverIdx == 0 ? 'advantage_server.wav' : 'advantage_receiver.wav';
    } else if (p1 == 'AD' && p0 == '40') {
      fname = serverIdx == 1 ? 'advantage_server.wav' : 'advantage_receiver.wav';
    } else if (p0 == '40' && p1 == '40') {
      fname = 'deuce.wav';
    } else if (p0 == '15' && p1 == '15') {
      fname = 'score_15_all.wav';
    } else if (p0 == '30' && p1 == '30') {
      fname = 'score_30_all.wav';
    } else if (const {
      '0_15', '0_30', '0_40',
      '15_0', '15_30', '15_40',
      '30_0', '30_15', '30_40',
      '40_0', '40_15', '40_30',
    }.contains('${p0}_$p1')) {
      fname = 'score_${p0}_$p1.wav';
    } else {
      return;
    }

    await playUmpireCall(fname);
  }

  Future<void> playGameWon() => playUmpireCall('game_won.wav');
  Future<void> playSetWon() => playUmpireCall('set_won.wav');
  Future<void> playMatchWon() => playUmpireCall('match_won.wav');
  Future<void> playFault() => playUmpireCall('fault.wav');

  void setMasterVolume(double volume) {
    _masterVolume = max(0.0, min(1.0, volume));
    _updateVolumes();
  }

  void setGameVolume(double volume) {
    _gameVolume = max(0.0, min(1.0, volume));
    _updateVolumes();
  }

  void setMute(bool muted) {
    _muted = muted;
    _updateVolumes();
  }

  void _updateVolumes() {
    final vol = effectiveVolume;
    for (final voice in _sfxVoicePool) {
      if (voice.isPlaying) {
        voice.setVolume(vol);
      }
    }
    if (_isUmpirePlaying) {
      _umpirePlayer.setVolume(vol);
    }
  }

  Future<void> stopAll() async {
    _umpireSafetyTimer?.cancel();
    _umpireQueue.clear();
    _isUmpirePlaying = false;
    await _umpirePlayer.stop();
    for (final voice in _sfxVoicePool) {
      await voice.stop();
    }
  }

  Future<void> dispose() async {
    _umpireSafetyTimer?.cancel();
    await stopAll();
    await _umpireCompleteSub?.cancel();
    await _umpirePlayer.dispose();
    for (final voice in _sfxVoicePool) {
      await voice.dispose();
    }
    _sfxVoicePool.clear();
    _initialized = false;
  }
}
