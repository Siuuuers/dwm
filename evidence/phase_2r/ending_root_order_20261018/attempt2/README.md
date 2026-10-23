# Ending root-order experiment: corrected retry

Updated 19 October 2026 Hong Kong time (18 October UTC).

**The archive and focused recovery suite qualify, but the original exported Load still fails the ending-caption gate. The intended sibling order is observed; that change alone is insufficient in this pinned diagnostic run. Do not promote this runtime or proceed with the conditional composed controller on this evidence.**

The first attempt stopped at unexpected missing-metadata errors. This retry adds the reviewed metadata-presence guards in the EndingScene helper and its fixture, then exercises the same eleven focused methods and original native driver. Its negative native result is retained independently of the authentic archive and passing focused suite.

## Exact identities and scope

| Item | Identity |
| --- | --- |
| Original cloud run | [39155624496](https://github.com/Siuuuers/dwm/actions/runs/39155624496) |
| Original job | [117758138682](https://github.com/Siuuuers/dwm/actions/runs/39155624496/job/117758138682) |
| Corrected candidate source | `81847d8b1560340a3a7769223cee0b46c6bdc0f9` |
| Corrected candidate tree | `4581a9f12d63684836c722f72cffd533491f3c06` |
| Actual candidate parent | `a25fae335247ba8074ea01d44990b3c6cd00f8ba` — the retained stopped attempt |
| Experiment reference source | `337c2d43e9ff508575f772b1c1b7cf5679be8d0f` |
| Reference tree | `1e4e752bd8e532f2e731dfc483be40fcff3bd3fc` |
| Reference trace run | [39152708408](https://github.com/Siuuuers/dwm/actions/runs/39152708408) |
| Controller | `cf1ffe0ec204cc51ecc532e4a95136f9177577d1` |
| Controller tree | `738a6b7130652ddd6a14915aa542348389f2e44d` |
| Controller workflow | `.github/workflows/scene-first-reveal-profile-diagnostic.yml` |
| Controller workflow SHA256 | `fc5fd9d673033b9326ba592e3c5fb2dafe8c1216c146bc6ff39826041f35535c` |
| Cloud engine/runner | Godot 4.6.3 standard GDScript; Windows Server 2022 |

The exact two changed files versus the experiment reference are:

| Source | Corrected candidate Git blob | Bytes |
| --- | --- | ---: |
| `scripts/ui/EndingScene.gd` | `dec4979b1d6331a22aac268b4b2a926e70a601eb` | 15926 |
| `tests/scene/test_ending_recovery_localization.gd` | `0c09f6843e17e9f0611327519376c71248228656` | 16640 |

The six driver/settings files and all three existing passive trace files remain byte-identical to the reference. The retry controller differs from its predecessor only in the candidate source and tree pins. It retains three separate ten-minute Capability/Create/Load steps, the original **30-second action and 480-second journey deadlines**, Always accessibility, Dummy audio, and ProjectDefault renderer. Load retains `ProfileSaveLoad`, `ContinueAfterQuiet`, `TraceDay5`, and `NativeReadyCaptions`. The same existing Load environment enables the passive trace; no new flag or test is introduced by the retry.

## Separate original outcomes

| Gate | Original result |
| --- | --- |
| Import, original driver parser and deadline checks | Pass; all four expected deadline cases retained |
| Focused ending recovery | **11 methods, 142 XML assertions, zero failures/errors/skips**; isolated and outer process exits 0 |
| Export/package validation | Pass; original release export, packaged data audit and isolated headless startup |
| Native Capability | Pass; player exit 0, driver exit 0, clean player exit, no forced cleanup |
| Native Create | Pass; player exit 0, driver exit 0, clean player exit, no forced cleanup |
| Native Load | **Fail**; player exit −1, driver exit 1, no clean player exit, forced cleanup |
| Final original acceptance | **Fail**; preserves both original Load failure reasons |

The focused suite is `tests/scene/test_ending_recovery_localization.gd`, running headlessly with simulated input/focus and its unchanged 180-second ceiling. It completes in 18.0919601 seconds. Its generic `ERROR:` guard finds no engine errors. Exact per-method assertion counts and source-to-XML census are in `ci/focused-results.json`, the original XML/process/log files, and [verification.json](verification.json). These scene-integration checks do not establish native UI Automation or pixel-rendered recovery behavior.

The raw Load failure is `UIA_UNAVAILABLE_OR_TIMEOUT: TEST Seven-day ending.` Its original result records 231.5087116 seconds; the outer driver records 232.5206807 seconds. These durations include failure diagnosis and cleanup. They are neither successful journey durations nor a new performance comparison. `continue-on-error` normalization of an Actions step cannot replace the raw result, process receipt, or final gate.

## What the original ending wait observed

The one original ending wait starts at **2026-10-18T18:53:58.7332112Z**, with a 30-second deadline. Its final record reports **30.0222674 seconds**. This records loop/return overhead after the unchanged deadline; it does not extend the acceptance window.

There are **14 original action enumerations, all returning zero matches**. The first Window acquisition runs from 26.6716288 to 26.6995454 seconds into that wait. The first enumeration runs from 26.7161978 to 26.772564 seconds; the last runs from 29.9208932 to 29.9762196 seconds. The exact sequence remains in `ci/exported-load/events.json` and [independent-inspection.json](independent-inspection.json). No late or missing match is converted into acceptance.

The canonical `ci/exported-load/game.stdout.log` is **109105 bytes**, SHA256 `4784bd05e387fe9c6e84790c99c86449a38c159153147955f0e2ef293be5af51`. It contains six valid `DWM_ENDING_PUBLICATION_TRACE` records with PID **7264**, matching the original Load player, and one stable live caption layer. The native driver separately records HWND **524500** for that player. This process-level match does not map a Godot object ID, window ID or accessibility RID to HWND/UIA RuntimeId. The stdout was parsed as one primary stream; no secondary log was added to the count.

| Original event | Process frame | Approximate seconds into native wait | Layout / EndingScene root indices |
| --- | ---: | ---: | --- |
| `text_started_enter` | 1827 | 26.411 | 16 / 17 |
| `canvas_accessibility` | 1827 | 26.459 | 15 / 16 |
| First `caption_accessibility` | 1827 | 26.460 | 15 / 16 |
| Second `caption_accessibility` | 1829 | 26.501 | 15 / 16 |
| `text_finished` | 1831 | 26.547 | 15 / 16 |
| `text_finished_followup` | 1915 | 28.559 | 15 / 16 |

Root indices include internal children. The first sample still contains the retiring `SceneHost` at index 15; subsequent samples no longer contain that queued node. The caption layout and EndingScene retain the same live identities. Every sample already has the intended layout-before-EndingScene order. The trace does not record the move call itself or prove uninterrupted order between samples.

The canvas callback reads a valid existing element and writes `hidden=false`. The caption callbacks read a valid element/provider and write the exact ending name with button role. At the retained settled samples from the natural canvas callback through follow-up, the canvas is visible and not withdrawn, the presented line is accepted, and Next/bridge activity, caption-owned reading recovery, Pause coverage, Load/History and timed hold are inactive. `reading_recovery_empty` does not observe EndingScene's recovery-panel visibility. These are sampled states, not proof of continuous inactivity. They precede the first original enumeration and recur during the query interval; the native query nevertheless returns zero matches.

The follow-up occurs **2.012159 seconds after the actual text-finished synchronization anchor**, or 2.147998 seconds after the text-start anchor. Its cumulative caption callback count is **46**, while only **two** individual caption callbacks were emitted: **44 callbacks lack an individual output record by that observation**. The cap is two natural callback records per kind, at most seven records per layer overall. Six records are present here. Natural callbacks remain eligible after follow-up. This is bounded sampling, not a full publication trace or proof that no later callback occurred.

The approximate alignment in the table uses game `unix_seconds` and native UTC on the same runner. The game values have millisecond reporting; game `ticks_us` and the external driver's Stopwatch remain separate clocks. Native deadline and enumeration durations above come directly from their own original records. No Godot object ID, accessibility RID, or internal window ID is mapped to HWND/UIA RuntimeId by this evidence.

## Captures, saved witnesses and the unaccepted tail

All capture receipts match their retained PNG bytes: eight Capability captures, twenty-five Create captures and twenty-one Load captures. Independent visual inspection of the original `failure.png` shows `TEST Seven-day ending.` and the six History, Save, Load, Skip, Auto and Next controls. That image was captured at **18:54:33.0320740Z**, approximately **4.276 seconds after the ending wait ended**. It establishes visible pixels at that later capture, not their presence throughout the original deadline.

The original later `failure.uia.json` contains 23 descendants, beginning with Continue, Backup, Settings and Return to Title, followed by audio groups. The ending caption is absent. This preserves the observed native omission; it does not identify its cause or justify another duplicate hierarchy/query diagnostic campaign.

The retained source and restored saves preserve the compared narrative checkpoint, gameplay, scene, command receipts, applied effect IDs and applied variable IDs, with the same run and a new branch. The saved frontier is `line.Day4.two`. The retained Slot1 captures match Create's bytes. The retained profiles are byte-identical across Create completion, before Load and after the witness save. Load fails before its final post-exit source-slot hash guard; that guard did not pass or even run. These are concrete retained witnesses, not continuous immutability certification. Separately copied live files are not an atomic multi-file checkpoint and do not establish arbitrary saved-document equivalence.

There is no `completed-autosave.json` in this failed run. Ending activation, completed lifecycle with `GALLERY_RECORDED`, exactly one durable ending Gallery transaction/unlock while preserving all prior Gallery receipts, Title return and normal Load shutdown remain **unqualified**. Those are the unchanged driver's later checks. The driver **does not open Gallery UI**.

## Integrity, reproduction and executable custody

[original-evidence.zip](original-evidence.zip) is the untouched **2566525-byte** archive, SHA256 **`d3fe288fe60167a2dda044c7a2d8962b0c88c789a5044f4347cb9b78993544cc`**. Its original run/job/source/controller receipt remains in [archive-receipt.json](archive-receipt.json).

The shared, independently peer-reviewed [verify.py](../verify.py) checks the external receipt, exact **241 ZIP members / 240 outer-manifest payloads**, **149 per-mode manifest entries** (Capability 22, Create 57, Load 70), **30 reference plus 30 candidate source snapshots**, exact controller, unchanged harness/trace bytes, focused source/XML/process/log gates, original native outcomes and source-cleanup allowance. The complete source/controller snapshots are inside the original archive. The full repository ancestry/tree pin additionally relies on the externally reviewed commits and pinned checkout guards; this ZIP is not a full Git object database.

The verifier SHA256 is `052ee52a800693653a8a05d5de9889e6b2cce04f52976580c2cb3bc0747b8da6`. This attempt's [verification.json](verification.json), SHA256 `6734176d484cec03e7e3975011ea4b6c5f00026caeab2a1d9510221ae2b4dab8`, reproduces byte-for-byte using Python alone. From this published attempt directory:

```bash
python ../verify.py original-evidence.zip archive-receipt.json verification.json
```

The verifier's expected exit is **0** for this retry: archive custody, retained harness and focused suite qualify. The report explicitly retains `original_journey_passed=false` and `original_acceptance_passed=false`. Exit 0 is not native journey acceptance. Launched native modes must retain their original redirected stdout/stderr and events; missing evidence is distinguished from an unexecuted or failed mode. [independent-inspection.json](independent-inspection.json) separately records the raw outcome, query, trace and capture analysis.

The executable remains in Actions artifact **12146662424**, `forward-profile-package-39155624496-1`, expiring **25 October 2026 UTC** according to the original Actions metadata. Its outer Actions artifact is 99395260 bytes with digest `9a3093964f5d49ed94c9eaf4375a9e99c0e19c4707c780957c24500c47f7a775`. The inner `DWM-windows-x86_64-validation.zip` has its own export receipt: **99457801 bytes**, SHA256 `7c3053d2073fc3caee98dc5c038e720d5e860952375039d0db054dcd14812eb8`. These two archive identities must not be substituted for one another. The inner executable ZIP is absent from this evidence ZIP; its raw bytes were not independently rehashed during this retention pass. The export receipt and all three mode receipts bind the inner package, executable and PCK to the candidate source.

The retained final tracked status contains only the two previously permitted legacy gitlink removals; generated untracked entries remain visible. No source mutation is hidden. No engine-source causality is claimed: the prior engine source-identity qualification remains unresolved at the complete build/tree level, even where selected source-file contents were obtainable.

## Decision and remaining uncertainty

The sampled owner order changed as intended and natural accessibility setters executed, but the original ending action remained unavailable. **Root sibling reordering alone does not resolve this run's failure.** This result does not prove that every conceivable ordering change is irrelevant, that the engine accepted a complete reachable provider subtree, or which publication boundary failed.

Retain both attempts as evidence. The conditional composed controller is canceled and unvalidated. Ending runtime promotion, PR36 merge, final journey acceptance and a new performance claim are not established. PR36 remains draft and unmerged. Any next investigation needs evidence that addresses the remaining gap between game-side caption state and a reachable native action; repeating the already observed root order or query count does not close that gap. No Godot or PowerShell ran locally while preparing this bundle, and root remains the sole publisher.
