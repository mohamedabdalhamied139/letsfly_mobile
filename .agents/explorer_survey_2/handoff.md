# Handoff Report: Explorer Survey 2 (R2: Instant Play & R4: Table UI Cleanup)

## 1. Observation

1. **Card/Tile Interaction in Scopa**:
   - In `Mobile/lib/presentation/screens/game/scopa_table_screen.dart`, lines 309-332:
     ```dart
     309: hint: 'اضغط لتحديده، أو اضغط مرتين للعب الكارت',
     ...
     330: onTap: () {
     331:   context.read<ScopaGameBloc>().add(ScopaSelectCard(idx));
     332: },
     ```
   - Lines 150-155:
     ```dart
     150: onDoubleTap: () {
     151:   if (isMyTurn) {
     152:     context.read<ScopaGameBloc>().add(ScopaPlaySelectedCard());
     153:   }
     154: },
     ```
   - Observation: Single tapping a card only selects it (`ScopaSelectCard(idx)`), forcing the player to double-tap to play it.

2. **Card/Tile Interaction in Ninety Nine**:
   - In `Mobile/lib/presentation/screens/game/ninety_nine_table_screen.dart`, lines 435-458:
     ```dart
     435: hint: 'اضغط لتحديده، أو اضغط مرتين للعب الكارت',
     ...
     456: onTap: () {
     457:   context.read<NinetyNineGameBloc>().add(NinetyNineSelectCard(idx));
     458: },
     ```
   - Lines 247-251:
     ```dart
     247: onDoubleTap: () {
     248:   if (canPlay) {
     249:     context.read<NinetyNineGameBloc>().add(NinetyNinePlaySelectedCard());
     250:   }
     251: },
     ```
   - Observation: Single tapping only selects the card; playing requires a secondary double-tap gesture.

3. **Card/Tile Interaction in Domino**:
   - In `Mobile/lib/presentation/screens/game/domino_table_screen.dart`, lines 442, 480-485:
     ```dart
     442: String semanticsHint = 'اضغط لتحديده، أو اضغط مرتين للعب الكارت';
     ...
     480: context.read<DominoGameBloc>().add(DominoSelectTile(idx));
     481: if (tile.validSides.length > 1) {
     482:   _showSidePicker(context, tile);
     483: } else {
     484:   context.read<DominoGameBloc>().add(const DominoPlaySelectedTile());
     485: }
     ```
   - In `Mobile/lib/presentation/bloc/domino_game_bloc.dart`, lines 244-262:
     ```dart
     244: Future<void> _onPlaySelectedTile(DominoPlaySelectedTile event, Emitter<DominoGameState> emit) async {
     247:   final tile = cur.selectedTile;
     ...
     258:   tileIndex: tile.index,
     ```
   - Observation: In `domino_table_screen.dart`, `DominoSelectTile(idx)` is added immediately before `DominoPlaySelectedTile()`. Because Bloc events execute asynchronously, `cur.selectedTile` inside `_onPlaySelectedTile` refers to the previously selected tile rather than `idx`. Additionally, semantics hint retains the double-tap prompt.

4. **Card Interaction in UNO**:
   - In `Mobile/lib/presentation/screens/game/uno_table_screen.dart`, lines 424-429:
     ```dart
     424: if (playable) {
     425:   context.read<UnoGameBloc>().add(
     426:     UnoSelectCard(idx),
     427:   );
     428:   context.read<UnoGameBloc>().add(
     429:     const UnoPlaySelectedCard(),
     430:   );
     ```
   - Observation: Chaining `UnoSelectCard(idx)` and `UnoPlaySelectedCard()` introduces unnecessary multi-step bloc queuing when `UnoPlayCardExplicit(card)` already exists.

