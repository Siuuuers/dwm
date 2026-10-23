# Narrative admission evidence

`witnessed-admission-accepted-20260907a.log` is the acceptance run: 15 suites, 248 tests, 6,248 assertions, exit 0. Twenty integration tests use the installed native Dialogic runtime. No script error remains. The log records 2,352 known addon-constructor fixture orphans and the environment's certificate-store/Unicode startup diagnostics. All runs use isolated user-data roots; exact invocations and outcomes are in `invocations.jsonl`.

Committed log copies use UTF-8/LF with trailing whitespace removed. Original raw logs remain at the invocation paths under `.godot/phase2r_logs`.

Retained diagnostics are not acceptance:

| Run suffix | Observation |
| --- | --- |
| red-20260906b | Missing ordinary admission reproduced: 1/4 tests passed, 48/66 assertions; fixture also exposed a native cleanup script error. |
| diagnose-20260906a | Native access violation (-1073741819) after canceling pending Hospital then retrying. |
| cancel-ablation-20260906a | Deferring deletion past queued layout mount: 10/10 tests, 192 assertions, exit 0. |
| acceptance-20260906a | 237/241 tests; four failures in the old Hospital port fixture, which leaked native playback and synthesized completion. |
| request-20260906a | 17/17 real-runtime tests, 397 assertions; includes explicit request identity under same-path replacement. |
| accepted-20260906a | 247/248 tests; detached fake runtime's layout cleanup queried a missing scene tree. Fixed with an attachment guard. |

The final run includes corrected Hospital fixtures, immediate retry during a failure callback, and pending/live restore rollback with both prior pause states. The cancellation ablation addresses its specific reproduced crash; it does not close the separate intermittent GPU-renderer shutdown investigation (`dwm-eei.17`).

The implementation and limitations are described in [narrative-live-admission.md](../../docs/design/current-ui/narrative-live-admission.md). This evidence establishes the `dwm-eei.19` prerequisite, not completion of Pause, all UI families, or integration into the dirty destination branch.
