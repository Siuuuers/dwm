# `hospital_dating_adapter_gate` — dwm-p2r.14's own acceptance gate

**Why this file exists.** `phase2r.verification_commands` on `dwm-p2r.14` names
`Invoke-IsolatedGodot.ps1:hospital_dating_adapter_gate`, but that string appeared only in
`.godot/beads/phase2r-all.json` and `prompt_docs/metadata/phase_2r_beads.v1.json` — nowhere in
`docs/`, `tools/` or any plan. `Invoke-IsolatedGodot.ps1` takes `-SuiteId` as a free label with the
real test list in `-GodotArgs`, so the name had nothing behind it. This note defines it from the
bead's acceptance criteria and records the observed result, so the name resolves to a command.

## The command

```powershell
& '.\tools\testing\Invoke-IsolatedGodot.ps1' -SuiteId 'hospital_dating_adapter_gate' -LogName 'hospital-dating-adapter-gate.log' -GodotArgs @('-s','res://addons/gut/gut_cmdln.gd','-gtest=res://tests/unit/test_hospital_presentation_port.gd,res://tests/unit/test_dating_presentation_port.gd,res://tests/unit/test_dialogic_presentation_owner_adapter.gd,res://tests/unit/test_day_resolution_coordinator.gd,res://tests/unit/test_day7_schedule_provenance.gd,res://tests/scene/test_hospital_scene.gd,res://tests/scene/test_dating_scene.gd,res://tests/integration/test_committed_schedule_day_resolution.gd,res://tests/integration/test_committed_schedule_effect_order.gd,res://tests/integration/test_committed_schedule_presentation_matrix.gd,res://tests/integration/test_committed_schedule_presentation_resume.gd,res://tests/integration/test_hospital_dating_adapter_negative_contract.gd,res://tests/integration/test_day_resolution_disk_durability.gd,res://tests/integration/test_dialogic_bridge_contract.gd,res://tests/integration/test_schedule_presentation_bootstrap_wiring.gd,res://tests/scenario/test_day7_schedule_provenance.gd,res://tests/scenario/test_hospital_invitation_closures.gd,res://tests/scenario/test_hospital_twofriends_order.gd','-gexit')
```

The plan wraps its gates in `powershell -NoProfile -ExecutionPolicy Bypass -Command "..."`. The
inner call above is the same argument list; run it directly when the wrapper is unavailable.

## Coverage survey — which acceptance path each suite carries

The bead requires "integration tests cover valid, stale, duplicate, conflicting, interrupted,
Hospital, pair, and Day-7 paths using the real committed schedule". Every one of those eight paths
was ALREADY covered before this gate existed. The gate's job is to say so in one command; no
duplicate suite was written for any of them.

