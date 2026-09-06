# DISPATCH

## 2026-09-06T22:18:56Z

Implement Milestone 2 (Requirement R3: Complete Game Sound Engine Restoration).

Working directory: `C:\Users\midoa\Downloads\Compressed\letsfly_final_100_parity_reviewed\Mobile\.agents\worker_m2`
Workspace directory: `C:\Users\midoa\Downloads\Compressed\letsfly_final_100_parity_reviewed\Mobile`
Reference Windows codebase: `C:\Users\midoa\Downloads\Compressed\LetsFly_TableVoice_Fixed_NoTableText_20260902_Final`

Write Ownership:
- lib/core/audio/voice_chat_service.dart
- lib/core/audio/audio_voice.dart
- lib/core/audio/sound_engine.dart
- lib/core/audio/tennis_sound_engine.dart
- lib/presentation/screens/game/tennis_table_screen.dart
- lib/presentation/bloc/tennis_game_bloc.dart
- lib/presentation/bloc/uno_game_bloc.dart
- lib/presentation/bloc/domino_game_bloc.dart
- lib/presentation/bloc/scopa_game_bloc.dart
- lib/presentation/bloc/snakes_and_ladders_game_bloc.dart
- lib/presentation/bloc/farkle_game_bloc.dart
- lib/presentation/bloc/ninety_nine_game_bloc.dart
- lib/presentation/bloc/thief_hunt_game_bloc.dart

Tasks:
1. lib/core/audio/voice_chat_service.dart: Remove _initAudioContext() from constructor so room entry does NOT poison global Android audio mode to inCommunication. Only configure VoIP audio context inside joinSession(). In leaveSession() and detach(), restore normal media audio context (AndroidAudioMode.normal, AndroidUsageType.game, speakerphone enabled).
2. lib/core/audio/audio_voice.dart: Change PlayerMode.lowLatency to PlayerMode.mediaPlayer so onPlayerComplete fires reliably and files > 1MB play without SoundPool failure. Ensure isPlaying is reset to false on completion, and add a safety timeout timer (e.g. 15s) so voices never get permanently stuck.
3. lib/core/audio/sound_engine.dart: In initialize(), configure AudioContextAndroid with usageType: AndroidUsageType.game, contentType: AndroidContentType.sonification, audioFocus: AndroidAudioFocus.gainTransientMayDuck, speakerphone from preferences.
4. lib/core/audio/tennis_sound_engine.dart: In _playNextUmpire(), switch _umpirePlayer to PlayerMode.mediaPlayer so onPlayerComplete fires and umpire announcements chain sequentially.
5. lib/presentation/screens/game/tennis_table_screen.dart & lib/presentation/bloc/tennis_game_bloc.dart: Instantiate and inject TennisSoundEngine. Wire tennis sound cues (floor_hit, net_pass, racket, wall, boundary) and lane movement to TennisSoundEngine. Suppress verbose screen reader speech during active rally so spatial audio cues are clear.
6. Game BLoCs (_onStateUpdated): Ensure _audioService.playEvent() is invoked on server event_type whenever game.eventId > _lastEventId:
   - uno_game_bloc.dart: gameType: 'UNO'
   - domino_game_bloc.dart: gameType: (game.scoringMode != null || game.openEndsSum != null) ? 'AMERICAN_DOMINO' : 'DOMINO'
   - scopa_game_bloc.dart: gameType: 'SCOPA'
   - snakes_and_ladders_game_bloc.dart: gameType: 'SNAKES_LADDERS'
   - farkle_game_bloc.dart: gameType: 'FARKLE'
   - ninety_nine_game_bloc.dart: gameType: 'NINETY_NINE'
   - thief_hunt_game_bloc.dart: gameType: 'THIEF_HUNT'
7. Verification: Run dart analyze or test scripts (e.g. dart test test/stress_polyphonic_pool.dart or test/adversarial_sound_stress.dart). Confirm no compile errors or regressions.
8. Write detailed handoff.md in your working directory and message orchestrator when done.
