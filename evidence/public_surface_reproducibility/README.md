# Public surface reproducibility (`dwm-sf7`)

This evidence records the current public declarations of `autoload/GameState.gd` and `autoload/SaveManager.gd` without changing either runtime owner. The required manifests are `evidence/phase_2r/runtime/game_state_required_surface.json` and `evidence/phase_2r/runtime/save_manager_required_surface.json`; their generated inventories are `game_state_surface.json` and `save_manager_surface.json` in the same directory. The current inventories contain 239 GameState symbols and 74 SaveManager symbols. This update classifies 34 newly exposed GameState symbols and 25 SaveManager symbols and removes four retired GameState opening/tutorial entries.

The generators' `--check` mode rebuilds each inventory from the current source and compares the complete canonical bytes with its checked-in artifact. That comparison covers signatures, call sites, dynamic references, and classifications; it reports drift and does not write either artifact. Both current inventories must pass independently. The historical `evidence/phase_2r/schedule/gate.json` stays unchanged: its recorded GameState inventory digest is checked against the matching artifact in commit `f7e601d54a6c25a6ed69b1651e48bbbd20e261b3`, the revision that last changed that gate and artifact together. The old gate is not resealed against today's larger surface.

Classification is not a claim that every public behavior has a current contract test. In the retained GameState manifest, 35 older `contract_test` labels covering 169 entries name tests that no longer exist. Wrapper and indirect-coverage gaps are tracked in `dwm-sx8`. Those labels remain visible as a separate follow-up; no missing test was invented to make the inventory pass.

The substring prefilter skips a regular expression only when its symbol is absent from the line. Local GameState scans improved from 34.45 to 7.70 seconds; SaveManager improved from 12.88 to 4.74 seconds. These are observed local samples, not universal performance guarantees. SaveManager retained every baseline byte. The only GameState difference before regeneration was a contemporaneous comment moving one reference from line 45 to 46, recorded in `prefilter-reference-delta.json`.

## Verification

Source base: `36145ea12c77878c299f399650952df1594b0c1b`, 2026-09-13. Godot 4.6.3; isolated application data and test roots.

| Check | Result | Evidence |
| --- | --- | --- |
| New live check before regeneration | 10/11 tests; both stale artifacts rejected | `public-surface-live-red-20260913.log` |
| HEAD copies of two dependent suites against unchanged runtime owners | 37/42; same five preexisting failures | `surface-dependent-head-baseline-20260913.log` |
| Final eight suites after fixture fixes and review | 89/89, 2,600 assertions, 22.867 seconds | `surface-reviewed-regression-20260913.log` |
| GameState and SaveManager CLI `--check` | Both exit 0 | `surface-game_state-final-check-20260913.log`, `surface-save_manager-final-check-20260913.log` |
| PowerShell canonical oracle and closeout refusal/helper tests | PASS | `public-surface-canonical-oracle.log` |
| New fixture test with missing and whitespace roots | Each explicitly fails before writing | `surface-negative-empty-20260913.log`, `surface-negative-whitespace-20260913.log` |

The baseline comparison uses retained HEAD test copies, with only the historical surface path pointed at its exact HEAD artifact; it is not a pristine full-tree campaign. The five failures were stale expectations for three lifecycle fields, an incomplete Schedule Done identity fixture, a newer issuer-call census, schema v6, and the removed Alone-ending fallback. The corrected Schedule fixture supplies real issuer custody and proves a mismatched command cannot advance, publish, or allocate; the matching command advances once and replay does not repeat those effects. The census explicitly identifies all six direct issuer calls and 15 producer paths, including registered child roles; it does not relabel them as original historical matrix rows.

The final run includes all six `dwm-ryl.1` suites: 47/47 tests (45 original plus the two new inventory checks). Their original negative probes remain in [fixture-root evidence](../fixture_root_guards/README.md). A supplemental probe overlays only the changed inventory test and scanner into the earlier disposable source copy and selects the new mutation test. Both missing-root modes report `test_root_missing` / `TEST_ROOT_UNAVAILABLE`, execute that test, leave the original isolated root empty, and restore the environment. All 8,437 file hashes and 521 descendant directories outside `.godot` remain unchanged (`surface-negative-verification.json`; the prior count of 522 included the root itself). The other new test reads live source without allocating fixtures. No parse, script, or engine errors occurred in final or supplemental runs. The 24 preexisting Dialogic orphans remain.

`runs.jsonl` and `surface-negative-runs.jsonl` retain exact invocations and exit codes, including failed attempts. Log copies trim trailing whitespace and excess blank lines at EOF only. The original ignored runner logs remain available in the integration checkout.

The historical Schedule gate SHA-256 remains `6fc757a375482b33c754dd130427a2505c522ac0a3eaa140be4b365e24017a55`; its frozen subject is `2bd24eb2ad0c4d76337cf0868257b77a7be666c0`. The matching f7 sibling hash remains `d09fb54614ac6861f7a98ebff6719e4b0c9ae540ede5d309693f3267b9c1e089`. The original sf7 acceptance mixed that closed historical gate with evolving live bytes and obsolete test counts. Its acceptance was explicitly corrected in Beads; this work does not claim to satisfy the superseded reseal requirement or reopen its closed owner.

To recheck either current inventory, run `tools/runtime/generate_public_surface_inventory.gd` through `Invoke-IsolatedGodot.ps1`, passing `--check`, its canonical `--script`, `--required`, `--output` paths and exactly the four `--search-root` values `res://autoload`, `res://scripts`, `res://scenes`, `res://tests`. Omit `--check` to regenerate after intentional source changes; never edit generated JSON by hand.
