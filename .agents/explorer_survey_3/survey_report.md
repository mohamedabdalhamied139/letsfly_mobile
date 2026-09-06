# Comprehensive Survey Report: Requirement R3 — Complete Game Sound Engine Restoration

**Explorer**: Explorer 3  
**Target Requirement**: R3 (Complete Game Sound Engine Restoration)  
**Mobile Workspace**: `C:\Users\midoa\Downloads\Compressed\letsfly_final_100_parity_reviewed\Mobile`  
**Authoritative Windows Codebase**: `C:\Users\midoa\Downloads\Compressed\LetsFly_TableVoice_Fixed_NoTableText_20260902_Final`  
**Date**: 2026-09-06  

---

## 1. Executive Summary

A comprehensive investigation into the Let's Fly mobile client sound subsystem reveals that **the underlying physical audio assets (107 WAV files) are 100% intact and identical to the authoritative Windows reference client**. However, sound effects across all 8 games are either completely silent, cut off, locked up, or incorrectly mapped due to **four distinct architectural and integration defects**:

1. **Global Process Audio Mode Poisoning by `VoiceChatService`**: Upon entering any table room, `RoomCubit` instantiates `VoiceChatService`, which immediately configures Android's global `AudioManager` to `MODE_IN_COMMUNICATION` with transient ducking. On Android, `setMode()` is process-wide; this forces all media streams (`STREAM_MUSIC`) to duck to zero or route to the phone's ear receiver rather than loudspeaker/headphones, even when voice chat is idle.
2. **`PlayerMode.lowLatency` SoundPool Lockup & Buffer Overflow**: `AudioVoice` invokes `audioplayers` with `mode: PlayerMode.lowLatency` (Android `SoundPool`). On Android, `SoundPool` **never dispatches `onPlayerComplete`**. Because `AudioVoice` relies on that callback to clear `isPlaying`, all 8 voices in the pool become permanently stuck in `isPlaying = true` after a single use. Furthermore, `SoundPool` has a strict 1MB buffer limit; files exceeding 1MB (e.g., `thief_answer_start.wav` at 3.9MB, `match_win.wav` at 1.2MB) fail silently.
3. **Completely Unhooked `TennisSoundEngine`**: The dedicated 3D spatial panning and Arabic umpire engine (`tennis_sound_engine.dart`) was never wired to `TennisTableScreen` or `TennisGameBloc`. Instead, `TennisGameBloc` called unmapped cues (`tennis/$sound` and `tennis/move`) on `SoundEngine`, resulting in total silence during tennis rallies.
4. **BLoC Failure to Invoke `playEvent()` on Server `event_type`**: The server communicates actions using `event_type` (`CARD_PLAYED`, `TILE_PLACED`, `ROUND_START`, `DICE_ROLLED`, `CANNOT_MOVE`, etc.) while often leaving `sound_cue` null or generic. The Windows client resolves these using `sound_engine.event_cues()`. In Mobile, `SoundEngine.playEvent()` contains the complete event-to-cue mapping, but **none of the game BLoCs call `playEvent()`**; they only checked `if (game.soundCue != null) playCue(game.soundCue!)`, causing card dealing, play sounds, domino clicks, and snakes dice to never trigger.

---

## 2. Sound Engine Architecture & Implementation in Mobile

### 2.1 Audio Package Selection
- `Mobile/pubspec.yaml` line 19 declares:
  ```yaml
  audioplayers: ^6.4.0
  ```
- Dependency injection in `lib/main.dart` lines 46-47 & 78:
  ```dart
  final soundEngine = SoundEngine();
  await soundEngine.initialize(prefs: prefs);
  ...
  RepositoryProvider<TableAudioService>.value(value: audioService)
  ```

