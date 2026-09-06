# Handoff Report: Reviewer & Adversarial Critic — Milestone 2 (R3: Complete Game Sound Engine Restoration)

## 1. Observation

### Verification Test Executions:
1. `dart .agents/worker_m2/test_sound_engine_restoration.dart`
   - Command result: Exited with code 0.
   - Verbatim output:
     ```
     ======================================================================
        MILESTONE 2: COMPLETE GAME SOUND ENGINE RESTORATION VERIFICATION
     ======================================================================
       [PASS] Test 1: VoiceChatService constructor does NOT call _initAudioContext()
       [PASS] Test 2: VoiceChatService sets VoIP audio context in joinSession
       [PASS] Test 3: VoiceChatService restores normal audio context on leaveSession and detach
       [PASS] Test 4: AudioVoice uses PlayerMode.mediaPlayer exclusively
       [PASS] Test 5: AudioVoice includes 15s safety timeout timer
       [PASS] Test 6: AudioVoice resets isPlaying to false on complete, stop, and error
       [PASS] Test 7: SoundEngine configures AudioContextAndroid with gainTransientMayDuck and game usage
       [PASS] Test 8: TennisSoundEngine _playNextUmpire uses PlayerMode.mediaPlayer
       [PASS] Test 9: TennisSoundEngine includes safety timer for sequential umpire calls
       [PASS] Test 10: TennisTableScreen instantiates and passes TennisSoundEngine to TennisGameBloc
       [PASS] Test 11: TennisGameBloc wires floor_hit, net_pass, racket, wall, and boundary to TennisSoundEngine
       [PASS] Test 12: TennisGameBloc suppresses screen reader speech during active rally
       [PASS] Test 13: uno_game_bloc.dart invokes playEvent with gameType: UNO
       [PASS] Test 14: domino_game_bloc.dart invokes playEvent with AMERICAN_DOMINO or DOMINO
       [PASS] Test 15: scopa_game_bloc.dart invokes playEvent with gameType: SCOPA
       [PASS] Test 16: snakes_and_ladders_game_bloc.dart invokes playEvent with gameType: SNAKES_LADDERS
       [PASS] Test 17: farkle_game_bloc.dart invokes playEvent with gameType: FARKLE
       [PASS] Test 18: ninety_nine_game_bloc.dart invokes playEvent with gameType: NINETY_NINE
       [PASS] Test 19: thief_hunt_game_bloc.dart invokes playEvent with gameType: THIEF_HUNT
     RESULTS: 19 / 19 VERIFICATION CHECKS PASSED (100%)
     ```

2. `dart test/stress_polyphonic_pool.dart`
   - Command result: Exited with code 0.
   - Verbatim output:
     ```
     === STRESS TEST 1: Rapid Burst of 25 Simultaneous Requests (>20) ===
     [PASS] 25 simultaneous requests completed without unhandled exceptions.
     [PASS] Voice pool size strictly bounded: 8 voices.
     === STRESS TEST 2: Massive Burst of 100 Requests with Random Completion ===
     [PASS] 100 rapid requests processed successfully.
     === STRESS TEST 3: Hardware Exception Injection Resilience ===
     [PASS] Engine gracefully survived hardware exceptions without propagating errors to caller.
     === STRESS TEST 4: Round-Robin Eviction Order Verification ===
     [PASS] Round-robin voice stealing functions correctly with 100% predictability.
     === STRESS TEST 5: Zero-Volume Voice Allocation Leak Guard ===
     [PASS] Zero volume unmuted request safely discarded without voice allocation.
     ALL EMPIRICAL STRESS TESTS COMPLETED WITH 100% SUCCESS
     ```

3. `dart test/adversarial_sound_stress.dart`
   - Command result: Exited with code 0.
   - Verbatim output:
     ```
     [PASS] Challenge 1: 50 simultaneous bursts: Voice pool bounded to 8, plays == 50
     [PASS] Challenge 2: SoundCues.cardPlayed resolves to audio/uno/place.wav cleanly
     [PASS] Challenge 3: Zero-volume guard (master=0.0): 30 cues completely discarded (0 plays, 0 active voices)
     [PASS] Challenge 4: Category-level zero-volume guard: game discarded, effects plays
     [PASS] Challenge 5: Mute guard (_muted=true): 25 cues discarded without voice allocation
     [PASS] Challenge 6: Volume clamping: negative clamped to 0.0 (discarded), excessive clamped to 1.0
     [PASS] Challenge 7: Predictable round-robin voice stealing across 3 full cycles (24 steals)
     [PASS] Challenge 8: 100 mixed concurrent operations (volume jitter + random completion): No deadlocks or leaks
     [PASS] Challenge 9: Survives simultaneous hardware faults across multiple pooled players without unhandled rejections
     RESULTS: 9 / 9 CHALLENGES PASSED
     ```

