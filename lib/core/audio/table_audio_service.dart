import 'dart:async';

/// Core contract for audio playback and volume control in Let's Fly.
/// Conforms to PROJECT.md § Interface Contracts.
abstract class TableAudioService {
  /// Play a semantic sound cue (e.g. SoundCues.unoPlace, SoundCues.turnStart).
  Future<void> playCue(String cueName);

  /// Play event cues based on game type and server event type.
  Future<void> playEvent({
    required String gameType,
    required String eventType,
    String? serverCue,
  });

  /// Set master volume scaling between 0.0 and 1.0.
  void setMasterVolume(double volume);

  /// Set volume for a specific category ('game' or 'effects').
  void setCategoryVolume(String category, double volume);

  /// Toggle or set mute status.
  void setMute(bool muted);

  /// Master volume level (0.0 - 1.0).
  double get masterVolume;
  double getCategoryVolume(String category);

  /// Mute status.
  bool get isMuted;

  /// Stop all currently playing audio cues.
  Future<void> stopAll();

  /// Dispose of all audio players and pool resources.
  Future<void> dispose();
}
