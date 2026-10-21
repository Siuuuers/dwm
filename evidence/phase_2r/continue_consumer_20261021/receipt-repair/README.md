# Reader receipt repair and Windows PowerShell 5 preflight

Prepared by replacement Coordinator A under Director PR30 comment6318547755. Exact candidate for external Coordinator C review; no controller installation, cloud attempt, or runtime acceptance in this checkpoint.

## Observable outcome and owner

The actual UIA reader receipt writer must publish first, repeated and terminal records atomically on Windows PowerShell 5. A failed preflight must stop before any Godot process. Save-ReaderEvent remains the sole writer, now shared by dot-sourcing; production registration, save, recovery and history owners are untouched.

Prior run39613426599 remains failed before attachment. The invalid-path File.Replace error is established; null/string conversion is still an explanation pending actual host execution. This candidate passes [NullString]::Value as the null backup filename, preserving File.Replace and exception propagation, without delete-then-move or backup-file management.

## Exact candidate

- Source: 023f2d501ef0726075d3dd706535860bf2615ae6, tree c49772578328a730e4885ede3c65f1ff6e227a90, parent1ee15f07b315fa762495a6bb93d07d91201ae600. Branch codex/a-reader-receipt-source-20261021.
- Exactly three source paths: Read-ContinueAccessibility.ps1 dot-sources the extracted writer; Save-ContinueReaderEvent.ps1 retains the former function body except the null argument; Test-ContinueReaderReceipt.ps1 exercises that shared function.
- Helper: 46d9d6eead37cc67e7349ba07c02fc1da76b6f9b, parentcd5d74f7bc72322dbb48e1592900552f757b3956. Only PRODUCT changes. Branch codex/a-reader-receipt-helper-20261021.
- Preparation SHA256: 3276b74abee01c669dd9ccc2ccf6b4e7c1dca0c7a309d403ffd20c24304209e8.
- Inert receipt-controller.yml SHA256: 42c560ad082a7e6ca337758cfecbba14f36b8370b3c4614d203f327d4a9ed675.
- Runtime owner blob4f0f81b8f8f0c02a4bc7ed06909d9be840fc1ab0, capture helper, fixture, original5000ms registration window, identity/lifetime/read-only discovery and cleanup unchanged.

## Failure-oriented preflight

Runs powershell.exe on windows-2022 and explicitly requires major5/Desktop. Uses a unique OS temporary directory outside game/profile data and the same dot-sourced writer as the reader. It checks first publication, second and repeated replacement, terminal failure followed by completion with exact retained error and exit1, and complete latest parsed JSON against the current record. It then holds a Windows file-sharing lock to require replacement failure, verifies the previous receipt bytes survive, and checks a subsequent successful terminal write replaces the stale temporary content. No UIA/game process is started by preflight.

Preflight result.json uses an independent evidence sink so a broken writer cannot hide its own failed check. Snapshots and process exit are retained. Inert workflow runs preflight immediately after checkout, before helper acquisition, syntax/import preparation and even Godot --version. Nonzero exit, missing result, false passed or nonzero reported exit prevents progression. Always-upload immediately preserves preflight evidence. With helpers skipped, the existing always preparation-after condition is false. Legacy checkout post-job cleanup may additionally complain about malformed gitlinks when failing this early; that cannot permit an engine launch or replace the primary preflight evidence.

## Verification and limits

Local text/AST inspection only: exact extraction/body comparison, Python helper AST, YAML parsing, step ordering and diff whitespace checks pass. All three published source files and helper were re-read from GitHub byte-equal. Independent internal static audit found no blocker; this is not external C clearance or Windows execution. Full hashes and consistency checks are in consistency.json.

Master41592fcc792aa615e47ee2ce2f05008ca195b311 has none of these three reader/preflight paths; this repair is not already integrated there. No gameplay files changed, no benchmark or broad suite rerun, and no product/master/integration movement.

## Next owner action

External C reviews ONLY this delta and preflight success/failure gating, reusing closed fixture/reader/preparation reviews. After exact clearance, Director6318547755 authorizes ONE cloud Windows attempt with successful preflight before existing preparation and the single registration case in the SAME run. Recheck controller1caf3f2c95ac1e7817d22eebd314c0bd725bef94 and current runs immediately, then install with expected-head protection. No additional user/Director confirmation needed; no automatic retry. Preserve independent preflight, attachment/timing, registration, child/reader exit and cleanup outcomes for C result review. No remaining suite, native action journey, export, merge or release.
