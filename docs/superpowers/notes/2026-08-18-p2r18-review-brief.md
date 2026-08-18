# dwm-p2r.18 review brief — presentation producer

**Purpose.** Hand a *cold* reviewer everything needed to audit the dwm-p2r.18 producer without
re-deriving it, and to say plainly where the author's own confidence is weakest. Written by the
author immediately after implementation; a same-session self-review keeps the author's anchoring,
so the correctness pass below is deliberately left to a fresh reader.

## What to review

Three commits on `codex/dwm-p2r13-resealed`, all children of the Task-8 boundary:

| Commit | Subject |
|---|---|
| `2f08fe1f` | `feat(flow): emit committed-Schedule presentation intents` |
| `e4d8321c` | `test(flow): prove the presentation rows against the Plan-01 matrix` |
| `7547df1b` | `chore(test): drop two unused preloads from the new presentation suites` |

Review base: `git diff db7c290b..HEAD`. Production diff is 6 files / ~988 insertions; the rest is
tests.

## The one-paragraph summary

Task 8 built the presentation *layer* — ports, narrative owner, scenes, composition — but nothing
handed those ports a command during a day resolution, so no stage ever paused on a presentation.
This work adds the *producer*: it mints the resolution root, drives the retained
`DayResolutionStartPort`, derives `P01.hospital.resolution → P01.hospital.miss[] →
P01.presentation.intent → P01.presentation.completion` in matrix order, pauses the walk on
`await_registered_command`, and has the coordinator checkpoint the port's completion receipt before
advancing the stage. The resolution root and its start receipt are now **persisted in the plan**,
because `resume()` never re-runs `begin_or_resume` and the intent projects
`day_resolution_start_receipt_id`.

## Where to look first, in priority order

1. **`GameStateDayResolutionPort._presentation_command` and `_derive_hospital_rows`** — the whole
   identity derivation. Every ordinal, source set and variant discriminator lives here.
2. **`DayResolutionPlan._validate_resolution_root`** — the re-proof on load. If this is weak, a
   tampered snapshot restores a resolution whose children cannot be reproduced.
3. **`RunLifecycle.begin_day_resolution` / `prepare_day_resolution`** — idempotence moved from
   `resolution_id` to `command_id`. If these two ever disagree, a prepare/commit pair disagrees
   about whether a resolution is already active.
4. **`DayResolutionCoordinator.complete_presentation_stage`** — checkpoint-then-advance ordering.

## Known deviations carried (all user-approved)

- **DEVIATION-4** (from `.14`): stage/substage transaction ids remain `DayResolutionPlan`'s
  synthetic strings rather than issuer-derived `P01.day_resolution.stage` children. The presentation
  rows carry and project `stage_id` exactly as supplied. Re-opening this would ripple through
  `DayResolutionPlan`, `RunSnapshotSchema`, SaveDocument v3 and every suite asserting the synthetic
  id format.
- **DEVIATION-5** (new, this bead): the board-fate receipt (`P01.day_resolution.start`) and the
  condition receipt (`P01.hospital.resolution`) are Plan-02 records that `dwm-p2r.9` never
  delivered, and plan line 1303 forbids Plan 01 from building desktop board fate. They arrive
  through `configure_desktop_consequence_source()`, which **Bootstrap deliberately never calls**.
  Production therefore fails closed at any stage that needs a presentation, and
  `get_desktop_contract_state().presentation_producer_ready` reports `false`.

## Where the author's confidence is weakest — audit these hardest

- **The deferred-pair variant is implemented but never exercised end to end.** `_deferred_pair_site`
  reads `contacts.group_action.deferred_twofriends`, matches its `action_id` against a committed
  `group` entry, and projects that entry's ancestry. Hospital and surviving-date are both covered by
  tests; the pair is not. Treat its ordinal, context and `input_receipt_ids` as unverified.
