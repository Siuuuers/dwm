# PHASES — Phase rules, subphases, and commands

Phase rules and command definitions. `TESTING.md` owns the test-file list and test requirements.

> **Skill discipline (global).** Each subphase lists the Godot skills to load. The Superpowers skill `verification-before-completion` governs every "run commands + report honestly" gate and reinforces `Prompt.md`'s honesty rules: never mark a subphase done unless the required commands actually ran and the final rerun succeeded. UI rules are owned by `FLOWS.md §9` + `godot-ui*`.

---

# 1. Stop rule
Unless the user explicitly says `RUN ALL PHASES`, execute only the current requested phase or subphase, then stop and report. If a later-phase requirement is needed for parse stability, create only a minimal stub and write the TODO into `ResultReport.md`. Full Minesweeper board logic is DEFERRED to Phase 6; phases 0–5 use the simulated-result placeholder. Do not add C# unless the user explicitly requests a C# phase. Do not require optional plugins, art files, localization resources, or save files to exist.

**Default current phase: PHASE 3 ONLY.**

---

# 2. Commands
Run commands only for the current phase/subphase. From the Godot project root. Can use Godot MCP and codegraph. Copy requested commands exactly; Godot may ignore unknown args without warning.

> **Binary invocation (this machine).** `godot` is NOT on PATH. Substitute the bare `godot` in every command below with the full-path call: `& "C:\Program Files\Godot_v4.6.3-stable_mono_win64\Godot_v4.6.3-stable_mono_win64.exe"` (PowerShell). If neither PATH nor full-path works, report `godot: command not found`.

## Godot version
`godot --version`

## Import resources
`godot --headless --path . --import --quit`

## Smoke test
`godot --headless --path . -s res://tests/smoke_load_scenes.gd`

## GUT command (only if `addons/gut/gut_cmdln.gd` exists)
`godot -d -s --path . addons/gut/gut_cmdln.gd -gdir=res://tests/unit -ginclude_subdirs -gexit`

## Exact skip / failure phrases (use these verbatim)
- `godot: command not found` — Godot binary missing.
- `GUT addon file does not exist.` — GUT missing; skip only the GUT command.
- `No shell access in this environment.` — no shell; report (Phase 0).
- `Godot MCP is not available in this environment.` — manual MCP verification unavailable.
- `Dialogic 2 addon file does not exist.` — Dialogic 2 missing; block phases needing it.

If a command fails: show output; fix; rerun; do not claim pass until the final rerun succeeds. Never claim a test passed unless it was actually run.

---

# 3. Phases 0–2 — IMPLEMENTED (skip on read)
Phases 0 (read-only audit), 1 (autoloads / `GameState` / managers / data / effects / unit tests), and 2 (scenes + smoke tests) are **implemented**. Do not re-read their subphase build detail.

> NOTE (ArtManifest): `scripts/data/ArtManifest.gd` is an intentional stub (art paths live in `CONTENT.md §11`); see `INDEX.md` implementation-status NOTE. The "implemented" claim covers gameplay/data code, not the deferred art-path data layer. The autoload API contracts now live in their `autoload/*.gd` files; `CONTRACTS.md` §1–§10 point to the code rather than duplicating signatures. Phase-3+ agents read `CONTRACTS.md` plus the relevant `autoload/*.gd` directly, and may skip `PHASES.md §Phase 0 – §Phase 2` unless explicitly rebuilding.

---

# 4. Phase 3 — desktop apps
Skills: godot-ui, responsive-ui, input-handling, save-load, localization, tween-animation, audio-system, godot-master (ui-containers, ui-rich-text, ui-theming, platform-desktop, save-load, input-handling, audio-systems, genre-visual-novel); Superpowers: verification-before-completion, systematic-debugging.

