# Ending checkpoint writer audit and diagnostic — 2026-10-22

Bounded outcome: traced the completion path and published independently reviewed test-only source candidate afca7b1d98d8d6e8221cc703f0eca2fc0d2aa15f (tree c9156807ed2574a05f23e5248e39b5fe8fed6e6d) on codex/ending-writer-timing-20261022. Parent43c907f8249b28d50c1cd4ea71ee61469c21157a. One changed shared test fixture. No cloud dispatch or production fix.

## Evidence and source conclusion
Existing run39731355730 remains FAILED/incomplete: creator102 assertions pass; loader240.038s exit124/no final JUnit. Ending Accept begins174.980s, press/release dispatch return, last release.return174.988s. No next-frame marker;1407 subsequent repeated story loads demonstrate work, not a proven deadlock.

Inspected exact source owners:
- scripts/ui/EndingScene.gd: validated playback callback enters GameState completion, then resume_ending drains a bounded eight-command tail.
- autoload/GameState.gd: lease, rollback capture, physical stage completion (including ordered-step Profile/Gallery), checkpoint writer, retirement and release. Gallery tail and complete_run use this same transaction path.
- autoload/ApplicationBootstrap.gd: scene-ending writer captures Bridge reading and GameState snapshot, then checkpoint capture/prepare/commit; conditional rollback is retained.
- scripts/application/run/SaveManagerCheckpointPort.gd: exact synchronous forwarding signatures; existing DWM_CHECKPOINT_PROFILE instrumentation emits on return.

One Accept can therefore invoke several synchronous checkpoints. This is a source-supported opportunity for measurement, not proof of the timeout cause. Deleting or coalescing writes is not authorized by this evidence.

## Candidate behavior
Only the witness journey installs the observation immediately before final ending Accept. It verifies the original writer is Bootstrap._commit_ending_checkpoint. A private test-only callable seam delegates to that original exactly once and returns its Dictionary unchanged.
During that synchronous call only, a RefCounted proxy forwards capture, prepare, commit and rollback to the original retained port. The original retains its state/caches/storage/policy. Each entry/return gets scalar monotonic phase output and invocation number. There are no new awaits, retries, snapshots, deep copies, deadline changes or production hooks. References restore on ordinary return; the writer restores after Accept.

## Review and limits
Independent read-only source review found no static blocker for inert publication. Forwarding signatures and inspected caller coverage match. Removal of additions reconstructs baseline exactly; candidate SHA256 d18f15af328d945fcb41f5224b212b94aee6675ab4a368e84488cbd90277b845, Git blob8f3a9f7b73db5df88372eab3b1c05c689af6c4c8; published contents read back exactly.
No Godot/PowerShell execution or syntax/runtime acceptance. Diagnostic reference substitution is a perturbation: an engine/script error could prevent restoration, and unknown synchronous callbacks could observe the temporary reference. No identity guard was found on the inspected synchronous path; setup guards remain elsewhere. Never promote this observer into production.
A missing writer-entry marker leaves completion delivery, rollback capture and Profile operations unresolved. Writer entry before port capture includes reading/snapshot assembly. Return markers do not imply success; existing assertions and final receipts still decide acceptance.

## Next bounded task
Prepare/review a cloud packet pinned to this candidate, using current assets aac507fe98971a6779edc550ce6c7fbba0890cdb as baseline. Preserve inherited and shared fixture receipts, creator/loader selection,240s outer bound and15/20/5s guards. Reconcile current refs/runs before installation on PR30, then one diagnostic; user permits handback after launch. Do not dispatch stale43c907 source or old3e286 assets.
Current controller99bc047ca19489ef44714dafbf7bec8000e40cd0; master41592fcc792aa615e47ee2ce2f05008ca195b311; PR36c8358870d3ece92d5f8cc7ba65aefe34a746be5c; integration3ae6d9138fb53c388380c78550cf6082eafc0ea3. No merge/release, no WCT/export retry, no timeout extension.

Workspace /workspace/scratch/a1978e779130/completion-audit retains inspected source and candidate. Existing run originals remain /workspace/scratch/83314963f3ce/run39731355730.
