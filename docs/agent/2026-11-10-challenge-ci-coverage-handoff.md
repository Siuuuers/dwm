# Focused Challenge CI coverage handoff

## Start here

Implementation now shares `challenge_transition_scope.py` between main validation and DTL preflight. The focused Linux runner imports once and runs the reviewed suites in seven processes, isolating immutable registrations and sharing storage only for the deliberate Save/Load pair. Runtime behavior is unchanged.

The historical #246 diff now selects `challenge_transition=true`, disables inventory/comparison, and selects `presentation_only=true` in DTL preflight. The five broad main-workflow jobs explicitly exclude this route. Unknown runtime or content changes retain existing coverage. A fallback diagnostic reports the unmatched paths before engine setup.

The authored End probe from #246 is now committed as `tests/integration/test_scene_challenge_transition_authored.gd`; it checks title-to-Day1-result traversal and exactly one `never_started` Challenge outcome. The focused runner expects the current source-declared tests and validates exact JUnit suite/method identities, passing status and nonzero assertions. It does not substitute a full-week journey.

Validation and final Actions evidence are recorded in PR #247. The assignment below preserves the original investigation and acceptance requirements.

Observable outcome: a change confined to the reviewed Challenge transition methods and their tests selects one focused Linux validation job; unrelated rendering, localization, audio and export jobs do not start. The same scope decision prevents unrelated DTL authoring preflight. Unmatched runtime changes retain existing broader coverage.

## Current state and evidence