- **3A1 desktop shell**: background, 7 icons (4-col grid), AppWindowHost, app caching (one visible, hide not free), daily reset clears cache, focus neighbors, localization refresh.
- **3A2 settings apps**: `Setting` + `SettingsApp`; language EN/CN/HK; accessibility; localization + accessibility refresh; store in `GameState.settings`.
- **3B1 MinesweeperApp placeholder**: difficulty tabs, signed round display, safety level, coins, foresight rate, placeholder board, task-list toggle, simulated result buttons, start/finish/clear calls; no full board logic (real board logic is Phase 6).
- **3B2 Minesweeper desktop notification**: `NotificationLayer` (Close/Go/Yes), show after 1st/2nd finished app round when a friend message appears; Go/Yes open ContactListApp + correct friend; no dating-challenge/abandoned shows.
- **3B3 ShopApp + ShopItemBox**: 18 items, 9/page, quantity selector, Buy x qty, sold-out text, affordability, bulk rules, effect validation before spend, refund on unexpected failure, secret Supportz invisible/focusable buy area (gate via `can_buy_supportz()`).
- **3C1 ContactListApp**: contact boxes, chat panel, open via `open_contact`, history/daily messages, reply placeholders, chat-bubble layout, scroll to bottom.
- **3C2 ScheduleApp base sequence bar**: action buttons, invitation date buttons, 7-box bar, remove alternatives, gift picker, GameState-only calls, Day-4 Priscilla first-slot disable.
- **3C3 Schedule Done + warning**: `_done_pressed` guard; `should_warn_minesweeper_before_schedule_done()`; alert (Close/Go/Yes) if warn; else execute via GameState/SceneRouter; no double day advance; hospital before dating; missed-group twofriends safe.
- **3C4 BackupApp + LogOutApp**: 3×3 grid (autosave/quick/slots 1..7), save/load/delete (confirm), SaveManager-only, LogOut routes menu.
- **3D1 input/focus pass**: every clickable button focusable; shop quantity/notification/schedule-warning buttons focusable; icon-grid neighbors; focus first control; controller cancel; right-click alternatives.
- **3D2 localization/accessibility visual pass**: locale refresh; sold-out text not grey-only; Minesweeper HUD numeric not red-only; high-contrast readable; large click targets; reduced motion; secret Supportz label.
- **3E desktop tests + bugfix-only**: run commands; fix failures only; update report.

---

# 5. Phase 4 — narrative, dating, hospital, ending
Skills: dialogue-system, animation-system, tween-animation, audio-system, localization, godot-ui, godot-master (dialogue-system, genre-visual-novel, genre-romance, audio-systems); Superpowers: verification-before-completion, systematic-debugging.

- **4A1 DialogueBox**: speaker, text, log/skip/auto/next; self-paced; auto interruptible; skip respects `skip_unseen_text_allowed`; placeholder log.
- **4A2 DatingScene layouts + visible dialogue history**: solo/group/twofriends; safe placeholders; full log retained; visible stack = current + previous 2 (greyed, oldest removed when >2).
- **4C MinesweeperChallengeOverlay**: placeholder 9×9/18-mine board; normal + dark + true-path buttons; true-path requires previous true path EXCEPT on the friend's FIRST solo dating day (Priscilla Day 1, Sylvia Day 1, Lavinia Day 2 — see `FLOWS.md §6` true-path entry rule); emits `challenge_finished(result)` with `context="dating"`; no app round/money.
- **4D1 hospital**: continue calls `apply_hospital_recovery_and_advance_day()`; if it returned `true` → `goto_main()`, else (Day-7 ending resolved) → `goto_ending()`; no double advance.
- **4D2 ending + twofriends ending state**: alone fallback; friend sweet/dark/true; priscilla_lavinia if two missed-group; return to menu.
- **4E routing hardening**: dating queue advances; final date clears schedule without refund; hospital/twofriends no double advance; Day 7 → ending (via `route_context["ending_id"]`); no auto-route in smoke.

---

# 6. Phase 5 — final hardening
Skills: godot-code-review, godot-testing, godot-debugging, godot-optimization, godot-master (performance-optimization, testing-patterns, debugging-profiling); Superpowers: verification-before-completion, systematic-debugging, requesting-code-review, receiving-code-review.

- **5A static hardening checklist**: no unsafe GameState mutation in UI when a safe method exists; EffectResolver two-pass; SaveManager schema validation + no save-data execution; input actions exist; accessibility settings exist; localization works with Dialogic 2; missing art cannot crash; required scenes load.
- **5B final command verification**: run version/import/smoke; GUT only if installed.
- **5C manual MCP verification if available**: open MainGameScene, run, click each icon, close, reopen (state persists), advance day (cache resets), change language, test focus; capture/describe UI. If unavailable → `Godot MCP is not available in this environment.`

---

# 7. Phase 6 — real Minesweeper board logic (playable core)

> Goal (user-confirmed): replace the simulated-result placeholder with an actually playable Minesweeper board. This is the ONLY phase permitted to implement full board logic. Phases 0–5 remain placeholder. Run this phase only when explicitly requested; it must not regress any Phase 0–5 contract.

Skills: gdscript-patterns, gdscript-advanced, math-essentials, godot-ui, input-handling, godot-testing, godot-master (gdscript-mastery, ui-containers, input-handling, testing-patterns); Superpowers: test-driven-development, verification-before-completion, systematic-debugging.

Run: `godot --version`, import, smoke, GUT (if installed). Do not break existing unit/smoke tests.

