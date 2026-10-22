# Ending validation source audit — run39745466691

## Conclusion
The two growing fields do not isolate metadata handling or cheap journal composition. Both include full Run9 validation of every recovery-journal bundle through `SaveDocumentSchema._scene_journal_error()`. Their names conceal a substantial semantic validation boundary. The next smallest observation should split those existing SaveDocumentSchema regions and measure the individual journal-bundle validations, retaining all existing calls, ordering, results and proof checks. This is a source-backed candidate explanation, not measured attribution or an optimization proposal.

Configuration/compilation aggregates do not explain the whole cost: configuration is roughly 0.28 seconds and compilation roughly 0.25 seconds per prepare/commit; those values are inclusive/nested, not additive. Prepare totals grow roughly 3.0/3.7/4.2 seconds. `document_schema_metadata_us` grows 947428/1627269/2112682 microseconds; commit `outgoing_schema_compose_proven_journal_us` grows 983134/1667485/2066101 microseconds. Current-bundle validation remains near 1.0 seconds. Each prepare reports two journal proof hits, no misses, and `document_schema_journal_proven=true`; each commit reports two history bundles. Fixed journal cardinality does not mean fixed contents or validation work.

## Exact source custody
Audited product: `0b9095e5c63275bc4721cd257413d286bcd958b0`. Original `preparation/import/before.json` records this HEAD and the following source hashes. Existing local audit text was recovered to those exact bytes (one added final newline removed where needed), then SHA256 verified against the original cloud receipt. Exact copies are in `source-audit-inputs/`.

| Source | Git blob | SHA256 |
|---|---|---|
| scripts/infrastructure/save/SaveDocumentSchema.gd | 44f7ebcb05d4b3fd0984018a8ac272999be67791 | 9d8864e32e4fa8cead3422452cbd3edd1c3eaada1b352ff987d9d27ed1299c7e |
| scripts/domain/run/RunSnapshotSchema.gd | 1759efa35a07df81bd39a256490604be1356e488 | 735025bedba926b9dbc3eee4df86df55d7efaca72b9adf8d50c30d8958836701 |
| scripts/application/run/SaveManagerCheckpointPort.gd | 9306b21bd1e92e1c81c25a709c89470b4e2d8179 | 09210b048a1a4c06d70b27ead984eba3415df70caef32780f11b3346fedc6e0e |
| autoload/GameState.gd | ca7fccac2344c9d59b21e101d5ac8930540681e3 | c3b9949ba09bf1a47969afd73daf835645bb7b4eb494d91f19a6f7e222917c4d |

## Timer ownership and covered operations

`SaveManagerCheckpointPort.prepare()` calls `SaveDocumentSchema.build()` with the current candidate, projected earlier journal and retained normalized document proofs. For this call `saved_time` is explicitly `{}` (port lines266–268).

`SaveDocumentSchema.build()` resets its phase tick immediately after composing the document (line105). The later field named `document_schema_metadata_us` spans:

1. `_journal_family_error()` (Save8/Run9 family protection; returns immediately for Save9).
2. `_scene_proof_error()` when proven: normalize engine text, normalize integral floats and compare each journal entry with its corresponding proof.
3. `_scene_journal_error()` for Save9: revalidate every journal bundle, then enforce family/run/content/registration identity, distinct checkpoint IDs, and recovery sequence strictly before current.
4. Optional saved-time normalization/validation. This specific prepare supplies empty saved_time, so that optional branch does not explain its measured ~0.95–2.11 seconds.

`_validate_document()` resets its tick after composing the current bundle (line260). In the proven outgoing branch, `outgoing_schema_compose_proven_journal_us` spans `_scene_proof_error()`, detached journal composition (`_proven_entries()` for normalized proofs, otherwise engine-text normalization), family checks, and the same `_scene_journal_error()` full validation. It is therefore not a measurement of copying alone.

