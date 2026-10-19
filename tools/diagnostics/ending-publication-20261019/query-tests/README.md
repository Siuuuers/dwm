# Ending action observation qualification

Cloud Windows PowerShell only; no local PowerShell/Godot/Rust run is authorized by
this packet. Execute the actual extracted helper, `Visible`, `Actions`, and
`Wait-One` functions against fake provider boundaries:

```powershell
pwsh -NoProfile -File tools/diagnostics/ending-publication-20261019/query-tests/Test-EndingActionObservation.ps1 -DriverPath tools/testing/Invoke-ExportedGameplay.ps1 -OutputPath ending-action-tests.json
pwsh -NoProfile -File tests/tooling/Test-ExportedGameplayDeadline.ps1 -DriverPath tools/testing/Invoke-ExportedGameplay.ps1 -OutputPath ending-deadline-tests.json
```

The first test checks provider getter/method sequences, returned object identity,
short-circuit nulls, observation failure, provider exceptions, scope cleanup,
zero descendants and observation limits. It never launches the driver top-level
or a game. Existing deadline tests remain unchanged and must also pass.

`-TraceEndingActions` activates observation only for NativeReadyCaptions Load's
exact ending-caption wait. The existing `caption-action-enumeration` event gains
`ending_actions`; there is no additional event flush. `Visible` is unchanged.
Returned collection ordinals are not stable IDs. Null name/Invoke fields mean
not evaluated, and name truncation is explicit. Complete refers to descendant
record coverage, not full provider-tree coverage or exact truncated names.

The recorder bounds name copying before JSON serialization and conservatively
budgets pretty-serialized record bytes plus 34 bytes per line and 2 per record,
with a 4096-byte envelope reserve. This covers final event nesting/CRLF overhead
rather than assuming compact JSON will be written. Recording stops at either
4096 records or the 1 MiB budget; original predicates continue. A copying or
serialization error sets `observer_failed` and disables recording while
preserving the actual provider outcome. Completed batch omission counts remain
explicit; provider errors do not fabricate a completed enumeration event.

Receipt diagnostic qualification is set after existing failure diagnostics and
cleanup, so it cannot change their original diagnostic-only conditional paths.