Design constraints (authoritative numbers already live in `CONTENT.md §12`; safety-level
modifiers live in `CONTRACTS.md §2`):
- Board sizes/mines: Beginner 8×8 (10), Intermediate 16×16 (40), Expert 22×22 (99). Oversized boards live inside the existing `BoardScroll` `ScrollContainer`. (Numbers authoritative in `CONTENT.md §12`.)
- Mine-density scaling, first-click-safe, flags/question-marks/flood-fill/chording, and the 3BV / foresight-rate invariant: authoritative in `CONTENT.md §12`. (Every mouse interaction MUST have a keyboard/controller equivalent — `CONTRACTS.md §7` / §8.)
- Safety-level modifiers (`get_minesweeper_safety_level()`, `2` lucky_charm / `3` debug_key): authoritative in `CONTRACTS.md §2`. Safety level never changes the visible round display.
- **Deterministic seed:** seed the board PRNG from `GameState.minesweeper_rng_seed` (`CONTRACTS.md §2`) and advance it deterministically per board so the same seed reproduces the same board sequence; persisted via save whitelist so reloads and tests are reproducible.
- **Romance ↔ board coupling:** the real board's `outcome`/`perfect`/`foresight`/`exploded` MUST feed romance per `FLOWS.md §6` (populate `result["board_performance"]`; `apply_dating_challenge_result` modulates `affection_delta` / `entered_true_path` additively on top of the player-choice selector and flag chain). The placeholder overlay sends `board_performance = {}`. (Coupling contract authoritative in `FLOWS.md §6`.)
- Outcome → the existing app-round result `Dictionary` (`CONTRACTS.md §2` Minesweeper app round result schema): map a real finish to `outcome` (`exploded`/`cleared`/`perfect`/`no_flag`/`foresight`), fill `three_bv`/`click_count`, and reuse `finish_minesweeper_app_round(result)` / `apply_dating_challenge_result(entry, result)` unchanged. No new reward path — the real board just produces the same result contract the placeholder buttons simulate today.
- **Board controller/keyboard navigation (Phase 6 TODO — concrete scheme).** Every mouse interaction MUST have a keyboard/controller equivalent (`CONTRACTS.md §7`/§8). `FocusGrid` is currently app-icon-based and must be extended or supplemented for grid navigation. Concrete scheme to implement in Phase 6: a single focused-cell model (one cell holds focus at a time); `ui_up`/`ui_down`/`ui_left`/`ui_right` move the focused cell by one (clamped at edges, no wrap); `ui_accept` reveals the focused cell; `game_hint` toggles a flag on it; a chord action (reuse `game_new_board`'s sibling or bind a dedicated chord input) chords the focused cell; `BoardScroll` auto-scrolls to keep the focused cell visible on the 22×22 Expert board; the focused cell shows a strong focus ring under `show_focus_ring`/`high_contrast`. Right-click flag MUST also have this keyboard/controller equivalent.
- Dating challenge (`MinesweeperChallengeOverlay`) may reuse the same board component with `context="dating"`; it still consumes no app round and rewards no app money.

Subphases:
- **6A board model**: pure-GDScript board (grid, mine placement with safe first click, neighbor counts, reveal/flood-fill, flag/chord, win/lose detection, 3BV + click_count). Unit-tested; no scene dependency.
- **6B MinesweeperApp integration**: swap `SimulationButtons` for the live board (keep a hidden debug simulate path behind a dev flag); wire start/finish/clear to existing GameState methods; signed round display unchanged.
- **6C challenge overlay integration**: reuse the board inside `MinesweeperChallengeOverlay`; preserve sweet/dark/true path buttons and `challenge_finished(result)` contract.
- **6D tests + bugfix**: add `res://tests/unit/test_minesweeper_board.gd` (mine count, safe first click, flood-fill, chording, 3BV, win/lose); rerun full suite; update `ResultReport.md`.

---

# 8. Definition of done by major phase (summary)
- Phase 0: read-only audit; only `ResultReport.md` writable.
- Phase 1: autoloads parse, resources parse, SaveManager safe, EffectResolver two-pass, unit tests where possible.
- Phase 2: every required scene exists, parses, instantiates without auto-routing; smoke passes.
- Phase 3: desktop apps open/close safely, reset on day change, input/focus works, save/load via SaveManager.
- Phase 4: narrative/dating/hospital/ending work without optional plugins; no double day-advance.
- Phase 5: final hardening; smoke + GUT (if installed) + MCP (if available) reported honestly.
- Phase 6: real playable Minesweeper board replaces the placeholder, produces the existing result contract, keeps all keyboard/controller alternatives, and does not regress Phase 0–5 tests.
