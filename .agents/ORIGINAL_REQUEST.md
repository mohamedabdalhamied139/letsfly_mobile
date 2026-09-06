# Original User Request

## 2026-09-06T18:36:25Z

Fix the Let's Fly Flutter mobile client to address Google Play Protect blocking, enable instant card playing on tap, restore game sound effects, and clean in-game table UI completely according to the reference Windows Python client.

Working directory: `C:\Users\midoa\Downloads\Compressed\letsfly_final_100_parity_reviewed\Mobile`
Reference Windows codebase: `C:\Users\midoa\Downloads\Compressed\LetsFly_TableVoice_Fixed_NoTableText_20260902_Final`

## Requirements

### R1. Google Play Protect Resolution (APK Signature & Package Details)
- The app must not trigger Google Play Protect blocked app warnings when installed on Android.
- Configure proper APK release signing in Gradle / Android build config or adjust applicationId/permissions if flagged.

### R2. Instant Card Play on Tap (No Two-Step Selection)
- In card/tile games (UNO, Domino, Scopa, Ninety Nine), tapping a card must directly play it immediately if valid, instead of selecting it first.
- If a card requires a choice (e.g., Domino branch choice or Uno wild color choice), tapping opens that immediate choice dialog/sheet; otherwise it executes the play action on single tap.

### R3. Complete Game Sound Engine Restoration
- All in-game sound effects (cards dealing, play sounds, domino clicks, tennis rally, snakes dice, etc.) must play properly through the media stream without silence or errors.
- Verify asset paths, audio player initialization, and sound engine bindings against Windows sounds.

### R4. Complete UI Cleanup on Tables
- Remove all non-essential on-screen gesture hints, helper text, and extra action buttons from game table screens.
- Keep only the cards/hand area and the voice button on the screen during gameplay.

## Acceptance Criteria

### Verification & Quality
- [ ] APK installs smoothly without Google Play Protect blocking.
- [ ] Single tapping a valid card or domino tile immediately plays it.
- [ ] In-game sound effects trigger and are clearly audible during gameplay.
- [ ] Table screen displays only the active hand/cards and the voice button without clutter or redundant labels.
