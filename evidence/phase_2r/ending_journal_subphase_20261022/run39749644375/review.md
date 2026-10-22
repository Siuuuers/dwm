# Independent journal-subphase review — run39749644375

Disposition: PASS for the bounded short-route observation. No blocking evidence discrepancy found. This review uses downloaded original preparation/qualification artifacts and Python/static inspection only; no Godot/PowerShell execution or retry. Lead separately verified original ZIP digests against the artifact API; that verification is not claimed here. Event workflow-blob reconciliation remains Lead-owned.

## Identity and custody

- Product `bef78c105697a256ee0ff1a40e9b4c306e2740e7`; assets `e2a0f30edb8fe8eae8315449f7b8d71423aeb5d9`; controller `5071b061850b13a2b81e1ea6119e6d19f621ff76`. Preparation records actual workflow event commit `d8b7cd7ebe685aaa42af7189066ccc8fcd70d2fe`, attempt 1.
- All four policies pass. Baseline has 13,423 tracked paths and no generated inputs. All seven source blob/SHA256 identities match the reviewed manifest at baseline and in all four phase receipts (28 phase/source matches).
- Import contains only the authorized project.godot byte change and two index-only malformed-gitlink removals. Restored/post-test captures retain original project bytes, identical product head, complete custody and no further authored-byte mutation.
- Import/restored/post-test each record 38 generated inputs with no rejection. Both narrow runtime UID exceptions complete 1,719 peer comparisons without collisions.
- Retained preparation helper rehashes to `2b503cad88833cfc6039f62f4012fef7d327f845934a4707cbe608e9c7c2b309`; capture helper to `a04a8560ea2ac7e8ff77d6bb3e3ffe8d1404193f5e1de2a71676332403fe7379`. All harness members match reviewed bytes and their manifest. Runner SHA256 `f2f802e5b5f83091cdf0028a8cf9309d2b0b4baea0cb0cd04fe07454294d3674`.

## Execution and attribution gates

Exactly one selected test passes: `test_direct_ending_accept_returns_without_save`, 69 XML assertions, 34.897719 seconds, zero failures/errors/skips, child exit 0. XML, result and isolation agree. The isolated rendered child retains gl_compatibility, accessibility always, existing 120-second timeout, and the same real input path. No runner error patterns appear in the engine log.

Nine configuration/compilation aggregates exactly match raw log records, retain successful returns and zero configuration/compilation failures, and map capture/prepare/commit to the three expected lifecycle/stage combinations at next_step_index 1. Six schema profiles likewise exactly match their raw log records and each lies between its unique corresponding writer-operation begin/return markers. Current labels identify sequences 4/5/6 and the expected ENDING/EPILOGUE_PLAYED, ENDING/GALLERY_RECORDED and COMPLETED/GALLERY_RECORDED states.

Dynamic journal input counts and completed entry counts agree; all six happen to contain two entries, but the parser does not assume that cardinality. Ordinals are contiguous and entries return successfully. PLAYING legitimately omits playback_stage. Entry duration sums equal bundle totals; bundle total plus checks/observation residual equals scene-journal total. Separate build composition and metadata nesting, outgoing combined nesting, and saved derived residuals all recompute exactly.

## Measured attribution

Final Accept takes 23.152293 seconds. Three returned writers take 6.201983, 7.600226 and 8.457054 seconds.

| Operation | Journal sequences | Bundle validation seconds | Proof equality milliseconds | Journal composition milliseconds |
|---|---|---:|---:|---:|
| Writer 1 prepare | 2, 3 | 0.989925 | 3.541 | 0.187 |
| Writer 1 commit | 2, 3 | 0.967443 | 3.528 | 0.113 |
| Writer 2 prepare | 3, 4 | 1.669327 | 4.114 | 0.199 |
| Writer 2 commit | 3, 4 | 1.673502 | 4.146 | 0.126 |
| Writer 3 prepare | 4, 5 | 2.100692 | 4.605 | 0.226 |
| Writer 3 commit | 4, 5 | 2.101147 | 4.620 | 0.160 |

Twelve returned journal-bundle validations across six nonoverlapping schema operations total **9.502036 seconds**, approximately **41.0% of final Accept**. Scene-journal inclusive total is 9.503010 seconds: the residual for cross-entry checks and observation bookkeeping is only 974 microseconds over these scopes. Proof equality totals 24.554 milliseconds and journal composition totals 1.011 milliseconds. Broader parent residuals are 26–30 microseconds per operation, with separate build-composition residuals 13–14 microseconds.

The growing metadata/proven-journal regions are therefore accounted for chiefly by their existing per-bundle validation calls in this run, rather than equality comparison or array composition. Entry cost changes as the two-entry window advances: PLAYING sequence 2 costs about 0.35 seconds, PRIMARY_PENDING sequence 3 about 0.61–0.64 seconds, and EPILOGUE_PLAYED/GALLERY_RECORDED sequences 4/5 about 1.05 seconds each. This is observed association with concrete saved bundles, not proof that a lifecycle label alone causes the cost.

Configuration totals 1.731424 seconds and compilation 1.570919 seconds in the enclosing operation aggregates. These overlap the validation measurements and compilation nests within configuration. They must NOT be added to journal-bundle, schema, writer or Accept totals. This run does not instrument enough of each bundle validator to identify its dominant internal cause; the remaining Accept time also includes current-bundle validation and other work.

## Acceptance limits and next bounded outcome

The original premature-input refusal and durable COMPLETED/GALLERY_RECORDED, Gallery and Title assertions remain passing. This is acceptance of the opt-in short-route measurement, not an optimization, restored full-history journey, packaged export, general Windows CI or arbitrary interruption qualification. The modest wall-time difference from the preceding observation is not a matched performance result and should not be described as regression or improvement.

Next inspect the existing bundle validation call path and proof contracts to locate the repeated expensive work and determine which reuse, if any, could preserve the exact validation/recovery guarantees. Do not skip validation or remove one of the three persistence boundaries on these timings alone. Any candidate optimization needs matched whole-operation evidence with identical observation flags. No automatic unchanged retry, deadline extension, merge, release or export run follows from this pass.