4. Physical Asset Integrity Audit (`.agents/reviewer_m2_1/check_assets.dart`):
   - Checked all 107 sound files referenced across `SoundEngine.soundRegistry`, `TennisSoundEngine.gameplaySfxFilenames`, and `TennisSoundEngine.umpireFilenames`.
   - Result: `Checked 107 assets. Missing/empty: 0`. 100% of files physically exist on disk and have non-zero size.
   - Verified file size extremes: `assets/audio/thief_hunt/thief_answer_start.wav` is 3,918,586 bytes (~3.9MB) and `assets/audio/match_win.wav` is 1,213,518 bytes (~1.2MB), which exceed Android's 1MB SoundPool buffer limit and confirm the requirement for `PlayerMode.mediaPlayer`.

### Codebase Observations:
1. `lib/core/audio/voice_chat_service.dart`:
   - Line 25: Constructor `VoiceChatService({required this.roomWs});` no longer calls `_initAudioContext()`.
   - Lines 27-49: `_setVoipAudioContext()` sets `AndroidAudioMode.inCommunication` and `isSpeakerphoneOn: true` only when `joinSession()` is called (line 123).
   - Lines 51-72: `_restoreNormalAudioContext()` sets `AndroidAudioMode.normal`, `AndroidUsageType.game`, `AndroidContentType.sonification`, and `AndroidAudioFocus.gainTransientMayDuck`.
   - Lines 84-92 (`detach()`) and lines 153-162 (`leaveSession()`): both invoke `_restoreNormalAudioContext()`.

2. `lib/core/audio/audio_voice.dart`:
   - Lines 42-46: `await player.play(source, mode: PlayerMode.mediaPlayer);`
   - Lines 36-40: Safety timer initialized: `_safetyTimer = Timer(const Duration(seconds: 15), ...)`.
   - Lines 48-52: Exception handler cancels `_safetyTimer` and resets `isPlaying = false`.
   - Lines 55-63 (`stop()`) and lines 73-80 (`dispose()`): both cancel `_safetyTimer` and clean up.

3. `lib/core/audio/tennis_sound_engine.dart`:
   - Line 29: `late final AudioPlayer _umpirePlayer;`
   - Lines 112-117 in `initialize()`:
     ```dart
     _umpirePlayer = _playerFactory != null ? _playerFactory() : AudioPlayer();
     _umpireCompleteSub = _umpirePlayer.onPlayerComplete.listen((_) {
       _umpireSafetyTimer?.cancel();
       _isUmpirePlaying = false;
       _playNextUmpire();
     });
     ```
   - Lines 414-422 in `stopAll()`:
     ```dart
     Future<void> stopAll() async {
       _umpireSafetyTimer?.cancel();
       _umpireQueue.clear();
       _isUmpirePlaying = false;
       await _umpirePlayer.stop();
       for (final voice in _sfxVoicePool) {
         await voice.stop();
       }
     }
     ```
   - Lines 424-434 in `dispose()`:
     ```dart
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
     ```
   - Observed Defect: Neither `stopAll()` nor `dispose()` checks `if (!_initialized) return;`.
   - Reproduction (`.agents/reviewer_m2_1/test_tennis_uninit_dispose.dart`): calling `dispose()` or `stopAll()` on an instance of `TennisSoundEngine` before `initialize()` has run throws:
     `LateInitializationError: Field '_umpirePlayer' has not been initialized.`

4. `lib/presentation/screens/game/tennis_table_screen.dart` and `lib/presentation/bloc/tennis_game_bloc.dart`:
   - `TennisTableScreen` line 31 passes `tennisSoundEngine: TennisSoundEngine()` to `TennisGameBloc`.
   - `TennisGameBloc` lines 124-135 listens to raw socket events `tennis_sound` and `tennis_action_result`.
   - `TennisGameBloc` lines 138-152 (`_handleTimedSound`) handles `floor_hit` and `net_pass`, applying audio lane reflection for player 1 (`_localIdx == 1 ? -lane : lane`) and incoming volume attenuation (1.0 vs 0.30).
   - `TennisGameBloc` lines 164-248 (`_handleActionResult`) handles `racket`, `wall`, and `boundary` scoring events (`match_won`, `set_won`, `game_won`, point score announcements).
   - `TennisGameBloc` line 292 suppresses screen reader announcements during active rallies: `if (cur.isMyServe) { _announcer.announce('تحركت $direction'); }`.
   - `TennisGameBloc` line 320 (`close()`): calls `_tennisSoundEngine.dispose()`. When navigating away from the table before audio plays, this triggers the `LateInitializationError`.

