# Trusted save: show the playable scene first

> Current status: [accepted Load and remaining work](al-trusted-load-accepted-history-next-20261027.md#brief-review-of-aa-through-ak).
> Read that review before using the implementation instructions below. Older status and policy statements are historical where later decisions replace them.

Date: 2026-10-27, Hong Kong time.
Status: Approved next-session design. Not implemented by this documentation update.

## Start here

Read current master and root AGENTS.md before editing. PR 117 is merged at
`63114b5649d2191d5fb189aa73019a880f6abb12`. See the
[accepted evidence](aj-new-account-snapshot-validation-20261027.md).
This record supersedes earlier instructions to retain full Load validation,
public/private preparation comparison, or a Load-applying gate where they conflict.
Do not treat old refusal tests as the current product contract without review.

## Observable outcome

Load shows the correct saved dialogue and art sooner. The first available input
acts on the restored Run. The screen must not show a new caption while its controls
still operate on the previous Run. Measure both first correct drawing and first
responsive interaction. Do not hide the same delay in the next frame.

## User decisions

- Trust saves produced by the game. Do not validate gameplay consistency to support
  manually edited or inconsistent saves. Such edits are unsupported.
- Remove the three full snapshot validations from ordinary current-save Load.
  Do not merely move them after the scene appears.
- Keep the small file boundary: read the save, decode JSON, and check the supported
  save-format version. A file-read or decode failure can return a simple error.
  No repair system or extensive edited-save diagnostics is required.
- Parsing converts file text into dictionaries, arrays and scalar values. It does
  not prove gameplay consistency. The current single JSON document is decoded as
  a whole. That does not require compiling all DTL, opening apps or rebuilding History.
- Do not keep or add a separate "Load is applying" gate. The user explicitly rejected
  that proposal. Simplify the existing asynchronous activation path accordingly;
  deleting lock calls alone is not evidence that the playable state is coherent.
- Remove unnecessary prepared-data acceptance/comparison work. Keep one clear owner
  of the selected save. A private preparation selected by a token is an implementation
  option, not a requirement to add another token system or manager.
- Prioritize the current dialogue and art. Defer unrelated passages, unopened apps,
  History reconstruction and future dialogue variations until needed.
- Resolve the current text variation before drawing it. Restore an active visible
  board before allowing actions that depend on it. These are parts of the current scene.
- Deferred work must not cause a large main-thread stall immediately after drawing.
  Prefer lazy work or bounded work. Do not assume a deferred callback is background work.

## Preserve existing content compatibility

The user already settled this in
[the reading handoff](aa-reading-startup-simplification-20261026.md#content-and-saved-progress).
Do not ask the user to choose it again.

1. Keep stable line IDs across wording edits.
2. If the saved line exists, resume there using current DTL.
3. If it was deleted, use the latest saved major checkpoint on the actual route.
4. If that checkpoint was deleted, use the start checkpoint of that day's DTL.
5. Preserve saved gameplay, choices, Challenge outcomes and route. Never reset the Run
   automatically. Do not replay old consequences or apply new defaults retroactively.
6. Updated unread content uses current DTL. Do not retain old full DTL versions.

Save-format compatibility and content compatibility are different. A version check
only tells the game how to interpret the save structure. It cannot locate a deleted
line when both builds use the same save-format version.

This compatibility behavior already exists in `SoloReadingSession.normalize_player_checkpoint()`,
called by `RunSnapshotSchema.normalize_scene_content()` through `SaveMigrations`.
Separate useful position resolution from surrounding consistency checks. Do not delete
all normalization and thereby remove the agreed fallback. The current implementation
also reconstructs route/history material; audit what is needed before first drawing.
Removing an entire day/start remains an exceptional authoring case with no invented
reset policy. Arbitrary branch rewrites are not guaranteed compatible.

## Current measured Load path

Evidence: run `40367674644`, tested head `3ddce8a80aaa16630fca3bb622b9fe38787fe120`.
Four candidate Load samples. The median click-to-complete-caption time is 1771.574 ms.
Application launch and save-menu browsing are outside that action time.

| Full snapshot pass | Current caller | Median |
| --- | --- | ---: |
| Saved-document admission | SaveDocumentSchema._validate_bundle | 160.375 ms |
| Route-context derivation | RunSnapshotSchema.derive_route_restore_context | 156.770 ms |
| Live Run application | GameState._apply_run_snapshot_silent | 160.813 ms |

Each calls RunSnapshotSchema.validate/validate_scene. The second is not ordinary
RunRestoreParticipant preparation: that preparation already reuses admitted input.
The phase counter increases between audio preparation and route preparation, matching
`derive_route_restore_context()`'s full validate call. Application adds the third.
The former fourth pass at journal installation was removed in PR 117.
Median combined validation time per sample: 476.342 ms, about 27% of the action.

Each pass spends roughly 70-71 ms on owner-state checks, 50-53 ms on reading checks,
and 33-36 ms on semantic checks. Primitive normalization takes about 0.3-0.4 ms.
That last figure is NOT a measurement of JSON parsing or content normalization.

| Current inclusive scope | Median |
| --- | ---: |
| SaveManager._prepare_restore | 841.635 ms |
| Participant preparation inside it | 254.850 ms |
| Commit prepared restore | 227.895 ms |
| RunRestoreParticipant.apply_silent inside commit | 161.101 ms |
| NarrativeRestoreParticipant.prepare | 90.923 ms |
| NarrativeRestoreParticipant.apply_silent | 53.620 ms |

Parent and child spans overlap. Do not add them together.
Load records 92 programme-compilation calls: 281.448 ms total median.
It records 16 reading-configuration calls: 314.863 ms total median, including compilation.
These are not 92 independent file reads. `SoloReadingSession.configure_scene()` shares
parsing within a DTL and caches prepared configuration, but initial configuration loops
through all registered programme entries. Investigate selected-passage preparation.

Milestones from the click: route confirmed 1122.595 ms; narrative confirmed 1461.295 ms;
live session ready 1662.582 ms; complete caption drawn 1771.574 ms.
Those are cumulative timestamps, not independent CPU costs.

## Next implementation and acceptance

1. Trace ordinary Load from the actual UI through parsing, position resolution,
   owner installation and native caption drawing. Check current master for later work.
2. Establish one owner for the decoded selected save. Remove full semantic revalidation
   and unnecessary prepared-copy comparisons from this path under the revised contract.
3. Preserve position fallback while trimming normalization checks. Make current
   dialogue/art ready first; make unrelated work lazy. Simplify activation without
   retaining the rejected Load gate under another name.
4. Update tests that only enforce the retired edited-save policy. Preserve tests for
   normal game-produced saves, correct next input, current variation, visible board,
   changed-content fallback, no replayed consequences and unchanged persistent bytes.
5. Audit shared callers before deleting helpers. Do not remove unrelated save-writing,
   New Account or legacy-operation behavior without tracing the dependency.
6. Run Godot tests only in cloud. Compare complete exported actions on matched sources.
   Include first drawing and interaction responsiveness, not only validator counts.
   Review the implementation and callers before final acceptance. Direct PR merge is
   authorized after evidence supports the change.

## Other retained decisions

Global Profile does not own current Challenge boards or attempt progress. The Run does.
Load keeps current settings and global unlocks. It does not write restoration bookkeeping
or allocate new gameplay identity. An interrupted Load may simply close; the source save
remains for a later explicit Load. Do not add a new recovery subsystem.

Named presentation checkpoints/overlays are still a separate pending feature. Use the
existing art manifest. Save the checkpoint ID and ordered overlay labels. Restore directly.
Each art appears once; showing an active label or removing an absent label is a no-op.
Entering a new named presentation checkpoint clears all active overlays.

This session's final task is documentation only. The next session implements the policy.
