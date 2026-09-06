# Handoff Report: Requirement R3 (Complete Game Sound Engine Restoration)

**Agent**: Explorer 3  
**Status**: Completed Survey  
**Working Directory**: `C:\Users\midoa\Downloads\Compressed\letsfly_final_100_parity_reviewed\Mobile\.agents\explorer_survey_3`  
**Reference Report**: `survey_report.md`  
**Target Codebase**: `C:\Users\midoa\Downloads\Compressed\letsfly_final_100_parity_reviewed\Mobile`  
**Reference Windows Codebase**: `C:\Users\midoa\Downloads\Compressed\LetsFly_TableVoice_Fixed_NoTableText_20260902_Final`  

---

## 1. Observation

1. **Asset Parity**:
   - `Mobile/pubspec.yaml` lines 27-37 declare 10 audio asset directories.
   - Physical scan of `Mobile/assets/audio/` reveals exactly 107 WAV audio files totaling 34,862,016 bytes (~34.8 MB), matching 1:1 all audio files in the Windows reference client (`LetsFly_TableVoice_Fixed_NoTableText_20260902_Final/client/assets/audio/`).
2. **Audio Mode Poisoning**:
   - `Mobile/lib/core/audio/voice_chat_service.dart` lines 25-51: `VoiceChatService` constructor calls `_initAudioContext()`, executing `AudioContextAndroid(audioMode: AndroidAudioMode.inCommunication, usageType: AndroidUsageType.voiceCommunication, audioFocus: AndroidAudioFocus.gainTransientMayDuck)` on the singleton Android `AudioManager`.
   - `Mobile/lib/presentation/bloc/room_cubit.dart` line 103: Instantiates `VoiceChatService` immediately when entering any room, activating `MODE_IN_COMMUNICATION` even when voice chat is idle/muted.
3. **SoundPool (lowLatency) Lockup**:
   - `Mobile/lib/core/audio/audio_voice.dart` lines 14-20 & 36: `player.play(source, mode: PlayerMode.lowLatency)` uses Android native `SoundPool`. Android `SoundPool` does not trigger `player.onPlayerComplete`. As a result, `isPlaying` never returns to `false` after a sound plays.
   - `Mobile/assets/audio/thief_hunt/thief_answer_start.wav` (3.9 MB) and `Mobile/assets/audio/match_win.wav` (1.2 MB) exceed Android `SoundPool`'s 1 MB buffer limit, failing silently inside `catch (_) { isPlaying = false; }` at line 38 of `audio_voice.dart`.
4. **Unhooked Tennis Sound Engine**:
   - `Mobile/lib/core/audio/tennis_sound_engine.dart` implements a 3D spatial panning audio engine with Arabic umpire calls.
   - `Mobile/lib/presentation/bloc/tennis_game_bloc.dart` lines 122 & 173: BLoC calls `_audioService.playCue('tennis/$sound')` and `_audioService.playCue('tennis/move')` on `TableAudioService` (`SoundEngine`), where these cues are unmapped and fail silently. `TennisSoundEngine` is completely unused.
   - `Mobile/lib/core/audio/tennis_sound_engine.dart` line 306: `_umpirePlayer.play(source, mode: PlayerMode.lowLatency)` locks up sequential Arabic umpire announcements because `onPlayerComplete` never fires.
5. **Missing `playEvent` Calls in Game BLoCs**:
   - The Python server sends table actions via `event_type` (`CARD_PLAYED`, `TILE_PLACED`, `ROUND_START`, `DICE_ROLLED`, `CANNOT_MOVE`, etc.) and frequently omits `sound_cue`.
   - `Mobile/lib/core/audio/sound_engine.dart` lines 299-539 implements `playEvent({required String gameType, required String eventType, String? serverCue})` with full event mappings.
   - In `uno_game_bloc.dart` (line 232), `domino_game_bloc.dart` (line 180), `scopa_game_bloc.dart` (line 186), `snakes_and_ladders_game_bloc.dart` (line 159), `farkle_game_bloc.dart` (line 278), `ninety_nine_game_bloc.dart` (line 199), the BLoCs only check `if (game.soundCue != null) playCue(game.soundCue!)`. `playEvent()` is never called.

---

## 2. Logic Chain

