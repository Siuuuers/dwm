# prompt_docs INDEX — Master map

Read this first, then open the file that owns the topic. Each topic has ONE owning file — open that file directly; do not infer from another.

## Reading order
1. Read `Prompt.md` (top-level rules), then this index.
2. Read only the files for the requested phase/subphase. Required scene/script/autoload paths: `CONTRACTS.md §11`.
3. Phases are incremental. Unless the user says `RUN ALL PHASES`, implement only the requested phase, then stop and write `ResultReport.md`.
4. `PROMPT DOC MAINTENANCE` mode: edit only Markdown prompt docs; do NOT implement gameplay files; do NOT run unrelated game phases.

## Implementation status
Phases 0–2 (audit; autoloads / `GameState` / managers / data / effects; scenes + smoke tests) are **implemented**. The autoload API contracts live in their `autoload/*.gd` files; `CONTRACTS.md §1–§10` point to the code rather than duplicating signatures. Phase-3+ agents read `CONTRACTS.md` plus the relevant `autoload/*.gd` directly, and may skip `PHASES.md §Phase 0 – §Phase 2` unless explicitly rebuilding.

Phase 2 built every required scene as a loadable node-tree (smoke instantiates all of them), but the desktop-app **controls** (Minesweeper simulate/difficulty buttons, Shop quantity/Buy/secret-buy, Schedule action/date/Done + `MinesweeperWarningAlert`, Contacts open/reply, Backup save/load/delete rows, `NotificationLayer`, focus-grid wiring) are **not yet wired to `GameState`** — the app scripts hold node references and hide/show only. Control wiring is owned by each control's phase (Phase 3 desktop apps; Phase 4 dating/hospital/ending; Phase 6 real board). A Phase-3+ agent MUST NOT assume any app control already calls a `GameState`/`SaveManager` method.

## File map
| File | Documents |
| --- | --- |
| `Prompt.md` | Top-level rules: engine/language, stability, forbidden, phase/stop, doc-maintenance mode, verification env. |
| `INDEX.md` | This map. |
| `CONTRACTS.md` | Code contracts: GameState API, EffectResolver, SceneRouter, managers, DialogicBridge, DataCatalog, ArtManifest, resource classes, AudioManager. |
| `FLOWS.md` | Game/day/schedule/invitation/dating/hospital/ending/Minesweeper-notification/audio-context flows + scene node-trees. |
| `CONTENT.md` | Shop items, tasks, friends, invitation-day tables, contact order, localization keys, art paths, audio tracks. |
| `DIALOGIC.md` | Dialogic 2 requirement, `.dtl` manifest, DTL syntax, timeline catalog. |
| `PHASES.md` | Phase rules, subphases, commands. Phases 0–2 collapsed to "skip on read". |
| `TESTING.md` | Required test files and test requirements. |
| `REPORT.md` | `ResultReport.md` template. |
| `GLOSSARY.md` | Quick-reference index of where each rule lives. |

## Master game flow
`MenuScene` → New Acc → `GameState.reset_game()` → `SceneRouter.start_game_from_menu()` → `OpeningScene` (Day 1, if not seen) → `MainGameScene`. Terminus: Day 7 finished → `EndingScene`. Full sequencing and scene node-trees: `FLOWS.md`.

## Flow entry points
| Flow | Entry point | Defined in |
| --- | --- | --- |
| Schedule Done | `GameState.execute_schedule_sequence_until_route_needed()` | CONTRACTS §2 |
| Schedule warning | `GameState.should_warn_minesweeper_before_schedule_done()` | CONTRACTS §2 |
| Day-7 ending | `GameState.resolve_day7_ending()` | CONTRACTS §2 |
| Date challenge result | `GameState.apply_dating_challenge_result(entry, result)` | CONTRACTS §2 / FLOWS §6 |
| Minesweeper app finish | `GameState.finish_minesweeper_app_round(result)` | CONTRACTS §2 / FLOWS §4 |
| Scene change | `SceneRouter.*` only (GameState never auto-routes) | CONTRACTS §4 |
| Locale change | `LocalizationManager.set_locale()` -> `GameState.set_language()` | CONTRACTS §5 |
| Save / load | `SaveManager.*` only | CONTRACTS §6 |
| Effect apply | `EffectResolver.apply_effect_ids()` only | CONTRACTS §3 |
| Dialogic start | `DialogicBridge.start_timeline_id()` only | CONTRACTS §10 |
| Audio context | `AudioManager.set_music_context()` only | CONTRACTS §9 |

## Quick-lookup by topic
| Topic | Primary doc |
| --- | --- |
| Phases / stop rule | `Prompt.md`, `PHASES.md` |
| Autoloads / ownership | `CONTRACTS.md` §1 |
| GameState API | `CONTRACTS.md` §2 |
| Save / input / accessibility | `CONTRACTS.md` §6–§8 |
| Effects | `CONTRACTS.md` §3 |
| Localization | `CONTRACTS.md` §5, `CONTENT.md` §2 |
| Data catalog / shop / tasks | `CONTENT.md` |
| Art / SafeImage | `CONTENT.md` §11, `CONTRACTS.md` (ArtManifest) |
| Desktop / Schedule | `FLOWS.md` |
| Dating / hospital / ending | `FLOWS.md` §6 |
| Minesweeper model / rewards | `CONTRACTS.md` §2, `CONTENT.md` §12 |
| Dialogic 2 | `DIALOGIC.md` |
| `.dtl` timeline manifest | `DIALOGIC.md` |
| Tests / commands | `TESTING.md`, `PHASES.md` |
| Result report | `REPORT.md` |
| Required scene/script/autoload paths | `CONTRACTS.md` §11 |
