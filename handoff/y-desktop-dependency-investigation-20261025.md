# Desktop dependency investigation — 25 October 2026

## Decision

Keep the desktop deferral experimental. Do not merge it as a proven speedup.
The full non-verbose comparison did not complete. A later verbose diagnosis
passed, but it did not explain or fix the original shutdown error.

The preceding [startup attribution](x-exported-startup-attribution-20261025.md)
is merged in PR101. Its baseline runtime is still
`47234a3395a4566e840140f1849da55a65d15521`; master `8f371576f63a17ad1ab9ae66207cfda3ed94e83d`
adds records only. Do not repeat the earlier registration parse-reuse change.

## Candidate and scope

`ApplicationBootstrap._ensure_scene_desktop()` now has a disposable candidate:
load `ComputerDesktop.tscn` after live-session admission, return
`scene_desktop_unavailable` if no PackedScene loads, then instantiate it at the
existing location. The cached-instance early return stays unchanged.

The literal dependency audit identifies five paths removed from early loading,
about 102 KB of source. This is not a measured time saving. MainGameScene has an
alternate preload, but its route is dynamically loaded. Runtime cache checks
confirm both desktop scene and script are absent before Title in the candidate.

Candidate controller: `335fac8c46db73f48ec25d22424fe8690db0c385` on
`codex/startup-attribution-20261025`. Product code on master is unchanged.

## Results

[Run 40203205178](https://github.com/Siuuuers/dwm/actions/runs/40203205178)
planned twelve exported processes. It stopped after the fourth:

- Forward baseline fresh and retained passed strict checks.
- Forward desktop fresh passed strict checks.
- Forward desktop retained reached the exact completed first caption, settled
  the creation journal, and exited zero. Godot then reported ObjectDB instances
  leaked and `ERROR: 2 resources still in use at exit`. The strict check rejected it.
- Reverse order and exported Apps measurements were not reached.
- The independent uninstrumented Apps creator and fresh-process loader passed
  two tests, 130 assertions, zero failures or skips.

[Run 40204864050](https://github.com/Siuuuers/dwm/actions/runs/40204864050)
uses the exact same exported packages, checked against their original manifests,
with `--verbose` added. Controller: `6e1213bf2b4095652549d09c37c5311ad9b6bcef`.
All six diagnostic processes passed: baseline/candidate fresh and retained, plus
independent baseline/candidate Apps journeys. No resource-leak identity was
reported, because the error did not reproduce.

The Apps journeys use the visible Check Computer button at the ordinary first
caption. They verify the production desktop script, the same instance on reopen,
and unchanged scene, gameplay and reading checkpoint after closing.

| Verbose diagnostic observation | Baseline | Candidate |
|---|---:|---:|
| First Apps opening | 153.383 ms | 206.294 ms |
| Warm Apps reopening | 127.360 ms | 126.025 ms |

This is one order on one runner with verbose output. It exposes a possible
53 ms first-use cost, not a qualified performance result. Do not combine these
times with the earlier runner to claim a speedup.

## Unresolved shutdown error

The failing journey never opens Apps. Thus the lazy-load function and its local
PackedScene do not run in that process. The new local variable cannot directly
explain the observed leak. The probe's stored observations contain scalar data;
the one-shot input callbacks completed with correct counts.

Immediate shutdown after the first complete-caption post-draw observation may
interact with pending native callbacks. This is a hypothesis, not a diagnosis.
Do not add arbitrary waits, suppress error checks, or label it a renderer leak.
The same generic message occurred in the earlier rejected renderer experiment;
neither occurrence identifies the resource owner.

If this candidate is revisited, first obtain a reproducible shutdown/resource
identity, then complete matched non-verbose timing and first-use checks. A clean
verbose rerun does not erase the original failure.

## Higher-priority next measurement

New Acc has a roughly 13-second observed maximum frame gap, separate from normal
caption reveal. Trace the synchronous scene-New-Acc owner before optimizing it:

1. `_prepare_scene_new_run_decision`: identity allocation, reading checkpoint,
   candidate construction/validation, participant planning and durable intent preparation.
2. The journal `commit_intent` call.
3. `_resume_scene_new_run`: settlement, repeated participant planning and scene activation.
4. Its `_settle_new_run_pair(operation, false)` call.
5. `_prepare_scene_new_run_plans` and `_run_scene_restore_transaction`.

The current `_resume_new_run(..., responsive)` branches scene New Acc directly
to `_resume_scene_new_run`, which settles with `responsive=false`. It bypasses
the older cooperative-yield path. This identifies a freeze boundary, not the
duration of its operations. Adding yields alone does not reduce total work.

Use existing SceneValidationTiming counters for configuration, compilation,
physical proof, bundle validation and snapshot phases. Keep nesting explicit;
do not add inclusive children to parent totals. Emit observations once, not per
compiler call. Preserve exact coroutine behavior in the diagnostic overlay.

Repeated SoloReadingSession configuration still compiles/freezes all programmes.
A later selected-day candidate must keep complete metadata/fingerprints, all
same-day History nodes, Contacts parent frames and Gallery coverage. It would not
by itself make bootstrap read only Day1: initial registration still authenticates
all seven files. Missing or changed selected content must fail before progress
mutation. Do not bypass that safety boundary to obtain a faster number.

## Evidence and continuation

All diagnostic workflows are manual-only again. No engine ran locally. No product
optimization, renderer change, save migration or Steam deployment was made.
Retained data and verification limits are in
[the evidence index](../evidence/phase_2r/desktop_dependency_20261025/README.md).

No user design decision blocks the next timing investigation. Keep storage,
retry and recovery semantics intact. The next useful result is attribution of
the New Acc pause, not another broad dependency rewrite.
