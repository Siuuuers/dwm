# C: authenticated scene-to-ending connection

Status: implementation proposal and connected TEST journey; no runtime implementation or gameplay acceptance.
Authority: Director [#30 comment6206547454](https://github.com/Siuuuers/dwm/pull/30#issuecomment-6206547454).
Source inspected: PR36 commit `5e4da996bdb896fb0db96641232595d78dd08cd9`.
Scope claim: [comment6206648946](https://github.com/Siuuuers/dwm/pull/30#issuecomment-6206648946).
B's ordered-sequence preparation: [PR39](https://github.com/Siuuuers/dwm/pull/39). A owns all shared implementation and cloud qualification.

## Recommendation

Add one authenticated scene-ending admission variant to the existing Run/receipt/checkpoint owners. Dispatch the selected terminal target to that admission, then reuse EndingScene and DialogicEndingPlaybackPort. Do not route an ordinary scene directly to EndingScene, manufacture Day7 state, or broaden ordinary scene admission to accept an ending as a scene.

This requires a bounded persisted scene-ending state, not merely a router edit. The exact serialization revision belongs to A; the concrete fields and invariants below define the proposed interface. Existing scene and legacy Day7 formats must remain strictly validated. This packet is sufficient for A to implement without another C approval gate.

## Observed gates at the pinned source

| Owner / function | Current behavior and implication |
| --- | --- |
| scripts/domain/narrative/SceneEventContract.gd: scene_completion_request | Registered target structures permit ending, but completion requires target.kind == scene. It binds marker, final reading anchor, source occurrence, event digest, programme and registration fingerprints, then derives a child from the issued event receipt. Preserve this authentication for the terminal variant. |
| Same: scene result/admission validation | Ordinary admission permits scene/contact, not ending. Changing only completion's enum does not produce a valid ending admission. |
| autoload/GameState.gd: _accept_scene_runtime_event | Makes and validates the receipt, commits it with the current checkpoint, then adopts command receipts. Preserve durable completion before terminal admission. |
| Same: _admit_scene_target_owned | Revalidates the saved trigger, active occurrence, target, current run and stable schema9 checkpoint. This is the analogous authority boundary; ending needs a separate branch before ordinary scene preparation. |
| Same: _admit_terminal_ending | Requires day7 and a legacy ending source, constructs provisional plan/frozen seed, calls lifecycle.enter_ending and the checkpoint writer. It is not callable as the scene terminal adapter. |
| scripts/domain/run/RunLifecycle.gd: enter_ending, validate_scene, to_dict | enter_ending requires Day7. Scene serialization has exact scene keys, no ending_plan; validate_scene permits PLAYING only. A scene ending cannot be made durable by setting the private state alone. |
| scripts/domain/run/RunSnapshotSchema.gd: _validate_scene_reading, _validate_scene_route_context | Scene save requires stage scene, reading schema5 and matching active admission/occurrence. Route context permits only challenge owners. Legacy ending checkpoint/cache cannot simply be inserted. |
| autoload/GameState.gd: capture_ending_presentation_signature / capture_ending_frozen_presentation | Compare against the saved current ending command; frozen cache is currently obtained from the legacy plan/eligibility seed. Scene admission must supply an authenticated equivalent, not a fabricated Day7 eligibility snapshot. |
| autoload/DialogicBridge.gd: start_ending_presentation / _start_ending_reading | Validates registered presentation signature, role/form/step token and frozen context; starts physical playback or the registered ending reading programme. It already knows how to play an ending. |
| scripts/ui/EndingScene.gd: resume_ending / on_ending_playback_completed | Consumes GameState commands, matches physical receipt against pending playback/transaction/stage/ending, retries failed persistence, drains gallery/completion commands, then calls goto_menu. Reuse this public interface. |
| autoload/GameState.gd: _commit_ending_playback_completion / _retire_completed_ending_session | Saves completion before retiring the live run. Scene variant must preserve this ordering. |
| autoload/ApplicationBootstrap.gd: _retire_completed_ending_after_menu | Retires ending reading only after actual Menu publication, completed lifecycle, inactive live run, no active playback, and matching run:ending session. Preserve this protection. |

## Concrete proposed interface for A

Suggested entry point on GameState: `admit_scene_ending(target_id, trigger_command_id)`. These are selectors, never authority supplied by UI. Return the usual result dictionary with route ending only after durable adoption. Names are proposals, not existing APIs.

1. Under the existing mutation gate, authenticate the current live run/branch/generation and active occurrence. Obtain the registered ending target from the validated bundle. Require the exact saved scene.transition trigger for this target and occurrence; validate its issuer/derived completion provenance, marker anchor, programme hash and registration fingerprint. Refuse stale, forged, mismatched, out-of-order or contact-local triggers.
2. Bind admission to the stable source checkpoint reference (ID, sequence, snapshot hash), trigger command ID/digest, source occurrence/admission, target ID and resolved presentation entry. Issue/derive identity through the existing issuer. Never accept a raw ending ID or UI route as proof.
3. Prepare a detached terminal candidate with a discriminated scene-ending record. Proposed logical contents: admission identity/provenance; source checkpoint and trigger binding; registered target/presentation binding; frozen plan/presentation inputs; playback stage/cursor and physical completion receipts. Retain original run identity, assignment, receipt ledger and board/consequence state. Existing scene creation must still start in PLAYING.
4. Give the scene lifecycle a validated ENDING/COMPLETED variant whose ending record survives capture, rollback, save and restore. Couple the narrative checkpoint explicitly to the admitted ending step (or durable pre-playback boundary). Preserve the source scene receipt/history as provenance; do not relabel a scene reading5 checkpoint as an ending checkpoint. Ordinary PLAYING validation remains unchanged. A chooses an explicit schema variant/version with strict compatibility handling rather than relaxing every schema9 save.
5. Commit through the existing save/checkpoint owner before retiring source playback or exposing ending text. Failed pre-commit writes leave source state resumable. A successful commit followed by refused native adoption must retain recoverable committed authority, not silently replay the source marker. Duplicate admission returns/reuses the same admitted step.
6. Project the admitted record through existing `request_next_ending_command`, `capture_ending_presentation_signature`, `capture_ending_frozen_presentation`, and `complete_ending_playback_stage`. The playback command retains the four context keys: playback_id, transaction_id, expected_stage, role. Use existing registered role/form/entry validation. Keep IDs stable across retry; validate physical completion against the pending command.
7. Save each completed physical stage before advancing; run existing Profile/gallery semantics only for actual reached/completed presentations. After durable COMPLETED, retire live authority and use EndingScene's existing menu return. Retire reading after actual Title/Menu publication. New Game then uses the existing scene creation transaction and B's first_target_id, allocating a fresh run directly at Day1.

For the first TEST, use a single already registered neutral ending presentation (ending.alone.normal, semantic ending.alone, if the composed registration resolves it) with its supported role and frozen presentation fields. Resolve and validate this through existing catalogues at composition time. Missing registration is a clear content failure, not fallback prose. The TEST selects a fixed registered ending to prove connectivity; it does not claim full relationship-based ending selection. Do not invent eligibility, Hospital, dating or gallery evidence to satisfy a legacy validator.

## Proposed shared paths, all owned by A

Required implementation surfaces:
- scripts/domain/narrative/SceneEventContract.gd — terminal completion/admission receipt variant and verification.
- autoload/GameState.gd — authenticated terminal admission, capture/rollback and ending command/presentation/completion projections.
- scripts/domain/run/RunLifecycle.gd — persisted scene ENDING/COMPLETED variant.
- scripts/domain/run/RunSnapshotSchema.gd — exact lifecycle, reading, receipt and terminal state joins.
- scripts/application/narrative/SaveManagerNarrativeCheckpointPort.gd — retain terminal candidate custody and durable acknowledgment through existing save owner.
- autoload/DialogicBridge.gd — terminal-target dispatch/source handoff to the existing ending playback path.
- autoload/ApplicationBootstrap.gd — scene-aware ending checkpoint wiring and route/restore composition.

Verify during implementation, change only where the new variant requires it:
- scripts/narrative/EndingFrozenContext.gd — reuse compatible presentation projection or add explicit scene input support; never fake legacy seed facts.
- scripts/narrative/DialogicEntryManifest.gd — composed TEST target registration.
- scripts/narrative/SoloReadingSession.gd — family boundary compatibility; coordinate with A's active reading fix.
- autoload/SceneRouter.gd — existing goto_ending/goto_menu wiring.
- scripts/ui/EndingScene.gd and scripts/application/ending/DialogicEndingPlaybackPort.gd — preserve their current consumer interfaces.
- SaveManager/restore semantic consumers reached by the above variant — follow actual compile/validation dependencies; this list is not a claim that a serializer edit alone completes restore.

No C changes to these paths, controllers or inventories. A's later-caption fix comes first; do not overwrite its Bridge/reading work. B's explicit sequence owns ordinary-next relinking and preserves the final terminal policy.

## One connected TEST journey

Use replaceable TEST content and real owners on the composed A candidate:
1. Title New Game starts Day1 directly with fresh run/branch identities. Traverse B's explicit Day1 → Day1.1 → Day2 ordering; the last ordinary entry contains a registered final transition to the selected ending.
2. Real Accept reaches the final ordinary caption. Where A's Save/Load proof is included, separate-process Load shows that exact saved caption fully, without advancing or replaying consequences.
3. Accept the final transition once. Capture authenticated source occurrence, saved trigger, admission binding and durable ending checkpoint. Show the resolved ending's first real caption. There is no intervening numeric-day router or fake Day7 allocation.
4. Complete physical ending playback. Assert one matching completion and correct durable stage progression; Profile/gallery witnesses follow existing semantics. Observe actual Title/Menu publication and retirement of the old live run and ending reading.
5. Choose New Game again. Show Day1's first caption under a different run identity, fresh initial history and no active old ending command. Assert stale callbacks from the old run cannot change the new one.

Focused failure/recovery coverage for that same connection:
- Forged target, stale occurrence/branch, mismatched trigger/programme and direct UI ending request fail without playback or state mutation.
- Repeated final Accept/admission and duplicate physical completion do not allocate another ending or repeat consequences.
- Failed admission persistence leaves the final scene usable; retry uses exact retained authority. Failure after durable commit is recovered from that checkpoint.
- Separate-process Load at an admitted ending boundary resumes the admitted step; Load after completed state does not replay completed prose or resurrect old run authority.

A records exact composed commit/tree, executed tests/assertions, process exits, original logs and rendered journey evidence through its existing cloud workflow. C has not executed Godot or PowerShell and claims no passing tests. Static inspection establishes the gates above, not executable compatibility.

## Deliverable boundary

No new DTL fixture is installed: the persisted terminal seam is absent, so content alone cannot exercise this journey. This interface packet is the Director-authorized alternative. C's preparation ends here; A can implement and qualify the connection while B's sequence remains disjoint.
