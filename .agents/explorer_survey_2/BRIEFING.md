# BRIEFING — 2026-09-06T18:43:00Z

## Mission
Investigate Requirement R2 (Instant Card Play on Tap - No Two-Step Selection) and Requirement R4 (Complete UI Cleanup on Tables) across all games in Mobile/lib/ and compare against reference Windows client.

## 🔒 My Identity
- Archetype: explorer
- Roles: investigator, analyzer, synthesizer
- Working directory: C:\Users\midoa\Downloads\Compressed\letsfly_final_100_parity_reviewed\Mobile\.agents\explorer_survey_2
- Original parent: 34c1fd39-742a-4397-b475-7a828e6a1fd7
- Milestone: Survey Phase - R2 & R4 Investigation

## 🔒 Key Constraints
- Read-only investigation — do NOT implement
- Strict user instruction rule: do exactly what the user requested, no unrequested improvements, no assumption
- Write only to .agents/explorer_survey_2/
- Reference Windows codebase: C:\Users\midoa\Downloads\Compressed\LetsFly_TableVoice_Fixed_NoTableText_20260902_Final
- Deliver survey_report.md and handoff.md, notify orchestrator via send_message

## Current Parent
- Conversation ID: 34c1fd39-742a-4397-b475-7a828e6a1fd7
- Updated: 2026-09-06T18:43:00Z

## Investigation State
- **Explored paths**:
  - `Mobile/lib/presentation/screens/game/` (uno, domino, american_domino, scopa, ninety_nine, farkle, snakes_and_ladders, tennis, thief_hunt)
  - `Mobile/lib/presentation/bloc/` (uno, domino, scopa, ninety_nine, etc.)
  - `Mobile/lib/presentation/widgets/` (table_voice_button, table_nav_menu, table_navigation_menu, table_options_menu, table_waiting_view)
  - Reference Windows Client: `LetsFly_TableVoice_Fixed_NoTableText_20260902_Final/client/views/table_view.py`
- **Key findings**:
  - R2: Scopa and 99 have rigid two-step selection (tap to select + double tap to play). Domino has race conditions with async state selection and misleading double-tap semantics hint. UNO chains two events rather than direct explicit play.
  - R4: All mobile tables are heavily cluttered with visual status tiles, opponent lists, redundant section headers, and on-screen gesture hints. In Windows client (`Fixed_NoTableText`), only the gameplay hand and voice controls exist during gameplay, with all game info announced via TTS/swipes/menu.
- **Unexplored areas**: None within R2 & R4 scope.

## Key Decisions Made
- Comprehensive blueprint created for R2 direct play on tap and immediate modal choice routing.
- Comprehensive blueprint created for R4 UI cleanup across all 8 game table screens.
- Produced survey_report.md and handoff.md.

## Artifact Index
- DISPATCH.md — Dispatch log
- BRIEFING.md — Context and working memory
- progress.md — Liveness heartbeat
- survey_report.md — Comprehensive survey report
- handoff.md — 5-component handoff report
