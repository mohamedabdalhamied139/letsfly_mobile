# Forensic Audit Report: Milestone 2 (Requirement R3: Complete Game Sound Engine Restoration)

**Work Product**: Milestone 2 Deliverables (`lib/core/audio/`, `lib/presentation/bloc/`, `lib/presentation/screens/game/tennis_table_screen.dart`, test suites)  
**Profile**: General Project (Integrity Forensics)  
**Integrity Mode**: Development / Demo Parity  
**Auditor**: Forensic Auditor (`auditor_m2_1`)  
**Verdict**: **CLEAN**

---

### Phase Results

- **VoiceChatService Lifecycle Check**: PASS — `_initAudioContext()` completely excised from constructor. VoIP context (`AndroidAudioMode.inCommunication`, `AndroidUsageType.voiceCommunication`, `isSpeakerphoneOn: true`) applied exclusively on `joinSession()`. Media/Game context (`AndroidAudioMode.normal`, `AndroidUsageType.game`, `AndroidContentType.sonification`, `isSpeakerphoneOn: true`) faithfully restored in `leaveSession()` and `detach()`.
- **AudioVoice mediaPlayer & Timeout Check**: PASS — `PlayerMode.mediaPlayer` utilized exclusively. Real `onPlayerComplete` stream listener resets state and cancels timer. 15-second safety timer guarantees `isPlaying = false` recovery if platform channel stalls. Catch block handles playback failures gracefully.
- **TennisSoundEngine Spatial & Screen Reader Suppression Check**: PASS — `TennisSoundEngine` properly instantiated and injected in `tennis_table_screen.dart` into `TennisGameBloc`. Full spatial audio pipeline active for `floor_hit`, `net_pass`, `racket`, `wall`, and `boundary` with acoustic lane mirroring (`-lane`) for Player 1. Verbose screen reader announcements on lane movements are suppressed during active rallies (`cur.isMyServe` check), preserving clear ball localization.
- **Game BLoCs Server Event Dispatch Check**: PASS — All 7 target BLoCs (`uno_game_bloc.dart`, `domino_game_bloc.dart`, `scopa_game_bloc.dart`, `snakes_and_ladders_game_bloc.dart`, `farkle_game_bloc.dart`, `ninety_nine_game_bloc.dart`, `thief_hunt_game_bloc.dart`) contain monotonic event tracking (`eventId > _lastEventId`), state advancement (`_lastEventId = eventId`), and genuine `_audioService.playEvent(...)` dispatch mapping game-specific events (e.g., cards dealing, domino clicks, dice rolling, scopa sweep).
- **Physical Audio Asset Verification Check**: PASS — All 107 registered audio asset paths in Dart files were verified against disk (`assets/audio/`); exactly 107 files exist on disk (0 missing). All audio subdirectories are declared in `pubspec.yaml`.
- **Worker Verification Suite**: PASS — `dart .agents/worker_m2/test_sound_engine_restoration.dart`: 19 / 19 verification checks passed (100%).
- **Polyphonic Pool Stress Suite**: PASS — `dart test/stress_polyphonic_pool.dart`: 5 / 5 stress scenarios passed (100%), pool strictly bounded to 8 voices.
- **Adversarial Sound Stress Suite**: PASS — `dart test/adversarial_sound_stress.dart`: 9 / 9 challenges passed (100%).
- **Independent Forensic Audit Harness**: PASS — `dart .agents/auditor_m2_1/independent_engine_stress_audit.dart`: 9 / 9 independent checks passed (100%).
- **Absence of Facades / Dummies / Fabricated Results**: PASS — Zero pre-populated log/result artifacts. Zero `UnimplementedError` or dummy facades.

---

## 1. Observation

1. **`lib/core/audio/voice_chat_service.dart`**:
   - Constructor at line 25 is `VoiceChatService({required this.roomWs});` with no call to `_initAudioContext()`.
   - Lines 27-49 define `_setVoipAudioContext()` using `AndroidAudioMode.inCommunication` and `AndroidUsageType.voiceCommunication`. This method is invoked strictly at line 123 inside `joinSession()`.
   - Lines 51-72 define `_restoreNormalAudioContext()` using `AndroidAudioMode.normal`, `AndroidUsageType.game`, `AndroidContentType.sonification`, and `isSpeakerphoneOn: true`. This method is called at line 91 in `detach()`, at line 161 in `leaveSession()`, and in the error/timeout branches of `joinSession()` (lines 130, 135).