### 2.2 Core Audio Components
- `lib/core/audio/table_audio_service.dart`: Abstract interface defining `playCue(String cueName)`, `playEvent({required String gameType, required String eventType, String? serverCue})`, volume controls, and lifecycle.
- `lib/core/audio/sound_engine.dart`: Main polyphonic sound engine conforming to `TableAudioService`. Maintains a pool of 8 `AudioVoice` instances. Contains `soundRegistry` (mapping semantic cues to asset paths) and `playEvent()` (event-to-cue resolution).
- `lib/core/audio/audio_voice.dart`: Individual voice wrapper around `AudioPlayer`. Listens to `player.onPlayerComplete` to reset `isPlaying`.
- `lib/core/audio/tennis_sound_engine.dart`: Dedicated spatial audio engine with 4 SFX voice slots and 1 sequential `AudioPlayer` for Arabic umpire voice clips.
- `lib/core/audio/voice_chat_service.dart`: Voice chat controller using `record: ^6.1.1` and `AudioPlayer` for VoIP audio over WebSocket.
- `lib/core/audio/audio_cubit.dart`: Reactive BLoC wrapper around `TableAudioService` exposing volumes and mute status.

---

## 3. Asset Inventory & Path Parity Verification

### 3.1 `pubspec.yaml` Asset Declarations
In `Mobile/pubspec.yaml` lines 27-37:
```yaml
  assets:
    - assets/audio/
    - assets/audio/uno/
    - assets/audio/domino/
    - assets/audio/farkle/
    - assets/audio/ninety_nine/
    - assets/audio/scopa/
    - assets/audio/snakes_and_ladders/
    - assets/audio/tennis/
    - assets/audio/tennis/arabic_umpire/
    - assets/audio/thief_hunt/
```
All asset directories are declared.

### 3.2 Physical File Comparison: Mobile vs. Windows Client
A complete scan of `Mobile/assets/audio/` confirms **107 WAV audio files** totalling **34,862,016 bytes (~34.8 MB)**.
Comparing against `LetsFly_TableVoice_Fixed_NoTableText_20260902_Final/client/assets/audio/`:

| Directory / Category | Windows Client Assets | Mobile Assets | Parity Status |
|---|---|---|---|
| `audio/` (root common lifecycle) | 10 WAVs (`player_joined`, `player_left`, `turn_start`, `round_start`, `round_end`, `match_win`, `match_loss`, `game_stopped`, `invalid_action`, `win`) | 10 WAVs identical | **100% Match** |
| `audio/uno/` | 14 WAVs (`deal`, `draw`, `draw_two`, `place`, `place_special`, `reverse`, `skip`, `uno_call`, `uno_penalty`, `wild_color`, `wild_color_prompt`, `wild_draw_four`, `bluff_challenge`, `shuffle`) | 14 WAVs identical | **100% Match** |
| `audio/domino/` | 11 WAVs (`domino_blocked`, `domino_draw`, `domino_draw_original`, `domino_pass`, `domino_place`, `domino_place_original`, `domino_pre_round`, `domino_round_start`, `domino_setup`, `domino_shuffle`, `domino_win`) | 11 WAVs identical | **100% Match** |
| `audio/farkle/` | 5 WAVs (`farkle_bank`, `farkle_bust`, `farkle_hot_dice`, `farkle_roll`, `farkle_score`) | 5 WAVs identical | **100% Match** |
| `audio/ninety_nine/` | 3 WAVs (`ninety_nine_draw`, `ninety_nine_exceed`, `ninety_nine_reach`) | 3 WAVs identical | **100% Match** |
| `audio/scopa/` | 11 WAVs (`scopa_announcement`, `scopa_capture`, `scopa_card_throw`, `scopa_deal`, `scopa_deal_batch`, `scopa_deal_single`, `scopa_eat_cards`, `scopa_play`, `scopa_round_start`, `scopa_shuffle`, `scopa_sweep`) | 11 WAVs identical | **100% Match** |
| `audio/snakes_and_ladders/` | 9 WAVs (`DICE_ROLL`, `LADDER_CLIMB`, `SNAKE_BITE`, `MYSTERY_BOX`, `PLAYER_BUMP`, `MATCH_WIN`, `FREEZE_TRAP`, `BONUS_ROLL`, `STEP_MOVE`) | 9 WAVs identical | **100% Match** |
| `audio/tennis/` | 17 WAVs (`air_center/left/right`, `bounce_center/left/right`, `hit_1_center/left/right`, `hit_2_center/left/right`, `jm_center/left/right`, `claps_1`, `claps_2`) | 17 WAVs identical | **100% Match** |
| `audio/tennis/arabic_umpire/` | 21 WAVs (`advantage_receiver/server`, `deuce`, `fault`, `game_won`, `match_won`, `set_won`, `score_*` 15 variations) | 21 WAVs identical | **100% Match** |
| `audio/thief_hunt/` | 6 WAVs (`thief_answer_start`, `thief_caught`, `thief_escape`, `thief_game_start`, `thief_round_end`, `thief_round_winner`) | 6 WAVs identical | **100% Match** |

