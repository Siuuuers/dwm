# Direct Load, New Account, and Settings Back

Date: 2026-10-26. PR: https://github.com/Siuuuers/dwm/pull/116.

## User decisions

- Use cloud Godot tests. Do not run Godot locally.
- The user permits direct PR merges after validation.
- Trust shipped dialogue. Handle missing or changed user-edited content at its boundary.
- Load restores the selected Run. Keep current language, settings, and global unlocks.
- Challenge boards and attempt progress belong to the Run, not Global Profile.
- Load must not write recovery progress or allocate new saved identities. A fresh
  process can load the original source again after interruption.
- Preserve shared creation records and identity storage. Remove only obsolete
  `scene_restore` journal records at startup.
- The latest overlay decision is **clear all active overlays when entering a new
  named presentation checkpoint**. This corrects an earlier keep-overlays answer.

## Implemented behavior

Current scene Load prepares the saved Run directly. The existing participant pass
applies it in memory. Input waits for both the mounted route and native dialogue.
Process-local activation state supports Pause Load. Load keeps the saved lifecycle
and uses current settings. Acknowledging the restored caption does not write new
Profile progress. Later normal reading and saving still work.

Current scene Challenge restoration reads the saved board and attempts. It does not
consult newer Profile progress. Older non-scene compatibility paths remain.

Changing language repaints the native caption. The paused caption anchor now
accepts the new reveal generation only when the native node, timeline instance,
timeline generation, and event still match. Back can resume that same caption.
A changed source still fails the existing custody check.

New Account builds its initial checkpoint through the existing runtime compiler
cache. Exact target, label, and opening-caption checks remain. Each account keeps
its own reading-session state.

Startup retires old scene Load records before shared journal admission. It retains
creation and legacy records, validates retained records, and uses atomic storage.
Failed cleanup can retry. A process-local successful-check flag and the admitted
document avoid extra startup reads. There is no persistent migration marker.

## Validation status

Runtime candidate: `89cc74a5f550cbeb9a47e3ebc1083760fee1b422`, tree
`db700e6e62ffeaa5c3c69ecdd943f4a8f9cd7ff4`.
Cloud run: https://github.com/Siuuuers/dwm/actions/runs/40352266909.
It passed 57 checks, including all 298 persistence tests, both process-kill points,
and the five-language Settings-to-Back journey. The API job failed because committed
inventories were old. Both generated replacements passed their own generation and
check commands. This commit records those exact generated files.

Final acceptance of the inventory/documentation commit is pending. Read the PR's
exact head checks for rendered desktop, Gallery, exported startup, and merge status.
No engine ran locally.

Matched comparison: https://github.com/Siuuuers/dwm/actions/runs/40352266790.
Evidence artifact `12664223388`; package artifact `12664102625`.
Evidence ZIP SHA-256:
`c43ac8863861f9809652e3f212bfbe6e05acfa5f4d27ed3d3b55c9fc9cbcee03`.
Baseline: master `0a3fe192f34c5ec1c1fa245d7db12a7ac2ad9bcf`.

| Action median | Baseline | Candidate |
| --- | ---: | ---: |
| Load click to caption | 2624.9305 ms | 2186.082 ms |
| Fresh New Account to caption | 2155.137 ms | 2091.4225 ms |
| Retained New Account, excluding consent dwell | 2029.214 ms | 2077.7285 ms |

Load improved in all four pairs, with a median reduction of about 16.7%. New Account
results are mixed: fresh improved, retained regressed. Do not claim an overall
New Account speedup. The compiler count fell from 93 to 92 in every New Account
sample. This proves removal of duplicate compilation, not a general timing gain.
The restored caption screenshot was inspected.

There are 24 exported journeys: four pairs per case, in AB/BA/AB/BA order on one
Windows runner. OS caches were not cleared. Each action starts a new process.
Retained New Account and Load use identical seeded user data. Four samples per
case are descriptive, not statistical certainty. A prior independent direct-Load
comparison also improved in all four pairs (run `40348921776`).

## Separate next feature: named presentation checkpoints

This feature is designed but not implemented in this PR. Existing presentation is
entry-owned. A later named checkpoint should own base art/background/music. Save
the checkpoint ID and ordered overlay labels. Resolve them directly on Load;
do not replay prior story actions.

Use the current art manifest as the owner. Keep one ordered overlay container.
Each art appears at most once. Showing an active label is a no-op. Removing an
absent label is a no-op. Entering a named checkpoint clears all active overlays.
Do not introduce another manager unless implementation proves it necessary.

Before implementing, inspect current master and the relevant authoring/schema
owners. Verify a visible player journey and exact save/Load presentation. Keep this
feature separate from acceptance of direct Load and Settings Back.
