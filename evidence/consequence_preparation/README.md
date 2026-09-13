# Consequence preparation: detached copies and issued-record refusal

2026-09-13; `dwm-634.3` and `dwm-634.4`. Baseline: `02b941480`.

## Changes

`DesktopConsequenceState.checkpoint_content_preimage()` now projects receipt
fields on the private tree already returned by validation. It removes two
redundant deep copies for a nonterminal candidate and one for terminal cleanup.
`SaveManagerCheckpointPort` likewise attaches its receipt directly to the tree
already detached by JSON subtype normalization. Across the five large App
checkpoints at ordinals 1, 2, 8, 9 and 10, this removes fifteen traversals of the
recovery payload. Validation, independent hashes, live-adoption isolation,
physical writes and complete-action recovery policy remain intact.

A regression test also reproduced a separate failure: a prepared record with
a nested integer changed to an equal float could enter an empty transient slot
with its old receipt. The initial audit blamed native dictionary equality;
that hypothesis was wrong. Godot 4.6.3 equality uses a type-aware comparison
([dictionary.cpp](https://github.com/godotengine/godot/blob/4.6.3-stable/core/variant/dictionary.cpp#L242-L269),
[variant.cpp](https://github.com/godotengine/godot/blob/4.6.3-stable/core/variant/variant.cpp#L3033-L3035)).
The changed record missed the issued-record cache and the cold shape validator
then accepted it. A successful cold normalization now must match any retained
issued proof before insertion. The ordinary hot comparison is unchanged.
StringName aliases still normalize successfully, and valid cache-evicted
records retain their existing path. The supplied-receipt type mismatch already
refused correctly; its new test passed before the fix.

## Measurements

The headless before/after runs use the same arguments, a real persisted Day 1
Lavinia reply in `zh-CN`, `DWM_CHECKPOINT_PROFILE=1`, and the diagnostic patch in
`evidence/native_json_encoding/temporary-consequence-profiling.patch`.
That patch was removed before the final suites and Windows runs.

| Boundary | Before | After |
| --- | ---: | ---: |
| Five App win checkpoint preparations, total | 199.805 ms | 179.822 ms |
| Five App loss checkpoint preparations, total | 138.935 ms | 125.040 ms |
| App first reveal, synchronous | 226.708 ms | 263.509 ms |
| App later new-board first reveal, synchronous | 578.996 ms | 511.443 ms |
| App win to settled | 0.994 s | 0.857 s |
| App loss to settled | 0.857 s | 0.875 s |
| Dating first reveal, synchronous | 321.674 ms | 299.058 ms |
| Dating loss to settled | 0.444 s | 0.416 s |

These are one fresh process per version with different seeds and history sizes
(223 versus 207 later routine App inputs). They show reduced preparation work,
but do not establish a general latency improvement or controlled attribution
of every difference. In particular, first reveal and loss did not improve in
this sample. Nested profile phases are inclusive; do not sum them as separate
costs. Early routine input medians stayed about 23.6 ms.

One final Windows/OpenGL run persisted the authored `zh-HK` reply and completed
Expert App win/loss plus Dating win. End-to-end settled times were 0.794/0.777 s
for App and 0.423 s for Dating. This invokes actual controls in a native game
process; it is not a physical device input-to-paint measurement.
A separate Windows/OpenGL journey passed New Account, pre-expiry Slot 1 Save,
Schedule Done, Day 2 Autosave Load and older Slot 1 Load, correctly restoring
the earlier Day 1 ordinary message.

## Verification and limits

The initial two-suite regression run had 63 passing tests and one expected
failure (six assertions); the new State detachment test already passed.
The fixed five-suite run passed 114 tests / 1,450 assertions. After removing
diagnostics, ten consequence/checkpoint/publication/Minesweeper suites passed
251 distinct tests / 5,837 assertions. New tests cover two-way nested mutation
isolation, changed known-issued records before first commit, unchanged original
retry, receipt numeric types, StringName normalization and valid proof eviction.
Independent reviews cleared both production changes. Existing Dialogic orphan
reports and startup malformed-string diagnostics are retained in the logs.

Both public-surface inventories were regenerated: all 239 GameState and 74
SaveManager contracts are unchanged, with only call-site locations and reference
ordering updated. The final repository gate passed 14 tests / 410 assertions,
bringing the total to **265 distinct tests / 6,247 assertions**. The run ledger
contains ten attempts: nine successful runs and the expected regression red.

All engine runs are serialized through `Invoke-IsolatedGodot.ps1`, with isolated
temporary user directories. `runs.jsonl` records each attempted command and its
actual exit; matching logs are retained here. No player save directory was used.

`dwm-634.3` remains in progress: final settlement is still noticeable and larger
manual/dialogue histories need measurement. `dwm-634.5` records the pre-existing
cold contract gap after a proof is evicted: the shape validator does not
re-derive the receipt hash or fully validate a stage candidate. This increment
protects retained issued records and does not claim to solve that separate gap.