### 3.3 AssetSource Path Resolution
In `audioplayers`, `AssetSource(path)` automatically prepends `assets/`.
In `sound_engine.dart` lines 37-170, all registered paths begin with `'audio/...'`.
`AssetSource('audio/turn_start.wav')` correctly resolves to `assets/audio/turn_start.wav`.
No "double assets/" prefix issue exists in `SoundEngine.soundRegistry`.

---

## 4. Deep Root Cause Analysis of Silence & Audio Errors

### Root Cause 1: Global Process Audio Mode Poisoning by `VoiceChatService`
- **Location**: `Mobile/lib/core/audio/voice_chat_service.dart`, lines 25-51 & `Mobile/lib/presentation/bloc/room_cubit.dart`, line 103.
- **Mechanism**:
  1. Whenever a user enters any room, `RoomCubit` instantiates `VoiceChatService(roomWs: _roomWsService)`.
  2. The `VoiceChatService` constructor immediately invokes `_initAudioContext()`, which executes:
     ```dart
     await _player.setAudioContext(
       AudioContext(
         android: AudioContextAndroid(
           isSpeakerphoneOn: true,
           stayAwake: true,
           contentType: AndroidContentType.speech,
           usageType: AndroidUsageType.voiceCommunication,
           audioFocus: AndroidAudioFocus.gainTransientMayDuck,
           audioMode: AndroidAudioMode.inCommunication,
         ),
         iOS: AudioContextIOS(
           category: AVAudioSessionCategory.playAndRecord,
           options: const {
             AVAudioSessionOptions.allowBluetooth,
             AVAudioSessionOptions.defaultToSpeaker,
           },
         ),
       ),
     );
     ```
  3. In the Android operating system, `AudioManager.setMode(MODE_IN_COMMUNICATION)` is a **process-wide global setting**. There is no per-player audio mode.
  4. Setting `MODE_IN_COMMUNICATION` forces the Android audio routing policy into phone call mode:
     - Media playback (`STREAM_MUSIC`) is automatically ducked to near zero or silenced.
     - Audio is rerouted to the phone's upper earpiece speaker rather than the main loudspeaker or headphones.
     - `SoundEngine`'s context (`audioFocus: AndroidAudioFocus.none`, `usageType: AndroidUsageType.game`) is rejected or muted by the OS because the active call stream has higher priority.
  5. The user hasn't even joined voice chat (it is muted/off by default), but the app's entire audio output is already hijacked and muted.
  6. `VoiceChatService` never restores `AndroidAudioMode.normal` upon room exit or when inactive.

### Root Cause 2: `PlayerMode.lowLatency` (Android SoundPool) Permanent Voice Lockup
- **Location**: `Mobile/lib/core/audio/audio_voice.dart`, lines 14-20 & 28-41.
- **Mechanism**:
  1. `AudioVoice.play()` calls:
     ```dart
     await player.play(source, mode: PlayerMode.lowLatency);
     ```
  2. In `audioplayers` on Android, `PlayerMode.lowLatency` is implemented via the Android native `SoundPool` API.
  3. **Android's `SoundPool` does NOT support playback completion callbacks**. Consequently, `player.onPlayerComplete` **never fires**.
  4. `AudioVoice` depends on that callback to set `isPlaying = false`:
     ```dart
     _completeSub = player.onPlayerComplete.listen((_) {
       isPlaying = false;
       currentCue = null;
       currentCategory = null;
     });
     ```
  5. Because the callback never triggers, every voice in the pool stays permanently stuck at `isPlaying = true`.
  6. After the first 8 sounds are played, `SoundEngine.playCue()` finds zero idle voices (`candidate == null`) and is forced into continuous round-robin voice stealing.
  7. **SoundPool 1MB Buffer Limit**: Android `SoundPool` has a strict 1MB (1,048,576 byte) decoded sample limit per sound.
     - `Mobile/assets/audio/thief_hunt/thief_answer_start.wav` is **3,918,586 bytes (~3.9MB)**.
     - `Mobile/assets/audio/match_win.wav` is **1,213,518 bytes (~1.2MB)**.
     - Both files fail to load into `SoundPool`. The failure is swallowed by `catch (_) { isPlaying = false; }` in `AudioVoice.play()`, causing these sounds to be completely silent.

