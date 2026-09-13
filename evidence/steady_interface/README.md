# Steady Interface preference

`dwm-vky.12` implements amendment Section 6.7's preference and Section 13 step 3.
Title, desktop and entered Pause Settings expose one generic writable checkbox
at `preferences.accessibility.steady_interface`, default false. English,
Simplified Chinese and Traditional Chinese each have their own label and brief
description. Visible and accessible descriptions use the same localized copy.
The row's name, toggle and explanation scroll into view together when they fit;
the existing focused-control fallback remains for a smaller reading aperture.

Profile validation admits an absent Steady field as false without altering the
source document. It preserves explicit true and rejects wrong types, unknown
keys and unrelated missing fields. Existing Minesweeper preference admission is
unchanged. Versions 2–7 retain their existing upgrade routes; version 8 writes
the missing default through the existing migration flag and ProfileManager.
Version 1 already builds its destination from current defaults. No schema
version, run snapshot, gameplay owner or persistence transaction changed.

This step adds no structural effects. The accepted Drift Deck's later
presentation filter must consume the preference to suppress its structure
family; that implementation and the parent epic remain unfinished.

The seven-suite focused run passes **72/72 tests and 7,965 assertions** in
**30.076 s** (`steady-interface-focused-20260913.log`). It covers the exact
registry, real ProfileManager serialization and restart over in-memory file
operations, false-to-true persistence, reset writeback, historical upgrades and
strict rejection. Real Settings hosts test generic checkbox commits, row/focus/
scroll retention, three independent locale catalogs and live text scaling.
Existing Settings suites exercise all supported locales and text sizes.
After the focus-scrolling correction, all three Settings suites pass again:
**37/37 tests, 7,264 assertions**, **29.513 s**
(`steady-interface-settings-reviewed-20260913.log`).
Both current public inventories were regenerated after the final source/test
edits. Inventory byte reproduction and documentation validation pass **14/14
tests, 410 assertions** (`steady-interface-inventory-and-docs-20260913.log`).
The parent epic's historical evidence reseal remains separate.

Three inspected Windows/OpenGL3 captures pass **37 checks** at 800 × 656
(`steady-interface-native-reading-row-20260913.log`). They mount real shared
SettingsContent with a real ProfileManager over memory-only storage and inject
native Enter. English uses 100% text; both Chinese samples use 150%. The checked
value commits and keeps focus; each complete name, control and description fits
the reading aperture. These samples do not certify physical-device or screen
reader acceptance. The three actual hosts are covered by the scene tests.

The first native capture used manual description scrolling and revealed that
large Chinese text could leave the row name offscreen. The initial direct
whole-row focus adjustment was overridden by the container's native focus
scrolling; its failed log and measurements remain. The final adjustment uses
the existing deferred focus-perimeter step and actual control focus guard.
Final native captures require the full visible row without a manual scroll.

All runs used the isolated wrapper. Logs retain existing Unicode/NUL diagnostics
and 24 Dialogic/GUT orphans; successful runs have no script/load errors. Log
copies trim trailing whitespace and blank EOF lines. `runs.jsonl` records exact
invocations. Source base: `5b71c4833f3d81a87a1fab0b83fa58cc0f6984d1`.
The concurrent `dwm-634.2` Minesweeper latency checkout remains untouched.
