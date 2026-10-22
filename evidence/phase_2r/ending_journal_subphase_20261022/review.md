# Independent source and caller review — schema subphase observation

## Disposition
Approved for source publication and subsequent cloud-packet preparation. Final candidate SHA256 `c0fe0f1e37d2c11fe4884a1efd6fde31c3f93c1963a65f6606c5ff9fe31cfce0`. Source review finds no remaining validator-semantic blocker. This is static approval of an inert diagnostic candidate, not a Godot compile or runtime pass, cloud dispatch approval, performance improvement, or restored/exported-journey acceptance.

## Baseline and scope
Baseline product `0b9095e5c63275bc4721cd257413d286bcd958b0`; SaveDocumentSchema Git blob `44f7ebcb05d4b3fd0984018a8ac272999be67791`, SHA256 `9d8864e32e4fa8cead3422452cbd3edd1c3eaada1b352ff987d9d27ed1299c7e`. Read the exact retained schema, checkpoint port, relevant RunSnapshotSchema constants/shape, source-audit contract, and existing synchronous ending-writer observation fixture. Candidate changes only SaveDocumentSchema.

## Findings and corrections
- Initial playback label lookup used the snapshot root; corrected to the actual `snapshot.lifecycle.ending_plan` location.
- Raw failing bundles can contain malformed strings. Final labels admit only values in existing canonical RunSnapshotSchema lifecycle/playback enum arrays after scalar type checks, avoiding arbitrary saved text and duplicate policy lists.
- Current-bundle scalar labels and explicit inclusive-nested marker were added. Existing enclosing writer markers and aggregate records remain the operation identity; lifecycle labels alone are not unique operation identifiers.
- A redundant new inclusive composition timer was removed; the existing parent timer remains authoritative.

## Semantic and caller checks
Independent function-body comparison found only `build`, `_validate_document`, and `_scene_journal_error` changed among 20 original functions. The journal core reconstructs exactly to the baseline after substituting its added optional arguments and pass-through bundle wrapper. Every other original function is unchanged, including `_validate_bundle`, proof equality, proof selection, detached proof composition, and saved-time validation.

The build helper evaluates the original proven/non-proven composition expression once at the original dictionary member position and returns that Array directly. No copy, normalization, hash, owner call, cache or validation bypass was added. Outgoing composition and all refusal branches remain ordered as before. Per-entry instrumentation calls `_validate_bundle` once, records after its return, and returns that same Dictionary. Family/run/content/registration, checkpoint uniqueness and earlier-sequence checks remain unchanged. No save candidate receives profile data.

The checkpoint port already passes its separate caller-owned profile only under `DWM_CHECKPOINT_PROFILE=1`. With an empty profile, journal wrappers delegate immediately and label/output allocation is bypassed; the composition wrapper preserves the original expression and its no-op profile helper. There is small additional call/branch overhead, so this is semantic preservation, not a claim of literally zero disabled-path cost. All three original internal journal call sites remain compatible: build/proven outgoing opt into the wrapper; ordinary non-proven validation still uses the two-argument default path. The original two-argument private signature remains accepted through defaults. No writer, persisted field or recovery boundary is changed.

## Measurement interpretation
Build journal composition is nested under `document_schema_compose_us`, not under metadata. Proof equality and scene-journal validation are nested under metadata. Outgoing composition/proof/scene-journal timing are nested under `outgoing_schema_compose_proven_journal_us`. Preserve this distinction when calculating residuals.

Scene-journal total includes all timed bundle calls plus cross-entry checks and observation work. `journal_checks_and_observation_us` subtracts only completed bundle durations from that total; it is not pure cross-entry-check cost. Current-label setup occurs before the scene-journal clock and is part of the broader parent's residual. Parent/child inclusive durations must not be summed. Entry ordinals are zero-based and track actual returned validator calls; input count is dynamic. A non-Dictionary entry fails before a validator call and produces no fabricated per-entry duration. A returned failing bundle records `ok=false`; an interrupted call has no completed elapsed record. Existing broad timers that were absent on early refusal remain absent, not zero.

## Remaining gate
No Godot or PowerShell was executed locally or remotely in this review. Added inferred variables derive from statically typed helper returns or integer arithmetic; dynamic `.get()` reads use explicit Variant types. No new warning-as-error risk was identified by inspection, but engine parsing and execution remain unverified. Before one bounded cloud dispatch, update and review exact source/custody pins and evidence extraction to require complete subphase records, correct writer association, actual entry counts, unchanged durable COMPLETED/GALLERY_RECORDED/Title gates, and the existing engine/renderer/deadlines. No retry or optimization is established by this patch.
