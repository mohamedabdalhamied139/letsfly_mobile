# Soft Handoff: Project Orchestrator to Successor (Generation 2)

**From**: Project Orchestrator Gen 1 (`34c1fd39-742a-4397-b475-7a828e6a1fd7`)  
**To**: Project Orchestrator Gen 2 (`orchestrator_gen2`)  
**Date**: 2026-09-06  
**Type**: Soft Handoff (Self-Succession at Spawn Quota Threshold: 16/16)  
**Parent (Sentinel)**: `92025069-9692-440c-8a8d-c1f5b35712d7`  
**Workspace**: `C:\Users\midoa\Downloads\Compressed\letsfly_final_100_parity_reviewed\Mobile`  
**Authoritative User Request**: `C:\Users\midoa\Downloads\Compressed\letsfly_final_100_parity_reviewed\Mobile\.agents\ORIGINAL_REQUEST.md`  
**Master Plan**: `C:\Users\midoa\Downloads\Compressed\letsfly_final_100_parity_reviewed\Mobile\PROJECT.md`  

---

## 1. Observation & State Completed So Far

1. **Phase 0: Comprehensive Survey Complete**:
   - Spawned 3 parallel Explorers covering R1, R2, R3, and R4 against the authoritative Windows codebase (`LetsFly_TableVoice_Fixed_NoTableText_20260902_Final`).
   - Reports stored in `.agents/explorer_survey_1/`, `.agents/explorer_survey_2/`, `.agents/explorer_survey_3/`.

2. **Milestone 1 (R1: Google Play Protect Resolution) — DONE & VERIFIED**:
   - Production PKCS12 release keystore created at `android/app/letsfly-release.jks` (RSA 2048-bit, 10,000 days validity to 2054, alias `letsfly`, password `letsfly2026`, DN `CN=LetsFly Mobile, OU=Mobile, O=LetsFly, L=Cairo, ST=Cairo, C=EG`).
   - `android/key.properties` configured and resolving to the keystore.
   - `android/app/build.gradle` configured for v1 + v2 release signing, compileSdk 34, versionCode 86, versionName "8.6.0".
   - `android/app/src/main/AndroidManifest.xml` cleaned (removed deprecated package attribute, icon configured, cleartext traffic absent).
   - `.github/workflows/build.yml` cleaned of destructive `rm -rf android` and `flutter create`; configured with `Configure Keystore` step.
   - `lib/core/services/app_update_manager.dart` synchronized to version 8.6.0 (code 86).
   - `version.json` cleaned of UTF-8 BOM.
   - Verified across 3 test harnesses: `m1_challenger2_packaging_harness.py` (60/60 PASSED), `m1_empirical_challenge.py` (59/59 PASSED), `verify_m1.py` (ALL PASSED).
   - Gate 2 passed: Auditor CLEAN, Challenger APPROVE, Reviewers APPROVE.
   - Marked DONE in `PROJECT.md`.

3. **Milestone 2 (R3: Complete Game Sound Engine Restoration) — 95% COMPLETE (Remediation Needed)**:
   - Worker M2 implemented:
     - `voice_chat_service.dart`: Removed `_initAudioContext()` from constructor to eliminate Android audio mode poisoning. VoIP mode applied only on `joinSession()`; normal media mode restored on `leaveSession()` and `detach()`.
     - `audio_voice.dart`: Switched to `PlayerMode.mediaPlayer` with safety timer (15s) and reliable completion tracking.
     - `sound_engine.dart`: Configured audio focus and sonification.
     - `tennis_sound_engine.dart`: Switched `_umpirePlayer` to `PlayerMode.mediaPlayer` with 10s safety timer.
     - `tennis_table_screen.dart` & `tennis_game_bloc.dart`: Injected `TennisSoundEngine`, wired spatial rally cues with player 1 inversion, suppressed screen reader announcements during active rally.
     - Game BLoCs: Wired `playEvent` on server `event_type` across all 7 games (UNO, Domino, Scopa, Snakes & Ladders, Farkle, Ninety Nine, Thief Hunt).
   - Forensic Auditor verdict: **CLEAN** (all 107 sound assets verified).
   - Reviewer M2 verdict: **REQUEST_CHANGES** on a single minor edge case:
     - In `lib/core/audio/tennis_sound_engine.dart`: `_umpirePlayer` is `late final AudioPlayer` and only initialized in `initialize()`. If `TennisSoundEngine.dispose()` or `stopAll()` is called before `initialize()` has run, it throws `LateInitializationError: Field '_umpirePlayer' has not been initialized.`.
     - Remediation: Add `if (!_initialized) return;` at the start of `dispose()` and guard `_umpirePlayer.stop()` in `stopAll()`. Also place `test_sound_engine_restoration.dart` into `test/` folder.

---

## 2. Milestone State

| Milestone | Name | Scope | Dependencies | Status |
|---|---|---|---|---|
| M1 | Google Play Protect Resolution | Keystore, Gradle signing, Manifest, CI | none | **DONE** |
| M2 | Sound Engine Restoration | AudioMode fix, voice pool, tennis engine, BLoC playEvent | none | **IN_PROGRESS (Remediation required)** |
| M3 | Instant Card Play & Table UI Cleanup | Single-tap play (UNO, Domino, Scopa, 99) and complete UI cleanup across all table screens | M2 | **PLANNED** |
| M4 | Final E2E Integration & Verification | Release APK build, apksigner verification, sound and gameplay tests | M1, M2, M3 | **PLANNED** |

---

## 3. Active Subagents

