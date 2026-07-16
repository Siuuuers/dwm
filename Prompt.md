# Prompt.md — Top-level rules

This file is the entry point for the whole project. Read it first, then open `prompt_docs/INDEX.md` for the file map.

## Project overview
- **Genre:** 2D visual-novel / psychological-horror dating sim, presented through a desktop-OS metaphor.
- **Engine:** Godot 4.6.3, typed GDScript. C# only if a proven engine limitation forces it (reason logged in `ResultReport.md`).
- **Player character:** Angela. **Friends:** Priscilla, Lavinia, Sylvia.
- **Core loop:** 7 in-game days. Each day = desktop apps (Minesweeper, Contacts, Shop, Schedule) → Schedule Done → dating / hospital / ending.
- **Goal of these docs:** build the prototype phase-by-phase (autoloads → scenes → apps → narrative → hardening) under strict stability and honesty rules.
- **How to read:** start at `prompt_docs/INDEX.md`. Each topic has ONE owning file (see INDEX). Read only the files for the requested phase.

Default current phase: **PHASE 3 ONLY**.

Phase status: Phases 0–2 are implemented and verified. Phase 2 built every required scene as a loadable node-tree, but the desktop-app **controls** are **not yet wired to `GameState`** (app scripts hold node references and hide/show only). Control wiring is owned per-phase (Phase 3 desktop apps; Phase 4 dating/hospital/ending; Phase 6 real board). Do not assume any app control already calls a `GameState`/`SaveManager` method (`prompt_docs/INDEX.md` Implementation status).

### Reading order
1. Read `prompt_docs/INDEX.md` first (master map + authority + reading conventions). Can use Godot MCP and codegraph for better understanding.
2. Read only the files for the **requested phase/subphase** (`PHASES.md`). Each topic has ONE owning file (INDEX file map); read that file, not copies.
3. Phases are incremental. Unless the user says `RUN ALL PHASES`, implement only the requested phase, then **stop** and write `ResultReport.md`.

### Symbol / notation legend
- `§N` = section N of the **same** file. `FILE.md §N` = section N of that file. Jump to it; do not infer.
- `->` = produces / routes to / returns. Example: `Schedule Done -> execute_schedule_sequence_until_route_needed()`.
- `{...}` = a GDScript `Dictionary` literal; its field list is **authoritative** — use exactly those fields, add none that affect logic.
- Normative verbs: `MUST` = hard requirement (tests enforce); `SHOULD` = strongly recommended, deviation needs a documented reason in `ResultReport.md`; `MAY` = optional.

### Discipline rules for the agent
- **One owner per topic.** Do not duplicate contract blocks across files; reference them by `§`.
- **Verify, never assume.** Prerequisites (`godot` binary, Dialogic 2, optional addons) must be checked at runtime; report exact phrases from `PHASES.md` §2 when missing. Never fabricate command output.
- **Forbidden:** `eval`; arbitrary method calls by name from resource/save/effect data; trusting resource or save data to execute code.
- **Honesty:** never claim a pass unless the commands actually ran. If a needed prerequisite (e.g. Dialogic 2) is missing, block and report the exact phrase; do not mark the phase complete.

## Entry point
- Read `prompt_docs/INDEX.md` first (master map + authority rules).
- Each topic has ONE owning file (see INDEX). Read only the files relevant to the requested phase.
- Phases are incremental. Unless the user says `RUN ALL PHASES`, implement only the requested phase/subphase, then stop and write `ResultReport.md`.
- `PROMPT DOC MAINTENANCE` mode: edit only Markdown prompt docs; do NOT implement gameplay files; do NOT run unrelated game phases.

## Prerequisites (verify, never assume)
- `godot` binary: verify with `godot --version`. On this machine the binary is NOT on PATH; it is installed at `C:\Program Files\Godot_v4.6.3-stable_mono_win64\Godot_v4.6.3-stable_mono_win64.exe`. Invoke it by full path (PowerShell: `& "C:\Program Files\Godot_v4.6.3-stable_mono_win64\Godot_v4.6.3-stable_mono_win64.exe" --version`). If neither PATH nor the full-path invocation works, report exactly `godot: command not found` and never fabricate output.
- Dialogic 2 addon: REQUIRED for narrative phases. If missing, report `Dialogic 2 addon file does not exist.` and block phases that need it.
- Optional addons (State Charts, GUT): absence must NOT crash the prototype.

## Language and engine
- Typed GDScript (Godot 4.6.3-compatible).
- C# only if a proven engine limitation forces it; write the reason into `ResultReport.md` before adding any C# file. Never use C# for UI, state, localization, save/load, scene routing, statistics, input, or prototype logic.
- Dialogic 2 REQUIRED for narrative (`.dtl`) systems: opening, tutorial, contacts, dating, hospital, ending.
- State Charts / GUT optional. Missing optional addons must NOT crash the prototype.

## Stability rules (priority order)
1. Scripts parse.
2. Scenes load and instantiate.
3. Missing optional plugins do not crash.
4. Missing art does not crash.
5. Missing localization keys do not crash.
6. Missing or corrupt saves do not crash.
7. State changes happen only through safe public APIs.
8. Tests and command output are reported honestly.

## Forbidden
- `eval`; arbitrary resource-provided method calls; arbitrary save-data-provided method calls; arbitrary method calls by name from effect data; trusting resource or save data to execute code.
- Hard dependency on optional plugins (State Charts, GUT, MCP).
- Full Minesweeper board logic before Phase 6 (deferred, not forbidden outright): phases 0–5 use the simulated-result placeholder only. Real board logic is implemented in Phase 6 (`PHASES.md` §Phase 6).

## Verification environment
- `godot` required for `--version`, `--import`, smoke, GUT. Not on PATH on this machine; invoke by full path (see Prerequisites). If neither PATH nor full-path works → `godot: command not found`. Never fabricate output.
- Project keeps a `[dotnet]` section in `project.godot`; prototype is GDScript-only. If import fails for dotnet reasons, report honestly.
- Pinned build: **Godot 4.6.3 stable (mono) is confirmed installed and verified**

## Output
- After the requested phase/subphase, update `ResultReport.md` using `prompt_docs/REPORT.md` template.
- Never claim a pass unless the commands actually ran.
- Stop after the requested phase/subphase.