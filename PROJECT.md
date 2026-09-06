# Project: Let's Fly Mobile Client Fixes

## Architecture
- Flutter mobile client matching reference Windows Python client `LetsFly_TableVoice_Fixed_NoTableText_20260902_Final`.
- Modules:
  - `android/`: Android packaging, Gradle build configs, signing configurations, APK release build.
  - `lib/core/audio/`: Polyphonic sound engine, audio voices, VoIP voice chat service, spatial tennis sound engine.
  - `lib/presentation/bloc/`: Game state management BLoCs resolving server event_types to sound cues and handling user game actions.
  - `lib/presentation/screens/game/`: Accessible game table screens rendering only active hand/cards and table voice button.

## Feature Inventory
| # | Feature | Description | Milestone | Source |
|---|---|---|---|---|
| 1 | Production Release Keystore | Generate PKCS12 2048-bit RSA keystore (letsfly-release.jks) and key.properties | M1 | Survey R1 |
| 2 | Gradle Release Signing Config | Configure signingConfigs.release with v1 and v2 signing in android/app/build.gradle, align SDK versions | M1 | Survey R1 |
| 3 | AndroidManifest Cleanup | Remove duplicate package attribute, ensure usesCleartextTraffic is false/absent, set app icon | M1 | Survey R1 |
| 4 | CI Workflow Fix | Remove destructive rm -rf android and flutter create in build.yml to preserve package name and release signing | M1 | Survey R1 |
| 5 | AudioMode Poisoning Fix | Prevent VoiceChatService from hijacking global AndroidAudioMode.inCommunication on room entry; restore normal mode | M2 | Survey R3 |
| 6 | SoundPool Lockup Fix | Switch AudioVoice and TennisSoundEngine from PlayerMode.lowLatency to PlayerMode.mediaPlayer with complete onPlayerComplete lifecycle | M2 | Survey R3 |
| 7 | Tennis Sound Engine Wiring | Wire TennisSoundEngine into TennisGameBloc and TennisTableScreen; handle spatial rally cues and umpire announcements | M2 | Survey R3 |
| 8 | BLoC playEvent Audio Dispatch | Wire _audioService.playEvent() across all game BLoCs on server event_type (cards dealing, card plays, domino clicks, snakes dice, etc.) | M2 | Survey R3 |
| 9 | UNO Instant Tap to Play | Single tap on playable card immediately executes play; wild card opens color picker bottom sheet immediately | M3 | Survey R2 |
| 10 | Domino Instant Tap to Play | Single tap on valid tile plays immediately; tiles with 2 valid branches open side picker immediately; add DominoPlayTileExplicit | M3 | Survey R2 |
| 11 | Scopa Instant Tap to Play | Single tap immediately plays card via ScopaPlayCardExplicit; eliminate 2-step double-tap requirement | M3 | Survey R2 |
| 12 | Ninety Nine Instant Tap to Play | Single tap immediately plays card via NinetyNinePlayCardExplicit; server PENDING_CHOICE triggers modal choice | M3 | Survey R2 |
| 13 | Table UI Clutter Removal | Remove all opponent score lists, status boxes, gesture hint banners, and redundant headers from all table screens | M3 | Survey R4 |
| 14 | Table Screen Minimal Parity | Retain only active hand/cards area and TableVoiceButton on screen during gameplay matching Windows client parity | M3 | Survey R4 |
| 15 | Release APK & Signature Verification | Build release APK, verify signature with apksigner (v1+v2, production cert), verify manifest permissions | M4 | Acceptance Criteria |
| 16 | E2E Integration & Parity Verification | Verify instant card play, sound playback through media stream, and clean UI across all games | M4 | Acceptance Criteria |

## Milestones
| # | Name | Scope | Dependencies | Status |
|---|---|---|---|---|
| 1 | M1: Google Play Protect Resolution | Keystore, Gradle signing, Manifest, and CI workflow | none | DONE |
| 2 | M2: Sound Engine Restoration | AudioMode fix, voice pool lifecycle, tennis sound engine, BLoC playEvent | none | IN_PROGRESS |
| 3 | M3: Instant Card Play & Table UI Cleanup | Single-tap play (UNO, Domino, Scopa, 99) and complete UI cleanup across all table screens | M2 | PLANNED |
| 4 | M4: Final E2E Integration & Verification | Release APK build, apksigner verification, sound and gameplay tests | M1, M2, M3 | PLANNED |

## Interface Contracts
### AudioService <-> Game BLoCs
- `TableAudioService.playEvent({required String gameType, required String eventType, String? serverCue})`
- BLoCs invoke `playEvent` whenever `game.eventId > _lastEventId` to trigger sound effects for cards, tiles, dice, and turn events.

### Game Table Screens <-> Game BLoCs
- Direct explicit play events:
  - UNO: `UnoPlayCardExplicit(card, chosenColor: colorCode)`
  - Domino: `DominoPlayTileExplicit(tile: tile, side: side)`
  - Scopa: `ScopaPlayCardExplicit(cardIndex)`
  - Ninety Nine: `NinetyNinePlayCardExplicit(card)`
- Single tap dispatches these events directly without prior selection step.

## Code Layout
- `android/app/build.gradle`: Android application build configuration and release signing
- `android/key.properties`: Keystore credentials configuration
- `android/app/letsfly-release.jks`: Production release PKCS12 keystore
- `android/app/src/main/AndroidManifest.xml`: Android application manifest
- `.github/workflows/build.yml`: CI build and release workflow
- `lib/core/audio/voice_chat_service.dart`: Voice chat service with safe audio context lifecycle
- `lib/core/audio/audio_voice.dart`: Sound voice wrapper with mediaPlayer mode
- `lib/core/audio/sound_engine.dart`: Polyphonic audio service and event-to-cue mapper
- `lib/core/audio/tennis_sound_engine.dart`: Spatial 3D tennis audio engine and umpire player
- `lib/presentation/bloc/`: Game BLoCs handling audio event dispatch and direct card play
- `lib/presentation/screens/game/`: Minimal game table screens showing only active hand and voice button