`_scene_journal_error()` (lines318–335) calls `_validate_bundle(raw)` once per journal member. `_validate_bundle()` (lines395–407) checks exact bundle shape and checkpoint kind, then calls `RunSnapshotSchema.validate(snapshot)` and uses its returned candidate. Even normalized retained journal proofs enter this Scene-specific owner validation. Existing fast-path comments about avoiding old generic journal walks do not authorize removal of these later Scene checks.

## Remaining inclusive work and obligations

`RunSnapshotSchema.validate()` selects the installed registration and delegates Run9 to `validate_scene()` (lines139–147,792–871). Its work outside the measured configure/compile wrappers includes normalization, primitive checks, lifecycle validation, scene assignment, Contacts receipts, board/consequence restore validation, transaction IDs, scene receipts, audio, reading restore and Frozen reading validation. It then hashes/detaches snapshot and registration, calls the privately installed semantic owner, and rehashes to reject mutation. These operations have not been individually timed by this run.

The semantic call is `GameState.validate_scene_snapshot_semantics()` (lines4250–4282). It validates authenticated receipts again in its live-owner context, reads the physical Profile assignment, validates Profile references, derives/validates Frozen frames, and joins authenticated commands to retained reading anchors through the scene bridge. These are candidates for later subdivision only if the journal-bundle timing establishes their relevance. This audit does not attribute seconds to any of them.

The obligations remain substantive: proofs must describe the exact spliced bytes; normalized document candidates must stay detached; scene journals must belong to the same installed registration/run/content, have unique earlier checkpoints, and be admitted by real current owners rather than a saved Boolean. Issuer chains, physical Profile references, assignment creation and historical reading anchors protect recovery/history validity. The three ending writers still separately persist playback receipt, Gallery receipt, and terminal COMPLETED state. No cache, skipped validator, proof expansion or checkpoint removal is established by these observations.

A plausible reason for the growing journal fields is that the two retained entries change as each new ending checkpoint is written, bringing different terminal lifecycle/receipt/reading content into the same two-entry journal. The source establishes that each is fully validated; this run does not label the individual journal entries inside these timings, so it does not prove which entry or subvalidator accounts for growth.

## Smallest next observation contract

Use the existing opt-in diagnostic profile, in the same short route, with the same engine/renderer/deadlines and unchanged three writer boundaries. Do not introduce another behavioral owner.

- Preserve the existing inclusive `document_schema_metadata_us` and `outgoing_schema_compose_proven_journal_us` fields.
- Add nested monotonic subphase totals around the existing proof equality, journal composition, and `_scene_journal_error()` calls in each of those two regions. Keep the current saved-time/family residual visible; do not relabel the whole field as actual saved-time cost.
- Inside `_scene_journal_error()`, time each existing `_validate_bundle(raw)` call and the remaining cross-entry checks. Record ordinal, existing scalar checkpoint sequence, lifecycle state/playback stage, elapsed microseconds and returned success/failure only. Read labels defensively without normalizing/capturing/hashing extra state. Do not include saved narrative text, full snapshots or additional owner calls.
- Attribute records to build versus outgoing validation and the existing writer operation/stage. Inclusive parent and child totals must remain explicitly non-additive. Match the actual bundle count; never hard-code a generally valid journal length from this one fixture.
- Preserve original early-return results and refusal order. A failure may retain a completed failing subphase; interruption without a return remains censored, never zero. Optional output must not enter save bytes or influence validation.
- Review the narrow source/caller patch and packet before a single new dispatch. This audit itself authorizes no replay. A subsequent optimization still requires a matched whole-operation baseline/candidate and independent save/recovery/history proof.

Success for that next observation is a complete attribution of both broad fields to proof/copy/journal validation plus identified per-entry durations, alongside the unchanged durable COMPLETED/GALLERY_RECORDED/Title gates. It is not acceptance of the restored full-history journey or exported game.

## Scope
Read-only source audit completed; no production edits, Godot/PowerShell execution, test dispatch, remote mutation, cache or validation bypass. Run39745466691 remains a short-route observation; earlier restored/export failures remain unresolved.
