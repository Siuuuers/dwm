# Historical Minesweeper receipt metadata

2026-09-13; `dwm-634.6`; baseline `072ec79f4`; Godot 4.6.3 mono.

## Change and compatibility

An accepted DesktopBoardState command already replaces older routine results
with a compact acknowledgement. Those records still retained command kind,
identity fingerprint and pre/post revisions even though replay only consumes the
transaction key, request fingerprint and result. The acknowledgement already
contains its revision.

At that same boundary, known six-field `board_command` and `visibility` records
now retain only `request_fingerprint` and their exact acknowledgement `result`.
Every transaction key survives. The latest response stays full until another
command is accepted; first-reveal and nonroutine proofs stay full. Loading alone
does not rewrite anything. There is no new cache or migration phase.

Only the known member set and metadata types permit removal. Unknown kinds and
minimal records remain untouched; extended or malformed records retain their
metadata while following their existing result-compaction behavior. The separate
top-level run effect/variable receipt ledger is unchanged. Continuation remapping
already rekeys every transaction and rewrites identity fingerprints only when
present. The safe-marker and completed-result full saves are unchanged.

## Fixed component comparison

`benchmark_fixed_board_receipts.gd` reads and validates the existing actual save
at `../localized_json_encoding/baseline-zh-CN-autosave.json`: 423,637 bytes,
SHA-256 `a49f3912e71a94033ba9b61195e65bcce3be5b1571cf400f28b67c179fb1ad99`.
Its three board components are identical. Each sample restores the same
`NONE:209` board with 206 command receipts and two terminal receipts, then uses
the public unpaid-shell command to reach `UNPAID_UNSTARTED:210`.

Five samples per source version passed 108 checks each. The expected record
representation is explicit via `--expected-metadata=full|compact`. Both variants
retain all 207 resulting command keys, the same acknowledgements, both terminal
proofs, the exact new shell receipt and a production-restorable board component.
The source save remains byte-identical. The probe writes no save.

| Same post-command component | Baseline | Current |
| --- | ---: | ---: |
| Board canonical bytes | 100,765 | 68,655 |
| Combined command/terminal ledger bytes | 100,561 | 68,451 |
| Historical acknowledgements with full metadata | 202 | 0 |
| Minimal acknowledgements | 0 | 202 |
| First legacy-compaction commit, median | 579 us | 782 us |
| Capture, median | 278 us | 216 us |
| Prepare + commit + capture, median | 926 us | 1,030 us |

The reduction is **32,110 bytes per component (31.9%)**. Three equivalent
components would save 96,330 bytes, about 22.7% of the original file. That is a
component projection, not a rewritten/revalidated whole save or a promise that
older recovery snapshots change immediately. The first accepted action pays a
small conversion cost; later capture/storage traversals carry less data.

Reproduce with the isolated wrapper and the archived argument lists in
`runs.jsonl`, using `-s res://evidence/receipt_metadata_compaction/benchmark_fixed_board_receipts.gd`
and `-- --expected-metadata=full` on the baseline or `compact` on the final code.
The baseline measurement temporarily used the exact HEAD version of
DesktopBoardState; the candidate was restored byte-for-byte afterward, SHA-256
`ca4cae3caa3bda9aa955976e276ffc08206cc0511bb208a5d1ceabdc29b86810`.

## Gameplay observations

One fresh headless process per version used `DWM_CHECKPOINT_PROFILE=1`, an actual
authored Day-1 Lavinia reply in Simplified Chinese, Expert App win/loss, and
Dating loss. The current comparison preceded the final malformed-type guards;
those guards do not alter the normally produced records used by this journey.

| Boundary | Baseline | Current |
| --- | ---: | ---: |
| App win to settled | 973.724 ms | 793.787 ms |
| App loss to settled | 919.689 ms | 755.060 ms |
| Dating loss to settled | 461.038 ms | 393.969 ms |
| App initial reveal | 246.417 ms | 245.032 ms |
| App later new-board reveal | 546.143 ms | 506.160 ms |
| App early routine median | 23.631 ms | 27.179 ms |
| App later routine median | 29.502 ms | 29.740 ms |
| Dating first reveal | 356.015 ms | 278.192 ms |

Generated boards and histories differ (242 versus 208 later App routine inputs),
so the timing pair does not isolate every difference. It does not demonstrate a
routine-click speedup or physical input-to-paint latency.

A final Windows/OpenGL run on the restored final source persisted the authored
Traditional Chinese reply and completed App win/loss (721.237/662.055 ms) and
Dating win (400.327 ms). These are automated production paths; neither the
whole UI's language setting nor a fresh-process save load is claimed here.
The broader latency parent `dwm-634.3` remains open.

## Correctness and repository checks

The red BoardState run failed exactly the two metadata-removal expectations
(35/37 tests, 155/157 assertions). Existing replay behavior stayed green. The
four-suite green run passed 172 tests / 1,466 assertions. After review added the
three malformed-type guards and independent fixtures, the final BoardState,
coordinator integration, board-fate, run-schema and continuation-journal group
passed 150 tests / 4,126 assertions.

The tests cover old retry acknowledgement and conflict, exact latest retry,
first-reveal and terminal proof retention, load-then-accept behavior, source and
capture isolation, unknown/malformed/extended receipts, and mixed compact/full
continuation rekeying with independent remap validation. The new remapping test
also passed on the baseline, establishing existing two-field compatibility.

The repository gate passed 14 tests / 410 assertions. Excluding the overlapping
37-test BoardState rerun, the final total is **299 distinct tests / 5,845
assertions**. Regenerated inventories retain all 239 GameState and 74 SaveManager
public contracts and the same dynamic-reference sets; only call sites moved.
Independent production review cleared the final source.

`runs.jsonl` and its adjacent logs retain all 12 attempts: 11 passes and the
explained red run. Engine processes ran serially with isolated temporary user
directories. Existing Dialogic orphan/malformed-string diagnostics remain in
the logs. No player save directory was touched.