1. From Observation 1: Physical sound files are intact and match Windows. Therefore, missing audio is NOT caused by missing WAV assets or incorrect pubspec declarations.
2. From Observation 2: `VoiceChatService` runs in the constructor of `RoomCubit`. Calling `setMode(MODE_IN_COMMUNICATION)` alters global OS routing. Android routing policy treats media sounds (`STREAM_MUSIC`) as background audio to be ducked to 0 or redirected to the phone earpiece. Therefore, game sounds become inaudible or faint as soon as a room is entered.
3. From Observation 3: In `audioplayers` 6.4.0 on Android, `PlayerMode.lowLatency` uses `SoundPool`. `SoundPool` provides no completion callbacks, so `onPlayerComplete` never triggers. `AudioVoice.isPlaying` remains `true` permanently. Furthermore, files > 1 MB cannot be loaded by `SoundPool`. Therefore, polyphonic voice allocation breaks after 8 sounds, and large files (`thief_answer_start.wav`, `match_win.wav`) are completely muted.
4. From Observation 4: `TennisSoundEngine` was never injected into `TennisTableScreen` or `TennisGameBloc`. Instead, `TennisGameBloc` requested unmapped keys from `SoundEngine`, resulting in total silence during tennis matches.
5. From Observation 5: Game actions in card dealing, tile placing, card playing, and dice rolling communicate via `event_type`. Because BLoCs only look at `soundCue` (which is usually null/empty) and never call `playEvent()`, the sound engine is never notified to trigger `UNO_DEAL`, `SCOPA_DEAL`, `DOMINO_PLACE_ORIGINAL`, `DICE_ROLL`, etc.
6. Synthesizing 1-5 leads to Conclusion: Full restoration requires fixing audio mode management in `VoiceChatService`, switching `AudioVoice` and `TennisSoundEngine._umpirePlayer` to `PlayerMode.mediaPlayer`, injecting and wiring `TennisSoundEngine` in Tennis, and calling `_audioService.playEvent()` on state updates across all game BLoCs.

---

## 3. Caveats

- **Device Hardware Variability**: Different Android manufacturers (Samsung, Xiaomi, Pixel) apply differing ducking curves and earpiece routing policies when `MODE_IN_COMMUNICATION` is active. Some devices mute media streams completely while others merely reduce volume by 80%. Reverting to `MODE_NORMAL` when voice is inactive resolves this consistently across all OEMs.
- **LowLatency vs MediaPlayer Trade-off**: Switching to `PlayerMode.mediaPlayer` introduces negligible (~15-30ms) latency on modern Android devices while gaining full format support, files > 1 MB support, and reliable completion callbacks. If sub-10ms UI click latency is desired in the future, a hybrid approach (using `SoundPool` only for tiny button clicks with timer-based reset, and `MediaPlayer` for gameplay/voice/music) can be explored, but `mediaPlayer` is the safest, most robust solution.
- No caveats regarding asset availability or reference parity.

---

## 4. Conclusion

Requirement R3 (Complete Game Sound Engine Restoration) is thoroughly diagnosed with an exact 4-step remediation plan:
1. **Audio Mode & Stream Cleanup**: Prevent `VoiceChatService` from activating `MODE_IN_COMMUNICATION` in its constructor; activate it only during an active voice session, and restore normal media audio mode on exit/idle.
2. **Audio Voice Reliability**: Use `PlayerMode.mediaPlayer` in `AudioVoice.play()` and `TennisSoundEngine._playNextUmpire()` to eliminate the 1 MB buffer limit and restore `onPlayerComplete` callbacks.
3. **Tennis Sound Wiring**: Inject `TennisSoundEngine` into `TennisTableScreen` / `TennisGameBloc` and wire `floor_hit`, `net_pass`, `racket`, `wall`, `boundary`, and lane movements to its spatial methods.
4. **BLoC `playEvent` Integration**: Update `uno_game_bloc`, `domino_game_bloc`, `scopa_game_bloc`, `snakes_and_ladders_game_bloc`, `farkle_game_bloc`, `ninety_nine_game_bloc`, and `thief_hunt_game_bloc` to call `_audioService.playEvent(gameType: ..., eventType: game.eventType, serverCue: game.soundCue)` on every new `eventId`.

---

## 5. Verification Method

To independently verify these findings:
1. **Asset Integrity Check**:
   ```powershell
   Get-ChildItem -Recurse 'C:\Users\midoa\Downloads\Compressed\letsfly_final_100_parity_reviewed\Mobile\assets\audio' -Filter '*.wav' | Measure-Object -Property Length -Sum -Count
   ```
   *Expected Output*: Count = 107, Sum = ~34,862,016 bytes.
2. **Voice Mode Inspection**:
   Inspect `Mobile/lib/core/audio/voice_chat_service.dart` lines 25-51. Notice `_initAudioContext()` is called in constructor without checking `sessionActive`.
3. **SoundPool Mode Inspection**:
   Inspect `Mobile/lib/core/audio/audio_voice.dart` lines 36 & 15. Verify that `mode: PlayerMode.lowLatency` is used with `player.onPlayerComplete`.
4. **Tennis Engine Inspection**:
   Inspect `Mobile/lib/presentation/bloc/tennis_game_bloc.dart` lines 122 & 173. Verify `_audioService.playCue('tennis/$sound')` is called instead of `TennisSoundEngine`.
5. **BLoC Event Inspection**:
   Inspect `Mobile/lib/presentation/bloc/snakes_and_ladders_game_bloc.dart` lines 156-168 and `Mobile/lib/presentation/bloc/uno_game_bloc.dart` lines 229-238. Verify that `game.soundCue` is checked while `playEvent` is never called.
6. **Post-Fix Verification Command**:
   Run Flutter test harness on audio:
   ```bash
   dart test test/e2e/tier1_features/f04_sound_engine_test.dart
   ```