| Path | Already proved by |
|---|---|
| valid | `test_hospital_presentation_port` (`a_valid_intent_returns_the_canonical_command_and_nothing_else`), `test_dating_presentation_port` (`a_valid_solo_intent_returns_the_canonical_command`), `test_day_resolution_coordinator` (`a_published_completion_is_checkpointed_and_then_advances_the_stage`) |
| stale | `test_committed_schedule_presentation_resume` (`a_superseded_date_never_presents_across_a_crash`, `a_crash_after_the_stage_checkpoint_never_presents_again`), `test_hospital_presentation_port` (`a_drifted_replay_cannot_overwrite_the_stored_command`, `owner_receipt_drift_is_refused_before_any_stage_mutation`), `test_day7_schedule_provenance` (`a_registry_that_moved_on_since_the_commit_is_refused`) |
| duplicate | `test_hospital_presentation_port` (`a_duplicate_owner_emission_returns_the_same_receipt_without_a_second_publication`), `test_dialogic_presentation_owner_adapter` (`a_duplicate_runtime_end_signal_emits_no_second_completion`), `test_committed_schedule_presentation_resume` (`a_duplicate_physical_completion_publishes_exactly_one_receipt`), `test_day_resolution_coordinator` (`a_duplicate_completion_does_not_leave_the_coordinator_awaiting_a_finished_stage`) |
| conflicting | `test_hospital_presentation_port` (`a_tampered_command_is_a_conflict_not_a_completion`, `a_bypassed_binding_still_conflicts_on_command_identity`), `test_dialogic_presentation_owner_adapter` (`the_same_completion_id_with_changed_bytes_is_a_command_conflict`), `test_committed_schedule_day_resolution` (`a_same_resolution_replay_returns_the_existing_plan_and_a_rival_conflicts`) |
| interrupted | `test_committed_schedule_presentation_resume` — all nine crash cuts, plus `test_day_resolution_disk_durability` |
| Hospital | `test_hospital_presentation_port`, `test_hospital_scene`, `test_scenario/test_hospital_twofriends_order`, `test_committed_schedule_effect_order` (supersession, faint, witness, rollback), `test_committed_schedule_presentation_matrix` (Hospital variant + both ancestry rows) |
| pair | `test_dating_presentation_port` (`the_pair_order_is_priscilla_then_lavinia_and_is_never_sorted`, `a_deferred_pair_intent_is_accepted_in_the_canonical_order`), `test_committed_schedule_presentation_matrix` (`hospital_supersession_is_what_owes_the_pair_a_presentation`, `the_deferred_pair_variant_carries_its_exact_matrix_row`) |
| Day-7 | `test_unit/test_day7_schedule_provenance`, `test_scenario/test_day7_schedule_provenance` (`day7_stops_after_the_provenance_checkpoint_with_no_ending_and_no_board`, `no_day8_aggregate_can_reach_the_handoff`), `test_committed_schedule_day_resolution` (`a_receipt_backed_empty_commit_starts_a_day_seven_resolution_with_no_substages`), `test_day_resolution_coordinator` (`day7_resume_never_needs_the_identity_port`) |

## The one genuine gap, and what was written for it

The NEGATIVE half of the criteria — "No old nine-key Schedule fields, twofriends pseudo-route,
synthetic completion, direct Dialogic start, or presentation-owned mutation remains" — had no
check. Two of its five clauses were already proved and were NOT rewritten:

- **synthetic completion** — proved four times over, in both port suites, the owner adapter suite
  and `test_dialogic_bridge_contract`.
- **presentation-owned mutation, for the SCENES** — `test_hospital_scene` / `test_dating_scene`
  compare a full owner snapshot across `_ready()` and across button input.

The other three, plus the ports/owner half of the mutation clause, are new in
`tests/integration/test_hospital_dating_adapter_negative_contract.gd` (11 tests, 308 asserts):

- **no old nine-key Schedule fields.** The retired shape is the pre-Phase-2R
  `ScheduleRules.ENTRY_KEYS` at `fb7291680`: `action_id, day, effect_ids, entry_id, friend_ids,
  route_id, slot_index, type, unlock_receipt_id`. Three survive by name; the six caller-owned ones
  are asserted absent from `ScheduleStateSchema.ENTRY_KEYS`, asserted *refused* one at a time by
  `validate_aggregate` on a real committed entry, and asserted absent at any depth from both the
  frozen aggregate and the frozen presentation context over a real Day-3 committed schedule.
  `route_id` gets its own test: a committed entry carries none, and the route the producer emitted
  equals the REGISTRY's route for that entry's action — so the route is a registry fact, not a
  caller fact that moved.
- **no twofriends pseudo-route.** Asserted absent from `ScheduleStateSchema.ACTION_KINDS`, from
  every registry manifest record's `route_id`, and from `DatingPresentationPort.CONTEXT_KINDS`,
  while `twofriends_if_deferred` is asserted PRESENT as a stage and as a presentation kind — so
  this is a claim about routes, not a blanket ban on the substring. `SceneRouter` is required to
  refuse both `twofriends` and `twofriends_if_deferred` with `invalid_presentation_route`.
