# Native caption driver reuse review — 2026-10-23

## Recommendation

Reuse the exact four-file native driver closure from qualified source `ddc3ce041dd1597c9086e56d0206e810d1237316`, preserving all current production files. Do not import that diagnostic branch wholesale. This is a test/tooling compatibility repair proposal, not acceptance of the new composition.

| File | Qualified Git blob | Action |
| --- | --- | --- |
| tools/testing/Invoke-CaptionNativeAccept.ps1 | a8ea3220634dd152759f7458d7f32f43f0221dc3 | Replace stale caption-Invoke driver |
| tests/manual/verify_caption_native_accept.gd | a0f091472f52af6c6b60779e8f8dc1fb3ae11095 | Add the matching observational fixture fields |
| tools/testing/ContinueNativeProvider.cs | 2174afddda04b2d59c1e126e738c9e64056dfa01 | Add exact native provenance dependency |
| tools/testing/Get-ContinueFileSha256.ps1 | 125dc8c496f4f918ef21024f0577dada0a6b4446 | Add exact hashing dependency |

## Why this repairs the demonstrated failure

Current source `5eee8406f4c2c466ac05d03c489c7cdd1cbc1164` still makes Resolve-Caption demand InvokePattern on the named caption text. The retained driver instead requires a focused Text node without InvokePattern and a separate enabled geometry-bound Continue Button with InvokePattern. It refuses ambiguous, wrong-process, offscreen, stale-stage, wrong-focus, wrong-role, changed-identity or changed-geometry matches. Invocation remains one call per named stage with no callback substitution or automatic retry.

The imported fixture differs from current blob `877f15ed1eeaa440d076cc57bc8bcac12d71b036` only by ten added lines: five Continue/target geometry observations and a rectangle helper. It does not change inputs or progression. Driver assertions consume those fields, so importing the driver alone is insufficient.

## Dependency closure and production preservation

The driver directly dot-sources only Get-ContinueFileSha256.ps1 and Add-Type loads only ContinueNativeProvider.cs; its launched script is the named fixture. It does not call the modified diagnostic Invoke-IsolatedGodot.ps1, separate publication readers, registration fixture, or other Continue helper scripts. Do not import them for this repair.

The fixture extends tests/ui/render_witnessed_caption.gd, blob `a96a4ce74900eba0a9e1416cf96276c09b14951b`, and preloads JsonFileStorage.gd, blob `df3f1bd3d612e5125dd9c91953946da8386b6d97`; both are exact matches between qualified and current source.

The WitnessedCaptionLayer scene, AccessibleCaption, and AccessibleReviewCaption are exact blob matches. Qualified AcceptInput and AccessibleContinue differ from current only in diagnostic registration-observer hooks; this native fixture does not seed or require those hooks. Current CaptionLayer additionally selects split panels through ArtManifest; preserve that later behavior. No production reversion or instrumentation is justified.

The imported C# dependency owns only its diagnostic COM session, authenticates the bound window through PID/HWND properties, reads provider provenance, and disposes acquired COM objects. The exact qualified route starts managed discovery before native COM provenance. The historical acceptance explicitly does not prove native activation unnecessary: removing that dependency would create an unqualified variation and is not recommended as part of this bounded repair.

## Evidence and acceptance boundary

Retained report: `b92fd83ccd3b3bb6edf1e8c2f2690e49e9f9b8f4:evidence/phase_2r/native_geometry_20261022/run39717822164/README.md`. Run39717822164/job119624061713 passed nine Continue invokes, one wheel packet, 21 ancestry/geometry observations, preserved partial-caption review return, native identity/provenance and clean teardown. The report limits this to a synthetic mounted fixture with seeded partial reveal and frozen elapsed time; it does not establish exported gameplay, save recovery, natural timing or whole-game acceptance.

Preserve those exact limits. Verify the four-file diff and dependency hashes, then run the canonical public-surfaces gate on the repaired candidate. Require the same native action/custody assertions and clean exit; inspect runtime/receipt and original artifacts. Do not merely bypass the native step. Broad downstream CI still needs its own completed results.

## Review limits

Read-only review using fresh connector file reads and hashes. No engines, PowerShell, remote mutations or new cloud run were executed by this review. Local command execution became unavailable (exec-server transport disconnected); report writing may require coordinator persistence if the shared patch tool also fails. No claim of exhaustive transitive engine dependency identity is made beyond the named fixture dependencies and production controls inspected.
