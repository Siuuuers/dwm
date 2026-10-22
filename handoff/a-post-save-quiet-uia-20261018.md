# A — quiet post-Save UIA diagnostic, 2026-10-18

## Result

The recorded next experiment is complete. Removing repeated UIA traversal after the witness-save file became readable did not restore native responsiveness during the existing 30-second observation interval. This narrows the prior hypothesis; it does not identify the originating game/engine function or prove earlier UIA activity irrelevant.

Run [39113018109](https://github.com/Siuuuers/dwm/actions/runs/39113018109), job117632952558, deliberately remains **failure / diagnostic-only**. Capability and Create succeeded with normal exits0. The loader reached the intended diagnostic stop, then required forced cleanup; no ending, Back return, Gallery completion, normal loader exit or full exported acceptance.

## Pins and scope

- Product base/unchanged runtime: 17683fba678968afde3b4144a692760fae74a7a8, PR36.
- Isolated diagnostic candidate: 146791302b2a0df4ca09a9deb5a3485ec10cb2fc, tree ae2946cd542e4360e03483a8db7679c55038428d; branch codex/a-post-save-quiet-uia-20261018.
- Only candidate code change: tools/testing/Invoke-ExportedGameplay.ps1, blob b0aca70231e0ea48e43abecbe04d0c936a5e433d. Do not compose this intentionally stopping experiment into the normal driver.
- Controller: cf6fe7c476be7da6a268c6a0870f812d35092fe6, workflow blob81ad1a2a103352687ad9133312b8540aa50f371e.
- Same retained package artifact12127144275 from run39103588380, product source bb167aa1b5692f6bf5ceb6789201f38d4f86360a. ZIP SHA256625fad0d7ab746c6413192f82db6b461e9db05f40634772e0b1e387dcdb017bf.
- ProjectDefault renderer, accessibility Always, audio Dummy. Existing package/identity/action checks and deadlines retained. Godot/PowerShell execution was Windows cloud-only.
- Master checked at0c8b2384415d71bd3de4ff7408640bbf60b63740; no merge, integration movement or release.

C's prior evidence-retention patch was already incorporated at the product base; it was not reapplied. B's completed historical-fixture proposal remains ready and unimplemented in this slice.

## Experiment and evidence

After ordinary UI Load and slot2 Save, the experiment preserves separate quiet-before and quiet-after live file captures. It samples native HWND/PID identity, IsHungAppWindow and bounded WM_NULL response, without repeated UIA traversal or foreground activation, then performs one fresh process-bound UIA enumeration. Generic failure probes/capture are suppressed after experiment entry so they cannot add another UIA enumeration or activation. Independent source review caught and corrected that issue before dispatch. Both PowerShell scripts parsed successfully in cloud.

All40 samples, at0.0406–29.3611 seconds, report hung=true/responds=false. The first reports foreground=true; the remaining39 report false. The same observed process1080 and HWND393244 were retained. The fresh query starts at30.0146 seconds and returns at42.4650 seconds with zero descendants and no Saved node. The interval is the original Saved-observation budget after Wait-File, not a new acceptance timeout; the one later query is bounded by the existing journey watchdog.

Save invoke was recorded at08:55:33.4538Z and quiet sampling began at08:55:44.0560Z, leaving10.6022 seconds covering Invoke return, its200ms wait and Wait-File without separate timing. The first native sample is already hung. Earlier UI transitions also took substantial time. There is no pre-Save native baseline, so this evidence does not establish when the stall began, whether UIA Invoke contributed, or what owns the later foreground window. WM_NULL is an active native probe, not pure idle observation.

The six compared snapshot fields (narrative_checkpoint, gameplay, scene, command_receipts, applied_effect_transaction_ids, applied_variable_transaction_ids) match the source at all three capture stages. Run ID matches, branch ID changes as expected, Profile is semantically unchanged and source slot1 remains byte-identical. All four copied files are unchanged across quiet-before, quiet-after and final failure captures. These are live, non-atomic diagnostic observations; no save/recovery/history guarantees were weakened and no whole-transaction proof is inferred.

## Retention and verification

Original archive: ../evidence/phase_2r/exported_gameplay_20261018/39113018109-evidence.zip.
Bytes754989; SHA256 b951fa0b8f90321f384e02758446eb197f7cb05c5e3211e16f9ba79347e9ab34.

verify_quiet.py and quiet-verification.json in the same evidence directory retain the checks and full result. All137 outer-manifest members plus per-mode manifests were independently rehashed, with no duplicate archive names. Candidate/tree/source blob pins match. Cloud tracked changes are limited to the documented disposable-index removal of two malformed legacy gitlinks. A separate read-only reviewer confirmed the comparisons and timing limits. No new post-Save image exists by design; this run supplies no new visual-overlap disposition.

## Next bounded work

The useful next native diagnostic is baseline and action timing: record process-bound native responsiveness immediately before Save, separately time Invoke return and Wait-File, and identify the actual foreground HWND/PID/class when focus changes. Preserve the same package and observed action identity; do not substitute a ghost/foreign window, raise timeouts, or patch persistence from these observations. A focused later comparison of invocation mechanisms needs that baseline first. No additional diagnostic was dispatched here.

C can review this concrete retained result; B's existing two-fixture correction remains the subsequent bounded implementation task. No repeated inventory, speculative runtime surgery or full acceptance claim. The current controller deliberately stops the loader: do not rerun it expecting a green acceptance result.
