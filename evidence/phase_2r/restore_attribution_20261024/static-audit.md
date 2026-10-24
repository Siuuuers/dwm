# Restore validation: static audit

Reviewed source: diagnostic commit `3adfc26238ba13cfa005d925fd9189aa71d83765` in `dwm-attribution`. Read-only audit; no local Godot or PowerShell execution. Diagnostic observations are not product-performance acceptance results.

## Boundaries that must remain explicit

- Selected Save9 admission follows physical revision inspection and strict parsing. The first built-in run participant now reuses only unchanged same-call admission material with exact owner guards. This does not authorize reuse by later participants or across consent/commit.
- Profile, localization, audio and route participants execute between initial admission and narrative preparation. They are separate extensible owners. A later validation cannot assume those calls preserved inputs or authority merely because their ordinary implementations prepare silently.
- Continuation intent commit persists a new operation. Identity allocation then obtains the retained source through `load_restore_context`, after the intent exists durably. Participant application, identity remapping, journal progress and checkpoint-journal installation are additional boundaries.
- Recovery/reconstruction can run after uncertainty or restart. It lacks the original synchronous admission material and must reconstruct plans from its durable retained source.
- `CheckpointJournal.commit_prepared -> _validate_candidate` validates at installation after participant work. It is not interchangeable with initial selected-file validation.

## Additional full-validation caller: route context

`SaveManager._prepare_bundle_with_all_participants -> RunSnapshotSchema.derive_route_restore_context -> validate` is a full-schema validation, despite the projection-oriented function name. It runs after Profile/localization/audio preparation and before route preparation. It returns detached route context derived from the validated candidate, including scene, contacts and terminal ending plan where applicable.

This caller was missing from the earlier static caller map. That omission does not establish a removable check: the public helper accepts arbitrary snapshots, and intervening participant callbacks separate it from initial admission. Attribute its measured cost before considering a narrowly guarded internal projection seam. Preserve the public validator and its normalization/refusal behavior.

## Intent preparation is not complete commit admission

`DesktopContinuationOperationJournal.prepare_intent` checks request keys and `_validate_intent_request`; `commit_intent` independently checks the generated operation with `_validate_operation` and requires the intent stage. Preparation's checks do not discharge all commit obligations:

- Preparation checks nonempty fingerprint strings; operation validation requires lowercase SHA-256 form.
- Preparation requires a transaction issuer receipt dictionary; operation validation calls `_validate_transaction_issuer_receipt` against the transaction identity.
- Commit validates operation-only stage, activation state, allocation receipt, participant index, participant receipt shape and stage relationships.

These differences are reasons not to replace `_validate_operation` with an unconditional “prepared” assertion. They are not a claim that the existing prepare/commit contract is defective. Any future optimization would need to isolate only a genuinely duplicate subproof while retaining these commit checks and current error ordering.

## Cold-load callback gap

Both intent entry points perform their initial request/operation checks before `_load()`. If already loaded, `_load` returns immediately. Otherwise `_load_owned` calls storage reconciliation with `_parse_document`, validates the loaded document and its operations, serializes it, and adopts a detached journal document. Source validation can call creation, issuer and physical Profile owners during this work.

Thus normal adjacency of `prepare_intent` and `commit_intent` does not prove an uninterrupted pure interval: preparation can cross cold storage reconciliation and validation callbacks before returning. A reused source proof would need an explicit unchanged-input and unchanged-authority argument across that gap, including injected adapter/callback cases. Do not silently treat cold and warm preparation as identical. The existing exact-text journal cache is scoped to its own documented obligations; it does not make unrelated caller inputs trusted.

## Phase instrumentation and interpretation

The diagnostic forwards the existing opt-in `restore_transaction` profile into the scene branch. Markers partition owner/activation setup, captures, each participant apply, run remap, each continuation advance, applied-stage transition, checkpoint-journal commit, completion, finalize/connect, and activation kickoff. The workflow checks that these exclusive phase values plus `unphased_us` equal the transaction's elapsed time.

