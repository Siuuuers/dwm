# Reuse the expanded New Game checkpoint

Base: master a70e8876b8755d819d613b9cc458caeaa04cdffc (PR #269).
Outcome: reach the same usable first caption with less synchronous New Game
preparation. NarrativeRestoreParticipant owns its prepared narrative plan.

## Measurement and smallest change

Baseline preparation spans (Linux headless): identity 4.855 ms; snapshot input
76.482 ms; initial reading 65.383 ms; snapshot construction 57.654 ms; profile
capture 0.087 ms; all plans 81.108 ms (including narrative 73.144 ms); transaction
until pending return 53.961 ms. These top-level spans total 339.530 ms.

Deeper attribution found eight ledger initializations, each about 19–23 ms.
Compact checkpoint expansion rebuilds a reading session, including validation,
copying, freezing and indexing the full caption registry. Each expansion took
about 20–25 ms in that trace.

New Game narrative preparation already expanded the compact checkpoint to derive
its scene frames, then passed the original compact checkpoint to validation,
which expanded it again. Pass expanded.value to that existing validator instead.
This is one changed runtime line. Keep the compact checkpoint as the retained
and returned plan. Ownership, normalization, schema/content/context checks and
independent staging validation remain unchanged. No saved-data format changes.

Candidate diagnostic: narrative preparation 50.565 ms versus baseline 73.144 ms;
all plans 57.772 ms versus 81.108 ms. Other spans varied substantially, so this
is attribution of the removed reconstruction, not a universal total-speed claim.

## Complete operation and focused checks

Uninstrumented B/C/C/B, separate fresh process/profile, same Linux host and
Godot 4.6.3. Click two seconds after runtime readiness; immediately open Computer
on the first acknowledged, visible, fully revealed caption with input unblocked.

| Endpoint | Baseline | Candidate |
| --- | --- | --- |
| Click to usable caption, samples | 728.465 / 672.747 ms | 572.412 / 604.649 ms |
| Median | 700.606 ms | 588.531 ms |
| Immediate Computer, samples | 34.724 / 35.789 ms | 39.178 / 29.846 ms |

All four exact-caption/Computer observations passed, exit 0, no warnings/errors.
Two samples per variant do not establish a percentile or portable speedup. The
whole-operation median difference exceeds the isolated removed cost; do not
attribute all of it to the one-line change. OS caches were not cleared.

Focused suites, separate processes: initial candidate (6 tests / 61 assertions),
joint New Game/Save/Load (1 / 42), native activation (10 / 165). Total 17 tests /
268 assertions, exit 0 and clean logs. A first attempt grouped them in one process
and failed fixture selection with registration_already_selected; the immutable
registration fixtures require separate processes. That failed log is retained.
Independent caller review found no new branch requiring an added test.

Windows exported opening, Computer, Save and exact fresh-process Load: pending.
No unrelated regression matrix or new fault-injection tests.

## Evidence and next target

Evidence: tools/player_latency/evidence/2026-11-11-newgame-preparation, including
raw compressed logs, JUnit, temporary attribution scripts and comparison runner.
Reproduction requires an imported source checkout, godot on PATH and fresh
user directories. Copy observe.gd.txt to .godot/ci/title-art/observe.gd; decompress the
baseline participant into .godot/ci/newgame-preparation under its recorded name,
then run compare.py from the root on the candidate. Timing scripts temporarily
edit sources and restore them in finally; do not run with other editors/engines.

The broader repeated caption-registry initialization is a measured next candidate.
Any future reuse must keep unknown/mutable inputs validated and session progress
separate from immutable authored indexes. No registry cache is introduced here.