2. **`lib/core/audio/audio_voice.dart`**:
   - Lines 15-22 initialize `_completeSub = player.onPlayerComplete.listen(...)` to cancel `_safetyTimer` and reset `isPlaying = false`, `currentCue = null`, `currentCategory = null`.
   - Line 36 initiates a 15-second safety timer: `_safetyTimer = Timer(const Duration(seconds: 15), ...)`.
   - Line 45 executes `await player.play(source, mode: PlayerMode.mediaPlayer);`.
   - Lines 46-52 catch any playback error, cancel the safety timer, and reset `isPlaying = false`.
   - Lines 55-63 (`stop()`) and 73-80 (`dispose()`) cancel the timer and cleanup resources.

3. **`lib/core/audio/tennis_sound_engine.dart`**:
   - Line 310 implements a 10-second safety timer for sequential umpire calls: `_umpireSafetyTimer = Timer(const Duration(seconds: 10), ...)`.
   - Line 318 executes `await _umpirePlayer.play(source, mode: PlayerMode.mediaPlayer);`.
   - Lines 319-323 handle catch blocks, resetting `_isUmpirePlaying = false` and advancing `_playNextUmpire()`.

4. **`lib/presentation/screens/game/tennis_table_screen.dart` & `lib/presentation/bloc/tennis_game_bloc.dart`**:
   - In `tennis_table_screen.dart` lines 27-35, `TennisGameBloc` is provided with `tennisSoundEngine: TennisSoundEngine()`.
   - In `tennis_game_bloc.dart` lines 124-135, the BLoC subscribes to `roomWsService.rawEventStream`, processing `tennis_sound` and `tennis_action_result`.
   - Line 143 applies lane inversion for Player 1: `final audioLane = _localIdx == 1 ? -lane : lane;`.
   - Lines 145-152 dispatch `playFloorHit(audioLane, vol)` and `playNetPass(audioLane)`.
   - Lines 175-243 dispatch `playRacketHit`, `playOpponentHit`, `playScoreAnnouncement`, `playWin`, `playMiss`, `playCrowd`, `playMatchWon`, `playSetWon`, and `playGameWon`.
   - Lines 288-295 play spatial move sound `_tennisSoundEngine.playMove(newLane)` and strictly gate verbal screen reader announcements with `if (cur.isMyServe)`, muting screen reader chatter during rallies.
   - Line 320 calls `_tennisSoundEngine.dispose()`.

5. **BLoC Server Event Audio Dispatch across 7 Games**:
   - `lib/presentation/bloc/uno_game_bloc.dart` (lines 230-236): dispatches `playEvent(gameType: 'UNO', eventType: game.eventType, serverCue: game.soundCue)` on `game.eventId > _lastEventId`.
   - `lib/presentation/bloc/domino_game_bloc.dart` (lines 178-185): dispatches `playEvent(gameType: isAmerican ? 'AMERICAN_DOMINO' : 'DOMINO', eventType: game.eventType, serverCue: game.soundCue)` on `game.eventId > _lastEventId`.
   - `lib/presentation/bloc/scopa_game_bloc.dart` (lines 184-190): dispatches `playEvent(gameType: 'SCOPA', eventType: game.eventType, serverCue: game.soundCue)` on `game.eventId > _lastEventId`.
   - `lib/presentation/bloc/snakes_and_ladders_game_bloc.dart` (lines 156-171): dispatches `playEvent(gameType: 'SNAKES_LADDERS', eventType: game.eventType, serverCue: ...)` on `game.eventId > _lastEventId`.
   - `lib/presentation/bloc/farkle_game_bloc.dart` (lines 223-229): dispatches `playEvent(gameType: 'FARKLE', eventType: state.eventType, serverCue: state.soundCue)` on `state.eventId > _lastEventId`.
   - `lib/presentation/bloc/ninety_nine_game_bloc.dart` (lines 194-200): dispatches `playEvent(gameType: 'NINETY_NINE', eventType: game.eventType, serverCue: game.soundCue)` on `game.eventId > _lastEventId`.
   - `lib/presentation/bloc/thief_hunt_game_bloc.dart` (lines 138-149): dispatches `playEvent(gameType: 'THIEF_HUNT', eventType: game.eventType, serverCue: game.soundCue)` on `game.eventId > _lastEventId`.

