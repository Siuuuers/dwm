# Native provenance attempt 39655663875 — harness failure, correction prepared

Run: https://github.com/Siuuuers/dwm/actions/runs/39655663875
Job119415093242, attempt1, completed FAILURE.
Controller0edeafbdb7af0c10101e880f1a4f52e8262bfe57; sourcef4228bd96afacdc182f895c8638e15eb2258c8e8; helper249d82c4f1f63695236a69eda82480fe812a9632. Installation was one workflow-only change from a19be156 with expected-head protection, exact cleared blobb bbb6a4f9151c5ccbfec92cdfdb42b63a161d3470.

## Actual outcome

- Writer7/selector11 checks passed. Native capability preflight passed PS5 syntax, C# compilation, COM activation/sentinel and cleanup; STA64bit, expected interop SHA25681135cc9571654f52ee746bb41e146123c91722abda987d01cb76627922488b6.
- Source capture, import, settings restore and post-test policies passed; original preparation archive retained.
- Game exact one case17 assertions,16 passing/1 failing, child exit1. Continue registration timed out; zero managed descendants.
- Managed discovery timing is timely under unchanged10ms gate: reader maximum drift6.7247ms, game drift0ms. This classifies only managed discovery.
- Native reader failed at loading_interop: Get-FileHash command unavailable. Native operations empty, identity_verified false; native client/query never reached. Reader exit1, not forced; lifecycle/cleanup errors empty.
- Therefore native provenance and Continue remain UNQUALIFIED. This is not a generic/empty/unsupported native-query result, and the diagnostic stopping condition has not yet been exercised.
- Inherited module discovery differences are a hypothesis, not established root cause. The observed fact is command unavailability in the child after a successful standalone preflight.

## Preserved originals

All five original ZIP downloads matched GitHub SHA256 digests. archives.json records sizes, digests and Git blob identities. Preparation ZIP is split into42 ordered262144-byte-or-smaller parts; concatenate filename order to reconstruct the exact original. Other four ZIPs are whole. All46 part/archive blob IDs match locally computed Git blob hashes. Browsable receipts are UTF-8 text copies; ZIPs are original byte authority.

## Minimal correction / next attempt

Source bf0c0b1048b1f4cb0959e36f17ce0032780867f3 (tree64796882238e78d7b25c31dc03614b10e9523755) changes exactly three tooling paths:
- new Get-ContinueFileSha256.ps1 uses .NET SHA256 over a file stream with finally disposal;
- native reader uses it for its three hashes;
- native capability preflight uses same helper and a known abc+LF digest/released-stream check.

Helper6597de2a2f686753ffd9097e8b630b3b1b7337c0 only changes PRODUCT pin. Full13836bytes, SHA2567a51e4b0e7e61db09da46b3c365b7cd3ae78cd538f5b39d2e58f535f60dc6e44, Git blobc11d7790ed22bfd4e5efa65aaabea8691b7342d9.

Corrected inert native-hash-controller.yml:18562bytes, SHA2563bd26d21d063eef3e87f8c3dcaaadf5bcbb6d324bd8d91a9f075943db0a9c370, blobdb99d6b99a63238b372d3a9f5e19b70bb3a69be7.
Native preflight now uses pwsh parent + absolute PS5 ProcessStartInfo launch mechanics matching the reader, with bounded wait and concurrent output capture; no claim of identical full environment. Existing capability-before-game gate and all acceptance limits retained.

Independent Reviewer inspected actual failure, helper/reader/preflight correction and exact published source/helper/pins, finding no remaining static blocker for one corrected attempt. Reviewer authored preflight launch mechanics; Lead cross-reviewed that delta. This is cross-reviewed preparation, not runtime acceptance. No local Godot/PowerShell executed. No game/save/history changes, held branch movement, merge or release.

Next: fresh controller/runs check; expected-head install exact corrected controller once; monitor, preserve original results and review actual native query. If it returns generic/empty/unsupported metadata without useful distinction, stop this sequence and present a bounded next proposal. No unchanged retry or weakened gate.
