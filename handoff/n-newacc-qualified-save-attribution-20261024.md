# New Acc configuration reuse qualified; Save/Load callers attributed — 24 October 2026

## Publication and outcome

PR [#78](https://github.com/Siuuuers/dwm/pull/78) is qualified for merge. This record is written immediately before publication; consult live PR metadata for its merge commit. Baseline master is `a5a7da03b9573ab2d751129de0063027dd2d2d50`, which already includes PR #77. Final qualified source/tests/inventories are `d951ff53a20967a8a0cd65dae325324eb24cb7bc`. Its three runtime files are byte-identical to the initial measured candidate `7c6da61345ed2bcde804b8b6f56922a505fdf817`. Later publication changes retain evidence and this handoff only.

**New Acc reaches the complete first caption sooner in both comparison orders, with a smaller maximum frame gap and identical durable behavior.** This is a bounded improvement; remaining freezes are still multi-second. Ordinary Save/Load correctness passed, but its timings remain mixed and slow. No Steam upload occurred.

`RunSnapshotSchema.validate_scene_new_run_candidate` previously configured the entire registered story twice in one synchronous check. It now passes its freshly admitted reading session to a private Bridge reconstruction helper. `SoloReadingSession` creates an independent sibling with fresh ledger/cursor state, shares recursively frozen configuration, and copies mutable lookup/manifest containers. The restored saved ledger never supplies the expected initial publication. Public reconstruction still starts fresh; selected-target compilation, physical-source checks, exact initial-checkpoint comparison and refusal order remain. No persistent cache, manager, saved field or save-policy change was added.

## Qualification

All Godot and PowerShell execution occurred on checksum-pinned Godot 4.6.3 Windows cloud runners. Local work was source, Git and artifact review.

- [Run 40096923561](https://github.com/Siuuuers/dwm/actions/runs/40096923561), controller `2437f8b640506bab8c7d5d28b29628ecde7b3a8f`: native baseline-first comparison and ordinary Save/Load comparison passed. Its initial focused run failed **80/86**: incompatible immutable registration fixtures shared one GUT process; an unchanged materials fixture also introduced a StringName key through dot syntax. All nine initial-candidate cases, including the five new regressions, passed. The failed artifact remains retained, not relabeled.
- [Run 40097392016](https://github.com/Siuuuers/dwm/actions/runs/40097392016), controller `5dc1aad33d21c0d9185bcc01eb3717fcbc139b4b`: **86/86 tests, 1,801 assertions, zero failures/skips, eleven separate suite processes**; committed inventories checked without regeneration; candidate-first native comparison passed. An isolated unchanged-baseline materials suite reproduced its exact existing failure. Those four diagnostic cases and their expected failing exit are excluded from passing totals.

The materials fixture now inserts the explicit String key `["dark_mode"]` and verifies primitive admission before asserting the intended member refusal. No tests were removed. Five new cases cover canonical-byte equality and one fresh configuration per validation, forged-but-generally-readable saved publication/frame rejection, fresh sibling mutable state, and changed physical content on a subsequent public call.

Both inventory payloads differ from baseline only in reference line locations. Independent normalization and byte checks confirm unchanged public surfaces and required contracts. Final committed GameState inventory SHA256 is `af2faf714b9a61dd282fb5ede16ccee5f0a71117cadd8f903650a2fb11f0c8f1`; SaveManager is `839034b1ff2d89bdd23c18e6f62947939f826db91e5bc52ea12174f00ced427b`.

## Complete-operation comparisons

Seconds, baseline → candidate on the same runner for each pair:

| Operation | Baseline-first | Candidate-first |
| --- | ---: | ---: |
| Fresh New Acc → complete first caption | 13.081 → 11.666 | 10.686 → 9.838 |
| Retained New Acc → complete first caption | 13.854 → 12.538 | 11.217 → 9.931 |
| Retained confirmation → complete first caption | 13.755 → 12.439 | 11.141 → 9.860 |
| Fresh maximum action frame gap | 8.633 → 7.584 | 7.064 → 6.467 |
| Retained maximum action frame gap | 8.586 → 7.711 | 6.926 → 6.156 |

New Acc improves approximately **7.9–11.5%** across these observations; maximum frame gaps improve approximately **8.5–12.1%**. The initial pair's complete configuration counts fall 34→19 fresh and 36→20 retained, with no configuration or compilation failures. Compilation requests are not parser invocation counts. Title timings vary in both directions; this change makes no additional startup-speed claim.

Eight native processes used actual button input, showed expected retained-account consent, reached the exact complete `line.Day1.one`, settled the continuation journal, left the New Acc owner idle and exited 0. All twenty capture sizes/hashes were verified and every distinct state reviewed. Captions differ in clock/transient UI tint; titles and consent match. The instrumentation's immediate resume `ok:false` is not an eventual flow failure; completed-caption/journal assertions pass.

These are source-project launches on Microsoft software rendering, not an installed Steam executable or player-GPU guarantee. Fresh user data is not a cold OS cache, and two pairs are not a latency distribution. Editor imports show the same ObjectDB leak warning on both variants. Save/Load uses its recorded OpenGL-to-ANGLE fallback; do not call all logs warning-free.

The separate ordinary Save/Load comparison passes **four current cases / 426 assertions / six clean exits**, retaining exact newly written slot bytes and complete restored captions in distinct processes. Fresh Load press→Ready is 35.793→35.315 s; retained-input Load is 57.005→57.654 s; Save press→return is 31.590→29.730 s. The small mixed Load changes do not establish a Save/Load acceleration. Historical input reports are excluded from current passing counts.

## Parallel Save/Load investigation and next work

[Diagnostic run 40096860109](https://github.com/Siuuuers/dwm/actions/runs/40096860109) passes two current native cases / 213 assertions / three clean exits on instrumentation-only source `f0a6285168f86a95cdb58f65c4299d174e52b1d3`, controller `755f595990e677fdd1d0048b798301469a28894c`. Read the [full caller/owner analysis](../evidence/phase_2r/save_callers_20261024/analysis.md) and [exact phase/input records](../evidence/phase_2r/save_callers_20261024/analysis.json) before new instrumentation.

The eight Load snapshot validations belong to selected Save9 admission, route derivation, narrative preparation, continuation prepare/commit, identity source loading, remapped Run application, and checkpoint commit. Seven share canonical source bytes; remapped application differs despite the same checkpoint sequence. Equal sequence numbers or hashes alone do not authorize reuse across storage or callbacks.

The next observable outcome should be **shorter ordinary Load press→Ready, preserving the exact saved caption, byte identity, fresh physical Profile checks and refusal precedence**. The measured next target is duplicate **nonempty-terminal Frozen validation**, not the smaller final anchor restore. Across the eight calls, terminal reading totals 8.334 s and the following semantic Frozen validation 7.121 s; final semantic anchors total 1.254 s. These are inclusive nested observations, not additive savings or optimization results.

The first Frozen result and the following equivalent semantic Frozen check appear separated only by hashing/copying and selected-registration comparison. Audit a private same-call reuse path in the canonical owners. Capture the semantic/issuer/creation/Frozen owner group **before** the first validation and compare afterward: merely checking currently matching owners could miss coordinated replacement inside callbacks. Preserve fresh public calls, empty-terminal fallback, final Profile/anchor proofs and mutation-over-refusal precedence. The analysis names exact code boundaries and regression coverage. No Save/Load optimization candidate is implemented or qualified yet.

## Durable evidence and session boundary

[New Acc evidence](../evidence/phase_2r/newacc_configuration_20261024/results.json) retains both comparison orders, final isolated tests, the failed initial run, ordinary Save/Load comparison, exact manifests and controller reconstruction patches. [Save/Load attribution](../evidence/phase_2r/save_callers_20261024/analysis.json) has its own source/controller patches and exact-byte compact archive. Manifests account for every original member, including byte-identical duplicates and explicitly verified historical inputs. Source, tests, controllers, rendered states and evidence received independent review. Diagnostic controllers do not belong in master.

No qualification job remains pending. This is a useful fresh-session boundary: one optimization is qualified and retained, and the next task is a different measured owner-boundary change with an actionable audit. No design answer currently blocks that audit. The unresolved font-corruption report still needs the original affected screenshot/build/display details described in handoff j; it does not block Load work. Do not dispatch the old Steam workflow assuming it exports current master; deployment remains separate.
