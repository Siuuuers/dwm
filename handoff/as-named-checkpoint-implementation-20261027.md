# Named checkpoints and live reading

Date: 2026-10-27.
Implementation: [PR 133](https://github.com/Siuuuers/dwm/pull/133).
Read that PR for the exact accepted commit, cloud runs and merge status.
This record continues [ar](ar-named-checkpoint-autosave-plan-20261027.md).

## Player behavior

Ordinary current-Scene reading and intermediate actions update the live Run.
They do not create progress Autosaves. This includes choices, Contacts, passage
completion, board first Reveal, board configuration, shop and round outcomes.
Independent Profile persistence remains enabled.

An explicitly authored named checkpoint installs its base presentation, clears
the ordered overlay labels and saves the actual target Run at its first caption.
It preserves gameplay consequences, Contacts, History and applicable board state.
Manual Save captures the current live state between checkpoints.
Load restores the saved presentation directly and does not execute entry commands.

New Account does not Autosave, including when its first entry has a named binding.
It preserves existing save files. Closing or logging out discards unsaved progress.
[PR 132](https://github.com/Siuuuers/dwm/pull/132) separately implements Logout
without saving; its merge is `7ae0a089f9f93ed18d7f4401836057e0a61ca1e7`.

## Authoring decisions

The user selected reusable templates, not invented production checkpoint locations.
No production story entry is designated as a checkpoint by this change.
Until authors add bindings, the current story relies on manual Save.

Use [the presentation template](../tests/fixtures/presentation/README.md).
The existing art manifest owns three optional maps:

- `presentation_checkpoints`: checkpoint ID to existing art-scene and audio-plan IDs.
- `overlay_labels`: label to existing asset ID and normalized rectangle.
- `presentation_entries`: registered entry ID to ordered checkpoint/show/remove commands.

Use registered entry IDs, not raw DTL label strings. Split an entry at a registered
label when a change belongs inside a longer passage. An unbound entry carries the
active checkpoint's background and music forward. Existing entry presentation
continues to work before any named checkpoint is active.

Showing an active label and removing an absent label are no-ops. Active labels
remain ordered and unique. Load preserves that order without replaying commands.
Background remains part of checkpoint presentation; show/remove operate on overlays.

## Owners and saved data

`GameState` owns the optional current `scene.presentation` facts:
`{checkpoint_id, overlays}`. The art view consumes resolved presentation and owns
no second saved overlay list. `ArtManifest` resolves art and ordered labels;
`AudioManifest` resolves existing named audio plans.

Ordinary Scene acknowledgments explicitly describe live publication. They do not
fabricate durable checkpoint IDs. The named-arrival path uses the existing
SaveManager transaction, rollback and uncertain-commit handling before adoption.
Definite refusal retains the target for the existing Retry path.

Scene command and occurrence IDs use the existing deferred issuer path. They
verify immediately in memory. The existing storage hook flushes issuer provenance
before a real Save, and a failed flush refuses that Save. Do not delete the issuer
root or make saved allocation provenance rewindable.

Current Run9/Save9 documents may omit `scene.presentation`; existing saves retain
their old entry-based presentation. No format migration or version bump is added.
Legacy non-Scene routes retain their existing save behavior.

## Edited content and verification

Keep the accepted edited-DTL behavior from [aq](aq-trusted-reading-accepted-20261027.md).
Required missing checkpoint, base-scene, overlay or named audio-plan references
use the existing persistent content-error boundary. Invalid requested presentation
commands are checked at their authoring boundary. Unvisited command lists are not
scanned on every arrival. Optional missing image media keeps the existing art policy.

All Godot and exported-game execution stays in the cloud. The named-presentation
journey uses mounted native controls, actual audio playback and real save files.
It covers manual Save/Load, checkpoint arrival and Autosave Load.
At the user's request, this named-presentation journey includes no
deliberate storage-failure or edited-file injection. Existing transaction failure
handling and previously established regression coverage remain.
Tests must wait for mounted input admission, not only adapter line completion.

The matched comparison separates Load, ordinary captions, passage transition and
complete manual Save. It counts actual lower save calls and storage paths, checks
unchanged Autosave bytes and retains paired outcomes. Profile writes are reported
separately. Named-arrival timing belongs to its dedicated authored journey; the
baseline has no equivalent named-presentation feature.

Use the final PR evidence, not superseded diagnostic failures, for acceptance.
Do not add overlapping phase durations or infer a universal speedup from fewer calls.
Further registry-initialization work requires its own measured complete-operation
comparison; it is not part of this implementation.

## Next measured investigation

The current registration contains 1,666 captions across 92 entries.
`NarrativeCaptionLedger.initialize` revalidates and copies the caption registry,
then rebuilds three lookup dictionaries. Existing Scene configuration already
caches immutable admitted registration data, while each ledger still needs its
own mutable encountered History.

Existing registry-lookup timing belongs to a different History helper and does
not isolate this initialization. Measure ledger validation/copy, index creation
and History restoration separately in the existing complete Load, caption and
passage journeys before changing ownership or caching. Keep manually edited
registry validation and end-to-end drawing/input evidence. No savings estimate
is established for this follow-up.
