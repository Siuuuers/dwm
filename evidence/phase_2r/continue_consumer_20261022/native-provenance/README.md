# Native provider provenance — inert candidate for C review

Director scope authorization: PR30 comment6323039180, handoff8678181ef44c389d3f4c5943dc4b10533de9ff25. Prior C actual-result disposition6322520961/6322523809 and A API feasibility6322681010 are consumed. This packet does not clear a run.

## One observable outcome

Determine what provider/proxy description the supported native COM client obtains for the verified game window after the existing managed observation. The diagnostic reader owns this observation. Success of this investigation is a trustworthy distinction between raw description, empty/null/unsupported data, identity failure, API failure and cleanup failure. None of those alone establishes Continue acceptance.

This is explicitly an additive changed client route: managed FromHandle/FindAll/current metadata, then CUIAutomation ElementFromHandle and three property reads. The original Read-ContinueAccessibility.ps1 remains byte-unchanged and remains the default. This experiment can affect activation and does not provide a matched causal comparison with historical runs.

## Exact candidate

- Source f4228bd96afacdc182f895c8638e15eb2258c8e8, tree e563f6f1baecac8717fb63c12603873ce3e5b4b6, parent d57fc90af73141f1a19e871e48205adc9788208e; branch codex/a-native-provenance-source-20261022.
- Exactly five changed paths, all under tools/testing: new ContinueNativeProvider.cs, Read-ContinueNativeProvider.ps1, Test-ContinueNativeProvider.ps1; opt-in routing changes in Invoke-IsolatedGodot.ps1 and Invoke-ContinuePublicationChecks.ps1. No GDScript/gameplay/save/history edits.
- Helper249d82c4f1f63695236a69eda82480fe812a9632 changes only prepare_caption.py PRODUCT pin from helperff32e3488257ef3e2ab67ebdb24be7391f0047a9. SHA25619febf2379044c202a28e2bf7b2c418a2348653edac4082c487e43497540bfc3.
- Inert native-controller.yml SHA256a40428625cd8c2385eec72c125d4f81e5bd80b9cd5cbdda6983d560deafd1953. Source/helper pins and helper hash updated; adds bounded native capability preflight + artifact upload before preparation, new script parse entries, and explicit -NativeProviderProvenance. Active PR30 workflow is not changed.

Source SHA256:

| File | SHA256 |
| --- | --- |
| ContinueNativeProvider.cs | 81135cc9571654f52ee746bb41e146123c91722abda987d01cb76627922488b6 |
| Read-ContinueNativeProvider.ps1 | 6f6ef4c792eecc65231fe4a5534590d72b812afca7ac6a49ec2a91f57aeb6ae5 |
| Test-ContinueNativeProvider.ps1 | 82ef5f60f6706f870b91f937ba12616d3f1f2a688ce79fe9fffe788eb9b48d8b |
| Invoke-IsolatedGodot.ps1 | 673cfdc1a1e91fecf16201969c4786952840bb71e8068e645ee6e73f1711f899 |
| Invoke-ContinuePublicationChecks.ps1 | 8231ac4c755f2c203a69826c13512fa0f4b7282cc51100034f6815378cc84195 |

## API/interop and request order

Official Microsoft ABI sources: microsoft/win32metadata generation/WinSDK/RecompiledIdlHeaders/um/UIAutomationClient.idl blob655287aeae4608114bd8ea77713e5cb1792a5c69; UIAutomationCoreApi.h blob675367b41c8961fb92ec47c4a84246ef1356b6e8. C# declares exact prefixes in original IUnknown vtable order, with PreserveSig HRESULT, BOOL, HWND and VARIANT marshaling. Unused action slots exist solely to preserve ABI and are never invoked. C# is diagnostic interop loaded by PS5, not a Godot/.NET engine migration.

Public API references:
- https://learn.microsoft.com/en-us/windows/win32/api/uiautomationclient/nf-uiautomationclient-iuiautomation-elementfromhandle
- https://learn.microsoft.com/en-us/windows/win32/api/uiautomationclient/nf-uiautomationclient-iuiautomationelement-getcurrentpropertyvalueex
- https://learn.microsoft.com/en-us/windows/win32/api/uiautomationcoreapi/nf-uiautomationcoreapi-uiagetreservednotsupportedvalue
- https://learn.microsoft.com/en-us/windows/win32/winauto/uiauto-automation-element-propids

