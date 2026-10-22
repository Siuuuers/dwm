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

## Launch checkpoint — 2026-10-22
User requested one launch then handback while cloud runs. Independently reviewed complete packet is installed.
- Target run: https://github.com/Siuuuers/dwm/actions/runs/39731355730 (run249), observed in_progress, no conclusion.
- Separately triggered ordinary Windows run39731355684 is not the targeted diagnostic.
- Controller99bc047ca19489ef44714dafbf7bec8000e40cd0, tree35bd06fcf89f51551aafb73dc9dfd9d729a1f828. Expected-old99898a4f update succeeded; compare exactly one workflow file and published bytes match reviewed blob9d80fd755605a26f32e9cc2b68b059cc28a2102a; SHA2563bf113dcd07cfdca88f59aa501d8a853dead70bfbb740462604b6b07d09256ac.
- Product43c907f8249b28d50c1cd4ea71ee61469c21157a; assets aac507fe98971a6779edc550ce6c7fbba0890cdb (tree32ff305d4430b5597d87272053bdf3c75303bf7a).
- Assets under evidence/phase_2r/ending_timing_20261022: prep SHA256689c0c84b81997b2e8761752522457e32ba2cdd8c167fdfdd7646e407896a508; manifest073dbbedf000ad706c080f33342d561d135c46cd5a1c05409619d8c0e9725591; runner885a34370cd14228cae08e7baf316124216f64a3f5f119c5ae2ed6451ccb40d0.
- Only runner delta is inherited fixture source binding and receipt; preparation only changes PRODUCT. Isolation/hash helpers exact baseline blobs. All5 asset contents read back exactly. Independent reviewer checked final controller/pins; no launch blocker.
- Local validation was static Python parse/hash/YAML/pin checking only. All Godot and PowerShell execution remains on cloud.
- Existing240s child,10min focused step,8min import and strict engine/JUnit/source/failure-evidence gates unchanged. No production/WCT/export retry or merge.
Next: consume this run, verify actual preparation-origin/source/selection/isolation receipts, retain original artifacts, and interpret phase records with actual outcome. Do not dispatch a duplicate or infer runtime success from static clearance. User will notify when finished; no continued polling required this turn.
