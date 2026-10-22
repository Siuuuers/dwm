# Run9 validation follow-up — run39749644375

## Finding
The journal timing now attributes almost all of the growing broad region to its existing full bundle validations. The same sequence2 PLAYING snapshot costs about0.35s, sequence3 PRIMARY_PENDING about0.62s, and sequence4/5 later ending snapshots about1.05s. Proof equality, journal copying and checks/observation residuals are small. These measurements identify the boundary, not its internal root cause.

The next bounded observation should split `RunSnapshotSchema.validate_scene()` into pre-semantic validation, mutation-guard preparation, the installed semantic callback, and post-callback mutation checks. Apply it to every call inside the existing writer scope, including current snapshots and journal snapshots; preserve the per-call checkpoint/lifecycle labels. This requires only RunSnapshotSchema and the existing SceneValidationTiming helper. Do not alter GameState internals or remove any validation yet.

## Source-backed work inside the boundary
Source owners are the exact productbef78c105697a256ee0ff1a40e9b4c306e2740e7 composition (only SaveDocumentSchema changed from0b9095e5). Prior exact RunSnapshotSchema/GameState copies and hashes are in run39745466691/source-audit-inputs. Additional FrozenRunContext, SceneEventContract, DialogicBridge and DialogicEntryManifest copies were SHA256-matched to the original preparation source receipts; ProfileManager and SaveManager were fetched atbef78c. The relevant source files are retained in this run's source-audit-inputs.

`RunSnapshotSchema.validate_scene()` performs installed-registration selection/comparison, normalization and primitive/shape validation, lifecycle and assignment validation, Contacts, board/consequence validation, transaction/scene-receipt checks, audio, and reading validation before its live semantic callback. It then hashes and duplicates snapshot/registration, invokes the installed GameState owner under the existing reentry flag, and rehashes to reject mutation. None of those subregions is separately timed in this run.

`GameState.validate_scene_snapshot_semantics()` authenticates the receipt ledger, compares the installed Profile assignment, validates dating Profile references, calls `FrozenRunContext.validate(snapshot, true)`, and joins authenticated commands to retained reading anchors. The schema and semantic owner both call `SceneEventContract.validate_scene_receipts()`, but they serve distinct validation boundaries; repeated source calls alone do not prove one may be deleted.

A concrete lifecycle-dependent expansion exists in FrozenRunContext:
- `validate()` on a terminal snapshot calls `_validate_scene_terminal()` first; for a nonempty reading checkpoint it then calls `validate_reading_checkpoint()`, whose terminal branch calls `_validate_scene_terminal()` again.
- `_validate_scene_terminal()` rebuilds the ending projection, validates the terminal admission, then validates the retained source reading checkpoint as a scene checkpoint. That scene path authenticates receipts and derives all retained scene frames.
- The outer RunSnapshot reading validator also authenticates terminal admission and, for nonempty ending reading, calls FrozenRunContext's checkpoint validator.
- The PRIMARY_PENDING empty-checkpoint path returns earlier, so later nonempty ending snapshots traverse more of these existing boundaries. This is a plausible explanation for lifecycle-associated costs, not measured attribution or a full exact call census.

`derive_scene_frames()` validates reading shape and registration, walks actual ledger entry contexts, resolves each frame and admission, checks target/return bindings, rebuilds the immutable presentation frame, and compares it with retained data. It protects historical frames as well as the visible frontier. `DialogicBridge._validate_scene5_event_anchor()` configures/restores a reading session and checks the authenticated anchor against its ledger; this is one call per semantic command, not merely a string comparison. Existing configure/compile aggregates do not include all restore/frame/receipt work.

## Physical storage distinction
`ProfileManager.get_pair_deck_draw()` reads the initialized in-memory `_profile.pair_deck_draws` and returns a detached receipt. `get_dating_attempt()` delegates over in-memory `_profile.dating_attempts`. These methods do not themselves read a file.

There is nevertheless a concrete synchronous storage-proof path inside repeated receipt authentication: `SceneEventContract.validate_scene_receipts()` -> `_validate_committed_initial_admission()` -> `SaveManager.capture_committed_scene_creation()` -> `ProfileManager.prove_scene_assignment()` -> `_storage.inspect_revision("profile.json")`, strict profile parsing/canonical emission and retained-row validation. The creation owner also validates activated/completed creation state and allocation receipts and parses the retained initial autosave text. This audit establishes the call path; it does not measure storage latency or infer the OS cache state. Current physical bytes matter because later Profile writes must not let an old cached whole-file assertion stand in for durable creation authority.

Installed registration lookup returns a detached installed bundle after startup selection; it must not be described as a fresh manifest disk read on every call. Fingerprinting also canonicalizes/hashes the installed bundle. These costs remain unmeasured here.

## Smallest next contract
Add an opt-in per-call observation within the existing writer operation scope, using existing SceneValidationTiming rather than another manager. Preserve public `validate_scene(snapshot, bundle)` and delegate exactly once to its original body. With diagnostics inactive, bypass record allocation, labels and new clocks. With diagnostics active, retain scalar checkpoint sequence and admitted lifecycle/playback enum labels; never copy/hash state solely to label it.

Record total elapsed and returned `ok`, plus only reached phases: pre-semantic validation; preparation of mutation hashes/detached copies; semantic call including existing busy toggles; post-callback mutation verification. Preserve the existing OR short-circuit hash expression exactly. Early refusal has completed total and missing unreached phases, never fabricated zero durations. An interrupted call has no completed per-call record. The existing aggregate operation supplies prepare/commit and writer-stage identity; per-call ordinals disambiguate repeated validation of the same snapshot.

All current outputs, arguments, early refusal order, reentry checks, busy-flag behavior, snapshot detachment and mutation detection remain unchanged. The helper stores only diagnostics in its process-local active scope and cannot import RunSnapshotSchema back (avoid a dependency cycle). Parent operation, snapshot total and phase timings remain inclusive/non-additive; observations cannot enter save bytes.

Review the two-file candidate before any pinned cloud packet. A later optimization must first identify the costly phase. If repeated Frozen terminal validation dominates, the narrow potential simplification to investigate is internal delegation to a checked continuation within a single call, preserving each public entry point's full validation and failure order. This is not authorization to bypass checks, reuse a saved Boolean, cache physical authority, or delete a checkpoint. Any such later change requires independent failure/caller proof and a matched complete-operation comparison.

No runtime change, dispatch or optimization is part of this audit. Restored/full-history/export acceptance remains unresolved.
