# Restored ending phase timing — reviewed candidate, 2026-10-22

Outcome: source review complete; no new Godot/PowerShell execution or cloud dispatch.

Candidate: 43c907f8249b28d50c1cd4ea71ee61469c21157a, tree f5f80412fb3bce2e3a84d744281c204e199dd68f, branch codex/ending-phase-timing-20261022.
Parent: 3e28641569c90c06a225368a8889dc9d97db97f2 (exact failed-run source).
Changed paths: tests/integration/scene_later_caption_child.gd and tests/integration/scene_seven_day_connected_child.gd only.

## Observable outcome and owner
The existing witness loader will emit PID, monotonic engine ticks in microseconds, and a scalar phase label. It brackets witness Save/Back, each remaining caption, ending entry/readiness/evidence, ending Accept, Title arrival, completion checks, and fresh Day1. The inherited Accept helper additionally brackets synchronous press/release push_input calls and the next frame. Timing is enabled only by witness_save; no production observer/manager is added.

## Failure questions
- Does most of the 240-second process allowance expire before ending Accept?
- Does a key push_input return, followed by no frame progress?
- Does Accept return but Title fail its unchanged route guard?
- Does evidence collection consume substantial time?
A missing subsequent marker only localizes the last observed boundary. It does not prove a hang, root cause, or a completed action. Return/checks markers are progress, not substitute success assertions.

Existing run39725463509 remains FAILED/incomplete. Its existing witness Save wait deadline114212ms minus unchanged15000ms guard places that point near engine uptime99.212s. Engine ticks and parent process elapsed have different origins; do not equate them. Creator102 assertions remain accepted separately; loader has no final JUnit.

## Verification and independent review
Independent read-only reviewer verified exact baseline connected blob c79f20fd3917d98b13d3419d2788fc29fbe94f30 and both candidate bodies. Reviewed blobs:
- inherited helper 5a5b16e1dfd00910be6995317fbc9646581d34e6; SHA256 eb032c12a41d188573cebcbdc30e0c059441fe9a572b277fb55ef8b4174526be
- connected fixture 298db623f34b8e5920a9ed8dc7d0c16a031ac9b4; SHA256 e2a8550dd77aff45e0b4887c08e76bdc21177443f4dc0e3321a63b09c8ad1635

Lead's static removal check restores original files byte-for-byte after removing the observation helper/declaration/calls and opt-in assignment. Published contents read back exactly. No changed assertions, focus, input edges, frame waits, local15/20/5s guards, or parent240s allowance. Logs add small measurement overhead; no performance improvement claim. No engine parse/runtime qualification yet. Independent clearance is for inert publication only.

## Next bounded task
Prepare the existing cloud runner/helper manifest/controller using this exact candidate. The preparation PRODUCT pin must change; bind both modified inherited and connected fixture bytes in runner receipts. Keep creator/loader selection,240s parent ceiling, source custody, log capture, first-failure handling, and all acceptance gates. Review complete packet before one new diagnostic dispatch. Do not run old pinned assets unchanged against new source.
Read scalar phase records with existing isolation start/elapsed evidence. Preserve original archives and report actual result. No production patch, WCT probe, export retry or timeout increase follows automatically.

## Reconciliation
master41592fcc792aa615e47ee2ce2f05008ca195b311, PR36c8358870d3ece92d5f8cc7ba65aefe34a746be5c, integration3ae6d9138fb53c388380c78550cf6082eafc0ea3 and controller99898a4f6553b1409a6ea9de6e0b6e3cc752ab9a matched handoff. Controller's targeted39725463509 and ordinary39725463468 runs are completed failures. No protected/product/controller movement, PR messages, merge or release. Existing clean/native/direct-ending acceptance is not rerun.
