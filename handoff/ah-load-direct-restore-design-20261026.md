# Load simplification and checkpoint presentation handoff

Date: 2026-10-26 (Hong Kong).
Status: implementation authorized. The design below is agreed direction, not shipped behavior.

## Start here

Read AGENTS.md and CLAUDE.md before implementation. Fetch current master. Check whether newer work already implements any item below.
Last verified master: 0a3fe192f34c5ec1c1fa245d7db12a7ac2ad9bcf.
Merged Load optimization: https://github.com/Siuuuers/dwm/pull/114.
Earlier context: handoff/ag-new-run-presence-results-20261026.md at c0a2e1a61adc0309397245fce0383a410e584c1a.

Use cloud-only Godot execution and automated tests. The user permits direct merges, isolated worktrees, and parallel agents. Ask only questions that change behavior or block implementation. Prefer simple code and existing owners. Do not add speculative recovery or anti-tamper mechanisms. Measure complete operations before claiming speed improvements.

## User decisions

- Prioritize reading speed. Trust shipped content. Handle manually edited/missing content with the agreed soft error and skip/fallback behavior. Do not reset player progress.
- Daily Minesweeper is the only source of money. Do not invent dialogue reward replay requirements.
- The user states global data should not store Minesweeper progress. Audit actual owners before making claims about current storage. The prior explanation implied global Profile had newer Minesweeper progress without establishing that fact. Do not reuse that explanation as evidence.
- Ordinary gameplay Load should reuse current language, font, text size, and settings already active on the title screen. A gameplay save must not rewind settings or global unlocks. New UI reads active settings from their existing owners.
- Keep saved gameplay values, prior story variations/choices, and Challenge results. Restore values directly; do not replay earlier gameplay.
- A named checkpoint should own base art, scene/background, and music. DTL references that checkpoint and can issue overlay show/remove commands. Avoid scattering the same base presentation information throughout DTL.
- Multiple overlays can be active together. Each art appears only once at a time. An authored overlay label identifies the art and its screen position. A remove command identifies the art to remove.
- Keep active overlays in display order; newly shown overlays go on top. Repeating an already active overlay label does nothing. Removing absent art does nothing. These were the recommended semantics accepted by the user.
- Save the currently active overlay labels, in display order. Resolve their authored art and position on Load. Do not replay show/remove commands or save removal history. Distinct labels must not accidentally create duplicate instances of the same art. If existing authoring allows the same art at different positions, inspect that use before choosing reposition semantics; the user has not explicitly selected reposition versus no-op for a different label that names already-active art.
- If the game closes during Load, let it close. Do not record/resume the unfinished Load or add special close-time recovery. The original save remains intact; on reopening, the player can select Load again.
- Target behavior: gameplay Load reads saved data and changes the live session without rewriting the source save or persistent player progress solely to restore it. Remove durable Load progress/acknowledgement bookkeeping made unnecessary by this rule. Normal later save operations are a separate concern.
- Current implementation is different: it writes continuation intent, allocation/restore bookkeeping and activation acknowledgement. Do not claim Load is already read-only. Audit all persistent write paths, including identity issuance and callbacks, before implementing the new behavior.
- Preserve exact current dialogue position within a checkpoint. Checkpoint identity and current caption position are separate. New Account starts at the checkpoint's first caption.
- No encryption was selected. A symmetric key does not replace decoding or semantic restoration. Anti-tamper protection is not the objective.
- The user approved proceeding with simplification after these explanations. This handoff marks a useful session boundary; no further general design interview is needed.

## Observable next outcome

Loading a current save restores the same gameplay values, exact reading position, base presentation, and active overlays. Current settings and global unlocks remain current. The player can read and click as soon as the actual UI and dialogue state are ready. Avoid redundant normalization, configuration, temporary-session construction, and repeated validation of internally prepared values.

Verify that interrupted Load leaves the source save and persistent player progress unchanged, creates no resumable Load operation, and permits a later normal Load. Verify overlay position/order and removal across save/load. These are acceptance checks for the new design, not results already obtained.

Do not promise a particular speedup before measurement.

## What shipped in PR 114

Ordinary scene Load reuses its detached admitted snapshot and prepared continuation allocation in SaveManager._begin_restore_continuation.
DesktopIdentityAllocationRestoreParticipant._prepare_admitted_allocation shares remap assembly with full preparation.
Legacy/recovery preparation retains its original admission and fingerprint path.
The change removes one duplicate preparation pass, not the whole restore architecture.
A regression compares full candidates, preserves selected progress, verifies input immutability and commit success.
Identity participant tests now run in the persistence gate.
Cloud-generated public inventories were updated.
PR 113's diagnostic overlay was incorporated; draft PR 113 was closed as superseded.

## Evidence