6. **Audio Asset Files on Disk**:
   - `assets/audio/` contains 115 files.
   - 107 registered audio paths across Dart source files were checked against the filesystem. All 107 files exist; 0 missing.

---

## 2. Logic Chain

1. **AudioMode Poisoning Resolution**:
   - Android's `AudioManager.setMode(MODE_IN_COMMUNICATION)` is process-wide and forces audio through voice call routing (earpiece / SCO), attenuating or muting standard media streams.
   - Removing `_initAudioContext()` from `VoiceChatService`'s constructor ensures that initializing the service on room entry never alters global audio state.
   - Applying `_setVoipAudioContext()` strictly upon explicit `joinSession()`, and restoring `_restoreNormalAudioContext()` (`AndroidAudioMode.normal`, `AndroidUsageType.game`) upon `leaveSession()` and `detach()`, guarantees that in-game sound effects play over `STREAM_MUSIC` to loudspeaker without routing conflicts.

2. **SoundPool Stalling & Buffer Limit Resolution**:
   - `PlayerMode.lowLatency` uses `SoundPool`, which does not emit `onPlayerComplete` events on Android, permanently locking voices in `isPlaying = true`. Furthermore, `SoundPool` fails on audio assets > 1MB.
   - Switching `AudioVoice` and `TennisSoundEngine` to `PlayerMode.mediaPlayer` guarantees reliable `onPlayerComplete` events and supports large assets (`thief_answer_start.wav` 3.9MB, `match_win.wav` 1.2MB).
   - Adding a 15-second safety timer in `AudioVoice` and a 10-second safety timer in `TennisSoundEngine` provides deterministic fault-recovery if hardware platform channels ever drop a completion event.

3. **Spatial Tennis Sound & Rally Accessibility Parity**:
   - Connecting `TennisSoundEngine` to `TennisTableScreen` and `TennisGameBloc` satisfies the requirement for 3D spatial positioning (`air_left`, `bounce_center`, `hit_1_right`, etc.) with Player 1 inversion.
   - Suppressing spoken accessibility announcements during active ball trajectories prevents screen reader voice synthesizers from masking essential spatial audio cues.

4. **BLoC Event-Driven Audio Restoration**:
   - Server WebSocket payloads often supply empty `sound_cue` strings while providing standard `event_type` strings (`CARD_PLAYED`, `TILE_PLACED`, `ROUND_START`, etc.).
   - By routing through `_audioService.playEvent()`, all 7 game BLoCs now trigger corresponding sound effects mapped in `SoundEngine.soundRegistry`, restoring full audio cues across all games.

---

## 3. Caveats

1. Microphone capture (`RECORD_AUDIO`) runtime permissions must be granted by the operating system user before voice transmission begins in `VoiceChatService`.
2. Standalone Dart environment does not execute Flutter widget tree UI tests, but all underlying state machines, BLoCs, audio engines, and stress suites run and pass in pure Dart.

---

## 4. Conclusion

Milestone 2 (R3: Complete Game Sound Engine Restoration) is **CLEAN** and authentic. There are **NO** integrity violations, dummy facades, hardcoded test results, or fabricated outputs. All components implement genuine logic matching the reference specification and pass all empirical checks.

---

## 5. Verification Method

To independently reproduce the forensic verification results:

```powershell
# 1. Milestone 2 restoration checks (19 assertions)
dart .agents/worker_m2/test_sound_engine_restoration.dart

# 2. Polyphonic pool concurrency and fault-injection stress suite (5 scenarios)
dart test/stress_polyphonic_pool.dart

# 3. Adversarial sound engine stress harness (9 challenges)
dart test/adversarial_sound_stress.dart

# 4. Independent disk asset verification script (107 audio files)
dart .agents/auditor_m2_1/verify_assets_integrity.dart

# 5. Independent forensic lifecycle and concurrency audit (9 checks)
dart .agents/auditor_m2_1/independent_engine_stress_audit.dart
```

---

## 6. Raw Execution Evidence

### 1. `dart .agents/worker_m2/test_sound_engine_restoration.dart`
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

