# Independent aggregate observation review — run39745466691

Disposition: PASS for this short-route observation only. No blocking evidence discrepancy remains. Review performed from downloaded original preparation/qualification artifacts using Python/static inspection; no Godot or PowerShell execution, retry or remote mutation. Original ZIP/API digest verification is the Lead's separately reported work, not repeated or claimed here.

## Identity and custody

- Product `0b9095e5c63275bc4721cd257413d286bcd958b0`; assets `df1f5df3f2a62ca871fbcd9bcdf0d98bb5c249c5`; controller `ab23ee7f8327b8be96a7fbd69f57d4032b563cc6`; preparation receipt records event workflow commit `de5db6cda7a7c76f55806d10fbc3e02448d65117`. Actual workflow-blob reconciliation remains Lead-owned.
- All four custody policies pass. Baseline has 13,423 tracked paths and no generated inputs. Import admits only the recorded project-settings mutation plus two index-only malformed-gitlink removals. Restored/post-test captures retain the original project bytes and no additional authored-byte change.
- All six source identities match the reviewed manifest in baseline and all four generated-input reports (24 receipts). Inherited helper is the corrected actual blob `5a5b16e1dfd00910be6995317fbc9646581d34e6`, 13,113 bytes, SHA256 `eb032c12a41d188573cebcbdc30e0c059441fe9a572b277fb55ef8b4174526be`.
- Import/restored/post-test each record the same 38 generated inputs, no rejection. Both specifically admitted runtime UIDs complete 1,719 peer comparisons with no collisions; neither receives a general runtime-metadata exception.
- Retained preparation/capture helpers and all harness members independently rehash to the reviewed pins. Preparation SHA256 `392aea1da0322ba940f08398654313b44cf1a5d5d1ecd32686b4604dcf1d2e12`; runner `ed1e27df5711b832ca5732ae192fef2b6ed409a8f63534c5053c056967220d5c`; manifest `98cb4346a72e5d4718067ad79590feaae53a7f4a24b2c3d7e7c1992eaa3ded8d`.
- Official Godot 4.6.3 standard executable receipt matches selection; rendered isolated child uses gl_compatibility, accessibility always, unchanged 120-second deadline and no external UIA consumer.

## Selected result

Exactly one selected test passes: `test_direct_ending_accept_returns_without_save`, 69 XML assertions, 34.440906 seconds, zero failures/errors/skips, child exit 0. Result and isolation receipts agree. Engine log contains none of the runner's error patterns. The existing test retains premature Accept refusal and real fresh Accept, durable COMPLETED/GALLERY_RECORDED, Gallery receipt and Title-return assertions.

Raw log and retained JSON contain exactly the same nine aggregate records. Capture/prepare/commit order matches three writer calls; labels are ENDING/EPILOGUE_PLAYED, ENDING/GALLERY_RECORDED, COMPLETED/GALLERY_RECORDED, all next_step_index 1. All returned operations are successful; configuration/compilation failure counts are zero.

## Measurement

Final Accept takes 22.743922 seconds. Sequential writers take 6.070841, 7.470135 and 8.352420 seconds. Capture aggregates are 219, 305 and 272 microseconds with no configuration/compilation calls.

| Writer operation | Outer seconds | Configuration calls / seconds | Compilation calls / seconds |
|---|---:|---:|---:|
| 1 prepare | 2.997211 | 8 / 0.277609 | 64 / 0.251374 |
| 1 commit | 3.069206 | 8 / 0.286338 | 64 / 0.259474 |
| 2 prepare | 3.703592 | 8 / 0.280813 | 64 / 0.254053 |
| 2 commit | 3.762050 | 8 / 0.286881 | 64 / 0.259814 |
| 3 prepare | 4.178854 | 8 / 0.285900 | 64 / 0.258380 |
| 3 commit | 4.168874 | 8 / 0.291674 | 64 / 0.263770 |

Across these nonoverlapping scopes, configuration totals 1.709215 seconds (48 calls), with compilation totaling 1.546865 seconds (384 calls) nested inside it. Configuration accounts for approximately 7.5% of measured final Accept, compilation approximately 6.8%; these are NOT additive. Neither nested total may be added to outer operation/writer/Accept totals. These timings locate measured cost, not a hypothetical optimization speedup.

The measured configuration/compilation work is a minority of this short route's delay and remains approximately steady while outer operation times rise. Existing checkpoint profiles put atomic writes at only 3.648–3.945 milliseconds. Metadata/proven-journal composition measurements rise across the writers (prepare metadata 0.947428/1.627269/2.112682 seconds; commit proven-journal composition 0.983134/1.667485/2.066101 seconds), while current validation remains near one second. This makes the remaining validation/composition work a better next investigation target than assuming repeated DTL compilation explains the whole delay. No exact internal cause is established by these aggregates.

## Limits and next bounded work

This result qualifies the opt-in observations on the short direct-ending fixture. It does not qualify the full restored-history journey, packaged export, broad Windows CI, arbitrary interruption, or performance improvement. It does not establish that a previous prepare stalled. Preserve the three distinct recovery checkpoints and current deadlines. Review the remaining expensive validation/composition call path before choosing any optimization; a future optimization requires matched whole-operation measurements with identical flags and preserved save/recovery/history contracts. No automatic unchanged replay, timeout extension, cache, checkpoint coalescing, merge or release follows from this pass.