Phase labels include small surrounding bookkeeping: for example, apply includes detached plan construction and result handling. Earlier failure and rollback work remains in the unfinished interval. Kickoff is timed unconditionally, including a normal `ok=false` / `scene_activation_pending` result and genuine kickoff failures. The original return object and control flow are preserved.

The transaction profile closes when the synchronous call returns. Later route/narrative confirmation callbacks, acknowledgement, publication and eventual Ready can lie outside it. Therefore kickoff is not complete activation latency, and a pending result is not by itself a failed player Load. Outer scopes and nested schema timers are inclusive; do not add them to exclusive transaction phases.

Caller records contain source/function/line only. Their offsets share the operation-scope origin; only `fresh_save_load` offsets should be compared with the recorded Load-press/Ready offsets. Stack collection occurs after the individual snapshot elapsed value is captured, but still adds enclosing-operation overhead. Instrumented runs are attribution evidence, not matched speed measurements.

## Recommendation

Use the measured exclusive scene phases to identify the remaining synchronous owner cost before more surgery. Preserve all existing physical proofs and commit/recovery boundaries. A route-context optimization or intent subproof reuse needs a specific same-input/owner argument and focused mutation/cold-load checks; neither is established by an aggregate snapshot count. No broader cache, proof framework or product redesign is justified by this audit alone.


## Follow-up: can route-context validation be removed?

Conclusion: not safely with the existing first-participant admission guard or with equality to the prepared run plan. Keep the full validation at its current boundary; no product refactor was made.

The exact call sequence in `autoload/SaveManager.gd::_prepare_bundle_with_all_participants` is run preparation, Profile preparation, localization preparation, audio preparation, then `RunSnapshotSchema.derive_route_restore_context(snapshot)`. The intervening callbacks are concrete, including when participant adapters themselves are built-ins:

- `scripts/application/restore/ProfileRestoreParticipant.gd::_prepare_profile_plan` calls configurable `_window_output.prepare_restore`.
- `autoload/LocalizationManager.gd::prepare_locale` calls `_prepare_root_plans`, which reaches the registered `root.prepare_presentation`.
- `autoload/AudioManager.gd::prepare_semantic_restore` calls `_prepare_scene_output`; for an available scene audio asset that function calls configurable `_playback_port.load_stream`.

These callbacks can change physical Profile content, issuer state, registrations or installed dependencies while preserving snapshot bytes and owner object identities. Checking exact participant/owner scripts alone does not constrain their configurable dependencies. The existing `_prepare_run_restore` comment deliberately limits its shortcut to the first participant, before external preparation callbacks. Extending its equality checks to the later route boundary would not establish that same uninterrupted condition.

There is also a representation distinction: `scripts/application/restore/RunRestoreParticipant.gd::prepare` checks `RUN_SCHEMA.validate(input.snapshot)` but discards its normalized candidate, then `_prepare_admitted_snapshot` duplicates the original input. A returned run plan is therefore neither an authenticated proof token nor necessarily the normalized candidate. Custom participants can return their own plans. By contrast, `scripts/domain/run/RunSnapshotSchema.gd::derive_route_restore_context` projects `validated.value.candidate`, whose scene validation normalizes integral floats, and uses `is_scene_terminal` to include a detached ending plan. Deriving directly from the run plan must not silently change that contract.

A private candidate-to-context projection could factor the existing code, but without a valid fresh proof at this boundary it offers no safe validation saving. Moving projection before callbacks would lose the existing post-callback refusal. Retaining only a fresh dynamic subproof would require separating registration, issuer lifecycle/contact/board/receipt checks, reading and terminal admission, semantic owner and physical Profile obligations; that is not a small deletion and is not recommended without a measured benefit.

Any future proposal must demonstrate equal detached route contexts for ordinary and terminal inputs, unchanged integral-number normalization, refusal after a window/localization/audio callback tampers with physical Profile or same-object authority state, and full fallback for snapshot drift, custom participants, absent material and mismatched owners. Static review only; no local Godot or PowerShell execution.
