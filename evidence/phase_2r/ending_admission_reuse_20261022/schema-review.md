# Save and snapshot schema audit — current optimized source

Source-only review of product `3f3621bd074d47c6e76d5e5b000a12ada08f142b`. GitHub-fetched SaveDocumentSchema blob `c9b3b58e21671cf5de39e3d5195869462ef68ca2` and RunSnapshotSchema blob `672d6c641f149164ac84966b4c0a1fead227496e` are saved alongside this report. No runtime edits or engine/PowerShell executions.

## Decision

No material schema-level shortcut is justified. Preserve current/journal full validation and public entrypoint behavior. The concrete narrow optimization boundary is inside a single SceneEventContract operation: reuse derived pure registration information while still executing every authority/receipt/association check in its existing order. The separate contract audit should select any additional candidate there; do not widen that context across schema calls, snapshots, journal entries, writer phases or owner callbacks.

## Why the apparent repetitions are not disposable

SaveDocumentSchema._scene_journal_error validates every actual retained bundle through _validate_bundle -> RunSnapshotSchema.validate before testing family/run/content, registration, unique checkpoint ID and earlier-than-current sequence. This occurs on full and proof/splice paths. The proof material establishes exact outgoing bytes and association to an owned bundle; it does not replace current live issuer/creation/Profile authority. Skipping journal revalidation or deduplicating identical-looking snapshots across prepare/commit would change the recovery trust boundary. Keep source-order traversal and the first failing bundle/code.

RunSnapshotSchema.validate_scene first screens exact initial-admission types and historical run binding, verifies live owners/nonreentrancy and selected registration, then normalizes and validates structure, lifecycle, scene assignment, gameplay, contacts, board, transaction partition and the full receipt ledger. Reading validation can invoke terminal admission and frozen-reading validation, each with its own authenticated context. The final semantic callback receives detached snapshot and bundle and is surrounded by before/after hashes plus a busy flag. Those copies/hashes guard mutation by a live callback; they are not redundant allocation merely because the current callback is well behaved.

Terminal source-reading validation deep-copies and transforms a hypothetical PLAYING view before validating that source. Replacing it with aliased/shallow input would require a separate caller-mutation proof; no measured benefit supports doing that now.

_scene_initial_types_error does repeat normalization/type comparisons for initial admission records, while validate() and validate_scene() both inspect run binding. These are pure-looking, but their placement protects public calls and first-refusal order. Removing or consolidating across public entrypoints is outside the requested safe narrow scope, and the existing measurements do not identify these helpers as material cost.

## Existing evidence already narrows priorities

Recomputed from the accepted optimized short-route run39759857757 log (nested/inclusive totals; never add them):

| Observation | Total |
|---|---:|
| 24 snapshot validations | 13.978395 s |
| Snapshot pre-semantic portions | 6.295739 s |
| Snapshot semantic callbacks | 7.452023 s |
| Mutation guard preparation / verification | 0.114145 / 0.110985 s |
| 188 receipt validations | 9.523689 s |
| 724 bundle-structure validations | 4.294682 s |
| 188 physical proofs | 1.559744 s |
| Six schema journal bundle groups | 6.096131 s |
| Six journal proof-equality checks | 0.023530 s |
| Six journal composition groups | 0.001025 s |

Thus composition/copy/proof-equality surgery targets tiny measured short-route categories; full validation dominates. These numbers describe the short route only. Restored run39762896961 has phase markers but no aggregate profiling: Accept 59.347270 s, writers 17.118577 / 20.044663 / 21.980125 s, all nested in Accept. They establish the long synchronous operation, not its current internal allocation. Do not extrapolate a measured percentage from short to restored.

## Measurement decision

Do not add more schema instrumentation or repeat the accepted restored qualification merely to collect every counter. If the independent contract audit identifies a narrow pure-work candidate with a source equivalence proof, use a matched complete-operation comparison and existing observers as needed for that candidate. If it finds none, one deliberately profiled restored baseline using existing observers is the minimum useful next measurement to determine whether residual bundle work, ledger/authority work or journal growth dominates. That would be a new diagnostic purpose, preserving all original deadlines and the accepted unprofiled result; do not call it an unchanged acceptance retry.
