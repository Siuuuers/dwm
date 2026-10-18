# A — native Save baseline and timing, 2026-10-18

## Concrete result

Director PR30 comment6248830175 and C's review6248504867 requested the missing pre-Save baseline, separate invocation/file timings and foreground identity. These measurements are now executed, retained and independently reviewed.

[Run39120290544](https://github.com/Siuuuers/dwm/actions/runs/39120290544), job117654366177, reached its intentional diagnostic stop. Capability and Create passed with normal exits0. Load is diagnostic-only, ok=false, forced cleanup exit-1; no Back/ending/Gallery/normal-loader-exit acceptance.

| Observation | Result |
| --- | --- |
| Before witness Save invocation | Original Engine HWND393534/PID1616 responds=true, hung=false, foreground is the game |
| Invoke call | Returns in0.0003677 seconds |
| Immediately after Invoke | Same original window responds=true, hung=false |
| Wait-File call | Returns a readable snapshot envelope in7.6568016 seconds |
| Immediately after Wait-File | Original window responds=false, hung=true; still foreground at this sample |
| Thirty-second native-only interval | All40 samples hung=true/responds=false; actual foreground HWND328250/PID6100/class Ghost |
| Sole fresh UIA query | Starts30.0121 seconds into quiet interval, returns32.1225 seconds;75 descendants including one Saved node on original HWND |

The original native window was responsive at10:46:22.2764803Z and unresponsive at10:46:30.1549814Z. This brackets the observed transition to approximately7.879 seconds after invocation return, before the first post-file sample. It excludes a long blocking Invoke client call as the explanation for this run's prior combined gap. It does not identify the work blocking the game thread.

Wait-File measures detection-call duration, not exact save execution or disk latency. It begins after the existing200ms sleep plus post-Invoke native probe/logging. There are no native samples inside that file-wait interval. The baseline follows preparatory UIA discovery/focus, not all earlier automation. Native samples record elapsed time before their bounded probe and UTC after it; their times have that small observation span.

The Ghost class, handle and owner PID identify the observed replacement foreground window. The driver never switched its action or UIA target to it. Window() now explicitly refuses any final HWND different from the baseline before FromHandle. No inference about the ghost owner's executable is made.

Crucially, no post-query native responsiveness sample exists.75 UIA nodes establish accessible provider data, not recovered native event-loop service. Unlike the previous quiet run's zero descendants, this run sees Saved; this is not a deterministic recovery fix or an acceptance pass.

## Source, package and execution pins

- Product base:4b14f39a2648a43648f44ec29b8782e31f9981fa; unchanged runtime and ordinary driver.
- Isolated final diagnostic candidate:752010894bcbc58abadd0065847a8470448570b0.
- Candidate tree:e6030450e3d394380fda7142844de01e7e878387.
- Diagnostic driver blob:1dd81f6d0cc5564ebf9a4d25c0ba437825ca6709.
- Branch:codex/a-post-save-timing-20261018. Diagnostic source is not composed into normal gameplay testing.
- Controller:ceea80078eb5a6279b5ad30e3362a916e3dec716; workflow blob20eb85b9e52d4a4f4cd54ab6ada77ff6c1d06d11.
- Same retained artifact12127144275/run39103588380, package productbb167aa1b5692f6bf5ceb6789201f38d4f86360a.
- Package ZIP SHA256625fad0d7ab746c6413192f82db6b461e9db05f40634772e0b1e387dcdb017bf.
- ProjectDefault renderer/accessibility Always/audio Dummy, Godot4.6.3 standard. PowerShell parsing and all game execution cloud-only. No timeout increases or runtime/save/recovery/history changes.

Source review requested a final original-HWND check after the first dispatch had begun. The corrected candidate superseded it through existing workflow concurrency. Original run39120260586/job117654257391 is **cancelled**, during package download, before any gameplay mode executed. Both original archives are retained; cancelled work contributes no gameplay result. Final cloud parsing passed for both scripts.

## Persistence evidence and verification

Original completed-diagnostic ZIP39120290544-evidence.zip:757780 bytes, SHA256 f5e31f2eac1a82b3a22a014602efe141fceba70423d5053de89cc41144d1b819.
Cancelled ZIP39120260586-evidence.zip:41660 bytes, SHA256 f85d442c61f19dff19d7a4aeedb6532e6f30b19bc12e14b5c4367f75a2b43b49.

Both are under evidence/phase_2r/exported_gameplay_20261018/, alongside verify_timing.py and timing-verification.json. Completed diagnostic has137 verified outer-manifest members, plus checked per-mode manifests and exact source/tree/blob pins. Cancelled archive has10 verified members. Independent read-only review checked the completed archive, identities, timings and comparisons.

At quiet-before, quiet-after and final failure, six snapshot fields match the source: narrative_checkpoint, gameplay, scene, command_receipts, applied_effect_transaction_ids, applied_variable_transaction_ids. Run ID is preserved, branch changes, whole observed Profile is semantically equal and source slot1 bytes remain unchanged. Live captures remain non-atomic; no whole-transaction or every-field proof. Existing persistence results are preserved rather than weakened.

No new post-Save screenshot is taken by this diagnostic. No additional visual-overlap acceptance is inferred. Master was checked at0c8b2384415d71bd3de4ff7408640bbf60b63740 and remains untouched. No merge, integration update or release.

## Smallest supported next action

Add a single process-bound native responsiveness observation immediately after the sole fresh UIA query. This distinguishes readable provider data while still hung from native responsiveness recovered by then; it cannot alone prove UIA caused recovery. Keep the same original HWND/package/settings and retain the diagnostic-only outcome. The next run should answer this specific missing question, not repeat a general acceptance campaign.

Source inspection also confirms the existing owner chain: BackupApp._commit_pending awaits the port; PauseBackupPresentationPort prepares Backup Save and delegates; BackupPresentationPort invokes the existing save owner's commit_backup_action; BackupApp subsequently refreshes presentation. These are inspection targets if internal phase profiling becomes necessary, not demonstrated causes or permission to move work to a new manager/thread.

C can review this actual evidence. B's two historical-fixture proposal remains queued after the active export boundary. No speculative runtime fix, extra feature scope, or broad CI acceptance.