### Root Cause 3: Unhooked `TennisSoundEngine` & Invalid Cue Paths
- **Location**: `Mobile/lib/presentation/bloc/tennis_game_bloc.dart`, lines 120-129 & 173; `Mobile/lib/core/audio/tennis_sound_engine.dart`.
- **Mechanism**:
  1. `TennisSoundEngine` in `lib/core/audio/tennis_sound_engine.dart` is an exact port of the Windows tennis sound engine with 3-lane stereo panning (`jm_left/center/right`, `hit_1_*`, `hit_2_*`, `bounce_*`, `air_*`, `claps_1/2`, Arabic umpire announcements).
  2. However, `TennisSoundEngine` was **never instantiated or provided** in `TennisTableScreen` or `TennisGameBloc`.
  3. `TennisGameBloc` was instead passed the standard `TableAudioService` (`SoundEngine`) and attempted:
     ```dart
     _audioService.playCue('tennis/$sound'); // line 122
     _audioService.playCue('tennis/move');   // line 173
     ```
  4. `SoundEngine.soundRegistry` has no entries for `tennis/$sound` or `tennis/move`. Lookups fail at `sound_engine.dart` line 269:
     ```dart
     debugPrint('[SoundEngine] Unknown sound cue: $cueName (ignored)');
     ```
  5. In addition, in `TennisSoundEngine._playNextUmpire()`, `_umpirePlayer.play(source, mode: PlayerMode.lowLatency)` was used, meaning even if `TennisSoundEngine` were called, the sequential umpire queue would lock up on the first call due to the lack of `onPlayerComplete` under `lowLatency`.
  6. In `TennisGameBloc._onMoveLane()`, `_announcer.announce('تحركت $direction')` was called on every swipe, violating the Windows reference client principle: *"Screen reader is kept completely quiet during active rallies so it does not interrupt or drown out the spatial audio cues."*

### Root Cause 4: Server Protocol Disconnect — Game BLoCs Never Call `playEvent()`
- **Location**: All game BLoCs (`uno_game_bloc.dart`, `domino_game_bloc.dart`, `scopa_game_bloc.dart`, `snakes_and_ladders_game_bloc.dart`, `farkle_game_bloc.dart`, `ninety_nine_game_bloc.dart`).
- **Mechanism**:
  1. The Python game server communicates table state changes by setting `event_type` (`CARD_PLAYED`, `TILE_PLACED`, `ROUND_START`, `DICE_ROLLED`, `CANNOT_MOVE`, etc.) and often leaves `sound_cue` empty or unpopulated.
  2. In the Windows client, `client/table_framework/state_engine.py` resolves sounds using `sound_engine.event_cues(game_type, et, state)`.
  3. In Mobile, `SoundEngine.playEvent()` **already implements the complete event-to-cue resolution table** for UNO, Farkle, Thief Hunt, Scopa, Domino, American Domino, Snakes & Ladders, and Ninety Nine.
  4. But **not a single game BLoC calls `_audioService.playEvent()`**!
  5. Instead, every BLoC contains code like:
     ```dart
     if (game.eventId > _lastEventId) {
       _lastEventId = game.eventId;
       if (game.soundCue != null && game.soundCue!.isNotEmpty) {
         await _audioService.playCue(game.soundCue!);
       }
     }
     ```
  6. When `soundCue` is empty or null (which is the case for most server events), **no sound is played at all**.

---

## 5. Game-by-Game Sound Restoration Audit

### 5.1 Card Games: Dealing & Play Sounds (UNO, Scopa, Ninety-Nine)
- **Cards Dealing**:
  - **Windows Behavior**: `GAME_STARTED` / `ROUND_START` triggers `UNO_DEAL` (`audio/uno/deal.wav`) in UNO, `SCOPA_DEAL` (`audio/scopa/scopa_deal.wav`) in Scopa.
  - **Mobile Defect**: `uno_game_bloc.dart` line 232 and `scopa_game_bloc.dart` line 186 only check `game.soundCue`. When the server sends `event_type: "ROUND_START"` with empty `sound_cue`, no dealing sound is played. Furthermore, `room_cubit.dart` line 215 prematurely plays a generic `roundStart.wav` for all games regardless of type.
  - **Restoration Requirement**: Call `_audioService.playEvent(gameType: 'UNO', eventType: game.eventType, serverCue: game.soundCue)` and `_audioService.playEvent(gameType: 'SCOPA', eventType: game.eventType, serverCue: game.soundCue)`.
