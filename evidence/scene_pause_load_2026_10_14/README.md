# Coordinator A — Text Pause / selected Load handoff

Status: connected integration accepted; diagnostic controller candidate only. Product branch and PR #1 are unmerged.

## Observable outcome
From a real native Text boundary, Pause → ordinary or Quick selected schema-5 Load retains suspension until SaveManager proves durable destination activation. It publishes one ready destination, then the existing lifecycle coordinator releases input, audio, publication custody and the paused tree. A precommit identity-issuer write refusal preserves the exact paused source and Continue works.

## Ownership and changes
- SaveManager remains the sole durable activation owner. ProductionPauseController retains the exact pending transaction and awaits existing retry/proof APIs; failures after pending preserve recovery custody.
- SceneRouter associates that operation with the existing Pause publication hold instead of creating a competing hold. It acknowledges scene activation while retaining outer suspension until lifecycle completion.
- DialogicBridge validates the real retained native Pause handle and acknowledges the activated scene without replaying it. An old completed handle cannot consume a newer Pause.
- BackupPresentationPort preserves pending/recovery results through Quick Load.
- The Backup-host regression test now observes real get_projection calls; layout revision was an invalid refresh counter. The unchanged base reproduced its original 7-versus-6 failure.

## Validation
Windows-2022 cloud only, PowerShell isolation wrapper, Godot 4.6.3 standard GDScript (4.6.3.stable.official.7d41c59c4), GUT 9.6.1. No local engine execution.

| Evidence run | Coverage | Passed cases | Assertions |
| --- | --- | ---: | ---: |
| 38431787156 | Pause coordinator/controller, Backup, scene activation, Dialogic Pause recovery, Backup host, ordinary connected creation and fresh-process Load | 96 | 5476 |
| 38436000873 | Native Text ordinary Load, Quick Load plus stale-handle rejection, precommit refusal plus Continue | 3 | 140 |
| Combined | Separate runs, identical production bytes | 99 | 5616 |

The earlier run also contains failed superseded Pause fixture cases and the deliberately unchanged baseline diagnostic; it is not claimed as wholly green. Final focused engine execution, strict case census, assertion checks, source-identity checks and import all passed. GitHub job status is failure solely because artifact upload hit storage quota. Original evidence ZIPs were recovered from bounded log retention and verified. Final ZIP has 44 manifest entries; an independent audit verified all hashes, test bodies, and 12 unchanged production files across the accepted evidence runs.

Final native tests require actual suspension during pending activation, foreign transaction refusal, one route/native confirmation and ready publication, one Pause close, released suspension, unchanged Profile consequences and command receipts, duplicate consent rejection, and actual reconstructed Witnessed caption in the main viewport. The write fault is a genuine desktop-issuer-root.json.next refusal before commitment.

## Fixture corrections and what the stall taught us
Each native case needs a fresh Godot process because registration and issuer authority are process-owned. Caption retirement must be queued after its ready callback. The fixture must configure the actual Witnessed default style: cancel/Load removes the initial layout, and otherwise native reconstruction falls back to the stock VN animation, which stalls while the tree is paused. The fixed tests select a real style and verify its reconstructed node; no synthetic native completion or unpausing bypass was introduced. A 30-second always-processing test watchdog now captures compact state before failing; it is not a production deadline.

## Acceptance limits / next slice
This is connected integration with an empty TEST scene host and fixture-selected Witnessed default style. Diagnostic desktop/consequence/localization restore participants remain inherited; input, audio, Pause, Backup, Profile, Run, Save, router and native Text owners are real.

The exact base Bootstrap does not yet configure a shipped schema-5 scene host. Legacy Hospital/Dating style selection uses Bridge._prepare_scene_art; schema-5 restoration bypasses that hook. Before shipping, the real scene host or Bridge must explicitly own Witnessed style selection through reconstruction. Do not treat the fixture setting as shipped wiring.

No claim is made for Challenge-control Pause, rendered player-journey E2E, same-branch OS crash recovery, or a newly tested postcommit activation-failure recovery UI. The current first-write refusal does not substitute for every later persistence failure boundary. Preserve prior selected-absence recovery acceptance and its separate evidence.

Recommended next slice: establish the real schema-5 scene host and its canonical presentation/style ownership, then exercise a rendered Pause → Load journey. Resolve a genuinely architectural ownership choice against recorded decisions before broadening the implementation. No new session is required solely because these tests passed.

## Exact identities
- Base product branch: 8ead20846f830d7e4227b6650c5bd24b9038d5d7
- Master unchanged: 0c8b2384415d71bd3de4ff7408640bbf60b63740
- Controller branch: codex/scene-runtime-integration-controller-20261009 (draft PR #30)
- Controller head: 64d060d1b5b7be05ff3e5ac374ebb58892074129
- Controller tree: 16d32436c01c6bf4ca15eaaade29080a8eca1b09
- Patch SHA-256: 0a903d14a56a8c5ed9ec37e6b931334a8f5f7354165d3bc9591b50b35057c8ac
- Frozen cloud source: cc910f2b84089c92dcfe74ea5137632c353d9528
- Frozen source tree: 4351e2238cf8c4d212425874b845482e5d927c5d
- Final run/job: 38436000873 / 115429999835
- Final original ZIP: 332556 bytes; SHA-256 02b203f1fba3d4298ac10d0aaebc3dcb2994a8d7dca86a10b81f2446ad177dbd

Final run: https://github.com/Siuuuers/dwm/actions/runs/38436000873
Regression and baseline run: https://github.com/Siuuuers/dwm/actions/runs/38431787156
Controller review: https://github.com/Siuuuers/dwm/pull/30

The original gate scope prose refers to the broader campaign; its final lane census is exactly the three native cases. Use the table above for cross-run attribution.
