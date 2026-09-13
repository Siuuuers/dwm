# Source checkpoint copy: measured and rejected

2026-09-13; `dwm-634.7`; baseline `ebb1f2b64e2847d278659ea6a7735c259a17de96`;
Godot 4.6.3 mono. No production change is retained from this experiment.

`MinesweeperRoundCoordinator.complete_round` deep-copies the captured checkpoint
input before replacing its board with the detached pre-terminal replay point.
The candidate copied only the three dictionaries along that replacement path.
Although it removed almost all of this copy's cost, the saving was less than
0.1% of the measured terminal delay. Retain the simpler full copy and its clear
ownership boundary; further work remains under `dwm-634.3`.

## Measurements

One isolated headless process per version, with the same benchmark arguments:
an actual authored Day-1 Lavinia reply in Simplified Chinese, Expert App win and
loss, and Dating loss. Both processes completed with exit 0. The source-copy
timer covers copying and board substitution; preparation is measured separately.

| App boundary | Original copy | Candidate copy | Original preparation | Candidate preparation |
| --- | ---: | ---: | ---: | ---: |
| Win | 558 us | 3 us | 27,819 us | 29,083 us |
| Loss | 445 us | 3 us | 41,245 us | 39,414 us |

| Action to settled state | Original | Candidate |
| --- | ---: | ---: |
| App win | 747.605 ms | 798.824 ms |
| App loss | 744.107 ms | 729.664 ms |
| Dating loss | 401.268 ms | 397.336 ms |

Generated boards and histories differ: the profiled App source boards contain
225/233 receipts in the original run and 232/240 in the candidate. These whole
journey timings establish neither a speedup nor a regression. The scoped copy
measurement does establish that this operation is too small to explain the
visible delay. This is not a physical input-to-paint measurement.

## Reproduction and disposition

`baseline-profiling.patch` adds timing only. `candidate-profiling.patch` contains
the path-copy experiment and the same timing. Each applies independently to the
baseline with `git apply --unidiff-zero`. Set `DWM_CHECKPOINT_PROFILE=1` for the
existing save-phase diagnostics and use the isolated wrapper with the benchmark
arguments recorded in `runs.jsonl`; preserve its isolated user-data setup.

The coordinator was restored byte-for-byte to the baseline afterward, SHA-256
`69799d66589389e6cff5f1c16c80ebe51ddf761c05da47b7def944090cfcd223`.
The two full-save boundaries and all recovery behavior remain unchanged.
`unexecuted-draft-tests.patch` preserves proposed ownership/refusal regressions;
these tests were **not run** and were removed from the active test suite when the
candidate was rejected. No candidate correctness or native-renderer acceptance
is claimed. They would be required before reconsidering this change for shipping.

Both original run logs and the process ledger are retained here. Archived logs
only normalize trailing horizontal whitespace and the final newline. Existing
Dialogic/NUL shutdown diagnostics remain visible in the logs.