- [PR #246](https://github.com/Siuuuers/dwm/pull/246) merged at `ccdcca976c16936b6245dd8474ed06ba49039f72`.
- Tested candidate: `c95bcf08bb6b1ec3d81df81c8385a7687e7b2762`; tested and merged tree: `6fbd967bd3ff99e0e28ae5831084f1ce5bcb85c3`.
- Before that PR, master was `be487bb62333dd57ef41b55258a76af59d07bbb4`. Use its diff to the tested candidate as the historical selector regression, including accompanying docs/lint/test changes. Do not compare current master to itself.
- The earlier [coverage run](https://github.com/Siuuuers/dwm/actions/runs/42041137547) selected full validation. Fixed path/method allowlists did not recognize this runtime slice; mixed documentation did not make it docs-only. DTL preflight separately matches autoload/integration paths.
- Sparse checkout and cancel-in-progress already exist. Adding them again will not fix selection.
- Runtime acceptance is complete: 56 focused Godot tests and six live-transition lint tests passed. Played-board creation/explicit Save passed 30 assertions; fresh-process Load passed 29. See PR #246 for per-suite counts and exact limits.
- Publication and merge used `[skip ci]` to avoid the known fallback. This was not a passing Actions run. Do not treat permanent CI skipping as the solution.
- [Passage handoff](2026-11-05-passage-latency-handoff.md) records performance work. No further runtime optimization is part of this assignment.

## Assignment

Goal: correct coverage selection for this demonstrated slice with the smallest complete change.

Owner: one coordinator owns workflow wiring, shared classification, integration and publication. Independent read-only caller/test audits can run in parallel.

Scope to investigate before editing:
- `.github/workflows/windows-tests.yml`: coverage outputs, embedded selector, sparse-checkout inputs, Linux runner, matrix construction and every downstream job condition.
- `.github/workflows/dtl-first-preflight.yml`: independent classification and preflight gating.
- `tools/testing/test_windows_coverage.py` and `tools/testing/test_inventory_preflight.py`: existing selector/workflow assertions.
- `tools/testing/progression_scope.py` and `tools/testing/self_talk_panel_scope.py`: existing method-boundary comparison patterns. Reuse the appropriate machinery; do not relabel Challenge work as story progression merely to reuse its job.
- `tools/testing/Invoke-CloudTests.ps1` and existing focused runners: suite entry points, setup reuse and data-root isolation.
- PR #246's exact changed functions, their callers, associated test bodies, exports/configuration and current master equivalents.

Dependencies: existing registration selection and cloud Godot 4.6.3 runner. No new framework or dependency.

## Implementation sequence

1. Reproduce classification using the historical PR diff. Record the matched rule or unmatched paths/methods. Check whether current master already solves any part.
2. Establish one shared decision for this bounded slice and consume it in both workflows. Keep unrelated existing categories intact; no file-wide GameState or Bridge exemptions.
3. Permit reviewed companion handoff prose without broadening runtime scope. Docs-only changes must stay docs-only. Include actual affected tests and any newly introduced classifier/runner files in checkout and coverage.
4. Wire one focused Linux job. Group compatible short suites to share setup; separate incompatible immutable registrations into fresh Godot processes. Keep test data isolated except for deliberate creator/loader pairs.
5. Audit all dependent job conditions before running acceptance. A new output alone is insufficient if a downstream fallback still starts the broad matrix.
6. Run lightweight selector and runner checks first. Inspect the selected jobs before publishing workflow changes without `[skip ci]`. Then obtain one appropriately scoped Actions run on the final candidate. Record revision, commands, exit codes, selected jobs and limits in this PR.
7. Update the PR title/body around the implemented result. Merge only when the focused route and broader fallback cases are both demonstrated.

## Focused game evidence to preserve

Use the behavior touched by the diff to choose suites, rather than always running all of these:

| Behavior | Existing suite |
| --- | --- |
| Command lookup avoids context capture | `tests/unit/test_scene_challenge_command_lookup.gd` |
| Live Challenge preparation | `tests/unit/test_scene_playable_preparation.gd` |
| Real reading owner and detached saved-anchor validation | `tests/integration/test_scene_owner_composition.gd` |
| Publication acknowledgement and single commit validation | `tests/unit/test_scene_checkpoint_ack.gd` |
| Native held control | `tests/integration/test_scene_playable_native_control.gd` |
| Control continuation | `tests/unit/test_scene_control_continuation.gd` |
| Played-board checkpoint and explicit Save | `tests/integration/test_scene_first_reveal_connected_create.gd` |
| Exact selected board after fresh-process Load | `tests/integration/test_scene_first_reveal_connected_load.gd` |

The live command/preparation/composition group ran with `DWM_SCENE_READING_FIXTURE=1`. Native control and continuation each require their own process. Acknowledgement uses production registration. Creator and loader use the synthetic registration and share the same isolated test root, in separate subprocesses of one runner. Separate tool containers may reuse numeric PID 2, so PID inequality across such containers is not proof of process identity.

Common command: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gconfig= -gtest=res://<suite> -gexit`, with fresh `XDG_DATA_HOME` and `DWM_TEST_ROOT` below `.godot/phase2r_tests/`. Import once before running suites. Check actual test/assertion counts; zero selected tests is not acceptance.

The authored title-to-Day1-result probe from PR #246 was temporary, not a committed suite. Its reproduction is in the PR. Inspect an existing suitable journey before committing a minimal reusable probe if the new job needs one; do not silently substitute a full-week run.

The old connected creator wrongly expected live publication to write autosave. The repaired creator saves explicitly, and the loader expands the compact saved checkpoint before comparing the native boundary. Other historical failure-injection scenarios were not repaired or qualified. Do not restore obsolete autosave behavior to satisfy them.

## Acceptance cases

- Historical #246 scope selects the focused route, including its accompanying handoff/lint/test changes.
- The bounded runtime slice alone and with reviewed prose select the same game coverage.
- Docs-only changes do not start game checks.
- A nearby saved-validator edit or unrelated runtime method cannot use this narrow route.
- DTL preflight and main validation agree for the supported slice; genuine DTL/content changes keep their authoring checks.
- Every expensive unrelated job is demonstrably skipped, not merely the main test matrix.
- Full fallback reports its reason and unmatched scope before expensive setup.
- Existing coverage categories retain their intended behavior.
- Final candidate has a passing focused Actions run with the relevant tests actually selected.

## Limits and next-session guidance

No game behavior changes, new injection tests, broad lint framework, speculative security work, blanket validation removal or timing thresholds. Selector regression tests are the useful guard here; the command-lookup lint already shipped in #246.

Optimize checkout/download and job dependencies only when measurements identify additional cost after routing is corrected. Shorter code does not prove lower latency. No Windows/render/audio qualification or in-game speedup claim is made for this CI change.

Suggested starting request: “Continue this draft's CI coverage-selection handoff. Inspect current master and reproduce the historical #246 fallback, then implement the smallest shared classification and focused runner. Use lightweight checks and report the selected jobs before launching CI.”