1. Preserve original managed discovery and generic metadata receipts first.
2. Record reader/interop hashes, PS/CLR/process bits, UIAutomationCore file version/hash and apartment. Load the reviewed C#5 interop.
3. Activate CUIAutomation CLSIDff48dba4-60ef-4201-aa87-54103eef594e and acquire the public reserved unsupported sentinel. CUIAutomation is intentional, not a silent CUIAutomation8 substitution. The existing reader apartment is recorded, not changed.
4. Validate launcher, engine start identity and Win32 window ownership, then attach ONLY the bound HWND. No desktop/root enumeration.
5. Read ProcessId30002 and NativeWindowHandle30020 using GetCurrentPropertyValueEx(ignoreDefault=true). Require Int32 values, exact PID and normalized unsigned32 HWND agreement. Recheck process/window identity around calls. Identity failure prevents the provenance query.
6. Read ProviderDescription30107 once. Preserve raw string without a pass/fail grammar, empty string, VT_EMPTY/null, VT_NULL, unsupported sentinel, unexpected type, HRESULT and exception details. Revalidate complete engine identity/argv afterward.
7. Hold native and original managed references until normal reader stop/engine exit; release owned COM acquisitions and sentinel in finally. Attempt every release; retain cleanup errors and force reader failure if any occur.

Operation-start receipts are written before native calls. Return receipts carry raw HRESULTs and result classification. During activation the raw HResult identifies the sentinel API; COM creation failures have a separate exception ErrorHResult. Do not mislabel this as a raw CoCreateInstance success HRESULT.

## Failures and evidentiary limits

- Wrong/reused/exited process or mismatched/unsupported PID/HWND: refuse provenance, retain the original failure.
- Compilation/activation/attach/property error: retain stage and HRESULT/error; reader fails. The parent keeps its existing bounded watchdog and forced-cleanup reporting.
- Empty/null/unsupported provenance: valid diagnostic state, not native acceptance or proof of absent provider. Unexpected scalar/COM types are retained as failures without serializing COM objects.
- Cleanup error: reader fails; no success substitution.
- Compile/hash work and native queries happen after managed discovery and consume real time. Native event timestamps/order are separate. Managed discovery timing is NOT a native-query timing classification. Existing10ms clock comparability gate and original registration deadline stay unchanged; no raw-UTC override.
- Querying can change activation. A changed game outcome alone does not identify the cause or retrospectively qualify the baseline. Provider text does not prove AccessKit callback execution, tree completeness or Continue publication.
- No action, focus, input, pattern invocation, raw WM_GETOBJECT injection, forced refresh, engine rebuild or internal-constructor reflection.

## Reviewed cloud plan — not launched

C must clear this exact implementation/ABI, lifetime/cleanup and plan first. A then rechecks current controller/held refs and active runs before an expected-head installation. Do not overwrite newer work.

One targeted Windows2022 run, official Godot4.6.3 standard:
1. Existing actual PS5 writer7 and selector11 preflights.
2. Native capability preflight (2-minute step bound): PS5/x64/platform guard, PS5 syntax parsing, C# compilation, COM activation/sentinel acquisition, cleanup. It calls neither Attach nor Read, launches no game and queries no window. Preserve its independent artifact; fail before engine preparation if unsuccessful. This establishes runtime API viability only, not provenance or registration.
3. Unchanged source/preparation/import/custody gates and exact helper pins.
4. One existing initial-registration case with explicit native opt-in. All registration, timing, clean-exit, isolation, script-error and exact JUnit gates retained.
5. Preserve first failure and every original artifact, including new native preflight artifact. Publish run link/pause; C reviews actual results. If provenance gives no useful distinction, stop this diagnostic sequence and report the unresolved boundary plus least-cost alternative. Do not rerun unchanged or chain metadata probes.

## Verification and current state

Five published source files and helper read back byte-exact. Python helper AST and controller YAML parsed locally; independent internal read-only implementation/ABI review found no remaining blocker. No local PS/Godot/C# compilation/COM execution. Internal audit is not external Coordinator C clearance. Runtime preflight and game results remain pending.

Run39638614243 remains failed/unqualified16/17,zero registration,clock_incomparable12.0388ms>10ms. Controllera19be156 and held productc8358870/integration3ae6d913/master41592fcc are the last known pins, to be freshly rechecked before any install. No active controller installation, merge or release in this candidate preparation. Continuous A/C mission and Director native-client disposition remain in force.
