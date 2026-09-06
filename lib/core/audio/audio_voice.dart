import 'dart:async';
import 'package:audioplayers/audioplayers.dart';

/// Managed audio voice wrapper for a single pooled AudioPlayer instance.
class AudioVoice {
  final int id;
  final AudioPlayer player;
  bool isPlaying = false;
  DateTime lastPlayTime = DateTime.fromMillisecondsSinceEpoch(0);
  String? currentCue;
  String? currentCategory;
  StreamSubscription? _completeSub;
  Timer? _safetyTimer;

  AudioVoice({required this.id, required this.player}) {
    _completeSub = player.onPlayerComplete.listen((_) {
      _safetyTimer?.cancel();
      isPlaying = false;
      currentCue = null;
      currentCategory = null;
    });
  }

  Future<void> play(
    Source source, {
    required double volume,
    required String cue,
    required String category,
  }) async {
    _safetyTimer?.cancel();
    isPlaying = true;
    lastPlayTime = DateTime.now();
    currentCue = cue;
    currentCategory = category;

    _safetyTimer = Timer(const Duration(seconds: 15), () {
      isPlaying = false;
      currentCue = null;
      currentCategory = null;
    });

    try {
      await player.stop();
      await player.setVolume(volume);
      await player.play(source, mode: PlayerMode.mediaPlayer);
    } catch (_) {
      // Audio playback errors are non-fatal to gameplay
      _safetyTimer?.cancel();
      isPlaying = false;
      currentCue = null;
      currentCategory = null;
    }
  }

  Future<void> stop() async {
    _safetyTimer?.cancel();
    isPlaying = false;
    currentCue = null;
    currentCategory = null;
    try {
      await player.stop();
    } catch (_) {}
  }

  Future<void> setVolume(double volume) async {
    if (isPlaying) {
      try {
        await player.setVolume(volume);
      } catch (_) {}
    }
  }

  Future<void> dispose() async {
    _safetyTimer?.cancel();
    await _completeSub?.cancel();
    try {
      await player.stop();
      await player.dispose();
    } catch (_) {}
  }
}
