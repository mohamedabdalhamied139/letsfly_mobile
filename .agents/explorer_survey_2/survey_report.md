# Comprehensive Survey Report: R2 (Instant Card Play on Tap) & R4 (Table UI Cleanup)

## Executive Summary
This investigation covers Requirement R2 (**Instant Card Play on Tap - No Two-Step Selection**) and Requirement R4 (**Complete UI Cleanup on Tables**) for the Let's Fly Mobile Flutter client (`Mobile/lib/`), compared directly against the reference Windows Python client (`LetsFly_TableVoice_Fixed_NoTableText_20260902_Final`).

### Core Findings
1. **Requirement R2 (Card/Tile Interaction)**:
   - **Scopa & Ninety Nine**: Currently enforce a rigid, two-step selection interaction (`Single Tap` solely selects the card by dispatching `SelectCard(idx)`, and the user is forced to perform a `Double Tap` gesture to trigger `PlaySelectedCard()`). Screen reader semantics explicitly declare: `"اضغط لتحديده، أو اضغط مرتين للعب الكارت"`.
   - **Domino**: Has an asynchronous race condition in `onTap` (dispatches `DominoSelectTile(idx)` immediately followed by `DominoPlaySelectedTile()`, which evaluates the asynchronous state's `selectedTile` rather than the tapped tile index). Furthermore, the semantics hint still instructs users to double-tap, and gesture handlers retain obsolete double-tap bindings.
   - **UNO**: Dispatches two consecutive events (`UnoSelectCard` + `UnoPlaySelectedCard`) instead of a single, direct explicit play event.
   - **Solution for R2**: Single tapping any valid card or tile must immediately play it in one step without prior selection. If a choice is required (Domino left/right branch choice, UNO wild color choice, Ninety Nine 10/Ace value choice), single tapping opens that choice dialog/sheet immediately.

2. **Requirement R4 (Complete UI Cleanup on Tables)**:
   - Every game table screen (`uno_table_screen.dart`, `domino_table_screen.dart`, `scopa_table_screen.dart`, `ninety_nine_table_screen.dart`, `farkle_table_screen.dart`, `snakes_and_ladders_table_screen.dart`, `tennis_table_screen.dart`, `thief_hunt_table_screen.dart`) is currently cluttered with visual table status cards, player/opponent score lists, redundant section headers (`كروت يدك (N)`, `قطعك (N)`, `أوراق الطاولة`), dividers, and on-screen gesture instruction text (e.g. in Tennis: `"استخدم السحب بإصبعين للتحرك: يسار ← اليسار..."`).
   - **Reference Windows Client Parity**: As evidenced by `LetsFly_TableVoice_Fixed_NoTableText_20260902_Final/client/views/table_view.py`, during gameplay, the screen displays **ONLY** the active cards/hand container (`cards_container`, `domino_tile_list`, `scopa_card_list`, etc.) and the table voice controls, with zero on-screen table text or status clutter. All auxiliary information (scores, table cards, opponent counts, turns) is served dynamically via TTS announcements (`AccessibilityAnnouncer`), directional swipe gestures, and the accessible Table Navigation Menu (`TableNavigationMenu`).
   - **Solution for R4**: Strip all non-essential visual headers, opponent bars, status tiles, and gesture hint text from game table bodies so that **ONLY** the active hand/cards area and the `TableVoiceButton` remain on the screen.

---

## 1. Requirement R2: Instant Card Play on Tap (Detailed Survey)

### 1.1 UNO (`Mobile/lib/presentation/screens/game/uno_table_screen.dart`)
- **Current File & Lines**:
  - `uno_table_screen.dart:421-438`:
    ```dart
    onTap: () {
      if (isMyTurn) {
        if (playable) {
          context.read<UnoGameBloc>().add(
            UnoSelectCard(idx),
          );
          context.read<UnoGameBloc>().add(
            const UnoPlaySelectedCard(),
          );
        } else {
          announcer.announce('لا يمكنك لعب هذا الكارت الآن');
        }
      } else {
        announcer.announce('ليس دورك للعب');
      }
    }
    ```
  - `uno_game_bloc.dart:295-325`:
    - `_onPlaySelectedCard` looks up `cur.selectedCard` and delegates to `_onPlayCardExplicit(card, chosenColor: event.chosenColor)`.
    - If `card.isWild` and `chosenColor` is null/empty, `_onPlayCardExplicit` emits `wildPendingCard: card` and announces `"اختر لونًا جديدًا للكارت الحر"`.
    - `UnoTableScreen` listens to `wildPendingCard != null` and invokes `_showWildColorPicker(context, state.wildPendingCard!)`.
- **Issues Identified**:
  - Tapping dispatches two separate events (`UnoSelectCard` and `UnoPlaySelectedCard`).
  - While it attempts immediate execution, chaining `UnoSelectCard(idx)` and `UnoPlaySelectedCard()` relies on `cur.selectedCard` which may create intermediate UI jitter.
  - If `card.isWild`, single tapping must directly open `_showWildColorPicker(context, card)`.
- **Immediate Play Blueprint**:
  - Single tap on card:
    - If `!isMyTurn`: announce `'ليس دورك للعب'`.
    - If `!playable`: announce `'لا يمكنك لعب هذا الكارت الآن'`.
    - If `playable`:
      - If `card.isWild`: directly call `_showWildColorPicker(context, card)` without waiting or selecting. When the user taps a color button, it dispatches `UnoPlayCardExplicit(card, chosenColor: colorCode)`.
      - Else: directly dispatch `UnoPlayCardExplicit(card)`.

### 1.2 Domino & American Domino (`Mobile/lib/presentation/screens/game/domino_table_screen.dart`)
- **Current File & Lines**:
  - `domino_table_screen.dart:442`:
    ```dart
    String semanticsHint = 'اضغط لتحديده، أو اضغط مرتين للعب الكارت';
    if (!tile.isValid) {
      semanticsHint = 'القطعة غير صالحة للعب الآن';
    }
    ```
  - `domino_table_screen.dart:257-269`:
    ```dart
    onDoubleTap: () {
      if (isMyTurn && selectedTile != null && selectedTile.isValid) {
        if (selectedTile.validSides.length > 1) {
          _showSidePicker(context, selectedTile);
        } else {
          context.read<DominoGameBloc>().add(const DominoPlaySelectedTile());
        }
      ...
    ```
  - `domino_table_screen.dart:471-486`:
    ```dart
    onTap: () {
      if (!isMyTurn) {
        announcer.announce('ليس دورك للعب');
        return;
      }
      if (!tile.isValid) {
        announcer.announce('القطعة غير صالحة للعب الآن');
        return;
      }
      context.read<DominoGameBloc>().add(DominoSelectTile(idx));
      if (tile.validSides.length > 1) {
        _showSidePicker(context, tile);
      } else {
        context.read<DominoGameBloc>().add(const DominoPlaySelectedTile());
      }
    }
    ```
  - `domino_game_bloc.dart:244-262`:
    ```dart
    Future<void> _onPlaySelectedTile(DominoPlaySelectedTile event, Emitter<DominoGameState> emit) async {
      final cur = state as DominoGamePlaying;
      final tile = cur.selectedTile; // <--- Depends on state.selectedTile!
      ...
      await _roomWsService.sendGameAction('play', tileIndex: tile.index, side: event.side);
    }
    ```
- **Issues Identified**:
  - **Misleading Screen Reader Hint**: Line 442 tells users `"اضغط لتحديده، أو اضغط مرتين للعب الكارت"`.
  - **Obsolete Double Tap**: Line 257 in `LetsFlyGestureWrapper` implements double-tap to play selected tile.
  - **Asynchronous Race Condition**: In `onTap`, `context.read<DominoGameBloc>().add(DominoSelectTile(idx))` is dispatched, and immediately afterwards `DominoPlaySelectedTile()` is dispatched. Because Bloc event handling is asynchronous, `DominoPlaySelectedTile()` reads `state.selectedTile` which has **NOT** yet been updated to `idx`, causing the previously selected tile to be played instead!
  - **Side Choice Handling**: In `_showSidePicker`, `DominoPlaySelectedTile(side: side)` is called, which again depends on `selectedTile`.
- **Immediate Play Blueprint**:
  - Update `DominoGameBloc` to add `DominoPlayTileExplicit({required DominoHandTile tile, String side = 'auto'})` (or `DominoPlayTile({required int tileIndex, String side = 'auto'})`).
  - In `onTap`:
    - If `!isMyTurn`: announce `'ليس دورك للعب'`.
    - If `!tile.isValid`: announce `'القطعة غير صالحة للعب الآن'`.
    - If `tile.isValid`:
      - If `tile.validSides.length > 1`: immediately call `_showSidePicker(context, tile)`. When the user selects a side (left or right), immediately dispatch `DominoPlayTileExplicit(tile: tile, side: side)`.
      - Else: immediately dispatch `DominoPlayTileExplicit(tile: tile, side: tile.validSides.isNotEmpty ? tile.validSides[0] : 'auto')`.
  - Semantics hint: update to `'اضغط للعب القطعة'` (or remove hint when single tap is standard button tap).
  - Remove `onDoubleTap` from `LetsFlyGestureHandler`.

### 1.3 Scopa (`Mobile/lib/presentation/screens/game/scopa_table_screen.dart`)
- **Current File & Lines**:
  - `scopa_table_screen.dart:309`:
    ```dart
    hint: 'اضغط لتحديده، أو اضغط مرتين للعب الكارت',
    ```
  - `scopa_table_screen.dart:330-332`:
    ```dart
    onTap: () {
      context.read<ScopaGameBloc>().add(ScopaSelectCard(idx));
    },
    ```
  - `scopa_table_screen.dart:150-155`:
    ```dart
    onDoubleTap: () {
      if (isMyTurn) {
        context.read<ScopaGameBloc>().add(ScopaPlaySelectedCard());
      }
    },
    ```
  - `scopa_game_bloc.dart:247-259`:
    `ScopaPlayCardExplicit(event.cardIndex)` already exists and directly sends:
    ```dart
    await _roomWsService.sendGameAction('play', payload: {'card_index': event.cardIndex});
    ```
- **Issues Identified**:
  - **Hard Two-Step Selection**: Single tap does nothing except highlight the card with `ScopaSelectCard(idx)`. The user must double tap the gesture board to play it.
  - Screen reader semantics verbatim: `"اضغط لتحديده، أو اضغط مرتين للعب الكارت"`.
- **Immediate Play Blueprint**:
  - In `onTap` for each Scopa card:
    ```dart
    if (!isMyTurn) {
      announcer.announce('ليس دورك للعب');
      return;
    }
    context.read<ScopaGameBloc>().add(ScopaPlayCardExplicit(idx));
    ```
  - Update Semantics: remove `hint: 'اضغط لتحديده، أو اضغط مرتين للعب الكارت'`.
  - Remove `onDoubleTap` from `LetsFlyGestureHandler`.

### 1.4 Ninety Nine (99) (`Mobile/lib/presentation/screens/game/ninety_nine_table_screen.dart`)
- **Current File & Lines**:
  - `ninety_nine_table_screen.dart:435`:
    ```dart
    hint: 'اضغط لتحديده، أو اضغط مرتين للعب الكارت',
    ```
  - `ninety_nine_table_screen.dart:456-458`:
    ```dart
    onTap: () {
      context.read<NinetyNineGameBloc>().add(NinetyNineSelectCard(idx));
    },
    ```
  - `ninety_nine_table_screen.dart:247-251`:
    ```dart
    onDoubleTap: () {
      if (canPlay) {
        context.read<NinetyNineGameBloc>().add(NinetyNinePlaySelectedCard());
      }
    },
    ```
  - `ninety_nine_game_bloc.dart:269-278`:
    `NinetyNinePlayCardExplicit(this.card)` already exists:
    ```dart
    await _roomWsService.sendGameAction('play', data: card.cardId);
    ```
  - `ninety_nine_table_screen.dart:85-147`:
    `_showChoiceDialog(context, pendingChoice)` handles modal value selection (+10/-10 for '10', +1/+11 for 'A').
- **Issues Identified**:
  - **Hard Two-Step Selection**: Single tap only sets `selectedIndex`. The player has to double tap the gesture controller to play.
  - Screen reader semantics verbatim: `"اضغط لتحديده، أو اضغط مرتين للعب الكارت"`.
- **Immediate Play Blueprint**:
  - In `onTap` for each Ninety Nine card:
    ```dart
    if (!isMyTurn) {
      announcer.announce('ليس دورك للعب');
      return;
    }
    context.read<NinetyNineGameBloc>().add(NinetyNinePlayCardExplicit(card));
    ```
  - When the card played is a 10 or Ace, if outside the server's auto-safe resolve range, the server immediately emits `PENDING_CHOICE` which triggers `_showChoiceDialog` via BlocConsumer listener.
  - Update Semantics: remove double-tap hint.
  - Remove `onDoubleTap` from `LetsFlyGestureHandler`.

---

## 2. Requirement R4: Complete UI Cleanup on Tables (Detailed Survey)

### 2.1 Reference Windows Client Architecture Analysis
In `LetsFly_TableVoice_Fixed_NoTableText_20260902_Final`:
- **Repository Title**: `LetsFly_TableVoice_Fixed_NoTableText_20260902_Final`. Note the explicit emphasis on **"Fixed_NoTableText"** and **"TableVoice"**.
- In `client/views/table_view.py`:
  - **Line 1-10**:
    ```python
    """Accessible table view for Let's Fly UNO.
    Features:
    - Clean 3-point TAB order:
      - Before start: main gameplay focus -> الدردشة -> السجل
      - After start: gameplay/hand -> الدردشة -> السجل
    - Pure card names on focus without redundant prefixes or labels.
    - Wild color picker modal (أحمر، أصفر، أخضر، أزرق) with "اختر اللون" speech.
    - Clean separation between waiting lobby and gameplay.
    """
    ```
  - **Line 75-94**: `FocusableWidget`: "Focusable pre-game gameplay container with no table-name text exposed." `self.setAccessibleName("")`, `self.setAccessibleDescription("")`.
  - **Line 1007-1033**: `domino_tile_list` renders **ONLY** the player's hand tiles. There is no visible table-top container, no opponent chips, no boneyard counters.
  - **Line 1200-1320**: `update_hand` renders **ONLY** the player's hand cards in `cards_container`. No table status, no scores tile.
  - **Line 1650-1662**: `scopa_card_list` renders **ONLY** the player's hand cards. No visible table cards list, no opponent bar, no score cards.
  - **Line 1697**: `_clear_main_table_item_text`: "Keep the pre-game table focus item completely text-free for NVDA/Qt accessibility."
  - **Table Voice**: Always accessible via global shortcut / voice chat toggle without taking up table screen real estate.
  - **Dynamic Audio Announcements**: Turn state, opponents, remaining cards, and table cards are spoken via TTS upon turn changes or key requests (`reader.speak`), avoiding persistent visual clutter on the gameplay surface.

### 2.2 Table-by-Table Visual Inventory & Clutter Breakdown

| Screen File | Current Clutter Elements (To Remove) | What Remains on Screen (R4 Compliance) |
|---|---|---|
| **UNO** (`uno_table_screen.dart`) | 1. `ListTile` 'حالة الطاولة' (line 328)<br>2. Subtitle with top card, color, turn<br>3. `ExpansionTile` 'نتائج اللاعبين' (line 347)<br>4. Header text 'كروت يدك (N)' (line 368)<br>5. Dividers (lines 345, 363) | 1. Active Hand Cards area (`ListView.builder` of playable card tiles)<br>2. `TableVoiceButton` (floatingActionButton)<br>3. Clean AppBar with turn title & options/navigation icons |
| **Domino** (`domino_table_screen.dart`) | 1. Table Top Area `Container` ('أطراف الطاولة', ends, sum, turn, count, `lastAction`) (lines 287-366)<br>2. Opponents Bar horizontal `ListView` (lines 368-399)<br>3. Hand presentation header `AccessibleHeader('قطعك (N)')` and 'سحب' / 'باص' action buttons (lines 402-430)<br>4. Divider (line 400) | 1. Active Hand Tiles area (`ListView.builder` of domino tiles)<br>2. `TableVoiceButton` (floatingActionButton)<br>3. Clean AppBar |
| **Scopa** (`scopa_table_screen.dart`) | 1. Status Bar `Container` ('الجولة', 'الهدف', 'الديك', 'مأكولاتك') (lines 198-210)<br>2. Opponents Bar horizontal `ListView` (lines 212-243)<br>3. `game.lastAction` text (lines 244-252)<br>4. 'أوراق الطاولة' header & `tableCards` `ListView` (lines 255-286)<br>5. 'كروت يدك (N)' header (lines 289-293)<br>6. Multiple Dividers (lines 253, 287) | 1. Active Hand Cards area (`ListView.builder` of Scopa cards)<br>2. `TableVoiceButton` (floatingActionButton)<br>3. Clean AppBar |
| **Ninety Nine** (`ninety_nine_table_screen.dart`) | 1. Table Top Area `Container` (Large 32pt Pile value box, direction, turn, tokens, `lastAction`) (lines 294-373)<br>2. Opponents Bar horizontal `ListView` (lines 374-409)<br>3. 'كروت يدك (N)' header (lines 412-419)<br>4. Divider (line 410) | 1. Active Hand Cards area (`ListView.builder` of 99 cards)<br>2. `TableVoiceButton` (floatingActionButton)<br>3. Clean AppBar |
| **Farkle** (`farkle_table_screen.dart`) | 1. Status Bar `Container` ('الهدف', 'مجموع الدور') (lines 108-124)<br>2. Scores List `Container` (lines 126-147)<br>3. 'النرد الحالي' header (line 155)<br>4. 'الإجراءات المتاحة' header (line 182)<br>5. Dividers (lines 148, 173) | 1. Farkle active gameplay area (interactive dice chips, available scoring combinations, roll & bank controls)<br>2. `TableVoiceButton` (floatingActionButton)<br>3. Clean AppBar |
| **Snakes & Ladders** (`snakes_and_ladders_table_screen.dart`) | 1. Table Status `Container` ('طاولة السلم والثعبان', 'الدور الحالي', 'لعبة إضافية', `lastAction`) (lines 212-265)<br>2. 'مراكز اللاعبين' header (line 272)<br>3. Divider (line 266) | 1. Player positions board list (`ListView.builder`) and roll dice button<br>2. `TableVoiceButton` (floatingActionButton)<br>3. Clean AppBar |
| **Tennis** (`tennis_table_screen.dart`) | 1. Top score `Container` ('أنت / الخصم: النقاط، الأشواط، المجموعات') (lines 186-210)<br>2. On-screen gesture hint text (lines 223-228):<br>   - `"استخدم السحب بإصبعين للتحرك:"`<br>   - `"يسار ← اليسار \| يمين ← اليمين \| أسفل ← الوسط"`<br>   - `"السحب لأعلى ← سماع النتيجة"`<br>   - `"ضغط بإصبعين ← السجل والدردشة"`<br>3. Divider (line 211) | 1. Current Lane / serve action area<br>2. `TableVoiceButton` (floatingActionButton)<br>3. Clean AppBar |
| **Thief Hunt** (`thief_hunt_table_screen.dart`) | 1. Helper text banner `promptText = 'اضغط مرتين بإصبع واحد للبدء بالإجابة (إذا كنت مستعدًا)'` (line 195)<br>2. Redundant player lists & answers headers (lines 293-317)<br>3. Status container clutter (lines 239-263) | 1. Active Floor Input & Submission Area<br>2. `TableVoiceButton` (floatingActionButton)<br>3. Clean AppBar |

### 2.3 Preserving Accessibility and Non-Visual Game State Discovery
A critical finding from analyzing `table_navigation_menu.dart` and `LetsFlyGestureHandler`:
Removing on-screen visual text does **NOT** reduce access for blind or visually impaired players. In fact, it dramatically **improves** the experience:
1. **Swipe Gestures (`LetsFlyGestureHandler`)**:
   - `Swipe Up`: Announces turn name (`announcer.announce('دورك الآن' / 'الدور الحالي للاعب X')`).
   - `Swipe Left`:
     - In UNO: Announces top card & active color.
     - In Domino: Announces open ends (`'اليسار X، اليمين Y، المجموع Z'`).
     - In Scopa: Announces cards on the table (`'الطاولة بها: X و Y'`).
     - In Ninety Nine: Announces pile sum (`'المجموع الحالي في الساحة: X'`).
     - In Snakes: Scans radar.
     - In Tennis: Moves left.
     - In Thief Hunt: Announces round info, start floor, directions.
   - `Swipe Down`:
     - In UNO: Draws a card from deck.
     - In Domino: Draws a tile or passes turn.
     - In Scopa: Announces deck count.
     - In Ninety Nine: Announces no manual draw needed.
     - In Snakes: Announces player positions.
   - `Swipe Right`: Opens the activity & chat log drawer (`_toggleLog`).
2. **Table Navigation Menu (`showTableNavigationMenu`)**:
   - Accessible via the top AppBar exploration icon.
   - Provides spoken queries on demand for:
     - 'اللاعبون على الطاولة' (`TableNavAction.players`)
     - 'النتائج والهدف' (`TableNavAction.scores`)
     - 'الدور الحالي' (`TableNavAction.turn`)
     - 'قواعد اللعبة الحالية' (`TableNavAction.rules`)
     - 'سجل النشاط والدردشة' (`TableNavAction.chat`)
3. **Turn & Action Announcements**:
   - Every game bloc automatically triggers `_announcer.announce(turnStart)` and `_audioService.playCue(turnStart)` whenever the active turn transitions.

---

## 3. Implementation Plan & Blueprint

### 3.1 Bloc Changes (Mobile/lib/presentation/bloc/)
1. **`domino_game_bloc.dart`**:
   - Add new event:
     ```dart
     class DominoPlayTileExplicit extends DominoGameEvent {
       final DominoHandTile tile;
       final String side;
       const DominoPlayTileExplicit({required this.tile, this.side = 'auto'});
       @override
       List<Object?> get props => [tile, side];
     }
     ```
   - In event handler:
     ```dart
     Future<void> _onPlayTileExplicit(DominoPlayTileExplicit event, Emitter<DominoGameState> emit) async {
       if (state is! DominoGamePlaying) return;
       final tile = event.tile;
       if (!tile.isValid) {
         _announcer.announce('هذه القطعة غير صالحة للعب');
         return;
       }
       try {
         await _roomWsService.sendGameAction(
           'play',
           tileIndex: tile.index,
           side: event.side,
         );
       } catch (_) {}
     }
     ```
   - Register event in constructor: `on<DominoPlayTileExplicit>(_onPlayTileExplicit);`.

2. **`uno_game_bloc.dart`**:
   - `UnoPlayCardExplicit(card, chosenColor)` is already defined and fully functional. No bloc event signature changes needed.

3. **`scopa_game_bloc.dart`**:
   - `ScopaPlayCardExplicit(cardIndex)` is already defined and functional. No bloc event signature changes needed.

4. **`ninety_nine_game_bloc.dart`**:
   - `NinetyNinePlayCardExplicit(card)` is already defined and functional. No bloc event signature changes needed.

### 3.2 Screen Changes (Mobile/lib/presentation/screens/game/)

1. **`uno_table_screen.dart`**:
   - **R2**:
     - In card `onTap`:
       ```dart
       onTap: () {
         if (!isMyTurn) {
           announcer.announce('ليس دورك للعب');
           return;
         }
         if (!playable) {
           announcer.announce('لا يمكنك لعب هذا الكارت الآن');
           return;
         }
         if (card.isWild) {
           _showWildColorPicker(context, card);
         } else {
           context.read<UnoGameBloc>().add(UnoPlayCardExplicit(card));
         }
       }
       ```
   - **R4**:
     - Remove `SingleChildScrollView(scrollDirection: Axis.horizontal...)`.
     - In `Scaffold.body`: Replace the cluttered `ListView` containing `ListTile` ('حالة الطاولة'), `ExpansionTile` ('نتائج اللاعبين'), and redundant headers with a clean `ListView.builder` containing **ONLY** the player's hand cards (or empty message if hand is empty).
     - Add `onSwipeLeft` in `LetsFlyGestureHandler` to announce top card and required color so that info is readily spoken.

2. **`domino_table_screen.dart`**:
   - **R2**:
     - In tile `onTap`:
       ```dart
       onTap: () {
         if (!isMyTurn) {
           announcer.announce('ليس دورك للعب');
           return;
         }
         if (!tile.isValid) {
           announcer.announce('القطعة غير صالحة للعب الآن');
           return;
         }
         if (tile.validSides.length > 1) {
           _showSidePicker(context, tile);
         } else {
           final side = tile.validSides.isNotEmpty ? tile.validSides[0] : 'auto';
           context.read<DominoGameBloc>().add(DominoPlayTileExplicit(tile: tile, side: side));
         }
       }
       ```
     - In `_buildSideChoice`:
       ```dart
       onPressed: () {
         Navigator.pop(sheetContext);
         context.read<DominoGameBloc>().add(
           DominoPlayTileExplicit(tile: tile, side: side),
         );
       }
       ```
     - Remove `hint: 'اضغط لتحديده، أو اضغط مرتين للعب الكارت'` from tile `Semantics`.
     - Remove `onDoubleTap` from `gestureHandler`.
   - **R4**:
     - Remove Table Top Area `Container` (lines 287-366).
     - Remove Opponents Bar `Container` (lines 368-399).
     - Remove Hand presentation header row (`AccessibleHeader` and 'سحب'/'باص' buttons).
     - In `Scaffold.body`: Keep **ONLY** the `ListView.builder` of hand tiles.
     - Note: Drawing/passing is seamlessly executed via `onSwipeDown` when no moves exist (`game.canDraw` / `game.canPass`).

3. **`scopa_table_screen.dart`**:
   - **R2**:
     - In card `onTap`:
       ```dart
       onTap: () {
         if (!isMyTurn) {
           announcer.announce('ليس دورك للعب');
           return;
         }
         context.read<ScopaGameBloc>().add(ScopaPlayCardExplicit(idx));
       }
       ```
     - Remove `hint: 'اضغط لتحديده، أو اضغط مرتين للعب الكارت'` from `Semantics`.
     - Remove `onDoubleTap` from `gestureHandler`.
   - **R4**:
     - Remove Game Status & Score `Container` (lines 198-210).
     - Remove Opponents Bar `Container` (lines 212-243).
     - Remove `game.lastAction` text (lines 244-252).
     - Remove 'أوراق الطاولة' header & `tableCards` `ListView` (lines 255-286).
     - Remove 'كروت يدك' header (line 291).
     - In `Scaffold.body`: Keep **ONLY** the `ListView.builder` of hand cards.
     - Table cards are spoken on demand via `onSwipeLeft` (`'الطاولة بها: X و Y'`).

4. **`ninety_nine_table_screen.dart`**:
   - **R2**:
     - In card `onTap`:
       ```dart
       onTap: () {
         if (!isMyTurn) {
           announcer.announce('ليس دورك للعب');
           return;
         }
         context.read<NinetyNineGameBloc>().add(NinetyNinePlayCardExplicit(card));
       }
       ```
     - Remove `hint: 'اضغط لتحديده، أو اضغط مرتين للعب الكارت'` from `Semantics`.
     - Remove `onDoubleTap` from `gestureHandler`.
   - **R4**:
     - Remove Table Top Area `Container` (lines 294-373).
     - Remove Opponents Bar `Container` (lines 374-409).
     - Remove 'كروت يدك' header (line 416).
     - In `Scaffold.body`: Keep **ONLY** the `ListView.builder` of hand cards.
     - Pile sum is spoken on demand via `onSwipeLeft` (`'المجموع الحالي في الساحة: X'`).

5. **`farkle_table_screen.dart`**:
   - **R4**:
     - Remove Status Bar `Container` and horizontal scores list (lines 108-147).
     - Remove redundant headers and dividers.
     - Display clean active gameplay column: interactive dice chips, scoring combinations, and roll/bank buttons.

6. **`snakes_and_ladders_table_screen.dart`**:
   - **R4**:
     - Remove Table Status `Container` (lines 212-265) and 'مراكز اللاعبين' header.
     - Keep clean player positions list and roll dice button.

7. **`tennis_table_screen.dart`**:
   - **R4**:
     - Remove top score `Container` (lines 186-210).
     - Remove all on-screen gesture hint text (lines 223-228).
     - Keep clean lane position indicator and serve action.

8. **`thief_hunt_table_screen.dart`**:
   - **R4**:
     - Remove helper text banner `promptText` instructing double-taps.
     - Remove redundant headers and players list during active answer phase.
     - Keep clean active input field and floor selector.

---

## 4. Edge Cases & Verification Criteria

1. **UNO Wild Card Color Picker**:
   - When a wild card is single-tapped, the bottom sheet modal opens immediately.
   - Selecting any of the 4 colors (or 4 dark colors if in dark mode) immediately emits the play action with `chosenColor`.
2. **Domino Multi-Branch Choice**:
   - If a tile matches only one end of the board (or is the opening double), it plays immediately on single tap without opening the side picker.
   - If a tile matches both the left end and right end (`validSides.length > 1`), single tapping opens `_showSidePicker`. Selecting Left or Right immediately executes the move.
3. **Ninety Nine 10 and Ace Value Choices**:
   - If pile value is in the safe auto-resolve range (e.g. >=90 for 10 which auto-applies -10), single tap immediately plays without prompting.
   - If not auto-resolved, single tap triggers the choice sheet (+10/-10 or +1/+11), and selecting a value immediately commits the action.
4. **Table Voice Button Integrity**:
   - `TableVoiceButton` remains prominently positioned via `floatingActionButton` across all 9 game screens in both waiting and playing modes.
   - Single tap toggles mute/unmute or joins; long press leaves voice session.
5. **No Visual Table Clutter**:
   - Gameplay screens during active play show only the cards/tiles/dice hand and the voice button.
   - No gesture hint text banners, no opponent score lists, no table status boxes, no redundant section headers.