- **Card Play Sounds**:
  - **Windows Behavior**: `CARD_PLAYED` triggers `UNO_PLACE` (`audio/uno/place.wav`) for UNO, `SCOPA_CARD_THROW` (`audio/scopa/scopa_card_throw.wav`) for Scopa, `NINETY_NINE_PLACE` (`audio/uno/place.wav`) for Ninety-Nine.
  - **Mobile Defect**: BLoCs do not resolve `CARD_PLAYED` through `playEvent()`. Ninety-Nine BLoC had improper manual remappings (mapping reach/exceed to Uno penalty, prompt to turn start).
  - **Restoration Requirement**: Dispatch `playEvent` on all `CARD_PLAYED`, `SPECIAL_CARD_PLAYED`, `CARD_CAPTURED`, `SCOPA_SWEEP`, `PENDING_CHOICE` events.

### 5.2 Domino & American Domino Clicks
- **Windows Behavior**:
  - Classic Domino: `TILE_PLACED` triggers `DOMINO_PLACE_ORIGINAL` (`audio/domino/domino_place_original.wav`), `TILE_DRAWN` triggers `DOMINO_DRAW_ORIGINAL` (`audio/domino/domino_draw_original.wav`), `ROUND_START` triggers `DOMINO_PRE_ROUND` (`audio/domino/domino_pre_round.wav`).
  - American Domino: `TILE_PLACED` triggers `DOMINO_PLACE` (`audio/domino/domino_place.wav`), `ROUND_START` triggers `DOMINO_SHUFFLE` (`audio/domino/domino_shuffle.wav`).
- **Mobile Defect**:
  - `domino_game_bloc.dart` lines 180-182 only calls `_audioService.playCue(game.soundCue!)`.
  - The server sends `sound_cue: "DOMINO_PLACE"` for all domino variants. Classic Domino requires `DOMINO_PLACE_ORIGINAL`. In Windows, `sound_engine.event_cues()` overrides `DOMINO_PLACE` to `DOMINO_PLACE_ORIGINAL` for classic Domino. In Mobile, because `playEvent` was skipped, classic Domino played the wrong sound or nothing.
- **Restoration Requirement**: Distinguish `DOMINO` vs `AMERICAN_DOMINO` (via `game.scoringMode != null`) and call `_audioService.playEvent(gameType: isAmerican ? 'AMERICAN_DOMINO' : 'DOMINO', eventType: game.eventType, serverCue: game.soundCue)`.

### 5.3 Snakes and Ladders Dice & Board Actions
- **Windows Behavior**:
  - Server sends: `event_type: "DICE_ROLLED"`, `"BONUS_ROLL"`, `"PLAYER_FROZEN"`, `"CANNOT_MOVE"`.
  - Windows resolves these to `DICE_ROLL`, `BONUS_ROLL`, `FREEZE_TRAP`, `INVALID_ACTION`.
- **Mobile Defect**:
  - The server for Snakes & Ladders **never populates `sound_cue` or `sound_cues`**.
  - `snakes_and_ladders_game_bloc.dart` lines 159-167 strictly checks `for (final cue in game.soundCues)` and `if (game.soundCues.isEmpty && game.soundCue.isNotEmpty)`.
  - Both are empty on every dice roll, bonus roll, and trap! **Snakes & Ladders audio is 100% dead**.
- **Restoration Requirement**: Call `_audioService.playEvent(gameType: 'SNAKES_LADDERS', eventType: game.eventType, serverCue: game.soundCue)` on every state update where `game.eventId > _lastEventId`.

### 5.4 Tennis Rally & Umpire Calls
- **Windows Behavior**:
  - Real-time 3D stereo panning for lane changes (`jm_left/center/right`).
  - Timed events from server: `floor_hit` (`bounce_*.wav` with 1.0 volume near / 0.30 far), `net_pass` (`air_*.wav`).
  - Action results: `racket` hit (`hit_1_*.wav`), opponent/wall return (`hit_2_*.wav`), `boundary` miss (`claps_1/2` crowd applause + sequential Arabic umpire score announcement).
  - Screen reader silenced during active rallies.
