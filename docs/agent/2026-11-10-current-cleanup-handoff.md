# Current cleanup handoff

## Outcome and baseline

Every selected check verifies current behavior and passes, or has a documented retirement reason and replacement coverage where required. Remove production code only after proving it is unused and recording its former purpose.

Reviewed master: `26dbcd42acf82f419b350a84e1237cbcfb09bc38` (PR #249).
The original assignment was written before implementation. This completion record supersedes its active queue. PR #215 was closed without merging; #250 merged this handoff.


## Completion record — 11 November 2026

Local candidate code revision: `5dc66149bc4d4cb6eadc98e745fae56698173ceb`.
Baseline runtime: `26dbcd42acf82f419b350a84e1237cbcfb09bc38`; #250 then merged
as `a610420aad32e2e7c7c98ea89d1d90d59fb462df` (documentation only).
Subsequent completion-record edits do not change tested code.

- Removed the generic `CLAUDE.md` at the user's request and its current routing,
  handoff and CI-selector references. Historical migration evidence retains its
  original file names and hashes; those checks explicitly do not require current
  file existence. No game requirement was relocated or removed.
- Mission A is complete: passage/Challenge guidance recognizes #247–249, the
  DatingScene History lead is superseded by retirement, and public-surfaces
  checkout optimization stays separately deferred pending measured need.
- Caption baseline reproduced missing `t`/`get_readiness` calls on `MemoryLocale`
  (one selected method, exit 1). The fake now implements readiness, key lookup
  and translation with the existing localization signatures. Production and
  original caption assertions are unchanged.
- Held-source baseline reproduced stale History expectations, a detached Bridge
  lookup and obsolete pre-acknowledgement ownership. The fixture mounts its
  Bridge, expects current bounded History, and checks the documented confirmed
  commit failure retains fatal custody and consumes the acknowledgement once.
- The detached scene-day test failed earlier at `reading_entry_context_mismatch`.
  Its obsolete snapshot test is retired; the unchanged compact-position test
  already proves the intended missing-Run-admission contract. See the
  [retirement record](../retired-features/legacy-dating-flow/README.md).
- The historical connected notification method
  `test_connected_bridge_partial_next_commits_marker_and_later_next_preserves_receipt`
  is already absent from baseline master. Do not rebuild that obsolete snapshot.
  The earlier progression report remains historical; no new marker-suite pass is
  claimed here.
- `GameStateDayResolutionPort` is already absent. `RunLifecycle`,
  `DayResolutionPlan` and `SaveManagerCheckpointPort` retain real shared callers
  or validation obligations. Only the proven-uncalled Schedule continuation
  method and its exclusive helper were removed (107 lines). No save format,
  UID or resource changed. No speedup is inferred.

### Focused verification

Godot 4.6.3 Linux. Each selection used a separate process and storage; the
connected Save/Load pair alone shared storage. All final rows exited 0, matched
the expected JUnit method names, passed with positive per-test assertions and
had no script errors. Counts exclude setup/teardown assertions.

| Suite | Selection | Tests | Assertions |
| --- | --- | ---: | ---: |
| `test_witnessed_run_presentation.gd` | fresh layout, live accessibility, no installed run, pending click | 4 | 57 |
| `test_scene_held_source.gd` | `test_real_` | 3 | 106 |
| `test_scene_day_reading.gd` | `test_compact_position_does_not_supply_its_own_run_admission` | 1 | 12 |
| `test_scene_transition_identity.gd` | original completion, restored retry, repeated selected Load | 3 | 36 |
| `test_scene_first_reveal_connected_create.gd` / `load.gd` | current explicit Save then fresh-process selected Load | 2 | 57 |
| **Total** | | **13** | **268** |

Reproduction command shape (run from repository root; expand `SUITE`, `METHOD`
and each unique `CASE`; `METHOD` is omitted for the single-method create/load
files):

```sh
mkdir -p .godot/phase2r_tests/cleanup/CASE/{data,root}
XDG_DATA_HOME="$PWD/.godot/phase2r_tests/cleanup/CASE/data" \
DWM_TEST_ROOT="$PWD/.godot/phase2r_tests/cleanup/CASE/root" \
godot --headless --path . --audio-driver Dummy \
  -s res://addons/gut/gut_cmdln.gd -gconfig= \
  -gtest=res://tests/integration/SUITE -gunit_test_name=METHOD \
  -gexit -glog=1 -gjunit_xml_file=/tmp/CASE.xml
```

Use `DWM_SCENE_READING_FIXTURE=1` for scene-day and held-source checks; leave it
unset for connected create/load and caption checks. The identity suite lives in
`tests/unit/`; its isolated semantic checks do not assert production wiring.
The three identity methods are
`test_original_completion_is_exact_nine_projections_and_returned_detached`,
`test_restore_derives_exact_four_quoted_projections_and_active_retry_reuses_allocation`,
and `test_repeated_selected_load_and_load_of_restored_checkpoint_have_distinct_children`.
The four caption methods are
`test_fresh_layout_reads_installed_run_and_next_run_waits_for_real_timeline_boundary`,
`test_live_accessibility_recolours_same_native_caption_without_owner_poll_or_input_loss`,
`test_no_installed_run_keeps_preview_defaults_until_a_real_scene_boundary`, and
`test_colour_change_keeps_a_real_pending_caption_click_until_one_release`.

An initial additional connected probe used a root outside the recognized
`.godot/phase2r_tests` ancestry and failed registration selection before executing
assertions. It is excluded; the corrected isolated create/load pair is the row
above. This was harness setup, not a runtime repair.

Other exit-0 checks: the focused
`test_windows_coverage.WindowsCoverageTests.test_audio_prototype_uses_its_workflow_and_retains_runtime_coverage`,
`python tools/lint/check_comments.py --base origin/master`, and
`git diff origin/master --check`. Independent read-only review covered the
reference cleanup, retirement reachability, fake contract and fixture assertions.
No inventory regeneration is required: the removed methods are neither public
GameState/SaveManager surfaces nor callers of those owners; renamed/removed test
methods have no runner references.

Skipped: broad CI/gameplay matrix, new injection tests, whole-suite claims,
rendered art-hold verification, Windows export/player/audio qualification,
performance measurement and formal-model expansion. Publication skips the broad
fallback CI for this bounded locally verified cleanup; that is not a CI pass.
Existing write-failure handling, shared save validation and accessibility remain.

## Confirmed decisions

- Keep development and focused verification cloud Linux-first.
- Defer Windows packaged player-experience, visible latency and audio-continuity qualification until the user's planned game features settle. This remains a later release task, not a passing result. Do not launch it as part of this assignment.
- Preserve current approved player behavior. Development saves may be incompatible when an authorized simplification requires it; do not introduce migrations solely for unshipped formats.
- Record each proven retirement in the existing `docs/retired-features/` structure before deleting implementation and its exclusive tests.
- Improve names only when their meaning becomes clearer. Update direct, dynamic, serialized and test references.
- The 11 November follow-up narrows comment removal to runtime GDScript in `scripts/` and `autoload/`; preserve all test/tool comments, required legal notices and machine directives.
- Use focused checks. No new injection campaign, broad matrix, generic state-machine framework, speculative hardening, or host-sensitive timing gate.
- The bounded cleanup below is completed; do not repeat its historical assignment.

## Sources

- [Closed prior queue #215](https://github.com/Siuuuers/dwm/pull/215)
- [Retained day-resolution dependencies #230](https://github.com/Siuuuers/dwm/pull/230)
- [Legacy fixture findings #237](https://github.com/Siuuuers/dwm/pull/237) and [#239](https://github.com/Siuuuers/dwm/pull/239)
- [Latency implementation #245](https://github.com/Siuuuers/dwm/pull/245)
- [Player latency audit](2026-11-05-player-latency-audit.md)
- [Passage handoff](2026-11-05-passage-latency-handoff.md)
- [Challenge CI handoff](2026-11-10-challenge-ci-coverage-handoff.md)
- [Progression implementation](2026-11-03-story-progression-implementation.md)
- [Model mapping and limitations](../../tools/verification/story_progression/README.md)

## Remaining scope

The selected historical leads have no remaining confirmed defect. Further retirement requires a new complete reachability proof for a specific cohort; the retained shared classes are not authorized deletion candidates merely because they contain legacy methods. Public-surfaces checkout work remains deferred pending measured cost. Windows player-experience qualification remains deferred until planned features settle. No new session is required to repeat the completed work.