5. **Table Clutter & UI Breakdown**:
   - In `uno_table_screen.dart`:
     - Line 328: `ListTile` 'حالة الطاولة' with top card, color, turn.
     - Line 347: `ExpansionTile` 'نتائج اللاعبين' with all player card counts.
     - Line 368: `Padding` with `Text('كروت يدك (${hand.length})')`.
   - In `domino_table_screen.dart`:
     - Lines 287-366: Table Top Area `Container` ('أطراف الطاولة', ends, sum, board count, boneyard, `lastAction`).
     - Lines 368-399: Opponents Bar horizontal `ListView` of player scores and tile counts.
     - Lines 402-430: Hand presentation header and 'سحب' / 'باص' action buttons.
   - In `scopa_table_screen.dart`:
     - Lines 198-210: Game Status & Score `Container` ('الجولة', 'الهدف', 'الديك', 'مأكولاتك').
     - Lines 212-243: Opponents Bar horizontal `ListView`.
     - Lines 244-252: `game.lastAction` text.
     - Lines 255-286: 'أوراق الطاولة' header & `tableCards` `ListView`.
     - Line 291: 'كروت يدك' header.
   - In `ninety_nine_table_screen.dart`:
     - Lines 294-373: Table Top Area `Container` (Pile value 32pt box, 'اتجاه اللعب', 'الدور الحالي', 'عدد الرموز', `game.lastAction`).
     - Lines 374-409: Opponents Bar horizontal `ListView`.
     - Line 416: 'كروت يدك' header.
   - In `tennis_table_screen.dart`:
     - Lines 186-210: Top score `Container` ('أنت / الخصم: النقاط، الأشواط، المجموعات').
     - Lines 223-228: On-screen gesture hint text:
       ```dart
       const Text('استخدم السحب بإصبعين للتحرك:', style: TextStyle(fontSize: 16)),
       const Text('يسار ← اليسار | يمين ← اليمين | أسفل ← الوسط', style: TextStyle(fontSize: 14)),
       const Text('السحب لأعلى ← سماع النتيجة', style: TextStyle(fontSize: 14)),
       const Text('ضغط بإصبعين ← السجل والدردشة', style: TextStyle(fontSize: 14)),
       ```

6. **Reference Windows Client Inspection**:
   - In `C:\Users\midoa\Downloads\Compressed\LetsFly_TableVoice_Fixed_NoTableText_20260902_Final\client\views\table_view.py`:
     - Line 76: `FocusableWidget`: "Focusable pre-game gameplay container with no table-name text exposed."
     - Lines 1007-1033: `_render_domino_items` populates `domino_tile_list` with **ONLY** the player's hand tiles. No table top area or opponent chips exist on screen.
     - Lines 1200-1320: `update_hand` renders **ONLY** the player's hand cards into `cards_container`. No status tiles or score headers exist on screen.
     - Lines 1650-1662: `_render_scopa_items` renders **ONLY** the player's hand cards in `scopa_card_list`. No table cards or opponent lists exist on screen.
     - Line 1697: `_clear_main_table_item_text` keeps table focus item completely text-free.

---

## 2. Logic Chain

1. **Step 1 (Two-Step Selection Identified)**: Observations 1, 2, and 3 confirm that Scopa, Ninety Nine, and Domino currently employ two-step interactions (`SelectCard` on single tap + `DoubleTap` gesture to play, with explicit semantics hints instructing the user to double tap).
2. **Step 2 (Immediate Play Solution)**:
   - In Scopa, `ScopaPlayCardExplicit(idx)` exists in `scopa_game_bloc.dart:247`. Replacing `ScopaSelectCard(idx)` in `scopa_table_screen.dart:331` with `ScopaPlayCardExplicit(idx)` immediately plays the card on single tap.
   - In Ninety Nine, `NinetyNinePlayCardExplicit(card)` exists in `ninety_nine_game_bloc.dart:269`. Replacing `NinetyNineSelectCard(idx)` with `NinetyNinePlayCardExplicit(card)` immediately plays the card on single tap (with server prompting `PENDING_CHOICE` for 10/Ace choices when outside safe auto-resolve ranges).
   - In Domino, replacing the asynchronous `DominoSelectTile` + `DominoPlaySelectedTile` with a direct `DominoPlayTileExplicit(tile, side)` eliminates the race condition and immediately plays the tile (or opens `_showSidePicker` when `validSides.length > 1`).
   - In UNO, invoking `_showWildColorPicker` immediately when `card.isWild` is tapped, and `UnoPlayCardExplicit(card)` for all other playable cards, satisfies immediate single-tap play without selection queuing.
