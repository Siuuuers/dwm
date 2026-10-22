# Review-only external wait-chain probe

Not integrated, executed or published. Adoption is conditional on the connected journey result and independent review. The original Bridge and exported driver remain unchanged.

`Probe-ExportedWaitChain.ps1` accepts the existing native-probe PID/executable/start-UTC identity plus the exact previously authenticated HWND. It asks GetWindowThreadProcessId for that HWND's owning TID, queries precisely that thread once, and rechecks identity afterward. It does not enumerate arbitrary threads, call UIA, send window messages, change focus, attach a debugger, suspend the target, change privileges or retry. The existing same-user token may lack required WCT access; failures/partial status are explicit evidence gaps.

ABI source: Microsoft's `microsoft/win32metadata/generation/WinSDK/RecompiledIdlHeaders/um/wct.h`, retrieved blob `d3441432da3965b4d321353d90d3f8ea6dc87470`. Only Windows x64 is admitted. SDK constants: max16nodes,128WCHAR object name, flags1|2|4. Under x64 default8-byte packing, the largest union member is272bytes and the node is280bytes; union begins at8. Runtime Marshal.SizeOf/OffsetOf assertions check the declared layout before allocating/querying. Raw buffer reads preserve DWORD type/status, thread PID/TID/wait/context counts, object name and reserved Timeout/Alertable values. Reserved values are not interpreted. No managed-reference union overlays or unsafe object casts are used. This static layout review is not a cloud runtime qualification.

COM callback functions are resolved from the explicit System32 Ole32 path, module identity checked, export names/addresses recorded, and registered once. There is no documented unregister operation: the LoadLibrary reference remains alive through disposable probe process exit, after session closure. No null callback registration or potentially dangling unloaded callback addresses. Kernel teardown releases that module reference.

Synchronous GetThreadWaitChain has no timeout and cannot be canceled. The helper is NOT self-bounded. Its caller must start a distinct process and impose one5000ms wall-clock budget covering process startup, Add-Type, identity checks, WCT and shutdown. On expiry terminate only that probe, retain the last atomically flushed phase receipt and record parent timeout. Never await stdout/stderr synchronously without the same outer bound. No new target wait/step/journey allowance or watchdog reset. A missing/incomplete final receipt is never success. Add-Type could consume the whole budget; report that, without retry.

Proposed tiny failure-only driver insertion (not authored): after existing failure-save capture, before fresh-client UIA probe, launch this sibling script through ProcessStartInfo using bound process identity/HWND and a fresh output path. Pass explicit arguments with ArgumentList. Record launcher UTC, deadline, completion/timeout, exit code and receipt hash, preserving original gameplay error and failed result. Read stdout/stderr asynchronously, kill only probe on deadline, and leave target cleanup and provider lifetime unchanged. No invocation during a successful journey. Stage/hash-pin the probe like existing external helpers. Do not replace the retained native-window probe or make a diagnostic result an acceptance gate.

Observed means one authenticated diagnostic snapshot, not healthy. A single node can mean running or an unsupported wait; no cycle does not exclude a hang. Partial chains, access errors, missing COM callbacks, node truncation and identity changes remain incomplete/error. WCT may identify an owner or cycle for supported waits; it cannot give a Godot/GDScript stack or prove the historical freeze cause. Snapshot timing can race target changes. COM/ALPC thread IDs may be0.

Primary documentation:
- https://learn.microsoft.com/en-us/windows/win32/debug/wait-chain-traversal
- https://learn.microsoft.com/en-us/windows/win32/api/wct/nf-wct-getthreadwaitchain
- https://learn.microsoft.com/en-us/windows/win32/api/wct/nf-wct-registerwaitchaincomcallback
- https://learn.microsoft.com/en-us/windows/win32/api/wct/ns-wct-waitchain_node_info
- https://learn.microsoft.com/en-us/windows/win32/debug/using-wct
- https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-getwindowthreadprocessid
