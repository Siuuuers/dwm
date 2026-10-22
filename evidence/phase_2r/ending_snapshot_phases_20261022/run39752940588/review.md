# Independent snapshot-phase review — run39752940588

Disposition: PASS for the bounded short-route observation. No blocking evidence discrepancy found. Review used original extracted artifacts with Python/static inspection; no local Godot/PowerShell, new run or remote mutation. Original ZIP/API digest verification and actual event workflow-blob reconciliation remain separately Lead-owned.

## Source and preparation custody

Product `9f404db25737fca51b1ab3f2fe495d55a0b4dbda`, assets `67f799e3cd14316097ed9f9d3ff150c94d5abac0`, controller `39c6eea78ed6342fea84ea78ce8d3f6da4c2d08b`. Preparation records actual workflow event commit `e6618172c9b95d9f7062af869c88c6b74de8c1c9`, attempt 1.

All four custody policies pass. All eight source identities match the reviewed manifest at baseline and in all four phase receipts (32 phase/source matches). Baseline has 13,423 tracked paths and no generated inputs. Import contains only the authorized project-settings byte change and two index-only malformed-gitlink removals; restored/post-test captures show original project bytes, complete custody, unchanged product head and no further authored-byte mutation.

Import/restored/post-test each record 38 generated inputs, no rejection. Both narrowly admitted runtime UIDs complete 1,719 peer comparisons with no collisions. The timing helper's changed source blob is correctly pinned. Preparation/capture helper hashes match reviewed pins; every retained harness member matches reviewed local bytes and its manifest. Preparation SHA256 `6295d41cd60ac82eaa8b5ad6c43889730cf137b6c23c083553955b9027ac5fb4`; runner `f84a9a302fb8f017c0909c015e66e21587ed1a9885c972647e0f43005d606055`.

## Runtime and observation gates

Exactly one selected test passes, `test_direct_ending_accept_returns_without_save`, with **69 XML assertions**, **32.751527 seconds**, zero failures/errors/skips and child exit 0. XML/result/isolation agree. The rendered isolated child preserves gl_compatibility, accessibility always, the existing 120-second deadline and real viewport input path. No runner error patterns appear in the engine log. Existing premature Accept refusal, durable COMPLETED/GALLERY_RECORDED, Gallery and Title gates remain passing.

Nine aggregate records exactly match raw log JSON and each is enclosed by its corresponding writer-operation begin/return markers. Capture has zero snapshot records; each prepare/commit has four, giving 24 completed snapshot validations. Every record is successful, has contiguous completion ordinal and all four nonnegative phase durations; its phase sum does not exceed total, and total does not exceed enclosing operation. All configuration/compilation failure counts remain zero.

The six journal profiles exactly match their raw log JSON and retain correct writer-operation association. Dynamic entry counts, contiguous entry ordinals, bundle sums, scene-journal residuals and distinct build/outgoing parent nesting recompute exactly. Their journal label sequence pairs remain 2/3, 3/4 and 4/5. Each operation's snapshot records include two copies of its current sequence plus those two older sequences. Completion ordinals are observations, not a general proof that arbitrary calls never overlap.

## Measured phases

Final Accept takes **21.586132 seconds**. The three returned writers take **5.747530**, **6.967519** and **7.988534 seconds**.

| Observed snapshot group | Completed calls | Per-call total seconds | Pre-semantic validation seconds | Semantic callback seconds |
|---|---:|---:|---:|---:|
| PLAYING, sequence 2 | 2 | 0.329700–0.336785 | 0.124303–0.127846 | 0.197482–0.201057 |
| ENDING/PRIMARY_PENDING, sequence 3 | 4 | 0.558357–0.578561 | 0.240988–0.249932 | 0.309349–0.320269 |
| Later ending/completed, sequences 4–6 | 18 | 0.950119–1.006449 | 0.434623–0.466190 | 0.504667–0.534534 |

Guard preparation (the original hashes/detached copies) costs **3.890–5.613 milliseconds per call**; post-callback mutation verification costs **3.788–5.179 milliseconds**. Both the pre-semantic schema region and live semantic callback are substantial. The guards are a small fraction of each later ending validation and are not the measured dominant region.

These are per-call ranges, not independently additive maxima. Snapshot totals enclose their four sequential phase durations; configuration/compilation and journal measurements overlap these regions. Do not add those categories to snapshot/writer/Accept totals, or infer a speedup by removing a measured category. The lifecycle-associated differences describe the actual saved bundles in this fixture, not a law that a state label itself causes delay.

## Limits and next bounded work

This pass qualifies the new opt-in phase observations on the short fixture. It does not establish a performance improvement despite the lower wall time than the preceding run: instrumentation/source and uncontrolled run conditions differ, and no matched optimized candidate exists. Full restored-history gameplay, export, general CI and arbitrary interruption remain separate and unqualified here.

The next source investigation should follow the substantial pre-semantic and semantic regions, using the already identified receipt/Frozen reading validation call paths and their distinct proof obligations. Repeated current/journal validations alone do not justify bypassing public validation, caching durable authority or deleting one of the three checkpoints. Preserve the original hashes, mutation rejection, reentry guard, failure order and recovery boundaries. Any optimization must be independently justified and compared as a complete operation with matching observation settings. No unchanged replay, timeout extension, merge or release follows from this result.
