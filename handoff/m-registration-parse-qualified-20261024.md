# Registration parse reuse qualified — 24 October 2026

## Result and current publication

PR [#77](https://github.com/Siuuuers/dwm/pull/77) is qualified for merge. Consult its live metadata for the merge commit; this record is written immediately before publication. The final qualified product/test snapshot is `c2c7411b50816b2571a6af3635f938df33263ae2`; inventory-only successor `fe73efbee464295b3dddb14fbc7472f42fd825f0` passed the read-only inventory gate. Subsequent changes in this PR only retain evidence and this handoff. Baseline master was `bb518236c741497d657b8b5bac19838b3ce1a4f0`.

One registration validation now shares parsed native timelines among entries with identical physical source bytes. The temporary scope belongs to `DialogicEntryManifest.validate_scene_registration`; `DialogicRuntimeAdapter` still owns compilation and per-entry projection. Public compilation starts with an empty scope, physical source reads remain fresh, translations bypass reuse, and native events never enter the process-wide primitive result cache. The projection body is unchanged. No schema, save policy, content, global cache or manager was added.

**Measured result:** complete launch to usable Title improved in both comparison orders. **New Acc remains slow**, with multi-second frame gaps. This is a bounded startup improvement, not a complete performance or release acceptance claim. No Steam upload or live-branch change occurred.

## Qualification

All engine and PowerShell execution occurred on Windows cloud runners using checksum-pinned Godot 4.6.3 standard. Local work was source/receipt review only.

- [Run 40094131174](https://github.com/Siuuuers/dwm/actions/runs/40094131174): controller failed before engine import/qualification (installation had printed the engine version). Its `Git` PowerShell function shadowed the executable case-insensitively and recursed. Renamed to `Invoke-ControllerGit`. The reviewed controller also adds a bounded editor import and explicit focused-log error scan.
- [Run 40094289837](https://github.com/Siuuuers/dwm/actions/runs/40094289837), controller `630d3e3e4a357364ad68418c2924a74caa73867b`: native baseline-first comparison passed. Focused suite was 151/165; its failure artifact is retained.
- [Run 40094723213](https://github.com/Siuuuers/dwm/actions/runs/40094723213), controller `aaaf82e5031129a2170a89e9b19dae731698a5b8`: repaired candidate passed **165/165 tests, 7,734 assertions, zero failures/skips**, ten complete suites. Candidate-first native comparison passed. Both inventories generated and reproduced.
- [Run 40095531928](https://github.com/Siuuuers/dwm/actions/runs/40095531928), controller `605629140e505932c39e2943f708a2672712195f`: committed inventories reproduced **without regeneration** at `fe73efb`; clean isolated check processes. GameState SHA256 `2175828c973519a4d823f0bacc196392b1951b0018c43f50bfaec705e3599bf4`; SaveManager SHA256 `fa14ce2a806169ea6238ccb5641734382a99fd54ad5e2537cc4b33d78e0e6169`.

The new repeated-validation test originally used `JSON.parse_string`, whose float-valued schema fields were rejected before compilation. It now uses canonical `StrictJson`; negative assertions also require the specific programme-hash/deleted-source refusal. The shipped-entry comparison uses the same strict reader. Two existing suites still expected the historical 137-entry default registry. Default tests now follow the installed 92-entry/seven-master authored week; explicit historical schema, locator-mutation, overlap and retirement checks remain. No tests were dropped. Independent review confirmed owner alignment and the unchanged test census.

Inventory differences are only shifted reference locations and expected lexical references in the revised catalogue fixture; public declarations, signatures, dispositions and required contracts are unchanged. Set-based diffs are retained alongside the generated artifacts.

## Complete-operation timings

Seconds; each row is baseline → candidate on the same runner. Each runtime had its own initially empty user profile, then a retained-profile process.

| Operation | Baseline-first pair | Candidate-first pair |
|---|---:|---:|
| Fresh launch → usable Title | 16.436 → 11.911 | 16.838 → 12.802 |
| Retained launch → usable Title | 15.695 → 11.393 | 15.719 → 11.878 |
| Fresh New Acc → complete first caption | 13.066 → 13.051 | 14.243 → 13.559 |
| Retained New Acc → complete first caption | 14.025 → 13.880 | 14.726 → 14.056 |
| Retained confirmation → complete first caption | 13.925 → 13.780 | 14.632 → 13.954 |

Title improvement is approximately **24–28%**, or **3.84–4.53 seconds**, across these observations. In the first pair, bootstrap itself fell 5.962→1.917 s fresh and 7.422→3.325 s retained; the reduction is not merely pre-bootstrap host timing. New Acc is effectively flat in one pair and modestly faster in the other. Candidate frame gaps remain about **8.57–8.86 seconds**, so no meaningful New Acc responsiveness fix is claimed.

Eight native processes across the two comparisons recorded actual button input, expected retained-profile consent, exact completed `line.Day1.one`, active session, idle New Acc owner, no incomplete continuation journal operations, and clean exit code 0. All twenty capture hashes were verified and every distinct visual state reviewed; Titles/consent are byte-identical across cases, captions differ in the clock. No gameplay log errors/warnings. Editor imports on both sides emit the same ObjectDB leak warning. The immediate resume phase's `ok:false` occurs on both sides because the timing wrapper only records the immediate boolean; eventual completion/journal checks pass. Do not describe every individual phase as a synchronous success.

These are source-project launches under D3D12 Forward Plus/Microsoft Basic Render Driver, not the installed Steam executable or the player's GPU. Fresh profile does not mean cold OS cache. Two paired comparisons are not a latency distribution. No exact candidate parser-invocation count was measured; compilation-request counters must not be described as parse counts.

## Durable evidence and next work

[Evidence directory](../evidence/phase_2r/registration_parse_20261024) contains the original focused/native/read-only artifact ZIPs, per-member size/SHA256 manifests, aggregate results, inventory diffs and exact controller reconstruction patches. Runtime overlay source is pinned to `3ed9cf1fd51cc1910d1d2a96fb4eb87784bb822c`; the six overlay bytes were identical in both runtimes and never replaced compiler/manifest code. Existing [handoff k](k-startup-new-acc-attribution-20261024.md) preserves its source reconstruction. Controller helpers/workflow remain isolated from the product branch. No cloud job remains pending for this qualification.

The next observable outcome should be **shorter New Acc input/confirmation → fully drawn first caption, with a reduced maximum frame gap, identical durable effects and ordinary save behavior**. Start from current master after checking PR #77's merge. Read existing `results.json` phase evidence before new instrumentation. The prior attribution identifies repeated configuration/bundle validation and participant-plan work during preparation and resumption; their inclusive timings overlap and must not be added. First identify the dominant remaining repeated work and its canonical owner; measure the full operation before choosing another surgery. Do not extend the new parse scope into a persistent native-event cache.

The font corruption report is still unresolved. It needs the original corruption screenshot, affected screen/locale/font style/text size/window resolution, installed Steam BuildID or exact package hashes, and whether Readable mode changes the same screen. This does not block New Acc profiling. The old master Steam workflow pins an earlier runtime; do not dispatch it assuming it uploads current master. Steam deployment is a separate task.

This is a useful fresh-session boundary: startup optimization is qualified and its evidence retained; remaining New Acc work is a different measured bottleneck. No product-design question is currently blocking that investigation.
