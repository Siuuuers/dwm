# New Acc attribution — 25 October 2026

## Current state

The New Acc measurement is complete. Four cloud exported journeys passed.
No runtime optimization was merged. The desktop deferral remains experimental;
see [its result and unresolved shutdown error](y-desktop-dependency-investigation-20261025.md).
PR101 and PR102 preserve the earlier evidence on master.

Product baseline: `47234a3395a4566e840140f1849da55a65d15521`.
Diagnostic controller: `f0921d50d3e8debdcbf7f97cc0679b63d77d895c` on
`codex/startup-attribution-20261025`.
[Cloud run](https://github.com/Siuuuers/dwm/actions/runs/40207210393): 40207210393.
All engine execution used cloud Windows runners. Do not run Godot or PowerShell
locally. The diagnostic workflows are manual-only again.

The overlay wraps synchronous owners and adds two call-site observations. It
preserves function signatures, return values, awaits and storage calls. Removing
only these hooks reconstructs the exact baseline SaveManager source. The probe
loads SceneValidationTiming after Title and opens its scope immediately before
the real New Acc click. It closes the scope after the complete first caption.

## Measured owner costs

Seconds, each cell lists pair 1 / pair 2:

| Owner phase | Fresh | Retained | Responsibility |
|---|---:|---:|---|
| Prepare decision | 4.491 / 4.401 | 5.634 / 5.882 | Identity allocation, first reading checkpoint, save candidate validation, plans and durable intent preparation |
| Commit intent | 0.772 / 0.720 | 0.785 / 0.872 | Commit and validate the continuation intent |
| Resume transaction | 7.403 / 7.341 | 7.227 / 7.776 | Settle persisted state, reconstruct plans and start scene activation |
| Settle pair, inside resume | 3.940 / 3.713 | 3.690 / 4.017 | Settle identity, autosave and profile, including validation |
| Initial plans, inside decision | 1.642 / 1.742 | 1.932 / 2.025 | Prepare participating owners without publishing the scene |
| Repeated plans, inside resume | 1.767 / 1.886 | 1.838 / 1.887 | Reconstruct plans from committed material |
| Apply transaction, inside resume | 1.026 / 1.020 | 1.026 / 1.115 | Apply participants and initiate activation |

Do not add child durations to parent durations. Pending scene activation is an
expected intermediate result; records retain the raw result code as well as the
normalized diagnostic success verdict.

The maximum observed frame gap is 8.634–8.738 s fresh and 8.598–9.213 s after
retained confirmation on this runner. Prior runs had roughly 13-second gaps.
These are different runners and diagnostic overlays, not a measured speedup.
The full button-to-caption scope includes normal reveal and retained consent
dwell. Keep those separate from synchronous owner intervals.

## Repeated work

| Observation | Fresh | Retained |
|---|---:|---:|
| Reading-session configuration calls | 90 | 96 |
| Compiler calls | 8,300 | 8,853 |
| Inclusive configuration time | 3.818–3.846 s | 4.209–4.474 s |
| Inclusive compilation time | 2.110–2.139 s | 2.300–2.332 s |
| Bundle validation calls | 36 | 38 |
| Inclusive bundle validation time | 2.338–2.443 s | 2.525–2.614 s |

Compiler calls include cache hits. Cache hits still check source bytes, encode
arguments and return detached data. These counts are not physical parse counts.
The existing registration parse reuse is already merged. Do not implement it again.

Settlement alone contains 28 configurations and 2,581 compiler calls in every
process. Its time must not be called disk-write time. The initial and resumed
planning passes each contain 13 configurations and 1,198 compiler calls.

The snapshot-detail arrays and snapshot subcategory counters are empty in all
four records. They cannot identify the largest snapshot substep. Treat this as
an instrumentation coverage gap. Do not infer zero snapshot-validation cost.

## First bounded code experiment

Test removal of the second node deep copy in
`SoloReadingSession._configure_scene_observed_body()`:

```gdscript
compiled_nodes[programme.entry_id] = compiled.value.nodes
```

The current code calls `compiled.value.nodes.duplicate(true)` at this point.
The independent ownership audit supports the narrow change:

- On a compiler cache hit, the compiler returns `cached.results[key].duplicate(true)`.
- On a cache miss, it builds fresh node dictionaries, stores a deep copy, and
  returns the original detached result.
- Translation-enabled compilation builds fresh results and bypasses cache reuse.
- Compilation failure returns before the candidate catalogue is installed/frozen.
- Registered node fields are primitive data, not native playback resources.
- Freezing the session's owned nodes therefore does not freeze the compiler cache.
- `_fork_scene_configuration()` already shares frozen nodes intentionally.

Do not remove the compiler's own cache-detachment copy. Do not claim a speedup
from the source audit. This second copy is outside compiler timing; configuration
also performs metadata copies and freezing, so the whole difference between
configuration and compilation is not its cost.

Required checks before accepting this candidate:

1. Configure cold-cache and warm-cache sessions. Check identical frozen nodes and checkpoints.
2. Fetch a compiler result after those sessions freeze their nodes. Mutate its
   array and nested dictionaries. Both sessions and a later compiler result must
   remain unchanged.
3. Keep existing compiler-cache physical-change/deletion, translation and
   argument-isolation checks in `tests/unit/test_scene_compiler_cache.gd`.
4. Run matched complete New Acc comparisons, with fresh and retained profiles
   in both orders. Measure the entire operation and maximum frame gap.
5. Keep exact rendered caption, active session, settled journal and strict
   shutdown-error checks. Do not suppress the earlier intermittent failure.

This is the smallest supported next experiment. If it has no useful effect,
retain the result and stop promoting it as an optimization.

## Larger alternative: same-day native nodes

Only consider this after the bounded experiment or a separate decision to take
on its wider tests. Add an optional selected entry to `configure_scene()`, while
preserving the complete manifest, catalogue, caption registry, scene bundle and
registration fingerprint. Filter only native compilation to all entries with
the same authenticated `story_days` value. Fixtures without day metadata must
retain the current full-configuration behavior.

The production map has 92 programmes: Day1 has 10, Days2–6 have 12–13 each, and
Day7 has 20. Reducing Day1 native compilation from 92 to 10 calls per selected
session does not imply the same percentage reduction in elapsed time.

Known-entry callers include checkpoint projection/expansion, snapshot reading
validation, current initial-checkpoint construction, saved-reading preparation
and event-anchor validation. Keep `_prepare_scene_entry()` on full configuration
initially: it restores a source reading and then admits the target. A cross-day
transition needs both source-day and target-day nodes.

History needs all current-day nodes plus cross-day metadata for finding the
day's start. Contacts must restore its parent reading correctly. Gallery uses
the complete passage metadata. Check Day3 fresh Load/History, both partner routes,
challenge outcomes, cross-day staging, Contacts return and Gallery replay.
Missing or changed selected content must fail before progress changes, including
on compiler-cache hits. Preserve fingerprints and saved checkpoint bytes.

Initial manifest registration still physically checks all seven files. This
alternative does not by itself make bootstrap load only Day1. Changing that
safety boundary is a separate project.

## Responsiveness boundary

`SaveManager._resume_new_run(..., responsive)` branches scene New Acc directly
to `_resume_scene_new_run()`. The latter settles with `responsive=false` and
bypasses the older cooperative frame-yield path. Decision preparation is also
synchronous. Yields may improve responsiveness, but they do not remove work.
Do not add a yield inside an atomic write or between unchecked mutation steps.

## Evidence and continuation

[Evidence index](../evidence/phase_2r/newacc_attribution_20261025/README.md).
The original compact ZIP, 55-member manifest and exact phase/counter summary are
retained. All ten image hashes pass. The coordinator reviewed the five unique
images. No cloud job remains pending for this investigation.

The investigation is at a clean boundary. A fresh session can start the narrow
node-copy experiment using this handoff, without repeating startup/renderer/menu
or font experiments. Read current master first, then create a product worktree.
Keep the diagnostic branch separate. No user design answer is needed for this
first experiment; use the existing save and reading contracts.