5. Game BLoC Wiring:
   - `uno_game_bloc.dart` lines 230-236: wires `playEvent(gameType: 'UNO', eventType: game.eventType, serverCue: game.soundCue)`.
   - `domino_game_bloc.dart` lines 178-185: wires `playEvent(gameType: isAmerican ? 'AMERICAN_DOMINO' : 'DOMINO', eventType: game.eventType, serverCue: game.soundCue)`.
   - `scopa_game_bloc.dart` lines 184-190: wires `playEvent(gameType: 'SCOPA', eventType: game.eventType, serverCue: game.soundCue)`.
   - `snakes_and_ladders_game_bloc.dart` lines 166-171: wires `playEvent(gameType: 'SNAKES_LADDERS', eventType: game.eventType, serverCue: game.soundCue)`.
   - `farkle_game_bloc.dart` lines 223-229: wires `playEvent(gameType: 'FARKLE', eventType: state.eventType, serverCue: state.soundCue)`.
   - `ninety_nine_game_bloc.dart` lines 194-200: wires `playEvent(gameType: 'NINETY_NINE', eventType: game.eventType, serverCue: game.soundCue)`.
   - `thief_hunt_game_bloc.dart` lines 145-149: wires `playEvent(gameType: 'THIEF_HUNT', eventType: game.eventType, serverCue: game.soundCue)`.

6. Workspace Layout Observation:
   - Worker placed verification script in `.agents/worker_m2/test_sound_engine_restoration.dart`. Per `PROJECT.md` layout rules, `.agents/` should contain only agent metadata, and test code belongs under `test/`.

---

## 2. Logic Chain

1. **Integrity Assessment**:
   - Inspected all source code for hardcoded test responses, dummy stubs, or fake implementations.
   - Result: No integrity violations. The implementation is authentic, complete, robust, and correctly integrates with the real state models, audio contexts, and socket events.
   - The test suites `stress_polyphonic_pool.dart` and `adversarial_sound_stress.dart` test real pool mechanics (voice stealing, volume clamping, hardware fault recovery) using pure Dart mock players because the standalone Dart SDK environment lacks Flutter platform channels.

2. **Audio Mode Poisoning Elimination**:
   - Removing `_initAudioContext()` from `VoiceChatService`'s constructor ensures that entering a table or instantiating the service never sets `AndroidAudioMode.inCommunication`.
   - Setting VoIP context only on `joinSession()` and restoring `AndroidAudioMode.normal` on `leaveSession()` and `detach()` ensures the global Android audio stream is restored to media/game loudspeaker mode.

3. **AudioVoice & PlayerMode.mediaPlayer**:
   - `PlayerMode.mediaPlayer` successfully removes the 1MB buffer ceiling of `PlayerMode.lowLatency` (SoundPool), allowing `thief_answer_start.wav` (3.9MB) and `match_win.wav` (1.2MB) to play without failure.
   - The 15-second safety timer in `AudioVoice` and 10-second safety timer in `TennisSoundEngine` provide fail-safe recovery if platform channel events are dropped.

4. **Adversarial Discovery: `LateInitializationError` on Uninitialized Dispose**:
   - In `TennisSoundEngine`, `_umpirePlayer` is declared as `late final AudioPlayer _umpirePlayer;` and initialized only inside `initialize()`.
   - `initialize()` is only invoked lazily on demand when the first audio cue is played (`playSpatialSfx`, `_playSfxFile`, or `playUmpireCall`).
   - If a user opens `TennisTableScreen` (which creates `TennisGameBloc`, which instantiates `TennisSoundEngine`) and exits the screen before any tennis sound is triggered (for instance, while waiting for an opponent or leaving immediately), Flutter disposes `TennisGameBloc`, which calls `_tennisSoundEngine.dispose()`.
   - `dispose()` immediately executes `await stopAll();` which executes `await _umpirePlayer.stop();`.
   - Because `_umpirePlayer` was never initialized, Dart throws an unhandled `LateInitializationError: Field '_umpirePlayer' has not been initialized.`.
   - This defect is 100% reproducible and will crash Bloc cleanup during ordinary user navigation.