- **no direct Dialogic start.** A comment-stripped source scan requires that neither port, neither
  scene, the coordinator, the state port nor `SceneRouter` names `start_timeline`, `DialogicBridge`
  or `Dialogic.` in executable code, and that `DialogicPresentationOwnerAdapter` reaches the runtime
  only through `_bridge.call(&"start_timeline_id"`. Neither port exposes a start method.
- **no presentation-owned mutation, for the ports and the owner.** The same scan requires that none
  of the five adapters names `GameState`, `SceneRouter`, `_run_lifecycle`, `advance_day`,
  `increment_day`, `apply_hospital`, `commit_effect_transaction`, `complete_active_stage` or
  `route_context` in executable code.

`HospitalScene.gd`'s doc comment deliberately still NAMES the two mutations Task 8 removed, so the
scans strip full-line comments. `test_the_comment_stripper_is_doing_real_work` requires those
tokens to be present in the RAW file and absent from the code, so the sweeps cannot go vacuous
unnoticed.

## A survival recorded rather than glossed

The pseudo-route producer is still in the tree. `GameState.execute_schedule_sequence_until_route_needed()`
still returns `route == "twofriends"`, and `create_missed_group_twofriends_entry()` still builds an
old-shape `{type, friend_ids, inviter_id, day, source, advance_day_after_finish}` entry. Both belong
to the legacy transport GameState's own comment records as replaced by the committed-receipt start
port, and both have **no caller anywhere in the repository** — not in production, not in tests.

They were not deleted: they are outside `dwm-p2r.14`'s file scope, and the plan assigns that
transport's retirement elsewhere. Instead `test_the_legacy_pseudo_route_producer_has_no_caller_in_production`
pins the containment, scanning every production `.gd` under `res://scripts` and `res://autoload`
and requiring the producer to have no caller outside `GameState.gd` itself. It goes red the moment
anyone wires the pseudo-route back in. Whoever retires the legacy transport should delete both
methods and then delete that test.

## Proof the new suite is not vacuous

A suite that is green on its first run proves nothing until a mutation makes it red. Four mutations
were applied to production source and reverted:

| Mutation | Result |
|---|---|
| `route_id` added to `ScheduleStateSchema.ENTRY_KEYS` | 4 tests red — the nine-key contract, the validator sweep, the real-schedule scan and the registry-fact test |
| `execute_schedule_sequence_until_route_needed` named in `autoload/SceneRouter.gd` | 1 test red, naming `res://autoload/SceneRouter.gd` as the caller |
| `start_timeline` named in `HospitalPresentationPort.gd` | 1 test red — `must not name start_timeline` |
| `GameState` named in `DatingScene.gd` | 1 test red — `must not name GameState` |

Under mutation set 1+2 the suite went 6/11 passing; under 3+4 it went 9/11. All four mutations were
reverted; `git status` on `scripts/` and `autoload/` is clean.

## Observed results

At tree `e66411a9` + this change. All exit 0, no `SUITE_NOT_EXECUTED`.

| Gate | Scripts | Tests | Passing | Asserts |
|---|---|---|---|---|
| `hospital_dating_adapter_gate` (new) | 18 | 230 | 230 | 5066 |
| Step 8.8 `presentation_day7_green` | 12 | 162 | 162 | 1916 |
| Step 7.7 `hospital_order_green` | 11 | 141 | 141 | 1945 |
| guarded-path regression | 5 | 62 | 62 | 2903 |
| the new suite alone | 1 | 11 | 11 | 308 |

Step 8.8, Step 7.7 and the guarded-path regression are byte-for-byte their recorded baselines
(162/1916, 141/1945, 62/2903): the change is test-and-docs only, in a suite none of the three lists.

## What this gate does NOT settle

Running green does not close `dwm-p2r.14`. The items the `.18` review brief left open are unchanged
by this work: `SceneRouter.route_presentation()` still has no caller in the walk, the producer is
unreachable in production until Plan 02 configures the desktop-consequence source, and the
deferred-pair variant is proved at the derivation level rather than end to end through a routed
scene. `dwm-p2r.14`, `.18` and `.19` all remain open.
