# Canonical CI reconciliation — 23 October 2026

Read-only audit of PR51 run39873079868 against continuation
`46bc029f5219fdc39d5d6859765c0fd412f91252`. This document changes no selector,
runtime, test assertion, historical seal or acceptance status. No new engine
execution was performed. The concurrent Backup retention fix is a separate
qualification scope.

## Outcome and scope

One current product candidate should run current supported behavior; retained
calendar/health/legacy-startup contracts should run on an explicitly pinned
historical checkout with separate user roots. The user already selected this
separation in [the earlier handoff](a-scene-current-historical-resume-20261023.md).
No product design question blocks it. A passing historical build cannot certify
current scene startup, current saves, authored progression or current performance.

Do not rerun the unchanged broad workflow: it still selects known incompatible
historical fixtures. Do not remove their assertions, restore retired mechanics,
raise deadlines, or substitute a historical result for current behavior.

## Source pins and reusable evidence

- PR51 head: `328edfe082c84bd9f6ca0a9d45e6603e0902695c`; tested merge
  `13b9087e5fb2d8e78c946f0acc42a0dd56054af5` has the same tree.
  [Canonical run39873079868](https://github.com/Siuuuers/dwm/actions/runs/39873079868)
  failed. Export/startup succeeded; that is not full integration acceptance.
- Existing historical lane: source
  `a24f71766a624b57601814dda487b53c66518c39`, tree
  `173218aacfb79c580f2a593d864fb625a84aa076`; run39882273467 passed 70 historical
  contract cases and 8 restore-control cases. Its October 2 source predates the
  timed-hold journey. Do not claim it covers that later test.
- Suitable later historical substrate: PR5 source
  `e5db010715c187cc775341d204391f527dc334ea`, tree
  `24773c04fc11d821839449df9f67995b47d98f55`. The current PR5 receipt records
  [run37535856887](https://github.com/Siuuuers/dwm/actions/runs/37535856887), actual
  tested merge `eae5a9cfa729f6cfa57a1939c8896476fb1a9141`, all 26 jobs and 2,696
  primary XML cases passing. This audit read that receipt and inspected source;
  it did not re-download or requalify those artifacts. The source retains health
  effects, old desktop startup and the later timed-hold journey.
- Current follow-up run39888007872 passed 135 GUT cases/30,968 assertions and
  11 child exits, but the **overall run failed** its PNG dimension gate. Offline
  verification authenticated original 992x558 images; it did not rewrite the
  cloud verdict. Corrected Settings renderer39889234425 passed 11 captures;
  artwork retry39891351724 passed 25 tests, 558 case assertions plus 2 setup
  assertions, and native initial/fresh-load images. See
  [retained evidence](../evidence/phase_2r/authored_followup_20261023/README.md).

## Exact mixed-file disposition

`tests/integration/test_desktop_bootstrap_wiring.gd` has 27 methods. Keep its
20 identity/composition methods in current qualification. The following seven
exercise retired gameplay and belong in the historical lane:

1. `test_gameplay_mount_uses_real_ports_and_first_reveal_persists_one_charge`
2. `test_fresh_graph_keeps_prior_day_two_autosave_after_failed_completion`
3. `test_fresh_graph_keeps_prior_autosave_after_failed_condition_departure`
4. `test_shop_purchase_saves_authored_effects_and_retries_without_a_second_charge`
5. `test_fresh_graph_keeps_prior_autosave_after_failed_ordinary_purchase`
6. `test_fresh_graph_keeps_prior_autosave_after_failed_special_purchase`
7. `test_shop_batch_and_public_gift_alias_commit_authored_values_and_inventory`

The seven assertions' bodies are retained at the PR5 substrate. Current fixture
evolution adds scene-binding lifetime isolation, mounts GameState, and relabels
the old diagnostic snapshot to the then-current legacy schema version. Preserve
those differences in the mapping; running the historical owner tests does not
prove current owner behavior. Do not drop the whole 27-method file.

In `tests/unit/test_japanese_korean_ui.gd`, only
`test_draft_story_resolution_retains_exact_english_locators_and_correspondence`
is wholly coupled to old English fallback and `reply.ordinary.*` IDs. Its body
matches PR5. Keep the other nine current locale/font/layout methods on current
source, including the glyph check; earlier focused qualification omitted this
whole file and does not establish those nine together.

All eleven methods in `tests/unit/test_ordinary_reply_echo_state.gd` depend on
the retired reply registry. The whole file is byte-identical to PR5 and can run
unchanged there. Its receipt/retry/expiry checks must remain historical coverage.

`tests/unit/tooling/test_phase2r_schedule_gate.gd` is also mixed. Preserve current
`test_derive_child_census_at_head_attributes_every_call_site_to_a_matrix_producer`:
the continuation explicitly accounts for four new scene issuer sites. Move only
the retired-health vector
`test_observed_vectors_for_the_day3_hospital_walk_with_two_superseded_dates`
to historical selection. Do not replace the current census with an old census.
The existing historical lane already selects the complete historical schedule
gate, DTL structure, EffectResolver and Hospital rules files.

Implementation should use explicit method manifests or split current/historical
test classes with exact source/method census verification. GUT's stock
`-gunit_test_name` is only a substring filter, not an exclusion list; avoid an
unreviewed broad-name filter or inherited duplicate discovery. Preserve every
method in an explicit current or historical disposition before changing selectors.

## Current counterparts, not equivalence claims

| Retained obligation | Current supported coverage to keep/select |
| --- | --- |
| Board reward, save refusal and no repeated charge | `test_scene_round_completion.gd`, `test_scene_round_checkpoint_transaction.gd` |
| Shop durable purchase, refusal/retry and immutable reading boundary | `test_scene_shop_checkpoint_custody.gd`, `test_scene_shop_checkpoint_transaction.gd` |
| Fresh-process purchased state and Challenge preservation | `test_scene_apps_connected_create.gd` then `test_scene_apps_connected_load.gd`, sharing one isolated root |
| Daily renewal and failed-boundary recovery | `test_scene_day_renewal.gd`, `test_scene_day_commit_ordering.gd` |
| Current authored locale and controls | `test_story_localization.gd`, `test_scene_controls_localization.gd` |
| Shipped Title and exact fresh Load | `test_current_title_scene_create.gd` then `test_current_title_scene_load.gd` |

These are concrete existing tests, not newly executed results or one-to-one
proofs of retired mechanics. Use their retained exact-source receipts where
applicable; qualify changed owners once after review.

## Benchmarks and rendered startup

The current files below are byte-identical to PR5, so the historical lane can
preserve their original behavior without test edits:

- `tests/manual/benchmark_minesweeper_click_latency.gd`
- `tests/manual/benchmark_seven_day_history.gd`
- `tests/integration/verify_timed_hold_journey.gd`
- `tests/integration/verify_hospital_reading_journey.gd`
- `tools/testing/run_hospital_reading_journey.py`
- `tests/integration/verify_new_acc_latency.gd`

PR51's first benchmark failures were `benchmark desktop ready` and
`history desktop exists`, before timing observations. Timed-hold's combined
startup assertion requires ComputerDesktop although current New Account opens
SceneHost. This is more than changing a wait: the benchmark then uses legacy
reply IDs, Schedule Done, calendar day and Dating assumptions. Existing retained
triage describes that dependency; no ready patch maps all those obligations onto
current authored flow.

Keep historical matched benchmark comparisons on their pinned historical source,
with the original controls and saved-payload custody. Current performance should
use the existing genuine authored recovery/Load/Save helpers and current native
board journey, explicitly identifying their different scope. The handoff's
multi-minute authored stalls remain a real current issue. Uninterrupted full-week
run39920770730 remains timed out; later ending recovery is stitched coverage.

## Smallest coherent implementation order

1. Finish the separate Backup retention fix with focused inspection and one
   affected native Load/Save journey. Reuse unchanged ending-replay evidence.
2. Add a versioned current/historical method-disposition manifest and a pinned
   historical checkout lane. Reuse PR5 evidence for unchanged historical scope;
   do not rerun the entire historical 26-job campaign merely to migrate selectors.
   Verify no method disappears and retain current owner/inventory checks.
3. Select the mixed current methods plus the existing current counterparts above.
   Repair actual fixture setup failures revealed there; first audit scripts with
   process-wide registration and isolate incompatible owners into fresh processes.
4. Only then run a coherent integration campaign and current Windows export.
   The available focused evidence does not by itself authorize declaring master
   integration verified.

Retained `proposals/persistence/unqualified.patch` and
`proposals/endings/unqualified.patch` predate these repairs; they are not a ready
canonical-selector solution. Most relevant fixture changes are already in the
continuation. Review an exact diff before reusing any old patch.

## Native inventory regeneration after SaveManager edits

Run in the authenticated Windows checkout after import:

```powershell
./tools/testing/Invoke-PublicSurfaceValidation.ps1 -Regenerate -EmitPayloads
./tools/testing/Invoke-CloudTests.ps1 -Suite public_surfaces
```

The first command generates and independently checks both inventories, then
retains exact outputs in `.godot/ci/public-surfaces` and emits bounded payloads.
The second runs the 11 inventory-contract cases. Adopt original cloud bytes;
do not manually shift coordinates or alter required-surface classifications.

## Implementation candidate prepared in this continuation

The test-only candidate removes 16 retired methods from four mixed files while
retaining all 74 current method bodies byte-for-byte. DTL structure remains in
the current suite with its 12 registration-independent validator tests; only
seven registry-dependent methods move to historical selection. The 11-method
ordinary-reply file remains in Git but is no longer selected on current source.
`tools/testing/canonical-test-disposition.json` records all 27 historical methods
and the retired startup-latency script, with exact PR5 body hashes.

Six explicit current suites are wired into the Windows matrix: scene round
checkpoint, scene Shop checkpoint, story localization, controls localization,
connected Apps create/load, and shipped Title create/load. The latter pairs use
separate OS processes sharing one isolated root. The round/Shop transaction
scripts move out of grouped suites without being dropped.

The manual-only `historical-contracts.yml` checks out and authenticates PR5
source/tree, then invokes its unchanged desktop, localization, new_account and
reading_delivery suites. It preserves a rerunnable historical lane; its new
workflow wiring is not a newly executed historical acceptance result. Reuse
the recorded PR5 evidence for unchanged source rather than repeating it here.

Focused current qualification and regenerated inventory adoption are pending
at this document checkpoint. Legacy benchmark/rendered job classification in
the broad workflow remains outstanding; this is not full master acceptance.
