# Repairing `test_public_surface_inventory.gd` — four unclassified GameState seams

**Bead.** `dwm-p2r.15` (Plan 01 Task 9) owns
`evidence/phase_2r/runtime/game_state_required_surface.json`. `dwm-p2r.14` recorded this red as
pre-existing and out of its own scope; this note is the repair.

## The red, reproduced before it was touched

`tests/unit/tooling/test_public_surface_inventory.gd` failed 2 of 9 tests, exit 1,
7 passing, **1480/1482 asserts**. Both failures carried the same four errors:

```
["SURFACE_UNCLASSIFIED: begin_minesweeper_round",
 "SURFACE_UNCLASSIFIED: complete_minesweeper_round",
 "SURFACE_UNCLASSIFIED: get_active_minesweeper_round",
 "SURFACE_UNCLASSIFIED: get_mutation_gate_instance_id"]
```

The two failing tests are `test_task3_required_surface_realizes_authenticated_contacts_and_retires_legacy_reply`
and `test_task4_committed_schedule_seams_carry_their_exact_frozen_signatures`. Neither asserts
anything about Minesweeper; both simply build the whole-GameState inventory and require
`inventory.ok`, so any unclassified public symbol anywhere on the facade fails them.

## Root cause — a manifest that predates the source it classifies

`autoload/GameState.gd` gained all four public methods in **345815ef4**
`feat(handoff): define deterministic Minesweeper round contract` (2026-08-17, dwm-p2r.9 Plan 06
Task 2). `evidence/phase_2r/runtime/game_state_required_surface.json` was last written in
**3ae8ca1ba** `feat(save): persist canonical committed Schedule`, which
`git merge-base --is-ancestor` confirms is an **ancestor** of 345815ef4. The Minesweeper-round
commit added public surface and did not classify it.

The reason it stayed invisible in review is the manifest's two-row idiom. `begin_minesweeper_round`
and `complete_minesweeper_round` were ALREADY in the file — as `availability: "target"` rows
carrying their exact frozen signatures, written back when they were the replacement target for
`consume_minesweeper_app_round` / `start_minesweeper_app_round` / `finish_minesweeper_app_round`.
A `target` row freezes a signature; it does **not** classify. `PublicSurfaceInventory._classifications_by_symbol()`
keeps only rows whose `availability` is `"current"`, so the symbols read as present in the manifest
while contributing no disposition at all. `get_active_minesweeper_round` and
`get_mutation_gate_instance_id` had no row of any kind.

## The repair

Four `availability: "current"` / `disposition: "retain"` rows added, each naming a contract test
that already exists and already passes. This is the same shape `configure_mutation_gate` has
carried since it was realized: one `current` row that classifies, one `target` row that freezes the
signature. Both existing `target` rows were left in place.

| symbol | contract_test | lives in |
|---|---|---|
| `begin_minesweeper_round` | `test_round_facade_fails_closed_before_the_coordinator_is_installed` | `tests/unit/test_application_bootstrap.gd` |
| `complete_minesweeper_round` | `test_round_facade_fails_closed_before_the_coordinator_is_installed` | `tests/unit/test_application_bootstrap.gd` |
| `get_active_minesweeper_round` | `test_minesweeper_stage_constructs_exactly_one_coordinator_over_production_adapters` | `tests/unit/test_application_bootstrap.gd` |
| `get_mutation_gate_instance_id` | `test_game_state_reports_only_its_gate_identity_never_the_gate` | `tests/unit/test_application_bootstrap.gd` |

Rows were inserted in GameState declaration order, matching the file's existing convention
(190 of 197 adjacent `current` rows are already in source order). The edit is a pure insertion:
32 lines added, none removed, and the file round-trips byte-identically through
`json.dumps(indent=2)` before and after, so the diff is only the four rows.

No production source changed. The evidence file is the only change.

## RED proven by mutation, because a first-run green proves nothing

Three mutations to PRODUCTION source (`autoload/GameState.gd`), each reverted, each with a
distinct failure signature. Each ran the repaired suite, which is green at 9/9.

| mutation | observed | proves |
|---|---|---|
| `get_active_minesweeper_round` renamed to `..._v2` | 7/9, 1504/1506, exit 1 — `SURFACE_UNCLASSIFIED: get_active_minesweeper_round_v2` **and** `SURFACE_REQUIRED_MISSING: get_active_minesweeper_round` | the unclassified sweep is live over real GameState source, AND the row added here is load-bearing rather than inert |
| `begin_minesweeper_round(request: Dictionary)` → `(request: Dictionary, extra: int = 0)` | 7/9, 1504/1506, exit 1 — `SURFACE_REQUIRED_MISMATCH: begin_minesweeper_round` | adding the `current` row did NOT neuter the pre-existing `target`-row signature freeze; both rows still bite |
| `get_mutation_gate_instance_id` renamed to `_get_mutation_gate_instance_id_private` | 7/9, 1504/1506, exit 1 — `SURFACE_REQUIRED_MISSING: get_mutation_gate_instance_id` | that row is load-bearing too; the seam cannot silently leave the public surface |

All three reverted; `git status` on `autoload/` clean before the commit.

## Observed evidence at the repaired tree

All exit 0, no `SUITE_NOT_EXECUTED`.

```
test_public_surface_inventory (repaired): exit 0 |  1 script  |   9 tests |   9 passing | 1522 asserts
                                (was)     exit 1 |  1 script  |   9 tests |   7 passing | 1480/1482 asserts
hospital_dating_adapter_gate:             exit 0 | 18 scripts | 230 tests | 230 passing | 5066 asserts
Step 8.8 presentation_day7_green:         exit 0 | 12 scripts | 162 tests | 162 passing | 1916 asserts
Step 7.7 hospital_order_green:            exit 0 | 11 scripts | 141 tests | 141 passing | 1945 asserts
guarded-path regression:                  exit 0 |  5 scripts |  62 tests |  62 passing | 2903 asserts
(coordinator, presentation_matrix, presentation_resume, effect_order, committed_schedule_day_resolution)
the four cited contract tests' suites:    exit 0 |  2 scripts |  21 tests |  21 passing |  249 asserts
(tests/unit/test_application_bootstrap.gd, tests/integration/test_application_bootstrap.gd)
```

The four verification gates are byte-for-byte the recorded 162/1916, 141/1945, 62/2903 and
230/5066 baselines. None of them lists the surface-inventory suite, and the change touches no
production source, so an unchanged baseline is the expected result and not evidence of the repair.
The repaired suite itself is the evidence.

## What this does NOT settle

Task 9 still owes a full REGENERATION of this manifest from
`tools/runtime/generate_public_surface_inventory.gd` on a clean subject, with the rest of the
dwm-p2r.15 closeout. This is a targeted classification repair that takes the suite from red to
green; it does not discharge Task 9, and `dwm-p2r.15` stays open.

Also worth a look during that regeneration: `begin_minesweeper_round` and
`complete_minesweeper_round` now hold both a `current` and a `target` row, and the three legacy
methods they replaced (`consume_minesweeper_app_round`, `start_minesweeper_app_round`,
`finish_minesweeper_app_round`) still carry `disposition: "replace"` pointing at them. The
replacements now exist, so whether those legacy rows should move to `remove` is a Task 9 call, not
one made here.
