# Ending publication: retained passive diagnostic

Updated 19 October 2026 Hong Kong time (18 October UTC).

**The evidence is authentic and the retained harness checks pass. The original Load journey still fails the ending action gate.** This bundle records a completed passive diagnostic, not an ending fix or permission to promote the isolated reconstruction runtime to PR36. PR36 remains draft and unmerged.

## Observable outcome and scope

Observe the actual ending caption owner, parent and sibling order, visibility/withdrawal, stored Next state, and natural accessibility calls while the original exported Load journey runs. Existing caption and Canvas owners supply those observations. The trace changes only three existing witnessed-caption source files, emits through normal game stdout, and keeps the original driver bytes, controls, checkpoints, recovery/history behavior, and deadlines.

The output now establishes a live caption/Canvas with natural game-side accessibility calls during the failed ending wait. It does not establish that the complete corresponding subtree reached the native provider.

## Exact identities

| Item | Identity |
| --- | --- |
| Cloud run | [39152708408](https://github.com/Siuuuers/dwm/actions/runs/39152708408) |
| Cloud job | [117749446911](https://github.com/Siuuuers/dwm/actions/runs/39152708408/job/117749446911) |
| Candidate source | `337c2d43e9ff508575f772b1c1b7cf5679be8d0f` |
| Candidate tree | `1e4e752bd8e532f2e731dfc483be40fcff3bd3fc` |
| Parent/reference source | `4963a847f0a7e2da82a87f29d1a27a7b8256eae1` |
| Reference tree | `588074015df4dec61b01941c4db08efd4d379911` |
| Prior reconstruction comparison run | [39149704882](https://github.com/Siuuuers/dwm/actions/runs/39149704882) |
| Controller source | `87c3b1303c457578ee57d9d77b7e4869153d0e78` |
| Controller tree | `a4e6789efcc36ff5966177b79fdc934a692e0db9` |
| Controller workflow | `.github/workflows/scene-first-reveal-profile-diagnostic.yml` |
| Controller workflow SHA256 | `e08b4d63eb3d6ff536229520b872bea53a30eb6843a1eb1f5d1cc4a52478c3f5` |
| Engine/configuration | Godot 4.6.3 standard GDScript; Windows Server 2022; Always accessibility; Dummy audio; ProjectDefault renderer |
| Original driver SHA256 | `0e819db31a69824934b771442b7a19c540b54b4c706192fcb152556c2f7a116b` |

The three candidate source Git blobs are:

| Source | Git blob | Bytes |
| --- | --- | ---: |
| `scripts/ui/witnessed/WitnessedCaptionLayer.gd` | `5c85ce306366917c995db06794e18cb4035b2711` | 84211 |
| `scripts/ui/witnessed/WitnessedAccessibleCaption.gd` | `c29b306199bf1b8f9ce4352872ff569e2b3f0bd4` | 1485 |
| `scripts/ui/witnessed/WitnessedSourceCanvas.gd` | `db11d71216b47004da8a3207acaac73e964cffa6` | 1107 |

All 28 reference and 28 candidate source snapshots are independently pinned in [verify.py](verify.py) and recorded in [verification.json](verification.json). The reference includes the established reconstruction and contract-test overrides from `4963a847`; only the three trace files differ between these retained snapshots.

## Original method and outcomes

The controller runs three explicit Capability, Create, and Load steps, each with its own ten-minute outer ceiling. The unchanged external driver retains its original 30-second action and 480-second journey defaults. Load uses `ProfileSaveLoad`, `ContinueAfterQuiet`, `TraceDay5`, and `NativeReadyCaptions`. Its existing environment sets `DWM_SAVE_LOAD_PROFILE=1`, `DWM_CHECKPOINT_PROFILE=1`, and `DWM_SAVE_LOAD_CONTEXT=exported-load-phase-diagnostic`.

The passive observer requires the existing profile flag and exact Load context; Capability and Create remain unprofiled. Cloud import, external-driver parsing, the four original deadline cases, export/package validation, and raw mode execution were retained. The prior 57/37 focused suites were not repeated for this passive diagnostic.

| Mode | Original result | Player exit | Driver exit | Clean player exit | Forced cleanup |
| --- | --- | ---: | ---: | --- | --- |
| Capability | Pass | 0 | 0 | Yes | No |
| Create | Pass | 0 | 0 | Yes | No |
| Load | Fail | -1 | 1 | No | Yes |

The original failure is `UIA_UNAVAILABLE_OR_TIMEOUT: TEST Seven-day ending.` The final raw gate retains both `load failed its original gate` and `Load driver process or step failed`. `continue-on-error` can normalize the individual Actions step conclusions to success; those conclusions do not replace original `result.json`, driver process receipts, or `diagnostic-acceptance.json`. The final workflow failed correctly.

The original ending wait expired after **30.0165036 seconds**. Its **47 ending action enumerations all returned zero matches**. Query completion times extend from **18.9534239 to 29.9973096 seconds** within that original wait. This failed before the connected ending → Gallery → normal exit journey could qualify. Sources inside the ZIP are `ci/exported-load/events.json`, `ci/exported-load/result.json`, `ci/load-process.json`, and `ci/diagnostic-acceptance.json`.

## Six bounded publication observations

Only `ci/exported-load/game.stdout.log` is projected: **108976 bytes**, SHA256 `9b43e4744933fdf621e8bf91afc887fca1e848344566d07c3ff353be9ba94b7d`. It contains six `DWM_ENDING_PUBLICATION_TRACE` records and 112 profile records. No secondary log stream is merged, and no nested timing groups are added together. The trace adds bounded logging overhead, so this run is not a fresh performance comparison.

| Emitted event | Records | What the retained sample shows |
| --- | ---: | --- |
| `text_started_enter` | 1 | Ending text present; original text-start callback entered before its normal guards and acknowledgement work. |
| `canvas_accessibility` | 1 | Existing element valid; natural Canvas setter writes `hidden=false`. |
| `caption_accessibility` | 2 | Existing element/provider valid; natural caption setter writes `TEST Seven-day ending.` with role `button`. |
| `text_finished` | 1 | Original synchronization completed; reveal finished; follow-up anchor recorded. |
| `text_finished_followup` | 1 | Sample occurs 2.015391 seconds after the text-finished anchor. |

All records bind to original Load PID **6308** and the same layer, Canvas, and caption instances. Canvas remains visible and not withdrawn in the six snapshots. The settled snapshots show inactive local Next, bridge Next, recovery, pause, load/history, and timed hold. The relevant nodes are inside the tree and not queued for deletion.

At follow-up, the cumulative caption-notification counter is **44**, although only **two caption-notification records** were emitted. At least 42 such callback records had therefore been omitted by the sampling cap at that observation. This is not a count of exactly 44 callbacks over the whole journey.

The maximum output is seven records per layer: two natural notifications for each of caption and Canvas, one text-start, one text-finish, and one follow-up. Natural callbacks remain eligible after the follow-up; later callbacks update fixed counters even when their output quota is exhausted. A missing record is not proof that the event never occurs. The verifier found no trace parse, schema, PID-binding, or sampling-bound violations.

At the settled follow-up, the root children end with `EndingScene` at index **15**, followed by the separate `DialogicLayout_WitnessedCaption` at index **16**; both indices include internal children. The caption's ancestry remains under that separate layout rather than under EndingScene. These are actual game-tree observations. Godot object IDs, window IDs, and accessibility RIDs must not be interpreted as native HWNDs or UIA RuntimeIds.

## Next bounded hypothesis

The recorded live owner state and natural setter calls narrow the next investigation to publication around the surrounding root-node order. A separate isolated candidate may test whether the EndingScene/layout sibling order at their confirmed mounting boundary affects exposure to the unchanged native action query. Existing EndingScene ownership is the bounded edit location; a new manager or broad recovery rewrite is not justified by these observations.

This is an experiment hypothesis, not a proven ordering defect or fix. Preserve the original driver, exact action names, process/window checks, 30/480-second deadlines, recovery controls, save/history guarantees, and raw failure reporting. Any focused owner/recovery check supplements the decisive original exported Load → ending → Gallery → clean-exit journey. Do not repeat the completed RawView/FindAll discriminator simply to restate the prior omission. Distinguish changes to sibling order from changes that explicitly request publication when assessing causality.

## Verification and custody

[original-evidence.zip](original-evidence.zip) is the untouched original **2535519-byte** ZIP, SHA256 **`bec3499cc753522d335f08db21e1f98461d8ca99953f13f4a2790a07c67f9904`**. Its [external receipt](archive-receipt.json) binds the run, job, source, tree, controller, byte count, and ZIP hash.

The verifier checked exact membership and hashes for **230 outer entries plus the manifest**, and **149 original per-mode entries**: Capability 22, Create 57, Load 70. All 56 source snapshots and the controller match independent pins, all six shared driver/settings files remain identical, and all three raw outcomes agree with the retained final gate. Final source status contains only the two predeclared legacy gitlink removals; 34 generated untracked entries remain separately visible in the report.

Run the retained verifier without executing game or driver code:

```sh
python3 verify.py original-evidence.zip archive-receipt.json verification-recheck.json
```

**Verifier exit 0 qualifies archive/source custody and retained harness checks. It does not mean the journey passed.** Read `original_journey_passed=false` and `original_acceptance_passed=false`. Diagnostic observations remain separate. The verifier is self-contained and requires no baseline index or local Godot/PowerShell. Its SHA256 is `18f8b60c9daeb89438bbb6c8113d60b552e1dccc11a903593af2a12e9683f555`.

The executable package is a separate Actions artifact: **12145334910**, `forward-profile-package-39152708408-1`, expiring **25 October 2026 UTC**. Its validation receipt binds `DWM-windows-x86_64-validation.zip`, **99457040 bytes**, SHA256 `bb7569051ec66df876938dc9c8fceba29e3387c6dde8964852d561b82f45951c`. All three mode receipts bind that same package and executable/PCK hashes. The executable ZIP bytes are absent from this evidence bundle and were not independently rehashed by this verifier. This distinction remains even though its source and package receipts agree.

The evidence ZIP contains full snapshots of the selected 28 sources for each role, rather than a complete Git object database. Complete repository ancestry and tree identity additionally depend on the independently reviewed commit pins and the pinned controller's checkout guards. Import errors were checked from the retained log; the original native import exit is enforced by the controller but has no separate exit receipt in this archive.

## Engine-source attribution qualification

The accompanying [engine-source-identity-note.md](engine-source-identity-note.md) records a mismatch between the executable's reported build revision and the official release-tag revision, successful corresponding source-file lookups, and failed commit/tree lookups. **Exact build-to-source-tree identity remains unverified.** Preserve both the successful and failed retrieval observations. The game-side trace remains evidence of its own executed calls; it does not establish an engine-internal defect or authenticate a complete engine source tree. The unrelated issue mentioned in that note supplies build-banner context only.

## Contents and remaining limits

This folder contains the original evidence ZIP, external archive receipt, independent verification report, self-contained verifier, this README, and the engine-source qualification note. The exact executable ZIP remains in the separately retained Actions artifact. No focused XML is expected from this passive run.

Original ending, Gallery, and normal Load exit acceptance remain missing. The next bounded order hypothesis has no result in this bundle. Runtime promotion, merge, broad CI acceptance, and source-to-engine causality are not established. No Godot or PowerShell ran locally while preparing or verifying this retention bundle; root remains the sole publisher.
