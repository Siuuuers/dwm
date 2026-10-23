# A — exported post-Save native diagnosis, 2026-10-18

## Outcome and ownership

The bounded target is unchanged: a fresh exported process loads slot 1, visibly restores Day4, saves a witness to slot 2, then completes the ending and exits normally. Backup owns presentation; existing save/scene owners retain persistence semantics; the external PowerShell driver owns observation and process cleanup. No runtime code, schema, registered content, save writer, recovery policy or history validator changes in this batch.

Director assignment: PR30 comment6247200700. C's evidence-retention successor6c5fba66 is composed and executed. B's historical-fixture proposal is delivered in PR36 comment6247255989 and remains a separate next task, not silently applied here. Master was checked at0c8b2384415d71bd3de4ff7408640bbf60b63740; product starting headca4a4ed1324e4371b707130ad6ada65def48050e.

## Implemented and executed

Diagnostic candidate d099ca1ad8a6286530d765b5fc5b6d83664fa559 retains C's read-only failure capture of Profile, slot 1, slot 2 and autosave before potentially blocking UIA. Files have bounded reads and individual hashes; live captures are explicitly non-atomic.

A separate, bounded failure-only PowerShell process verifies PID/executable/start-time identity, enumerates native windows, records HWND/thread/class, IsHungAppWindow and bounded WM_NULL response, then attempts fresh UIA FromHandle enumeration. A bounded noninvasive CDB capture preserves thread stacks when the configured debugger is available. Neither diagnostic changes success criteria or recovers a failed journey into a pass. Original UIA action, visibility, uniqueness, package and process-identity checks remain.

Both scripts passed cloud PowerShell parsing. The first native-probe candidate694c76b had an invalid optional ProviderDescriptionProperty lookup; d099 removes it. Preserve the first failed probe as evidence, not as proof of fresh-client zero descendants.

## Exact package and runs

All runs use Godot 4.6.3 standard export from bb167aa1b5692f6bf5ceb6789201f38d4f86360a, retained artifact12127144275 from run39103588380. Package SHA256625fad0d7ab746c6413192f82db6b461e9db05f40634772e0b1e387dcdb017bf; EXE91724f15024a3a545e28ccd83134403d31ce2323a38e51c95e4dfa282f732ab6; PCKe6fe5dab1eb7588704c24ae5d7eb231f7e475dff62cb663b637cbd5ea1baa22d. No rebuild or fixture-seeded saves.

| Run / job | Driver / condition | Result |
| --- | --- | --- |
|39108575134 /117619620985|694c76b, ProjectDefault|Capability/Create normal exits; Load Saved-status timeout; native windows unresponsive; optional probe-property error|
|39109040408 /117620994270|d099ca1, ProjectDefault|Capability/Create normal exits; Load same timeout; fresh native-root UIA 0; stacks captured|
|39109479250 /117622302435|d099ca1, gl_compatibility only changed|Capability/Create normal exits; Load same timeout; fresh native-root UIA 0; stacks captured|
|39110047155 /117624028766|abd7897, ProjectDefault plus one foreground check within existing Saved deadline|Capability/Create normal exits; already foreground; Load same timeout; fresh UIA 0, later 75nodes|

All use Accessibility Always and Audio Dummy as harness overrides, not default accessibility/audio acceptance. ProjectDefault reports D3D12 Forward+ on Microsoft Basic Render Driver. Compatibility reports OpenGL ES3 through ANGLE on Microsoft D3D11 software rendering; this is not an independent native OpenGL hardware test.

## What the evidence establishes

At the failed boundary, the game child remains alive. Native Engine-window observations report hung=true and WM_NULL responds=false. Corrected stacks and compatibility probes resolve the actual process-bound HWND through a fresh client but return zero descendants. Therefore a stale cached automation root alone does not explain those observations.

The default-renderer stack capture shows the main GUI thread waiting in WaitForSingleObjectEx below unsymbolized game frames. Four workers show d3d10warp work. Export-relative labels such as NoHotPatch are not recovered game function names; !runaway is cumulative CPU time, not measured interval utilization. Compatibility capture instead resolves the GUI-thread path through dwmapi and DXGI swap-chain presentation. These are useful presentation-path observations, not proof of an AccessKit, renderer, or game-code root cause.

Crucially, all four later failure captures contain 75 UIA nodes including Saved. This happens after failure-only diagnostics, elapsed time, and Capture's foreground activation plus 200ms wait. The exact recovery trigger is unresolved. Do not call this a permanent deadlock or permanent provider loss.

For every run, independently hash-verified failure files establish equality of narrative_checkpoint, gameplay, scene, command_receipts, applied_effect_transaction_ids and applied_variable_transaction_ids between source and witness snapshots; same run ID and new branch ID; semantic equality of the whole observed Profile; byte-identical original source slot. This is scoped live diagnostic evidence, not equality of every snapshot field, an atomic multi-file transaction, or a successful exported journey.

Rendered compatibility captures show the full Day4 closing line and preceding opening line; the late failure image shows Saved and occupied slot 2. The observed Back/Check Computer overlap remains a UI observation with foreground/hit impact unqualified. Ending, Gallery traversal and normal loader exit remain unaccepted.

## Evidence and review

Original ZIPs, manifests, source blobs, events, images, live save copies, native observations and CDB output are retained alongside post-save-diagnosis-verification.json in evidence/phase_2r/exported_gameplay_20261018/. verify_post_save_diagnosis.py rechecks archive-member hashes, inner manifests, source blob hashes, capture hashes and scoped equality. Independent read-only review confirmed 131/133/133/133 retained members across the four runs and the same comparison/recovery limits.

No broad automatically triggered workflow is accepted by this handoff. No merge or release.

## Foreground experiment disposition and next boundary

Run39110047155 used controller57c4ca927a3ee6d1b867ab96474a07c18905cfc3 and immutable driver candidateabd78970fc803e81f7cb838dc5eef09e7d99a2b0. The Saved wait recorded native foreground before=after=window=328126, PID7864. The requested=false field is the SetForegroundWindow return-value field; because the window was already foreground, no activation call was needed. It still failed UIA_UNAVAILABLE_OR_TIMEOUT: Saved status. Native observation again showed hung=true/responds=false and fresh UIA 0, followed by 75 nodes including Saved in the later failure capture. The same six snapshot comparisons, run/branch checks, Profile equality and source-slot byte equality all passed. This rules out a simple missing-foreground precondition in this attempt, not every possible focus-lifecycle issue.

Do not retain the unsuccessful foreground workaround in the composed driver. Publication uses the tested d099 tree, preserving the experiment only as immutable source/evidence. This keeps the production diff from ca4 limited to the external driver and native diagnostic helper, plus evidence/documentation.

Remaining capability limit: Windows hosted software-rendered exported gameplay transiently stops servicing its native window and exposes no UIA descendants after the witness Save; it later recovers during failure diagnostics. Existing stacks do not identify the originating game function or which action/time passage restores responsiveness. A permanent deadlock, lost provider, or persistence failure is not established.

The next discriminating export diagnostic is to isolate UIA observation pressure: after the same process-bound Save action, sample native responsiveness without repeated UIA traversal until the existing observation deadline, then make one fresh process-bound UIA observation. Keep exact package/settings, retain pre-UIA save evidence, and label the experiment diagnostic-only. It must not substitute file existence or later recovery for successful normal acceptance. This tests whether the stall depends on repeated client traversal before changing runtime or renderer again. No such additional run is dispatched in this batch. B's separate two-case fixture correction is ready for A's subsequent bounded implementation/cloud verification.
