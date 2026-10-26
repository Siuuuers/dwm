# Trusted runtime performance results — 26 October 2026

## Start here

PR [#110](https://github.com/Siuuuers/dwm/pull/110) is merged.
Master merge: `ff5b327a5433867f33c85644e3173d15cdef01d0`.
Tested candidate: `baa4b41cf5c852c144a9537150763462dcc73995`.
Fetch current master before further edits. Do not repeat this implementation.

This handoff and the raw evidence are retained on
`codex/trusted-runtime-evidence-20261026`. This is an evidence branch, not another
product change to merge. Use current master for product work.

Read AGENTS.md, CLAUDE.md and relevant owners. Run Godot and Windows execution
only in cloud CI. Local static checks are permitted.

## Latest user priority

Prioritize reading speed. Trust shipped content after CI checks. Remove redundant
validation, hashing, comparisons and copies. Keep the implementation small.
The user explicitly deferred audience-edited DTL rejection and soft-error behavior.
Do not make that feature a prerequisite for further speed work.

The user permits direct PR merges after verification. Use independent agents for
disjoint investigations while cloud tests run. One coordinator owns integration,
publication and evidence. Start a new session when a completed batch gives a clean
baseline and a narrow next target; do not stop in the middle of a useful job.

Current save progress and supported story-update behavior remain required. Do not
silently reset a run or replay consequences. Do not add speculative recovery systems.

## Implemented

- The manifest owns one frozen registration and its derived tables.
- Runtime consumers reuse those tables by exact owner identity. Arbitrary inputs
  retain their boundary checks.
- Snapshot, New Acc, journal, scene and audio paths avoid repeated registration
  copies. Audio reuses the prepared fingerprint and catalogue.
- Session configuration reuses prepared semantic data. Its first compilation loop
  shares one local parse per DTL across entries. Native resources are not retained
  in the global semantic cache.
- Repeated physical-source scans and runtime story-hash comparisons were removed.
- CI performs strict authored-story validation inside the exact Windows release pack.
- No edited-DTL skip UI, native skip guard or new recovery manager was merged.

## Verified result

See the [retained report and raw evidence](../evidence/phase_2r/trusted_runtime_20261026/README.md).

| Complete journey median | Baseline | Candidate |
|---|---:|---:|
| Fresh New Acc click to complete caption | 14.638 s | 6.428 s |
| Retained New Acc confirmation to complete caption | 15.149 s | 6.542 s |
| Load click to complete saved caption | 7.701 s | 3.150 s |

All 12 paired comparisons improved. Full bundle validations during those actions
fell from 36/36/23 to zero. Four samples per case describe one Windows cloud runner;
OS caches were not controlled. Do not promise these times on player hardware.

[Windows run 40285967588](https://github.com/Siuuuers/dwm/actions/runs/40285967588)
passed 61 jobs, with one expected archived-comparison skip. This includes exported
pack validation, current save/content-update tests and rendered journeys.
[Timing run 40285967600, attempt 2](https://github.com/Siuuuers/dwm/actions/runs/40285967600/attempts/2)
passed all 24 processes, state/source-save checks, package checks and 64 screenshot
checks. All screenshots were visually reviewed.

Timing attempt 1 reached its expected caption and exited zero, then reported two
resources still in use at shutdown. The same signature occurs in the earlier
[desktop investigation](y-desktop-dependency-investigation-20261025.md). The cause
is not proven. The unchanged rerun passed. Do not describe this as a leak fix or
hide the failed attempt; its logs and result are retained with the evidence.

## Next primary outcome: reduce the remaining Load pause

Restore the same caption and gameplay state with less repeated snapshot work.
Candidate Load takes 3.150 s, with a median longest frame gap of 3.087 s.
All four samples perform seven snapshot validations. The median sum per run is
1.348 s: 1.040 s pre-semantic and 0.294 s semantic work are nested inside it.
These values do not prove that all seven calls are redundant.

Start at `scripts/domain/run/RunSnapshotSchema.gd`,
`_validate_scene_observed_body` (about line 951 in the tested candidate).
Trace callers through `SaveDocumentSchema.gd` (about line 512), `SaveManager.gd`
(about line 2902) and restore participants. Add temporary caller labels and
subphase timings around lifecycle, Contacts, board, audio and reading checks.
Use an observation overlay rather than a new production diagnostics framework.

Remove only work proven redundant for unchanged input and owner state within the
same operation. Do not add a cross-operation cache or caller-supplied trust flag.
Configuration and compilation costs overlap these phases; do not add them.

Required checks:

- Restore the same caption, board, inventory, money and choices.
- Do not replay consequences.
- Reject malformed current save fields before adoption.
- Refuse a changed selected slot.
- Preserve the current run if preparation fails.
- Compare complete Load time, longest frame gap and validation counts under
  matched cloud conditions, using current master as the new baseline.

For New Acc, `_resume_scene_new_run` in SaveManager (about line 656) takes 2.905 s.
Its nested `_settle_new_run_pair` (about line 1124) takes 1.552 s. Settlement
includes journal, issuer, Autosave and Profile work. This does not establish that
disk I/O is the cause. `_prepare_scene_new_run_decision` takes 2.172 s and includes
the first participant-plan preparation. Do not sum parent and child phases.

## Independent startup investigation

Launch to the observer entering the tree still takes 6.927 s fresh, 5.235 s
retained and 5.169 s for Load. The first constructor starts at about 2.731 s fresh
and 0.986 s retained/Load. Larger later gaps precede ApplicationBootstrap (about
1.27 s), GameState (0.89 s), and ProfileManager, DialogicBridge and SceneRouter
(about 0.45 s each). Constructor bodies themselves take microseconds. These gaps
include dependencies, member initialization and engine bookkeeping; they do not
prove disk, GPU or script compilation as the cause.

A small independent experiment can keep one exported build and duplicate the same
74-file seed. Keep copy A intact. Remove only the 64 observed shader-cache files
from copy B. Verify that the ten non-cache files remain byte-identical. Run
AB/BA/AB/BA retained New Acc and Load journeys. Preserve complete Title, caption,
frame-gap and constructor measurements. Do not change the renderer, fonts or
product code. This tests cache presence; it does not assume the cache is the cause.

This completed merge is a useful session boundary. The next session can focus on
the Load-validation investigation while the startup experiment runs independently.
