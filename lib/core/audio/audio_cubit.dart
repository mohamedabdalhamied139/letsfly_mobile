import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'table_audio_service.dart';
import '../settings/settings_store.dart';

/// Immutable state for AudioCubit.
class AudioState extends Equatable {
  final double masterVolume;
  final double effectsVolume;
  final double gameVolume;
  final bool isMuted;

  const AudioState({
    required this.masterVolume,
    required this.effectsVolume,
    required this.gameVolume,
    required this.isMuted,
  });

  AudioState copyWith({
    double? masterVolume,
    double? effectsVolume,
    double? gameVolume,
    bool? isMuted,
  }) {
    return AudioState(
      masterVolume: masterVolume ?? this.masterVolume,
      effectsVolume: effectsVolume ?? this.effectsVolume,
      gameVolume: gameVolume ?? this.gameVolume,
      isMuted: isMuted ?? this.isMuted,
    );
  }

  @override
  List<Object?> get props => [masterVolume, effectsVolume, gameVolume, isMuted];
}

/// Cubit managing reactive audio settings and triggering sound cues.
class AudioCubit extends Cubit<AudioState> {
  final TableAudioService _audioService;
  final SettingsStore? _settings;

  AudioCubit(this._audioService, {SettingsStore? settings})
      : _settings = settings,
        super(AudioState(
          masterVolume: _audioService.masterVolume,
          effectsVolume: _audioService.getCategoryVolume('effects'),
          gameVolume: _audioService.getCategoryVolume('game'),
          isMuted: _audioService.isMuted,
        ));

  void setMasterVolume(double volume) {
    _audioService.setMasterVolume(volume);
    _settings?.setMasterVolume(volume);
    emit(state.copyWith(masterVolume: _audioService.masterVolume));
  }

  void setEffectsVolume(double volume) {
    _audioService.setCategoryVolume('effects', volume);
    _settings?.setEffectsVolume(volume);
    emit(state.copyWith(effectsVolume: volume.clamp(0.0, 1.0)));
  }

  void setGameVolume(double volume) {
    _audioService.setCategoryVolume('game', volume);
    _settings?.setGameVolume(volume);
    emit(state.copyWith(gameVolume: volume.clamp(0.0, 1.0)));
  }

  void setMute(bool muted) {
    _audioService.setMute(muted);
    _settings?.setMuteAllSounds(muted);
    emit(state.copyWith(isMuted: muted));
  }

  void toggleMute() {
    setMute(!state.isMuted);
  }

  Future<void> playCue(String cueName) async {
    await _audioService.playCue(cueName);
  }

  Future<void> playEvent({
    required String gameType,
    required String eventType,
    String? serverCue,
  }) async {
    await _audioService.playEvent(
      gameType: gameType,
      eventType: eventType,
      serverCue: serverCue,
    );
  }
}
