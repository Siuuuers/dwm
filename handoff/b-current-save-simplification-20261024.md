# Current-build Backup simplification handoff — 24 October 2026

Status: PR [#59](https://github.com/Siuuuers/dwm/pull/59) merged as `87ed3a1aafb68aafccfaf3faa7aeb1bdec8bc75c`. Qualified source `91704781f81c3fdcf1c397f937acdcbeb4ed04c8` and merge have the same tree, `15354cb42c1d8a8279af248c29549dc16a109758`.

Opening Backup now reads basic slot metadata without preparing restoration. Load prepares the selected current snapshot once, without an older-checkpoint fallback. Save and Delete do not require the prior file to pass restoration checks. SaveManager remains the owner; connected transaction machinery still needed to apply current state correctly is retained.

## Final cloud acceptance

Full CI [40014024806](https://github.com/Siuuuers/dwm/actions/runs/40014024806) passed: 30 successful jobs and one intentionally skipped native-comparison job. Its 25 matrix suites passed 2,796 primary cases; the public-surface suite passed 11. The combined 2,807 primary executions made 155,313 assertions, with no failures, errors or skipped cases. Three separate fresh-process Load cases passed another 195 assertions. These are execution counts, not a claim of 2,807 distinct behaviors.

The native comparison was already qualified in [40010510207](https://github.com/Siuuuers/dwm/actions/runs/40010510207), with the seven measured runtime files matching the final source. Do not add its repeated coverage to the final primary count. Backup UI verification passed 17,011 checks; manual-witness/revision/storage verification passed 61,180 assertions. The latter exercised 94 distinct snapshots, 30 refusal pairs, 1,604 restart-fault pairs, 2,218 restart pairs, 154 write-fault pairs and 14 write pairs.

Two intentional storage-refusal child runs each produced 83 cases: 80 expected root refusals and three storage-free passes, exiting 1 as designed. Their preserved XML contains expected failure elements; these are reported separately, not counted as passing primary coverage. Inventory diagnostic [40013436598](https://github.com/Siuuuers/dwm/actions/runs/40013436598) is provenance only, not additional coverage. All Godot execution ran on cloud runners.

## Matched native result

One baseline-first pair in retained artifact member `ci/startup-load-comparison/comparison.json` compares baseline `3ed6d3b0d8d69f2b2aa6e95855ba2b5c5f65211e` with the seven candidate runtime files below. Both rendered Windows variants passed `test_genuine_ending_load_save`: one case and 112 assertions each, zero JUnit failures/skips. Both seed and test processes exited 0, with separate per-variant user roots.

Seconds; decrease is relative to this pair's baseline:

| Operation | Baseline | Candidate | Decrease |
| --- | ---: | ---: | ---: |
| Boot helper | 48.725959 | 48.150862 | 1.2% |
| Title → Backup press return | 39.020994 | 0.923900 | 97.6% |
| Complete Load helper | 312.803923 | 136.429109 | 56.4% |
| Load action → Ready | 233.637087 | 133.844274 | 42.7% |
| Ending → Backup press return | 45.813926 | 7.471516 | 83.7% |
| Complete Save helper | 195.129515 | 84.653772 | 56.6% |
| Save action press return | 147.674720 | 75.569936 | 48.8% |
| Whole variant wall time | 579.458703 | 290.775119 | 49.8% |

The helper starts its boot clock after process startup; it is not launch-to-Title latency. Complete Load and Save include verification and captures. Press-return timings include the existing five frame waits. Nested measurements overlap and must not be summed. This is one ordered pair, not a latency distribution or an order-independent performance guarantee. The remaining 133.844-second Load-to-Ready and 75.570-second Save press-return pauses are substantial.

## Source and input provenance

The comparison records candidate event ref `c10078366f941f2e194278a9f3e147f7a37d54f5`. Do not relabel this as the PR source SHA. Independently hashing Git blobs verifies all seven measured candidate file hashes match both runtime commit `794777c675c58faa8cf25115236287d689699786` and PR head `91704781f81c3fdcf1c397f937acdcbeb4ed04c8`. The latter changes no `autoload`, `scripts`, `scenes` or `project.godot` bytes from the former. All seven baseline hashes also match the recorded baseline ref. The controller uses one candidate checkout and replaces exactly the listed runtime files with baseline bytes, retaining the same helper and 40-file input.

| Runtime file | Measured candidate SHA-256 |
| --- | --- |
| `autoload/SaveManager.gd` | `bcf6638b22c96d1f37817bc9e8308b87a360f7cd1fa861263b2d523fe1d608c9` |
| `scripts/application/backup/BackupPresentationPort.gd` | `5dbbe86cf9aad515211f8390a79297d5f56de8c7de2229229b3838bab0fc198b` |
| `scripts/ui/BackupApp.gd` | `00b437d6bf20291dcdc8743c0907f1a00252bb3d10bbd79347dcb8c226606857` |
| `scripts/ui/dating/DatingQuickCommands.gd` | `4635e0d8de4e69142d98924c26fc4550d96970037107f98d6f0eb6f7921920da` |
| `scripts/ui/desktop/DesktopQuickCommands.gd` | `c91c29ca533cbb46bcc7ab58e0bb406ef124dfce79cdb4ffd5a600c52664b473` |
| `scripts/ui/desktop/QuickStatusEdge.gd` | `006dc4a10cb21436e5e7339c8365069dcabb51cdc08cacfe80c411dbdbc0a577` |
| `scripts/ui/pause/PauseQuickCommands.gd` | `a1ed81294f14389524e2bd5dadd8b285fbc86e45431ae5d0b5d37a96258ae6b3` |

The retained helper archive SHA-256 is `c49053565e4b9430f2e9f0157eea9c1602898156de13df2837ca714235279670`. `comparison.json` records individual hashes for `pair.gd`, `pair-next.gd`, `seed.gd` and `replay.gd`. Both runs report original source-slot SHA-256 `17934c8199a7d25f97c69890f0ca609e5106c6bb6dc187464d58c40d2baf987c`.

## Preserved behavior

Both `terminal-pair.json` records finish with `complete=true`, empty pending phase and observed line `line.ending.alone.normal.001`. The authored result records agree exactly on restored snapshot, narrative checkpoint, native presentation and Profile. Native presentation is visible, fully revealed (`visible_ratio=1`, `revealing=false`) and DONE (`event_done=true`), with the same caption ledger. Both Profiles retain exactly one Gallery receipt and one unlock, with Profile SHA-256 `40a3166a287790295a5270a42934337fc7bdd5f63c759d193d0d555c89c71f43`. Registration SHA-256 is `33be6b0a64cbad7105dcd397e10a5be0ff7b90e0fb27d8100380a2050a1eb33a`.

The saved output-file hashes differ between variants; the evidence establishes identical reported gameplay/Profile state, not byte-identical output save files. The compact evidence retains post-Load and post-Save PNGs for both variants. The root coordinator independently reviewed these rendered images.

## Why it improved, and next target

The logs record 56 Backup inspections in each variant, but full restore preparation falls from 20 calls to one selected Load. Total measured inspection time falls from 304.243 to 5.960 seconds; that aggregate overlaps the complete-operation clocks. Day-resource loader messages fall 15 → 12 and are not a physical-read counter. This supports the intended mechanism: listing and refresh no longer prepare restoration.

The remaining candidate Load helper records 236 bundle validations and 114 receipt/physical-proof calls; Save records 226 bundle validations and 108 receipt/physical-proof calls. Receipt-validation inclusive time remains 60.551 seconds in Load and 57.978 seconds in Save; these nested totals are not independent costs. A useful next investigation is repeated validation of the same current-state material during one operation, while retaining exactly-once consequence handling and correct state application. Measure a complete matched operation before accepting another optimization. No conclusion here justifies deleting the continuation path blindly: it also drives successful Load activation.

This pair covers the retained ending Save/Load/Continue journey. It does not rerun an uninterrupted authored week, all branches/boards, Steam packaging, installation, release acceptance or malformed/old-save support. The approved contract excludes compatibility repair and checkpoint fallback; low-level machinery still used by successful current-state transactions is a separate simplification task.

## Durable evidence

[`results.json`](../evidence/phase_2r/current_save_20261024/results.json) records source, merge, exact count groups and archive provenance. [`exact-evidence.zip`](../evidence/phase_2r/current_save_20261024/exact-evidence.zip) preserves 224 selected members from 38 verified source archives as 192 deduplicated objects, plus manifest and count inventories. Bundle SHA-256: `f6d0acade17fb14dcee62ce9b3aa3cb5ca605f10418feddec28291cf7524f93e` (2,734,706 bytes).

The manifest explicitly lists 330 excluded member paths with original hashes and metadata; those bytes are not retained. Full native comparison members, all final JUnit, relevant result/proof/summary/verification logs, final CI metadata and merge proof are retained. Bulky final captures and runtime/user-root data are omitted, as are duplicate generated inventories and verbose speech traces. The 110,865,501-byte Windows export distribution is excluded entirely; its GitHub metadata and completed export job API log are retained. Original ZIP containers are not preserved. Each included member maps to its exact `objects/<sha256>` bytes.

## Next work

PRs #60 and #61 completed the follow-up batch. Continue from [the final current-save handoff](c-current-save-final-handoff-20261024.md), which records their merged sources, complete cloud acceptance, measured tradeoffs and the next bounded retirement pass.
