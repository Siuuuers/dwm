# Ending root-order experiment: initial stopped attempt

Updated 19 October 2026 Hong Kong time (18 October UTC).

**The original evidence is authentic. The focused recovery suite failed, and export plus all three native modes were not executed.** This retained attempt supplies no native caption-exposure, root-order-publication, durable Gallery award, Title-return, or normal Load-exit result.

The experiment tested a bounded EndingScene sibling-order change while preserving the existing caption owners, passive trace, original external driver, and save/recovery/history guarantees. Its required headless scene-integration gate exposed missing-metadata errors before the controller could proceed to export or gameplay.

## Exact identities

| Item | Identity |
| --- | --- |
| Original cloud run | [39155054285](https://github.com/Siuuuers/dwm/actions/runs/39155054285) |
| Original job | [117756447001](https://github.com/Siuuuers/dwm/actions/runs/39155054285/job/117756447001) |
| Failed candidate source | `a25fae335247ba8074ea01d44990b3c6cd00f8ba` |
| Failed candidate tree | `6c44631f8f926461d86b44f29c25c970c22218e9` |
| Parent/reference source | `337c2d43e9ff508575f772b1c1b7cf5679be8d0f` |
| Reference tree | `1e4e752bd8e532f2e731dfc483be40fcff3bd3fc` |
| Reference trace run | [39152708408](https://github.com/Siuuuers/dwm/actions/runs/39152708408) |
| Controller | `fb8377d546b32542975b867e76de51a619d047ab` |
| Controller workflow | `.github/workflows/scene-first-reveal-profile-diagnostic.yml` |
| Controller workflow SHA256 | `ed689d71b8df6d22b677906b8935547cb1cd1fdf139079e0eb1d0f608b58f559` |
| Cloud engine/runner | Godot 4.6.3 standard GDScript; Windows Server 2022 |
| Focused suite | `tests/scene/test_ending_recovery_localization.gd` |
| Focused scope | Headless scene integration with simulated input/focus; 180-second isolated ceiling |

The two changed source files in the failed candidate are:

| Source | Failed candidate Git blob | Bytes |
| --- | --- | ---: |
| `scripts/ui/EndingScene.gd` | `6f4ebb80cef316aa4db0cee940a30eb38d08487d` | 15872 |
| `tests/scene/test_ending_recovery_localization.gd` | `babcce483346163a891c2a7c3ef36eabc6522835` | 16616 |

The six driver/settings files and three existing passive trace files remain byte-identical to the reference. The archive includes 30 complete source snapshots for each role plus the exact controller. These failed source bytes are preserved independently of the subsequent correction.

## Original focused failure

The source-derived census and original XML agree on **11 methods and 144 recorded assertions**. Nine methods passed; the two newly added methods failed because GUT recorded unexpected engine errors:

| Failed method | XML assertions | Original failure |
| --- | ---: | --- |
| `test_later_playback_failure_keeps_retry_focus_and_replays_the_same_command` | 24 | Two unexpected engine errors reported at the test boundary |
| `test_deferred_order_refresh_ignores_retired_scene_and_freed_layout` | 10 | Two unexpected engine errors reported at the test boundary |

XML contains two `failure` elements, zero `error` elements, and zero skips. The distinction is deliberate: these engine errors are represented by GUT as failed test cases. Both the isolated Godot wrapper and outer focused process exit with code **1**. The outer focused step recorded **14.4391994 seconds**, well within the unchanged 180-second ceiling.

The log retains four instances of:

> ERROR: The object does not have any 'meta' values with the key 'dialogic_layout_node'.

Two originate in the new fixture's `_mount_root_ending` read at `tests/scene/test_ending_recovery_localization.gd:115`; two originate in the new runtime helper's `_sync_recovery_root_order` read at `scripts/ui/EndingScene.gd:142`. Their stacks identify the missing-key `get_meta` calls. The explicit behavioral assertions display passing results, but those results do not clear the unexpected-error failures. The focused gate correctly rejects process failure, failed XML, and generic `ERROR:` log lines.

The original evidence paths are `ci/ending-recovery.xml`, `ci/ending-recovery.jsonl`, `ci/ending-recovery-process.json`, `ci/focused-results.json`, and `ci/focused-logs/ending-recovery.log` inside the ZIP. The failed `focused-results.json` remains unchanged.

## Downstream stages were not executed

| Stage | Evidence status |
| --- | --- |
| Import and original external-driver parser | Completed; retained checks pass |
| Four original deadline cases | Completed; all four pass |
| Focused ending recovery | Executed and failed |
| Export/package validation and package upload | Not executed |
| Original Capability | Not executed |
| Original Create | Not executed |
| Original Load | Not executed |
| Passive player publication trace | No player execution; zero records |

The final gate is `ok=false` with an empty `original_outcomes` array. It retains the focused failure and missing downstream mode/package reasons. Those umbrella gate messages do not show a native timeout or an attempted package-upload failure: the relevant stages were skipped after the focused failure. There are no exported-mode results, driver process receipts, native query timeline, or player stdout in this archive.

The original native controller still specifies three separate ten-minute mode steps, 30-second action deadlines, and a 480-second journey deadline, with Always accessibility, Dummy audio, and ProjectDefault renderer. These settings were preserved but not exercised in this attempt. A future successful Load tail would check completed lifecycle, `GALLERY_RECORDED`, one new durable Gallery transaction/unlock with prior receipt values unchanged, Title return, and normal shutdown. It would not establish Gallery UI coverage.

## Integrity and retention

[original-evidence.zip](original-evidence.zip) is the untouched original **760741-byte** archive, SHA256 **`d47951af394a5433b5b923409ea5d45d55c5292fb4321facf7589e38d55e842e`**. [archive-receipt.json](archive-receipt.json) retains its original run, job, source, tree, controller, byte count, and hash.

The separate coordinator-side [independent-inspection.json](independent-inspection.json) checks the exact **76 outer-manifest entries plus the manifest**, all **77 ZIP members**, all **60 source snapshots**, exact two-file source delta, controller bytes, unchanged harness/trace hashes, source-to-XML method census, original focused exits, error records, and partial final gate. It finds no custody or consistency issue. No per-native-mode manifest exists because no native mode ran. The original permitted gitlink removals and generated untracked entries remain visible in the archived final status.

The separately authored, independently peer-reviewed shared [verify.py](../verify.py) and this attempt's [verification.json](verification.json) support both the failed attempt and the corrected retry. The verifier's SHA256 is `052ee52a800693653a8a05d5de9889e6b2cce04f52976580c2cb3bc0747b8da6`; this attempt's report SHA256 is `581b7a784b3430084df40f771e318f7447488c6876bf9f491657ae1fdfddb36e`. The report reproduced byte-for-byte from the retained files using Python alone. From this published attempt directory:

```bash
python ../verify.py original-evidence.zip archive-receipt.json verification.json
```

The expected exit status for this failed attempt is **1**, because the focused suite did not qualify. Its separate fields are `archive_verified=true`, `harness_qualified=true`, `focused_suite_passed=false`, `original_journey_passed=false`, and `original_acceptance_passed=false`. All three native modes remain `not_executed`. The verifier requires original redirected stdout/stderr for a launched player and distinguishes missing executed evidence from an unexecuted mode. The original failed ZIP is never overwritten by the retry; authentic archive custody does not clear the focused failure.

No executable package was created in this attempt. This absence is expected from the stopped execution, not a missing binary attachment that could establish gameplay acceptance. Selected source snapshots and externally reviewed commit/controller pins establish the recorded source custody; this ZIP is not a full Git object database or engine source tree.

## Bounded correction and remaining work

The next candidate guards metadata absence before reading `dialogic_layout_node` in the runtime helper and its fixture. The original failed attempt remains preserved. The eleven test bodies, focused headless scope, generic-error rejection, original driver commands, and 30/480-second deadlines remain intact. A correction is qualified only by its own subsequent evidence.

No native result, publication-order conclusion, performance comparison, or source-to-engine cause claim can be drawn from this attempt. PR36 remains draft and unmerged; runtime promotion is not established. No Godot or PowerShell ran locally during inspection or retention, and root remains the sole publisher.