None. All subagents from Generation 1 have completed and have been cleanly terminated.

---

## 4. Pending Decisions & Key Constraints

- **STRICT USER INSTRUCTION RULE**: Follow user requirements exactly. Do not expand scope or add unrequested features.
- **Model Configuration**: Use `Model="flash"` for subagents to avoid 429 quota exhaustion encountered with `inherit`.
- **Audit is a binary veto**: If Forensic Auditor reports INTEGRITY VIOLATION, milestone fails unconditionally.
- **M2 Remediation**: Ready to dispatch Worker M2 Remediation to add the `_initialized` guard to `TennisSoundEngine.dispose()` and copy the test to `test/test_sound_engine_restoration.dart`.

---

## 5. Remaining Work & Concrete Next Steps for Successor

### Step 1: Complete Milestone 2 (Sound Engine Restoration)
1. Spawn a Worker (`teamwork_preview_worker`, `Model="flash"`) to:
   - Edit `lib/core/audio/tennis_sound_engine.dart`: Add `if (!_initialized) return;` at the start of `dispose()`, and in `stopAll()` check `if (_initialized) { await _umpirePlayer.stop(); }`.
   - Copy or place `test_sound_engine_restoration.dart` into `Mobile/test/test_sound_engine_restoration.dart`.
   - Run `dart test/test_sound_engine_restoration.dart`, `dart test/stress_polyphonic_pool.dart`, and `dart test/adversarial_sound_stress.dart`.
2. Spawn Reviewer and Auditor to verify and approve M2.
3. Update `GATE_STATUS.md` and mark M2 **DONE** in `PROJECT.md`.

### Step 2: Execute Milestone 3 (Requirements R2 & R4: Instant Card Play on Tap & Table UI Cleanup)
1. Read `C:\Users\midoa\Downloads\Compressed\letsfly_final_100_parity_reviewed\Mobile\.agents\explorer_survey_2\survey_report.md` for exact line numbers and code changes.
2. Spawn Worker M3 (`teamwork_preview_worker`, `Model="flash"`) to:
   - **R2 Instant Play**:
     - `uno_table_screen.dart`: Single-tap playable card directly plays; wild card immediately opens `_showWildColorPicker`.
     - `domino_table_screen.dart`: Add `DominoPlayTileExplicit` to `domino_game_bloc.dart`. Single tap plays immediately if valid; if 2 branches valid (`validSides.length > 1`), immediately opens `_showSidePicker`. Remove obsolete double-tap hint.
     - `scopa_table_screen.dart`: Single tap dispatches `ScopaPlayCardExplicit(idx)` directly. Remove double-tap requirement.
     - `ninety_nine_table_screen.dart`: Single tap dispatches `NinetyNinePlayCardExplicit(card)`. Server `PENDING_CHOICE` triggers modal value dialog. Remove double-tap requirement.
   - **R4 Table UI Cleanup**:
     - Strip visual table status boxes, opponent score lists, redundant section headers (`كروت يدك`, `أوراق الطاولة`, `قطعك`), dividers, and on-screen gesture hints from table screens (`uno_table_screen.dart`, `domino_table_screen.dart`, `scopa_table_screen.dart`, `ninety_nine_table_screen.dart`, `farkle_table_screen.dart`, `snakes_and_ladders_table_screen.dart`, `tennis_table_screen.dart`, `thief_hunt_table_screen.dart`).
     - Retain ONLY the active hand/cards area and the `TableVoiceButton` on screen during gameplay, matching reference Windows client parity (`LetsFly_TableVoice_Fixed_NoTableText_20260902_Final`).
3. Gate M3: Reviewer, Challenger, and Auditor verification.

### Step 3: Execute Milestone 4 (E2E Integration & Verification)
1. Run full test suite: E2E test runner, audio tests, parity contracts.
2. Verify all 4 requirements from `ORIGINAL_REQUEST.md`:
   - R1: Release APK signing, keystore, manifest, CI.
   - R2: Single-tap instant play on UNO, Domino, Scopa, 99.
   - R3: Game sound engine restoration and media stream routing.
   - R4: Clean table screens with only hand and voice button.
3. Report final completion back to Sentinel (`92025069-9692-440c-8a8d-c1f5b35712d7`).

---

## 6. Key Artifacts
- `ORIGINAL_REQUEST.md`: `C:\Users\midoa\Downloads\Compressed\letsfly_final_100_parity_reviewed\Mobile\.agents\ORIGINAL_REQUEST.md`
- `PROJECT.md`: `C:\Users\midoa\Downloads\Compressed\letsfly_final_100_parity_reviewed\Mobile\PROJECT.md`
- `GATE_STATUS.md`: `C:\Users\midoa\Downloads\Compressed\letsfly_final_100_parity_reviewed\Mobile\.agents\orchestrator_1\GATE_STATUS.md`
- `BRIEFING.md`: `C:\Users\midoa\Downloads\Compressed\letsfly_final_100_parity_reviewed\Mobile\.agents\orchestrator_1\BRIEFING.md`
- `progress.md`: `C:\Users\midoa\Downloads\Compressed\letsfly_final_100_parity_reviewed\Mobile\.agents\orchestrator_1\progress.md`
- Survey Reports:
  - R1: `.agents/explorer_survey_1/survey_report.md`
  - R2 & R4: `.agents/explorer_survey_2/survey_report.md`
  - R3: `.agents/explorer_survey_3/survey_report.md`
- Handoff Reports:
  - M1: `.agents/worker_m1_retry/handoff.md`
  - M2: `.agents/worker_m2/handoff.md`
