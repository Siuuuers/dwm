# Artwork placement verification ? 2026-09-09

Scope: optional art bindings in the existing game; original DTL organization and procedural Minesweeper graphics retained. Test images are geometric fixtures, not final production art.

- Godot 4.6.3 stable mono; all engine runs used isolated APPDATA/LOCALAPPDATA/DWM_TEST_ROOT, leaving production saves untouched.
- `art-final-focused-20260909.log`: all 49 catalog, exact-size fallback, real UI/Gallery, scene staging, art-only Continue/Pause/Load/retirement checks pass.
- `art-native-pause-final-20260909.log`: all 16 real native-caption and artwork Pause cases pass.
- `art-startup-20260909.log`: real New Account, Minesweeper first reveal/result, all daily transitions through Day 7, final Schedule, physical Alone ending, Gallery unlock, and title return pass with artwork loaded. Two real art-only ending cards displayed and continued exactly once. Run with `verify_art_startup.gd --probe-seven-days --probe-ending --render-evidence` and final bootstrap mode.
- `art-render-20260909.log`: eight rendered screens saved. Inspected title safe slot, desktop/launcher placement, shell bounds, solo/pair narrative aperture including 150% text, ending CG, and real Dating pre-challenge reading area. The portrait remains clear above the reading controls; shell art remains below the HUD.
- `art-cards-final-20260909.log`: all 19 Day 7 card, reached-replay owner, and Gallery artwork checks pass, including exact entry art, acknowledgment identity, and restored layout when art is missing.
- Catalog and artist CSV audit: 139 scene rows (137 semantic entries plus runtime IDs `opening.day1` and `tutorial.desktop_day1`), 161 asset IDs, 132 distinct optional paths. Every referenced DTL exists. Solo/pair entries keep fixed 1/2 portraits; pre/post art is shared.
- `art/README.md` is the current insertion guide. Larger canvases are suggested; small UI dimensions are enforced. No export preset exists, so this verifies the Godot project, not a packaged release.

Known inherited issue: broader regression found `generator_budget_unavailable / budget_source_stale` in Debug preparation (`test_production_pause_controller`). The committed reducer and generator-budget artifact were already inconsistent at the starting revision; neither is changed by this work. Tracked separately as `dwm-nsr` for the established measured benchmark write/check process. The current machine matches the previously recorded target device. This work does not bypass that guard.

Existing engine logs also contain the repository's NUL/localization warnings and Dialogic test-orphan reports; passing tests do not mean warning-free logs.

Reproduction: use `tools/testing/Invoke-IsolatedGodot.ps1` with the listed GUT suites for headless checks. The two rendering scripts require a real rendering driver and separate user-data environment; use `gl_compatibility`, final bootstrap mode for the startup journey, and preserve the renderer's `user://evidence/` output. Artist CSV `.import` sidecars use Keep File so they never become translation catalogs.

Main-folder integration at `117377f2d`: editor import/compile passed, all 26 required scenes loaded/instantiated, and the full 149-case regression set passed 148 cases. Its only failure is the independently verified pre-existing Debug budget mismatch tracked as `dwm-nsr`; no artwork or native presentation check failed. See `main-verification.log` for the final summary. Latest user story drafts and local settings were preserved byte-for-byte during the fast-forward; the original Minesweeper graphics/domain code and DTL files remain unchanged.
