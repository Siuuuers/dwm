# Coordinator A — ordinary exported Windows journey, 2026-10-18

## Outcome and ownership
C's external driver is composed with narrow corrections supported by actual Windows UIA evidence. No game runtime, save/recovery/history owner, startup registration, export builder, or package resources changed in this slice. PR30 remains the shared workflow controller; PR36 remains draft/unmerged.

The observable outcome is ordinary packaged New Game, reading, Computer open/close, Day4 UI Save, clean creator exit, distinct-process selected-slot Load, complete restored caption and matching saved authority, ending/Title, and clean shutdown. Capability and Create success do not establish Load or final journey acceptance.

## Immutable package and driver identity
- Original product base: 3f9dd27501303480a914744f5287c84824360ada.
- Package source: c97ba59ff08644b3aeca82ab567dc39d623327eb (C's original driver-only addition).
- Original exporter run39095028917/job117579581100 reused the existing Invoke-WindowsExportValidation.ps1. It verified 117 exact runtime resources and headless native startup.
- Original retained package artifact: 12124148336, exported-capability-package-39095028917-1, under run39095028917. GitHub artifact retention is seven days; this report does not claim permanent retention of the binary ZIP in git.
- ZIP SHA256: c699d28099d68500354e5d1e1e6638d444216d0eeab9db7cf04cdd729f12045d.
- Executable SHA256: 91724f15024a3a545e28ccd83134403d31ce2323a38e51c95e4dfa282f732ab6.
- PCK SHA256: a4877275fe9954302a3288894122083ec19923030f0ea1be418d7fadd546c46b.
- Subsequent runs downloaded and reverified that exact original artifact. No second export pipeline or nominally equivalent replacement package was used.
- Final diagnostic driver source: 3c57aacab993f8dd18eacb43707ef1ae6ac2c8cf. Product/runtime source is byte-identical to the exported source; only external driver code differs.

## Actual failures and narrow corrections
| Run / job | Driver source | Result / disposition |
| --- | --- | --- |
| 39095028917 / 117579581100 | c97ba59 | PowerShell parse and package validation passed. Default launch rendered Title, but UIA had zero descendants and could not find New Acc; WASAPI initialization failed on the cloud runner. Failed, forced cleanup. |
| 39095340628 / 117580499604 | c157f4e | Explicit accessibility Always and audio Dummy enabled real Title/New Game/Computer UI actions. Driver wrongly assumed reading Save was on the right. Failed at reading Save rail; observed bottom-left rail fixed. |
| 39095489458 / 117580944503 | eb33c85 | Corrected rail opened Backup; native names include trailing spaces, now normalized only for comparisons. Provider exposed nine drawers without a separate Backup ancestor. Failed, no save claimed. |
| 39095630321 / 117581353960 | 855aaa5 | Exact nine-drawer/3x3 native scope and unique lower-right dock action passed Capability and normal WindowPattern.Close exit0. No manual save performed. |
| 39095749666 / 117581713401 | 707ac39 | Added independent-review stop-at-window guard. Capability and Create passed with normal exits0. Fresh Load invoked the scoped slot1 Load action, then reported UIA_WINDOW_PID_MISMATCH before restored-caption observation. Original failure retained; old failure path omitted child exit code. |
| 39096152408 / 117582916396 | 3c57aac | Capability and Create passed again, both normal exits0. Fresh Load repeated UIA_WINDOW_PID_MISMATCH after invoking slot1 Load. Child had already exited before cleanup: -1073741819 (0xC0000005, Windows access violation); forced_cleanup=false. Console had engine/renderer startup only, stderr and game.log were empty. No restored caption, witness Save, ending, or successful Load exit was reached. |

The selector never invokes the first global Save/Load match. It requires a process-bound window, unique expected drawer identities, three rows and columns/nine distinct cells, and a unique enabled dock action right of and within the lower vertical extent of that grid. It stops at the bound window. The ordinary reading Save is a unique bottom-rail action, separate from SceneHost's left Save.

The final diagnostic correction drains console streams asynchronously, checks their contents on success, and retains child exit code and pre-cleanup exit state on failure. Identity refusal remains intact. Native provider calls remain bounded by the existing watchdog and cloud job timeout. A stream/cleanup exception is still a potential evidence-collection edge; it is not established as the observed Load failure cause.

## Evidence and visual scope
Original compressed evidence from every diagnostic run is retained unchanged under evidence/phase_2r/exported_gameplay_20261018/; verification.json independently checks member sizes/SHA256, inner driver manifests, and source Git blobs against pinned candidates. All screenshots and action trees are original cloud captures. Initial empty parser-error pipeline emitted no JSON file; the first two parse successes are established by the original cloud step logs. Later workflows retain an explicit parser result object.

Observed renderer: D3D12 Forward+ on Microsoft Basic Render Driver. Successful scoped probes request standard --accessibility always and --audio-driver Dummy; they do not qualify default accessibility activation, audio output, physical input devices, or every renderer. No source --path, script override, fixture startup, direct game-port invocation, profile seeding, or packaged GUT was used.

Independent screenshot review found complete Day1 and saved Day4 captions without visible clipping. Backup's selected drawer/details and action are readable. A real presentation issue remains: the bright Back label overlaps dimmed underlying Check Computer text at top-left. Images do not establish underlying input blocking. No full visual acceptance is claimed.

## Immediate blocker
The observed native process exit supersedes an interpretation of the final symptom as merely an inaccessible control. Its precise root cause is not located: no dump or native stack was captured. Do not disable PID checks, increase timeouts, claim a Load pass, or patch save semantics from this result. The next bounded investigation should capture a native failure stack and distinguish engine/UIA/renderer behavior from game restoration at this exact package and saved-slot boundary. Preserve the original access-violation failure and existing save guarantees. Creator state was obtained through ordinary UI, never seeded.

## Remaining integration work
The prior broad run39090268581 remains failed. A read-only source review traced the first persistence/new_account failures to historical dating/hospital/contact fixtures constructing contexts through today's scene-only registry. The existing scene-registration test switch cannot select that old vocabulary. A bounded next fix is explicit test-only retained context/ID dependency tables with save/restore of caches, preserving original receipt/physical-owner/no-backfill assertions and leaving live registration unchanged. This has not been implemented or tested here; it must not be described as historical saves loading under current content. Retired health:+1 fixtures require separate reconciliation, not revival of health gameplay.

B's corrected inventory remains authoritative for its scoped review. C should review the actual preserved driver/provider/Load evidence, rather than repeat preparation. No merge, master update, release, new feature scope, or full-game acceptance follows from this report.
