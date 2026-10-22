# Ending preparation source audit and comparative candidate — 2026-10-22

## Observable outcome and scope
Measure the real ending checkpoint writer on the existing short direct-Day7 route, reaching the target earlier than the full restored journey. Bootstrap and SaveManagerCheckpointPort retain write authority. Evidence required: real viewport Accept, writer begin/return and capture/prepare/commit markers, returned DWM_CHECKPOINT_PROFILE records, clean process completion, and the existing Title/durable COMPLETED/GALLERY_RECORDED assertions. This is comparative short-history evidence only, never restored-journey acceptance.

## Prior result
Run39734596457 remains failed/incomplete: creator102 assertions passed; loader240.042355s exit124, no JUnit. Writer began at engine239.440014s and prepare began239.445131s. Insufficient preparation observation time; no demonstrated stall. Parent elapsed and engine ticks have different origins and must not be subtracted as an exact allowance. Latest Actions list was reconciled: no new active focused run, controller2ebe3525f322510af94515fdddd489bd341a94c4.

## Pinned call graph
Audited product afca7b1d98d8d6e8221cc703f0eca2fc0d2aa15f.
- SaveManagerCheckpointPort.prepare -> RunSnapshotSchema.build; journal prepare; SaveDocumentSchema.build; storage preimage capture/validation.
- SaveDocumentSchema validates its current bundle and, when unproven, recovery bundles through RunSnapshotSchema.validate. Storage text validation also invokes SaveDocumentSchema.validate.
- RunSnapshotSchema.validate_scene checks reading/receipts and calls GameState.validate_scene_snapshot_semantics.
- GameState validates receipts, frozen context, then checks the reading anchor for every authenticated scene command.
- DialogicBridge._validate_scene5_event_anchor constructs a SoloReadingSession, configures it and restores the reading checkpoint for each anchor.
- SoloReadingSession.configure_scene compiles every registered programme per configuration.
- DialogicRuntimeAdapter.compile_scene_programme loads the resource, creates a new DialogicTimeline, converts resource text and processes it. Resource caching alone cannot eliminate that explicit reconstruction.
These nested operations plausibly amplify history-dependent work. They do not establish measured dominance, root cause, or an optimization's safety. scene_registration merely returns a detached selected bundle; validate_bundle_structure deliberately avoids full DTL admission. Do not misattribute compilation to either getter.

## Candidate
Commit b0c6ac928371ed849bb4c7f6a37d8921465aade9; tree b34741fcbb2e5971429cb4473644f2fde5fdb449; branch codex/ending-prepare-comparison-20261022.
Only tests/integration/test_scene_ending_direct_return.gd differs from parent. Published blob 3d70ba5d1652bcee7c94ed71112542bcfa5033ab fetched back and text-exact verified.
Reuses the inherited pass-through observer already reviewed on parent. Enables existing DWM_CHECKPOINT_PROFILE only around final real Accept, restores the original writer and previous environment presence/value on return, and asserts at least one real writer call. Existing assertions, input, local deadlines and production files are unchanged.

## Independent review
review_prepare independently traced the compile path and reviewed the candidate diff and inherited input helper. Approved for inert publication: calls forwarded once, input readiness/focus/press/release/frame waits retained; environment/writer cleanup reached even after ordinary early input refusal; existing durable and Gallery assertions retained. No blocking static type/lifecycle finding. No Godot or PowerShell execution; runtime compilation remains unverified.

## Failure interpretation and next bounded task
Prepare profiles are emitted only by _profile_result after return. _profile_phase records values in memory; a timeout inside prepare yields no partial phase record. Observer begin/return markers remain useful but cannot identify the interrupted inner call. A process timeout or script exception may bypass cleanup; isolated child termination remains the boundary.

Prepare and independently review a pinned cloud packet for this exact candidate using the existing direct-ending runner, preserving its existing outer and local deadlines. Pin both inherited helpers and the changed fixture, current assets, engine and actual workflow; reconcile live refs/runs before dispatch. Do not run the unchanged full journey, extend deadlines, modify production validation, or launch WCT/export retries. A completed profile can select the next inner boundary (snapshot build, document build or backup). A short-route pass cannot close the restored history/recovery problem. No cloud run dispatched in this checkpoint.

Held refs reconciled: master41592fcc792aa615e47ee2ce2f05008ca195b311; PR36c8358870d3ece92d5f8cc7ba65aefe34a746be5c; PR30base/integration3ae6d9138fb53c388380c78550cf6082eafc0ea3. No merge/release.
