# Atomic Profile caption-History union prerequisite

Source: `1cce6ff5424c3438e45b311407216a24fb144d59`. Tested merge: `7936c4be314e2b2e1b5d95df86a1cb4ca4902409`, with master parent
`dded76aee2e85aeea94f65218de043b1f4fdce7b`.

Accepted bounded storage prerequisite. Run 168 passed all 26 jobs, including
the retained-history producer, four comparisons and aggregate. This is not
production replay integration or a new performance-improvement claim.

## Observable outcome and ownership

An admitted batch of exact caption descriptors updates only
`witnessed_caption_variants` and `visited_line_ids` in one existing Profile
transaction. Every member is validated before candidate construction or storage;
an invalid suffix cannot install a valid prefix. Duplicate descriptors coalesce.
ProfileManager remains the only persistence/publication owner, using the existing
CaptionWitnessLedger admission and atomic `_commit_profile_candidate` path.
The existing per-caption canonical method is unchanged. No schema, migration,
storage journal, run checkpoint or recovery framework changes.

`value.history_added` is true only after successful durable addition of a
previously unvisited base line. A new exact variant of an already visited base
line still commits, but returns false. Duplicate/empty batches return unchanged
without writes, revision increments or witness/history signals. Guard,
initialization, fatal-custody and expected-revision checks precede those no-ops.

## Concrete failure evidence

Seven appended tests reuse the existing caption-witness fixture and real
JsonFileStorage with FakeFileOps. They cover the complete detached union,
nonallowlisted-field equivalence, fresh Profile restart, publication only after
whole-batch durable adoption, duplicate/empty silence, exact-variant-only status,
invalid late members/registries, stale revisions, restore custody, proven write
refusal and indeterminate promotion.

The refusal test prevents actual Profile file writes and proves unchanged live
Profile, revision and durable bytes, then permits one fresh batch. The uncertainty
test refuses transaction-marker cleanup after the whole candidate has been
promoted. It verifies the retained marker and complete candidate on disk, unchanged
live Profile, no success publication, and fenced changed/duplicate/empty requests
and unrelated preference writes even after the injected cleanup refusal is removed.
That is a reachable storage result, not a fake success or synthetic storage reply.

Independent source/test reviews finished before cloud acceptance. No Godot or
PowerShell execution took place locally. The preparation run regenerates caller
inventories in GitHub Actions; the final workflow restores strict comparison and
the unchanged full test matrix. Inventory deltas are reviewed separately and do
not introduce another public-facade ownership scheme.

Run 168's downloaded Settings XML verifies 368 cases, including all 17 existing
and new caption-witness cases (seven new atomic-union tests), with zero failures,
errors or skips. Public-contract XML verifies 11 cases with zero failures/errors/
skips. Both strict generated inventories equal their committed bytes. ZIP digests
were verified before extraction. The preparation run was superseded after its
public job passed and the generated inventories were adopted; its unfinished
jobs are not counted as acceptance evidence.

The inventory delta is exactly eight existing Profile caller locations shifted
by 33 lines, plus the new test's configure_mutation_gate call in each inventory.
No public-facade declarations or dispositions changed. The full strict workflow
matches the previously accepted workflow byte-for-byte; no diagnostic flag remains.

## Explicit remaining boundary

Registry membership is not proof of actual presentation. This is the storage
prerequisite only: replay does not call the method yet, and no player-facing
History notice or whole Gallery completion is claimed.

The next integration must bind a fresh existing NarrativeCaptionLedger to an
explicit fixture-only exact-signature/collectable-line admission within the
existing reached-replay owner. Canonical SoloReadingSession admission requires
causal fields absent from historical signatures; those must never be fabricated.
Use the lawful FrozenReplayContext and existing runtime binding/frontier plus
visible-caption acknowledgement. Publication alone is insufficient. Keep canonical
Save/Next/per-line-write denial, retain immutable session-bound presented receipts,
and preserve custody until the atomic merge result is determinate. Revalidate the
exact session after synchronous Profile publication before releasing or reporting.
Do not implicitly make canonical catalogues collectable production replay sources.

The existing WitnessedCaptionLayer mounts and configures Bridge transport without
requiring a canonical reading session, so its accepted-visible-caption callback is
reusable. Bridge's publication-error path currently assumes a canonical session
and also needs explicit admitted-archive handling. Local caption review is distinct
from the full History overlay: the latter is gated by SceneRouter and
ProductionPauseController canonical checkpoint/route capabilities. Archive History
therefore needs narrowly qualified read-only admission through existing owners;
do not add Gallery to canonical Pause routes or fake a canonical reading session
to expose that overlay and accidentally admit Save/Load/Next.

Authored exact replay/content, native accessibility and the larger Gallery release
contract remain open. No Bead is closed; the retained export does not claim live
Dolt synchronization. The records-only descendant is not independently engine-tested.

## Next rendered proof to reuse (not implemented or accepted here)

Use the existing EndingReadingTimelineCatalog/EndingReadingFixture three-caption
ending fixture and its registered exact descriptors. Seed one lawful reached
special.full signature, mount the real Gallery/replay/Bridge/caption layer, and
safely exit before the last caption. Reuse the reading-rail journey's mounted
caption/input helpers and ending journey's visible-leaf checks. Runtime line
arrival alone is not sufficient: assert a visible leaf and its accepted receipt.
Before exit Profile remains unchanged; after determinate success exactly the
acknowledged set merges once, while the unseen caption remains absent. Duplicate
replay must be silent and write-free. Failed start creates no merge; refusal and
uncertainty preserve the existing state/custody guarantees. Reuse this increment's
storage tests; do not bypass visible acknowledgement with direct fixture writes.
