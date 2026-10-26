# New Account snapshot validation

Date: 2026-10-27, Hong Kong time.

## Accepted work

PR 116 is merged at `292be5200d8ac25b5e3f5bafcc40725feca891d2`.
Its tested head was `1b6b492fa7247e78432b3bf09081ef6752eeea86`.
The merge has the same tree as that tested head.

- Current scene Load restores the saved Run and its identities in memory.
- Current settings and global unlocks stay current.
- Challenge boards and attempts belong to the Run, not Global Profile.
- Load writes no recovery progress. Both real process-kill tests passed.
- Settings Back works after changing language in all five supported languages.
- New Account reuses the existing dialogue compiler cache.

Final acceptance: 61 successful jobs and one intentionally skipped comparison job.
The separate comparison succeeded. All 298 persistence tests passed.
See https://github.com/Siuuuers/dwm/actions/runs/40354573498.

The final Load comparison changed median click-to-caption time from 2623.2975 ms
to 2149.4495 ms. All four pairs improved. This is about 18% in that cloud sample.
See https://github.com/Siuuuers/dwm/actions/runs/40354573437.
Evidence artifact: `12666116081`; package artifact: `12666380419`.
Evidence ZIP SHA-256:
`2e243f02ea5b267fbc8ee237791087d4179adc0a770c07609cb1fdfca09ca4ba`.
New Account timing changes in PR 116 varied between runs. Do not claim a reliable
overall New Account speedup from that PR.

## New Account investigation

PR 117: https://github.com/Siuuuers/dwm/pull/117.
Use its exact head checks and merge status as the final acceptance record.

One outcome owns this change: New Account reaches the same first caption sooner,
with a fresh Run and without changing prior saves or current preferences.

The measured path was:

1. `SaveManager._start_scene_new_run_in_memory` builds the initial snapshot.
2. `RunSnapshotSchema.build_scene` validates that snapshot.
3. SaveManager constructs a private journal reset from the validated result.
4. After applying detached participant plans, `CheckpointJournal.commit_prepared`
   validates that same snapshot again.

The diagnostic run used the same runtime and observer on both sources. It is an
attribution measurement, not an optimization result.
See https://github.com/Siuuuers/dwm/actions/runs/40356717090.
Evidence artifact: `12665624087`; package artifact: `12665609186`.
Evidence ZIP SHA-256:
`b3bff7be1de5707c2875418704df91facba77b71e3fcb9f5a5ee191ebf21f725`.

Each fresh New Account full validation took about 178–182 ms. Retained-account
validations took about 172–178 ms. Normalization and primitive traversal took less
than 1 ms. Owner-state and reading checks used most of the time.
Live input validation took about 78–89 ms and sees a different representation.
Keep that check. Do not add inclusive measurements to their nested child spans.

## Candidate ownership change

Only `memory_new_run` uses the existing private journal `_install_prepared` method
for its already validated reset. The production change is four added lines.

SaveManager is the sole producer of that reset. It retains the reset internally.
Participants receive detached plans. The journal installer keeps its existing
deep copies, sequence state, and proof clearing. Transaction rollback stays in
the existing owner.

Public `commit_prepared` still validates caller-supplied dictionaries. Load and
legacy creation keep their existing paths. There is no new manager, cache, proof
token, or general validation bypass.

The phase timers are test-only source overlays in the exported comparison harness.
They are applied equally to both variants and do not become shipped runtime code.
The observer records the source hashes before and after its changes.

## Candidate comparison

Runtime candidate: `4f32ccd8b96f618df531c7c68590419fec684545`.
Baseline: accepted PR 116 head `1b6b492fa7247e78432b3bf09081ef6752eeea86`.
Run: https://github.com/Siuuuers/dwm/actions/runs/40358476161.
Evidence artifact: `12666463526`.
Evidence ZIP SHA-256:
`3d75a57bf8c8d810b29a40185c2e667b6c86272dc73dece0e04d4e8d81c2d37f`.

| Action median | Baseline | Candidate |
| --- | ---: | ---: |
| Fresh New Account to caption | 2128.8525 ms | 1938.5595 ms |
| Retained New Account, excluding confirmation dwell | 2091.835 ms | 1927.813 ms |
| Load to caption, unchanged control path | 2197.091 ms | 2212.0975 ms |

All four fresh pairs and all four retained pairs improved. Median reductions are
about 8.9% and 7.8%. Every New Account sample changed from two full snapshot
validations to one. The Load control varied slightly; do not claim a Load gain
from this PR. PR 116's separate Load result is recorded above.

There are 24 exported journeys, four pairs per case in AB/BA/AB/BA order on one
Windows runner. Both variants use the same observer. Each action starts a new
process. Retained cases use identical seeded data. OS caches were not cleared.
These small samples describe these runs; they do not establish universal timings.
Use the PR's final head checks for acceptance after the generated inventory update.

## Further work

Read current master before another edit. Do not remove checks only because they
share names: live inputs and projected player snapshots can need different checks.
Measure a complete player action before accepting another performance change.
All Godot validation remains cloud-only.

Named presentation checkpoints and overlays remain a separate feature. Use the
existing art manifest as the owner. Save the checkpoint ID and ordered overlay
labels; restore them directly. Each art appears at most once. Showing an active
label or removing an absent label is a no-op. Entering a new named presentation
checkpoint **clears all active overlays**. This is the latest user decision.