- **`presentation_stage_receipt` builds a substage envelope with `superseded: false` hardcoded.** A
  surviving date is by definition not superseded, so this is believed correct, but it is a literal
  rather than a read, and nothing asserts the two can't diverge.
- **Timeline locators are constructed by string interpolation** (`dating.solo.%s.day%d.%s`) and then
  required to exist in `DialogicTimelineCatalog`. The registry check is the safety net; the
  construction itself encodes a naming convention that lives only in this function.
- **`_resolution_start` refuses a concurrent unfinished resolution before touching the issuer**, so a
  rejected Done command does not burn a root. Confirm that guard cannot be bypassed on a path where
  the plan exists but `command_id` differs *and* the plan is complete.

## What is already proven, so you needn't re-derive it

- **Matrix conformance.** `tests/integration/test_committed_schedule_presentation_matrix.gd` rebuilds
  the 13 intent members and 7 completion members from plan lines 97/98/100 *as text*, derives a child
  through the same issuer, and requires the id to equal the producer's. Member order is proven
  irrelevant (S(...) sorts); membership, parent and ordinal are proven load-bearing.
- **The sweep is not vacuous.** Removing `P("stage_index",…)` from the producer was verified to turn
  five tests red with the two differing child ids reported.
- **Crash resume.** `tests/integration/test_committed_schedule_presentation_resume.gd` destroys and
  rebuilds every process owner from the on-disk root plus persisted bytes across the Step 8.2 cuts.

## A latent defect this work fixed, worth confirming

`SUBSTAGE_CONTRACTS` was declared in Task 7 and **never consulted** — `_commit_completion` validated
every record against `STAGE_CONTRACTS[stage_id]`, so any substage driven through the coordinator
would have been rejected on a kind mismatch. No test reached it because the only coordinator-driven
walk commits an empty Schedule, which has no substages. Confirm the new `_validate_substage_envelope`
covers every kind a substage can actually return.

## Gates to re-run at the reviewed tree

```powershell
# Step 8.8, verbatim from the plan
powershell -NoProfile -ExecutionPolicy Bypass -Command "& '.\tools\testing\Invoke-IsolatedGodot.ps1' -SuiteId 'presentation_day7_green' -LogName 'presentation-day7-green.log' -GodotArgs @('-s','res://addons/gut/gut_cmdln.gd','-gtest=res://tests/unit/test_hospital_presentation_port.gd,res://tests/unit/test_dating_presentation_port.gd,res://tests/unit/test_dialogic_presentation_owner_adapter.gd,res://tests/unit/test_day7_schedule_provenance.gd,res://tests/scene/test_hospital_scene.gd,res://tests/scene/test_dating_scene.gd,res://tests/integration/test_dialogic_bridge_contract.gd,res://tests/integration/test_schedule_presentation_bootstrap_wiring.gd,res://tests/integration/test_desktop_bootstrap_wiring.gd,res://tests/scenario/test_day7_schedule_provenance.gd,res://tests/scenario/test_hospital_twofriends_order.gd,res://tests/integration/test_day_resolution_disk_durability.gd','-gexit')"
```

Last recorded results at `e4d8321c`: Step 8.8 gate 162/162 across 12 suites; Step 7.7 gate 135/135
across 11 suites; wide regression 509/509 across 38 suites, 6460 asserts; scene-load smoke exit 0.
All exit 0, no `SUITE_NOT_EXECUTED`.

## Still open, and blocking `.15`

- `SceneRouter.route_presentation()` has no caller in the walk. The coordinator returns the
  `await_registered_command` result carrying `route_id` and the `presentation_request`; who
  dispatches it is a live-desktop concern and Plan 03 owns the Done dispatch surface. Deliberately
  not guessed at.
- The producer is unreachable in production until Plan 02 configures the desktop-consequence source.
- The deferred-pair variant lacks end-to-end coverage.

`dwm-p2r.14` and `dwm-p2r.18` are both **open** and must stay open until the above are resolved.
Nothing has been pushed.