3. **Step 3 (Table UI Clutter Identified)**: Observation 5 shows that every game table screen in Mobile contains multiple redundant widgets (status boxes, player lists, section headers, gesture hint text banners).
4. **Step 4 (Windows Client Parity)**: Observation 6 demonstrates that the reference Windows client (`Fixed_NoTableText`) deliberately excludes all such on-screen text and visual clutter, leaving only the active gameplay hand/dice and voice integration on screen.
5. **Step 5 (Preservation of Non-Visual Access)**: All status information (scores, table cards, pile value, ends) is already wired into `AccessibilityAnnouncer` via directional swipe gestures (`onSwipeLeft`, `onSwipeUp`, `onSwipeDown`) and `showTableNavigationMenu` (`TableNavigationMenu`). Therefore, stripping visual clutter from the table body complies with Requirement R4 while maintaining full accessibility.

---

## 3. Caveats

- **Network / Voice Subsystem**: Voice chat audio encoding and UDP socket transport are handled by `VoiceChatService` and `RoomWsService` (covered by Explorer 1/Sound Engine); UI cleanup retains `TableVoiceButton` untouched.
- **Table Waiting Lobby**: The pre-game waiting view (`TableWaitingView` / waiting state before game starts) is distinct from gameplay (`isPlaying`); UI cleanup strictly targets the active gameplay table screens.
- **Server Choice Engine**: In Ninety Nine, the server applies smart safe auto-resolve for 10 and Ace (e.g. >=90 automatic -10); client immediate play seamlessly respects server choice states.

---

## 4. Conclusion

1. **Requirement R2 (Instant Card Play on Tap)** is fully actionable:
   - Eliminate two-step selection in Scopa and Ninety Nine by directly calling `PlayCardExplicit` on single tap.
   - Eliminate race conditions in Domino by introducing `DominoPlayTileExplicit` and opening `_showSidePicker` on single tap when `validSides.length > 1`.
   - Update Semantics hints to remove all references to "اضغط مرتين للعب الكارت".
   - Remove obsolete `onDoubleTap` handlers from `LetsFlyGestureHandler`.
2. **Requirement R4 (Complete UI Cleanup on Tables)** is fully actionable:
   - Strip all status cards, opponent score horizontal bars, redundant section headers, dividers, and gesture instruction text from all game table screens.
   - Retain **ONLY** the active cards/hand area (or active board controls) and the `TableVoiceButton` in the gameplay view.
   - Ensure all removed visual status details remain accessible via swipe gestures and `showTableNavigationMenu`.

Detailed implementation blueprints and code mappings are documented in `survey_report.md`.

---

## 5. Verification Method

1. **Static Analysis & Inspection**:
   - Inspect `Mobile/lib/presentation/screens/game/scopa_table_screen.dart` to verify `onTap` directly dispatches `ScopaPlayCardExplicit` and `hint: 'اضغط لتحديده، أو اضغط مرتين للعب الكارت'` is removed.
   - Inspect `Mobile/lib/presentation/screens/game/ninety_nine_table_screen.dart` to verify `onTap` dispatches `NinetyNinePlayCardExplicit`.
   - Inspect `Mobile/lib/presentation/screens/game/domino_table_screen.dart` to verify `onTap` calls `DominoPlayTileExplicit` (or `_showSidePicker` if `validSides.length > 1`).
   - Inspect all game screens in `Mobile/lib/presentation/screens/game/` to verify body contains only the active hand area and `TableVoiceButton`.
2. **Dart Analysis**:
   - Run `dart analyze` via Dart SDK at `C:\Users\midoa\AppData\Local\Programs\dart-sdk\bin\dart.exe analyze lib/` to verify zero syntax or typing errors.
3. **Invalidation Conditions**:
   - If single tapping a playable card requires a second tap or gesture to play, R2 is invalidated.
   - If an active game table screen displays table status boxes, opponent lists, gesture hint text, or redundant hand headers during gameplay, R4 is invalidated.