Final tested head: 2c6f051b1411ebe488b11ee5519033c75ab17431.
Merged master tree matched the tested tree.
Windows automated tests passed: https://github.com/Siuuuers/dwm/actions/runs/40330073980.
Matched comparison passed: https://github.com/Siuuuers/dwm/actions/runs/40330073750.
Each comparison batch ran 24 rendered journeys: baseline/candidate, fresh/retained New Account and Load, four samples each.
Caption screenshots were visually reviewed. Existing state/input/error checks passed.
First persistence batch: 265 tests passed, zero skipped.
Final artifact: 12655296119.
SHA256: 69cbfcc06a1373c73fb5884396b73da9e0f4493383fcbe16299a6c8dba2711cd.
Artifacts have limited retention; metrics below and PR body are durable.

Load-to-caption medians:
- First batch: 3415.851 to 3187.481 ms (6.7% lower).
- Final batch: 3000.743 to 2850.098 ms (5.0% lower).
- Three of four paired Load samples improved in each batch. Do not claim every run improved.
- Samples include observer overhead. They do not establish cold OS cache performance.
- Fresh/retained New Account controls varied slightly upward. Their product path was unchanged; no speedup claimed.

Final candidate Load inclusive medians:
- SaveManager._prepare_restore: 1050.592 ms.
- SaveManager._prepare_bundle_with_all_participants: 288.913 ms, nested inside preparation.
- SaveManager._commit_prepared_restore_profiled: 900.249 ms.
- SaveManager._run_scene_restore_transaction: 500.690 ms, nested inside commit.
- RunRestoreParticipant.apply_silent: 184.688 ms, nested within restoration.
Do not add nested spans.

Cumulative Load milestones, measured from Load input:
- Route confirmed: 2022.435 ms.
- Narrative confirmed: 2449.221 ms.
- Live session ready: 2684.605 ms.
- Complete caption: 2850.098 ms.
These are NOT individual function costs.
The route activation synchronous entry call was about 1.3 ms; later scene initialization is outside that entry call.
Read/parse cost has NOT been isolated from the 1051 ms preparation span.

Fresh New Account:
- Initial checkpoint construction: 574.223 ms.
- RunSnapshotSchema.build_scene: 308.374 ms.
- SaveManager._start_scene_new_run_in_memory: 1282.114 ms inclusive.
- Identity issue/prepare/commit: about 3.38/0.228/4.417 ms.
The initial checkpoint builder's inner costs are not yet individually measured.

## Source findings and next investigation

autoload/SaveManager.gd:
- _prepare_restore reads, parses, normalizes/admit-checks, then prepares plans.
- _prepare_bundle_with_all_participants prepares run, Profile, localization, audio, route, narrative, journal seed, identifier census and retained copies.
- _drive_scene_restore_activation_owned waits for route/narrative readiness, repeats validations, activates the live session, writes an acknowledgement, then publishes readiness.
- Avoid describing all remaining delay as rendering.

autoload/SceneRouter.gd:
- begin_scene_activation loads the gameplay PackedScene and changes to it.
- _on_scene_activation_mounted waits for the actual current scene and ready nodes.
- Route means the physical Godot screen, NOT a narrative fork or previous choice.
- UI existence is a real dependency. Repeated proof/token checks are separate candidates for removal.

autoload/DialogicBridge.gd:
- _build_current_scene_initial_checkpoint finds target/path/markers, calls compile_scene_programme, checks fingerprint/start label, creates/configures a temporary session, begins/admits the scene, allocates/publishes its first caption, captures it and wraps a checkpoint.
- The caller _start_scene_new_run_in_memory does not supply the optional configured session.
- compile_scene_programme starts a fresh parse scope. compile_runtime_scene_programme has reuse support.
- SoloReadingSession.configure_scene may prepare registered entries when configuration is not cached. Do not claim this happens on every call.
- Initial position already must resolve to a caption. Prefer a direct lookup from the existing authored content owner, reusable prepared content, and direct initialization of the actual session.
- Narrative activation installs the saved native reading position. Confirmation captures and compares it, then validation can capture and compare again.
- Assess redundant reconstruction and checks before moving them into background work.

RunSnapshotSchema.build_scene:
- Validates inputs, copies/projects state, then validates the built snapshot.
- _validate_scene_reading expands a saved checkpoint, configures a session and restores its reading state.
- Potential redundant work remains. A 308 ms builder is not an end-to-end New Account comparison.

## Implementation discipline

Start with a bounded Load simplification, with unchanged player-visible state. Audit Profile/global ownership before removing participants. Do not delete continuation bookkeeping blindly: identify callers and older-save/global obligations first.
Do not add background validation merely to hide redundant work. Remove unnecessary work; retain a small UI/dialogue readiness dependency before accepting input.
Presentation-label authoring is authorized direction, but inspect existing schema and commands before choosing syntax. Do not invent a new parallel presentation manager.
Use the confirmed one-instance-per-art overlay rule above. Keep art identity, authored position, and display order clear. Ask only if an existing use requires an unresolved behavior.
Use focused tests for pure rules, integration tests for ownership/storage, and rendered E2E for actual restored captions/art/input.
Finish independent audits before final acceptance testing. Compare complete Load-to-caption and fresh/retained controls with matched instrumentation.
No local Godot execution. Do not confuse the GitHub jobs tool's first 30 results with the entire workflow. Verify overall workflow conclusion.