- **Mobile Defect**:
  - `TennisSoundEngine` abandoned in `lib/core/audio/tennis_sound_engine.dart`.
  - `TennisGameBloc` called non-existent `_audioService.playCue('tennis/$sound')`.
  - Screen reader spoke on every lane change, drowning audio.
- **Restoration Requirement**:
  - Instantiate and inject `TennisSoundEngine` in `TennisTableScreen` / `TennisGameBloc`.
  - Wire server `tennis_sound` (`floor_hit`, `net_pass`) and `tennis_action_result` (`racket`, `wall`, `boundary`) to `TennisSoundEngine` methods.
  - Silence screen reader announcements during active ball in play; announce only on serve wait or match end.
  - Switch `_umpirePlayer` in `TennisSoundEngine` to `PlayerMode.mediaPlayer` so Arabic umpire calls chain sequentially.

### 5.5 Farkle Dice Rolling & Banking
- **Windows Behavior**: `DICE_ROLLED` -> `FARKLE_ROLL`, `COMBINATION_SCORED` -> `FARKLE_SCORE`, `TURN_BANKED` -> `FARKLE_BANK`, `FARKLE` -> `FARKLE_BUST`, `HOT_DICE` -> `FARKLE_HOT_DICE`.
- **Mobile Defect**: `farkle_game_bloc.dart` line 278 played `SoundCues.diceRoll` (the snakes dice sound!) locally on user roll, and completely ignored all server state updates for dice rolled by other players, scores, banks, busts, and hot dice.
- **Restoration Requirement**: Call `_audioService.playEvent(gameType: 'FARKLE', eventType: state.eventType, serverCue: state.soundCue)` in `_onStateUpdated`.

### 5.6 Thief Hunt Suspense & Caught Sounds
- **Windows Behavior**: `GAME_STARTED` -> `THIEF_GAME_START`, `ESCAPE_START` -> `THIEF_ESCAPE`, `ANSWER_START` -> `THIEF_ANSWER_START`, `ROUND_WIN` -> `THIEF_ROUND_WINNER`, `ROUND_TIE` / `THIEF_WIN` -> `THIEF_ROUND_END`, `THIEF_CAUGHT` -> `THIEF_CAUGHT`.
- **Mobile Defect**: `thief_hunt_game_bloc.dart` attempted to play `THIEF_ANSWER_START` (which is a 3.9MB WAV file). Because `AudioVoice` used `PlayerMode.lowLatency` (SoundPool), SoundPool silently refused to load the 3.9MB file, muting the suspense music.
- **Restoration Requirement**: Switch playback to `PlayerMode.mediaPlayer` so large WAV files play flawlessly.

---

## 6. Concrete, Actionable Remediation Plan for Implementers

The implementation team can execute the following concrete modifications to achieve 100% sound restoration:

### Step 1: Fix `AudioVoice` & `SoundEngine` Mode and Lifecycle
- In `lib/core/audio/audio_voice.dart`:
  - Change `await player.play(source, mode: PlayerMode.lowLatency);` to `PlayerMode.mediaPlayer` (or make `mediaPlayer` default with an automatic duration-based timeout fallback for `isPlaying` flag).
  - Ensure `player.onPlayerComplete` reliably resets `isPlaying = false`, `currentCue = null`.
- In `lib/core/audio/sound_engine.dart`:
  - Ensure `initialize()` sets `AudioContextAndroid` with `usageType: AndroidUsageType.game`, `contentType: AndroidContentType.sonification`, `audioFocus: AndroidAudioFocus.gainTransientMayDuck`, and speakerphone configured from preferences.

### Step 2: Fix `VoiceChatService` Mode Poisoning
- In `lib/core/audio/voice_chat_service.dart`:
  - Remove `_initAudioContext()` call from the constructor `VoiceChatService({required this.roomWs})`.
  - Only execute VoIP audio context configuration inside `joinSession()` when the user actually joins voice chat.
  - In `leaveSession()` and `detach()`, explicitly restore normal media audio context (`AndroidAudioMode.normal`, `AndroidUsageType.game`, speakerphone enabled).

