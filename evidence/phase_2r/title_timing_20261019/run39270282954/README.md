# Deadline fixture passes; timing overlay import/export blocker

## Outcome and immutable identities
Run [39270282954](https://github.com/Siuuuers/dwm/actions/runs/39270282954), job118120461192: completed/failure. Executed under [Director6269458094](https://github.com/Siuuuers/dwm/pull/30#issuecomment-6269458094) and [exact C review6269685549](https://github.com/Siuuuers/dwm/pull/36#issuecomment-6269685549).

Controller4ecffddfee0f56db51ac2c30f189f5c9ed4668f4; workflow blob27271c688466e5c75844b0a411c2d39cbe65effc. Tool source5e07d7075385844edbc77e01276950f186cf1dac; frozen game81847d8b1560340a3a7769223cee0b46c6bdc0f9; harnessd37ad1f6d3c0148205c1b4d21444d05d01e7cca6. Heads and no active/queued runs were reconciled immediately before one expected-head-protected controller installation. Retained engine artifact12184205891 was unexpired. No duplicate dispatch, engine rebuild or Baseline repeat. Incidental Windows suite39270282917 is separate, not diagnostic acceptance.

## Passed preparation
All28 Python tests passed on Windows. Source overlay and both PowerShell parser checks passed. The retained actual fixture equals published blobeb22c2c367b333f67cfae2765efadf4a680a5859 byte-for-byte. deadline-tests.json reports all four cases successful:
- late_root_refused_before_enumeration
- late_match_refused
- timely_unique_match_accepted
- ambiguous_match_refused

This qualifies the corrected isolated fixture against the actual transformed Wait-One. It does not recover/reproduce the hidden exception in original run39266748914, which remains a failure. No local Godot/PowerShell execution occurred.

## New substantive blocker
Official Godot4.6.3 import and export commands ran. Their retained logs contain missing EndingScene type errors at WitnessedCaptionLayer.gd:675 and:1447, dependent compile failures, and export.log explicitly records:
`Unexpected "class_name" in class body`, EndingScene.gd:4.

The generated file starts:
```gdscript
extends Control

const DWM_TITLE_TIMING := preload("res://scripts/diagnostics/TitleTiming.gd")
class_name EndingScene
```

The exact published game_patch.py transform reproduces all five retained generated game sources byte-for-byte. It inserts preload after extends, incorrectly preceding the original following class_name declaration. Independent read-only source review confirms this generator/header defect. The dependent missing-type errors are consistent with that failure; no claim that it is the only possible later compiler issue.

The strict editor log gate correctly fails. No validated new package, fresh smoke, Capability/Create/Load player execution or Title timeline was reached. Missing downstream results correctly make diagnostic-outcome.json fail. This is no phase-overlap, native-readiness, durable-completion or clean-exit evidence. Export command activity/file output must not be called a qualified package.

## Original evidence
Artifact12194417771, title-timing-evidence-39270282954-1. Original ZIP159196bytes, SHA256506e10dc4f858df16118d73bcb4b56d6c02ae89046810601c8bf54802ebfaca7. Retained unchanged as original-evidence.zip, Git blobac36064bf39c2901aa02555dbc33ab7e257551ce. CRC, exact22-member census, and all21 manifest payload sizes/hashes independently verify. The evidence includes original import/export logs, actual deadline fixture, four-case result, source overlay and provenance. Decoded job log, terminal steps and artifact metadata accompany the archive.

Retained harness before/after exactly reproduce the unchanged published transform. Game-source exact reconstruction and fixture byte identity were independently checked in the coordinator's Python inspection; no engine execution added. Original earlier failures/paired Load evidence remain untouched.

## Smallest correction proposal and stop
Correct the isolated generator to insert its preload after the complete existing class header. Actual pinned cases: EndingScene has extends then class_name; SaveManagerCheckpointPort has class_name then extends; the two autoloads have extends only. Use exact pinned header anchors or a bounded header scan, not a new general parser. Preserve all original headers, generated wrappers, original bodies, call/observation order and game/save/recovery/history behavior.

Add a regression using these actual pinned fixtures: complete original header stays the opening prefix; exactly one timing preload follows the header; both declaration orders and extends-only forms remain covered. Retain existing body-preservation checks. Cloud parsing is still required after any reviewed correction; source review alone cannot establish that later import stages pass.

No generator patch applied or next run dispatched here. This reaches Director6269458094's stop boundary for a substantive import/export blocker. External C reviews this retained outcome and Director selects the bounded next correction scope. No deadline widening, checkpoint surgery, instrumentation expansion, engine promotion, master/integration movement, merge or release. Official exported completion/clean exit, observed delays/relevant integration failures and final build-reference handoff remain open.
