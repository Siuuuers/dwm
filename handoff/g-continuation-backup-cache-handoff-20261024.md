# Continuation backup cache repair and the remaining Load cost

Continues [restore cost attribution](f-restore-cost-attribution-handoff-20261024.md). All Godot and PowerShell execution was on Windows GitHub Actions. Local work was source review, Git, artifact verification and report preparation.

## Product change and owner

The observable goal was to record the same ordered durable restore progress with less repeated work, retaining exact saved bytes, retry behavior and native Ready state. DesktopContinuationOperationJournal remains the sole journal owner; JsonFileStorage's atomic protocol is unchanged.

The journal's existing exact-text LRU now retains four documents instead of three. At the end of an ordinary write, the three-entry order was `[previous current, previous backup, outgoing]`. Inserting the next outgoing text evicted the previous current, which had become the backup needed by reconciliation. That backup was strictly parsed again on every subsequent write. The fourth entry absorbs this stale-backup overlap without changing validation, serialization, disk reads/hashes, writes, flushes, markers, renames or readback. Cost: one additional bounded detached journal document and text per journal instance.

The regression uses the actual JsonFileStorage with FakeFileOps. Across twelve writes, the historical three-entry control makes nine strict parses; the candidate makes zero. Every outgoing and backup byte array matches the canonical expectation. A fresh journal still strictly parses both physical documents. This is storage/cache coverage, not substitute scene-admission evidence.

The first broader focused run exposed two pre-existing persisted-input exceptions: an integer transaction ID compared with a string, and an array kind compared with a string. Two type guards now produce normal refusal instead of script errors. The public-method fixture now lists the fourteen APIs already present on master. No public API was added.

## Measurements and verification

Diagnostic run [40073066135](https://github.com/Siuuuers/dwm/actions/runs/40073066135), source `c312fab7fd5764daaa151bef7d7915ddff0ddbbc`, attributed the final ten progress updates: 29.880232 s total, 27.122112 s atomic storage, 1.254532 s proof-cache bookkeeping and 0.657772 s serialization. Nested components must not be added to their enclosing totals.

The deeper [40073625626](https://github.com/Siuuuers/dwm/actions/runs/40073625626), source `ee175b953a7f63ceb50292dde6c19af70c459c63`, measured 35.863364 s reconciliation inside 37.072254 s atomic storage (96.74%). Marker writes plus temporary-file write/flush totalled 0.040048 s. Reconciliation includes reads, decoding, hashing and callbacks; this was not an exclusive parser stopwatch. These two instrumented runs are not a matched performance comparison. Each passed two current cases / 213 assertions / three clean processes.

The comparison job in [run 40074198023](https://github.com/Siuuuers/dwm/actions/runs/40074198023) passed on one Windows runner, baseline first, with separate exact worktrees and identical helpers, retained input and engine. Baseline is `9db0b69f49266c26776dedd29e3b61a410c46002`; candidate controller `af817a6db0654b03676344fe06a210a1491fb288` has the same runtime as cache-only product `5882873aee5ab4f2e6ada282fdb260be670348d6`. Only the journal runtime file differs. Both variants passed two current cases / 213 assertions / three clean processes.

| Complete observation | Baseline | Cache-only candidate |
| --- | ---: | ---: |
| Fresh-process Load press to Ready | 102.201894 s | 53.918454 s |
| Earlier retained-input Load press to Ready | 129.337417 s | 86.494261 s |
| Save press to return | 52.385623 s | 52.584855 s |
| Complete helper journey wall time | 460.371637 s | 367.256245 s |

Fresh Load improved 47.24%; complete journey wall time improved 20.23%. Save was essentially unchanged. This is one baseline-first pair, not a latency distribution or a guarantee for other histories/hardware. The overall run retains its separate initial focused-job failure; only the comparison job passed.

Final product `b8defca3e7743d34e47af5853b7c3e43e4733490` adds the two malformed-input guards to cache-only product `5882873aee5ab4f2e6ada282fdb260be670348d6`. Final verification controller `1c4932059963da071f74d505a8bd931eb209ce62` differs from final product only by its workflow. [Run 40074441693](https://github.com/Siuuuers/dwm/actions/runs/40074441693) passed both jobs:

- 75 focused cases / 3,743 assertions; clean exit and no checked script errors. The new cache regression passes 104 assertions.
- Native Save followed by Load in a distinct process: two current cases / 213 assertions / three clean exits. Exact slot bytes and unchanged Profile/Autosave checks pass; the restored complete caption is visible and readable.

The final source's separate native observation was 57.923055 s Load press to Ready, 12.370893 s restore preparation and 17.652572 s synchronous transaction. `scene_activation_pending` is the normal synchronous handoff, not a failed native Load. Do not present the earlier cache-only pair as an exact timing measurement of the later guards. No full release suite, uninterrupted authored week, Windows export or Steam upload was run in this batch.

The initial focused job in run 40074198023 remains failed: 73 passes, two failures and exit 1. The new cache regression already passed there. The later final run qualifies the corrections; it does not relabel the original failure.

## Next task

This is a useful fresh-session boundary: the measured journal-cache cause is repaired and qualified; the remaining delay is in another restore path. No product-design answer is needed before investigating it.

Use the retained final `fresh-save-load.log` before adding new probes. Its `fresh_save_load` scope records 42 receipt validations / 31.200315 s and 92 bundle validations / 19.065230 s. These are inclusive nested totals, not additive exclusive costs. SceneEventContract owns the receipt-validation observations. Begin by attributing work within that owner and its actual callbacks; choose one concrete repeated computation before changing code. Preserve fresh physical/issuer checks and callback refusal boundaries. The previous handoff's reason not to blanket-remove route validation still applies. Do not rerun the completed cache qualification to rediscover this result.

A separate static follow-up remains: `_intent_keys` compares an untyped prepare-request kind with a string. It is outside the persisted-input failures exercised and fixed here; do not imply it was tested or repaired.

## Publication and retained evidence

The product and tests are published with this evidence on `codex/continuation-proof-window-20261024`. Diagnostic and verification controllers stay on their separate branches; only the product/test changes and retained evidence belong in master. Final publication adds documentation/evidence to the already qualified product runtime.

Only historical drafts #14, #30 and #50 remain deliberately unmerged. PR14's head is already a master ancestor; the product work associated with #30/#50 is also incorporated, while their diagnostic workflow overrides remain excluded. This batch adds no diagnostic workflow to product.

[Results and exact source/artifact provenance](../evidence/phase_2r/continuation_proof_window_20261024/results.json), [diagnostic evidence](../evidence/phase_2r/continuation_proof_window_20261024/diagnostic-evidence.zip) and [acceptance evidence](../evidence/phase_2r/continuation_proof_window_20261024/acceptance-evidence.zip) retain current reports, XML, process records, logs, selected native captures and source patches. Manifests record original archive checksums and every original member's retention/omission. Original archives were SHA-256/size/CRC verified. Historical fixture reports are excluded from current passing counts. Independent source and evidence reviews are recorded in results.json.