### Step 3: Wire `TennisSoundEngine` in Tennis Gameplay
- In `lib/presentation/screens/game/tennis_table_screen.dart`:
  - Provide `TennisSoundEngine` to `TennisGameBloc`.
- In `lib/presentation/bloc/tennis_game_bloc.dart`:
  - Replace `_audioService.playCue('tennis/$sound')` with calls to `tennisSoundEngine`:
    - `floor_hit` -> `tennisSoundEngine.playFloorHit(audioLane, volume: vol)`
    - `net_pass` -> `tennisSoundEngine.playNetPass(audioLane)`
    - `racket` hit -> `tennisSoundEngine.playRacketHit(lane)` or `playOpponentHit(lane)`
    - `boundary` -> `tennisSoundEngine.playPointScored()`, `playScoreAnnouncement(...)`, `playMatchWon()`
    - Lane movement -> `tennisSoundEngine.playMove(newLane)`
  - Suppress verbose screen reader announcements during active rally (`state is TennisGamePlaying`).
- In `lib/core/audio/tennis_sound_engine.dart`:
  - In `_playNextUmpire()`, change `_umpirePlayer.play(source, mode: PlayerMode.lowLatency)` to `PlayerMode.mediaPlayer` so `onPlayerComplete` fires and umpire announcements chain sequentially.

### Step 4: Call `playEvent()` in All Game BLoCs
Update the `_onStateUpdated` handler across all 7 other game BLoCs to invoke `_audioService.playEvent`:
- `uno_game_bloc.dart`:
  ```dart
  if (game.eventId > _lastEventId) {
    _lastEventId = game.eventId;
    await _audioService.playEvent(
      gameType: 'UNO',
      eventType: game.eventType,
      serverCue: game.soundCue,
    );
  }
  ```
- `domino_game_bloc.dart`:
  ```dart
  if (game.eventId > _lastEventId) {
    _lastEventId = game.eventId;
    final isAmerican = game.scoringMode != null || game.openEndsSum != null;
    await _audioService.playEvent(
      gameType: isAmerican ? 'AMERICAN_DOMINO' : 'DOMINO',
      eventType: game.eventType,
      serverCue: game.soundCue,
    );
  }
  ```
- `scopa_game_bloc.dart`:
  ```dart
  if (game.eventId > _lastEventId) {
    _lastEventId = game.eventId;
    await _audioService.playEvent(
      gameType: 'SCOPA',
      eventType: game.eventType,
      serverCue: game.soundCue,
    );
  }
  ```
- `snakes_and_ladders_game_bloc.dart`:
  ```dart
  if (game.eventId > _lastEventId) {
    _lastEventId = game.eventId;
    await _audioService.playEvent(
      gameType: 'SNAKES_LADDERS',
      eventType: game.eventType,
      serverCue: game.soundCue,
    );
  }
  ```
- `farkle_game_bloc.dart`:
  ```dart
  if (state.eventId > _lastEventId) {
    _lastEventId = state.eventId;
    await _audioService.playEvent(
      gameType: 'FARKLE',
      eventType: state.eventType,
      serverCue: state.soundCue,
    );
  }
  ```
- `ninety_nine_game_bloc.dart`:
  ```dart
  if (game.eventId > _lastEventId) {
    _lastEventId = game.eventId;
    await _audioService.playEvent(
      gameType: 'NINETY_NINE',
      eventType: game.eventType,
      serverCue: game.soundCue,
    );
  }
  ```
- `thief_hunt_game_bloc.dart`:
  ```dart
  if (game.eventId > _lastEventId) {
    _lastEventId = game.eventId;
    await _audioService.playEvent(
      gameType: 'THIEF_HUNT',
      eventType: game.eventType,
      serverCue: game.soundCue,
    );
  }
  ```

---

## 7. Conclusion
The audio engine failures in the Let's Fly mobile client are not due to missing audio files or corrupt packages. All 107 WAV assets are present and ready. The root causes are strictly code-level: an overzealous VoIP context setting in `VoiceChatService` that poisoned global Android audio routing, a reliance on Android `SoundPool` via `lowLatency` mode which broke completion tracking and dropped large files, unhooked tennis audio bindings, and missing `playEvent()` invocations across game BLoCs. Addressing these four issues will achieve 100% feature and sound parity with the authoritative Windows reference client.