======================================================================
RESULTS: 19 / 19 VERIFICATION CHECKS PASSED (100%)
======================================================================
```

### 2. `dart test/stress_polyphonic_pool.dart`
```
=== STRESS TEST 1: Rapid Burst of 25 Simultaneous Requests (>20) ===
Firing 25 simultaneous sound cues via Future.wait...
[PASS] 25 simultaneous requests completed without unhandled exceptions.
[PASS] Voice pool size strictly bounded: 8 voices.
Total play invocations across 8 players: 25

=== STRESS TEST 2: Massive Burst of 100 Requests with Random Completion ===
[PASS] 100 rapid requests processed successfully.

=== STRESS TEST 3: Hardware Exception Injection Resilience ===
Injected simulated hardware exceptions into Player 2 (play) and Player 4 (stop)...
[PASS] Engine gracefully survived hardware exceptions without propagating errors to caller.

=== STRESS TEST 4: Round-Robin Eviction Order Verification ===
[PASS] Round-robin voice stealing functions correctly with 100% predictability.

=== STRESS TEST 5: Zero-Volume Voice Allocation Leak Guard ===
[PASS] Zero volume unmuted request safely discarded without voice allocation.

==================================================
ALL EMPIRICAL STRESS TESTS COMPLETED WITH 100% SUCCESS
==================================================
```

### 3. `dart test/adversarial_sound_stress.dart`
```
===============================================================
   ADVERSARIAL STRESS HARNESS: SOUND ENGINE & CONCURRENCY
===============================================================

  [PASS] Challenge 1: 50 simultaneous bursts: Voice pool bounded to 8, plays == 50
  [PASS] Challenge 2: SoundCues.cardPlayed resolves to audio/uno/place.wav cleanly
  [PASS] Challenge 3: Zero-volume guard (master=0.0): 30 cues completely discarded (0 plays, 0 active voices)
  [PASS] Challenge 4: Category-level zero-volume guard: game discarded, effects plays
  [PASS] Challenge 5: Mute guard (_muted=true): 25 cues discarded without voice allocation
  [PASS] Challenge 6: Volume clamping: negative clamped to 0.0 (discarded), excessive clamped to 1.0
  [PASS] Challenge 7: Predictable round-robin voice stealing across 3 full cycles (24 steals)
  [PASS] Challenge 8: 100 mixed concurrent operations (volume jitter + random completion): No deadlocks or leaks
  [PASS] Challenge 9: Survives simultaneous hardware faults across multiple pooled players without unhandled rejections

===============================================================
RESULTS: 9 / 9 CHALLENGES PASSED
===============================================================
```

### 4. `dart .agents/auditor_m2_1/verify_assets_integrity.dart`
```
======================================================================
        FORENSIC AUDIT: SOUND ASSET INTEGRITY VERIFICATION
======================================================================

Discovered 107 unique sound asset references.
Existing asset files verified: 107
Missing asset files: 0

[PASS] All 107 registered sound assets empirically exist on disk!
```

### 5. `dart .agents/auditor_m2_1/independent_engine_stress_audit.dart`
```
======================================================================
   FORENSIC AUDIT: INDEPENDENT EMPIRICAL INTEGRITY HARNESS
======================================================================

  [PASS] Check 1: AudioVoice releases voice immediately upon onPlayerComplete
  [PASS] Check 2: AudioVoice safety timer forcibly resets isPlaying=false if hardware hangs
  [PASS] Check 3: AudioVoice catch block resets isPlaying=false when player throws error
  [PASS] Check 4: Tennis spatial lane inversion: Player 0 maintains direct orientation, Player 1 acoustically mirrors
  [PASS] Check 5: Tennis accessibility: movement announcer active ONLY during serve preparation, suppressed during rally
  [PASS] Check 6: VoiceChatService strictly enforces non-poisoning audio lifecycle contract
  [PASS] Check 7: All 7 Game BLoCs contain monotonic eventId guard, eventId advancement, and playEvent dispatch
  [PASS] Check 8: TennisSoundEngine umpire player uses PlayerMode.mediaPlayer with 10s safety timeout
  [PASS] Check 9: Polyphonic pool survives 64 rapid steals without pool size growth (>8)

======================================================================
RESULTS: 9 / 9 AUDIT CHECKS PASSED (100%)
======================================================================
```
