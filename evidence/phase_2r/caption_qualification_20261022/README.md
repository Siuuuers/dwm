# Focused caption/Continue batch

Prerequisite: initial registration run39657012775 passed (one exact case16 assertions), independently reviewed; see ../continue_consumer_20261022/run39657012775/README.md.

## Observable outcome and owners

The existing Continue action completes current text, retires stale callbacks and advances exactly once; caption remains accessible Text without Invoke. Existing caption/Continue/input owners retain all behavior. The runner tests eight exact cases, then the separate native driver verifies nine Continue invocations and one physical wheel transition with unchanged review/history checks.

## Exact candidate

Sourceb430cf2966d87d0da73f0d506f6acd89eecf6fa6 changes four tooling paths only relative tobf0c0b1048b1f4cb0959e36f17ce0032780867f3:
- Invoke-ContinuePublicationChecks.ps1 restores eight existing tests; native consumer only for organic/manual completion, per-case receipt preservation, exact source/JUnit/clean-exit gates.
- Invoke-IsolatedGodot.ps1 extends consumer suite allowlist only with organic/manual IDs. Existing isolation, bounded process lifetime and identity checks retained.
- Invoke-CaptionNativeAccept.ps1 carries the supported managed-then-native sequence once within first original10s lookup budget. It revalidates process/HWND, native PID/HWND before descriptive provenance, holds COM/managed objects until cleanup, and retains all caption Text/noInvoke and separate Continue/geometry/input/history assertions. Shared .NET hash helper removes Get-FileHash dependency. Success requires clean COM disposal; nested finally attempts process/native/DPI/manifest cleanup.
- Test-ContinueNativeProvider.ps1 adds native driver to PS5 syntax parser list.

Helper01a76f15b6c4ab303e8c4cac5b96cd1f72118fd9 only changes PRODUCT pin;13836bytes, SHA256443009023266c6c82dcfa298f794f3424f8c17ce198477c2fd33a07e99cd12b6.
Controller.yml18994bytes, SHA2568a40cf8ccdaa8802a431d25832bc455234a9be0a67ce0ce3bb9aadf3587b5cb6. Source/checkout/helper pins agree; capture helper unchanged.

## Failure and timing rules

Wrong/stale identity, native error, cleanup failure, receipt mismatch, script error, failed/skipped/wrong JUnit case or clock incomparability stops the batch. Per-case receipts are moved in finally before the next consumer case. No failed case is retried.
Completion fixture owns unchanged5000ms publication waits. Reader clock drift retains10ms gate. These completion cases do not emit successful cross-clock registration snapshots: native query timing is explicitly not_classified; no borrowed timing claim.
Native setup runs inside original10s first lookup, not an added deadline. Description is not a pass grammar; final native caption/action assertions remain required. No raw messages, forced updates, engine rebuild, product/save/history edits, merges or held-ref movement.

## Run plan and review

One Windows2022 official Godot4.6.3-standard run: writer/selector/native capability preflights -> exact preparation/import/custody -> eight cases (organic,manual,pointer,keyboard,touch,review,speech-start,speech-cancel) -> native caption/Continue only after eight-case success -> always source check/evidence retention.
Independent reviewer found one native cleanup ordering gap; author corrected nested finally and reviewer verified final driver SHA256bc482ed8a269464ae5dc9e0c44945c42607505d77acc74c17c7d775c27bd2f8a,46334bytes. Runner/helper/workflow/preflight review found no other concrete blocker. Final pins have been submitted for limited verification. Published source/helper match complete local bytes; Python AST/YAML checks pass. No local Godot/PowerShell runtime.
This inert packet does not itself launch tests or establish runtime acceptance. Lead performs fresh refs/runs check and expected-head installation after final pin verification.