5. **BLoC Event Dispatch and Spatial Audio Verification**:
   - All 7 game BLoCs correctly invoke `_audioService.playEvent()` on new `game.eventId > _lastEventId`.
   - Spatial audio in `tennis_game_bloc.dart` matches the Python reference implementation (`client/views/tennis_view.py`) 1:1, including court perspective reflection for player 1 and active rally screen reader silencing.

---

## 3. Caveats

- Runtime microphone permissions (`RECORD_AUDIO`) remain subject to platform permission dialogs upon first unmuting VoIP.
- The standalone Dart SDK environment cannot run Flutter widget tests directly; verification relies on standalone Dart suites, static AST/source assertions, and mock stress harnesses.
- Physical Bluetooth SCO routing transitions could not be verified on hardware, but the audio context options (`AVAudioSessionOptions.allowBluetooth`, `isSpeakerphoneOn: true`) are set correctly.

---

## 4. Conclusion & Findings

### Review Summary
**Verdict**: **REQUEST_CHANGES**

### Findings

#### [Major] Finding 1: `LateInitializationError` on `TennisSoundEngine.dispose()` / `stopAll()`
- **What**: Calling `dispose()` or `stopAll()` on an uninitialized `TennisSoundEngine` throws `LateInitializationError: Field '_umpirePlayer' has not been initialized.`.
- **Where**: `lib/core/audio/tennis_sound_engine.dart`, lines 29, 414 (`stopAll()`), and 424 (`dispose()`).
- **Why**: `_umpirePlayer` is declared `late final` and is only assigned inside `initialize()`. `initialize()` is called lazily upon playing a sound. If a user enters `TennisTableScreen` and leaves before audio plays, `TennisGameBloc.close()` calls `_tennisSoundEngine.dispose()`, causing an unhandled runtime exception.
- **Suggestion**: Add an initialization guard at the beginning of `dispose()` and `stopAll()`:
  ```dart
  Future<void> stopAll() async {
    _umpireSafetyTimer?.cancel();
    _umpireQueue.clear();
    _isUmpirePlaying = false;
    if (_initialized) {
      await _umpirePlayer.stop();
    }
    for (final voice in _sfxVoicePool) {
      await voice.stop();
    }
  }

  Future<void> dispose() async {
    if (!_initialized) return;
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
  ```

#### [Minor] Finding 2: Verification Test Location Violates Workspace Layout Convention
- **What**: Milestone verification test placed inside `.agents/worker_m2/test_sound_engine_restoration.dart` rather than under `test/`.
- **Where**: `.agents/worker_m2/test_sound_engine_restoration.dart`
- **Why**: Per `PROJECT.md` layout conventions, `.agents/` must contain only metadata. Tests should be located in `test/`.
- **Suggestion**: Relocate `test_sound_engine_restoration.dart` to `test/sound_engine_restoration_test.dart` or `test/test_sound_engine_restoration.dart`.

### Verified Claims
- Audio mode poisoning elimination → verified via code inspection of `voice_chat_service.dart` and `test_sound_engine_restoration.dart` tests 1-3 → PASS
- AudioVoice mediaPlayer mode and 15s safety timer → verified via `audio_voice.dart` and test 4-6 → PASS
- Large WAV assets (3.9MB thief answer, 1.2MB match win) exist on disk and exceed SoundPool limit → verified via disk audit → PASS
- All 107 sound assets exist and non-empty → verified via `.agents/reviewer_m2_1/check_assets.dart` → PASS
- Polyphonic pool concurrency and round-robin voice stealing → verified via `test/stress_polyphonic_pool.dart` and `test/adversarial_sound_stress.dart` → PASS
- Tennis spatial audio reflection and screen reader suppression → verified against `tennis_view.py` reference → PASS
- playEvent wiring in all 7 game BLoCs → verified via BLoC code inspection and tests 13-19 → PASS
- Uninitialized TennisSoundEngine dispose safety → tested via reproduction script → **FAIL (reproduced LateInitializationError)**

---

## 5. Verification Method

To verify the finding and fix:
1. Run the reproduction test:
   ```powershell
   dart .agents/reviewer_m2_1/test_tennis_uninit_dispose.dart
   ```
2. Verify that applying `if (!_initialized) return;` to `TennisSoundEngine.dispose()` and guarding `_umpirePlayer.stop()` in `stopAll()` resolves the `LateInitializationError`.
3. Re-run all milestone test suites:
   ```powershell
   dart .agents/worker_m2/test_sound_engine_restoration.dart
   dart test/stress_polyphonic_pool.dart
   dart test/adversarial_sound_stress.dart
   ```
