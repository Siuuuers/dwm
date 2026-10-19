# Run 39279335309 — retained result and offline timeline

Director instruction: https://github.com/Siuuuers/dwm/pull/30#issuecomment-6271681325
Run: https://github.com/Siuuuers/dwm/actions/runs/39279335309

## Outcome

The run completed with failure. Capability and Create passed with clean exits. Load failed `UIA_UNAVAILABLE_OR_TIMEOUT: TEST Seven-day ending.`, required forced cleanup, and did not establish clean player exit (player result exit -1; harness process exit 1). The capture step's continue-on-error normalization is not a pass: the final original-outcome gate correctly failed. Import/export, 30 Python preparation tests, four deadline cases and fresh diagnostic package smoke passed. This remains diagnostic evidence, not official engine or product acceptance.

## Custody

Original evidence artifact 12199553825 is retained byte-for-byte as `original-evidence.zip`: 1,960,221 bytes, SHA256 `477cef168d3c7e76f76d19198050866dfe132cc4003e5e486c2d9e8bfbf405c3`. CRC, exact 194-entry census and every one of 193 manifest payload sizes/hashes passed. `archive-verification.json` records the verification; `analyze.py` reproduces archive verification and `timeline.json` offline using Python only. Raw reports, process receipts, source overlays, snapshots, native probe, phase logs and source/EXE/PCK receipts remain inside that unchanged ZIP. `jobs.json`, `artifacts.json` and `job.log` retain API/log evidence.

Controller: `929423d0de7984e6fbfd90de292414bdafd62eb0`; preparation source: `d95ec53a38e8fecc859647724d5c8238b1b0112f`; frozen game: `81847d8b1560340a3a7769223cee0b46c6bdc0f9`; harness: `d37ad1f6d3c0148205c1b4d21444d05d01e7cca6`.
Reused diagnostic EXE SHA256 `f1f5a4b44d45c815f36bdc5649a0f1b37ff3ef9087c018aa298c880b6a9bdff2`; new PCK SHA256 `fdb87f1f8f275020f5117d2e91a41c2d0b27a96f35e3e6f0f1d0ada4f8f085f2`. All three journey reports bind those same digests. Package artifact 12199616439 remains on Actions (expires October 26); its original outer digest and size are in artifacts.json. The package binary is not duplicated in this evidence commit. Smoke confirms only isolated startup; the diagnostic engine is not promoted.

## Timeline and interpretation

All times below are UTC on October 19; the local Hong Kong date is October 19 for these events. Load PID 3068/HWND 786872 matches the game phase PID, harness target and later native probe.

| Observation | UTC | Meaning |
|---|---|---|
| Last invoke record | 15:45:32.995541 | Day7 closing action; not finish-ending; generic invoke record is not the requested finish-ending return anchor |
| Ending-caption wait start record | 15:45:33.201861 | 30-second budget |
| Ending checkpoint entry | 15:45:49.790 | About 16.588 seconds after wait record |
| Prepare return / commit entry | 15:45:58.292 | Prepare 8.497141 seconds |
| Caption wait end | 15:46:03.208014 | Actual elapsed 30.0060219 seconds; failure |
| Failure autosave copied | 15:46:03.221439 | Checkpoint 16, lifecycle PLAYING |
| Commit / checkpoint return | 15:46:06.210 / .212 | Commit 7.918463 seconds; full checkpoint 16.421435 seconds |
| Late native probe | 15:46:04–07.838 | Ending caption appears in diagnostic traversal after deadline; no acceptance |

There are 257 native observations for this ending-caption wait, all responds=false, zero caption-window-acquisition and zero caption-action-enumeration events. CPU increased 29.84375 seconds over the wait. The readiness guard prevented acquisition; there is no evidence here of an ending predicate mismatch. The checkpoint overlaps the latter part of this earlier wait and returns approximately three seconds after expiry. This is overlap evidence, not proof of exclusive causation or an estimate of uninstrumented latency.

There are **zero finish-ending invocations, zero finish-ending-invoke-return or New Acc wait anchors**, and no ending_completion, goto_menu, menu_mount or menu_first_idle records. Therefore binding phases to an actual New Acc deadline is impossible in this run: that boundary was never reached. Do not substitute the ending-caption wait for New Acc or silently apply conclusions from earlier runs.

Six game records have contiguous sequences, increasing same-process ticks, and no observed timing-write warning in retained game logs. UTC-minus-monotonic offsets vary by about 1.327 milliseconds across those records. This is an internal consistency check, not clock calibration: game UTC/tick samples are adjacent, harness event UTC is not an atomic stopwatch origin, and no cross-process monotonic conversion exists. Same-process phase durations are measured; relative UTC placements are approximate. Synchronous marker append/flush has observer cost; no ablation control was run.

The checkpoint result reports ok/code=ok and checkpoint17. `committed:false` is the helper's fallback for an absent field on the normal success result, not proof of rollback. Failure autosave16 was copied before checkpoint17 returned. No post17 disk snapshot is retained, so final durable checkpoint17 bytes/lifecycle are not established. Failure profile has no Gallery unlock; no COMPLETED state or clean exit is established. The late probe and publication state do not imply in-budget responsiveness.

## Smallest supported proposal; stop point

External C should independently review this new result and timeline. Internal independent review is in `independent-review.md` and does not replace C.

Next proposed slice: offline owner/caller review of the complete Day7-closing-to-ending-readiness operation, including checkpoint16 and17, using the already retained document/snapshot phase profiles. Checkpoint16 prepare/commit reports about 6.735/6.857 seconds; checkpoint17 about 8.497/7.917 seconds. Select one measured cost only after reconciling the sequence and save/recovery/history obligations. Any future optimization needs a matched complete-operation comparison; smaller code alone is not performance evidence.

Per Director's explicit stop, this commit contains evidence and analysis only. No redispatch, timeout/predicate changes, runtime surgery, engine promotion, master/integration movement, or acceptance claim. No further cloud run is needed to review this packet.
