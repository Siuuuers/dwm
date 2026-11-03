# Story progression command phases

Implementation of [the progression handoff](2026-11-03-story-progression-handoff.md),
based on master `87a4153836a2d8d47ce36c423d891fc13c3a769d`.

## Observable result and owners

One accepted progression command owns its transition until completion. Competing
commands cannot duplicate it. Success or ordinary refusal releases temporary
ownership so the next valid action remains available.

`DialogicBridge` owns temporary coordination. `SoloReadingSession` still owns
story position and traversal state; `GameState` owns gameplay consequences. No
save format, migration, content, layout, or player feature is replaced.

Six overlapping booleans become one `ProgressionPhase` value. The duplicate
`_next_command` frontier is removed; `_admitting_frontier` remains the one retained
Next request. Existing native callback generations and mutation leases keep their
separate purposes.

| Phase | Meaning |
| --- | --- |
| `IDLE` | No progression command owns execution |
| `NEXT_ADMITTING` | Next validates/prepares its source, or publishes completion before returning |
| `NEXT_ACKNOWLEDGING` | Next's authorized source acknowledgement runs synchronously |
| `NEXT_ACTIVE` | Existing durable/native traversal owns its lease |
| `AUTO` | One admitted automatic step |
| `SKIP` | One admitted reveal/acknowledge/classify/advance step |
| `ACKNOWLEDGING` | Standalone acknowledgement or nested Auto/Skip acknowledgement |

Acknowledgement restores its parent phase from a synchronous local variable.
Next's private source helper can acknowledge during admission. Public recursive
acknowledgement cannot enter. The same helper still works for Computer opening
from idle. Auto/Skip retain renderer acknowledgement during native publication.

Identical Next requests coalesce throughout all Next phases; changed frontiers
conflict. `_finish_next` returns to admission before emitting completion signals,
so callbacks cannot steal ownership before the outer request returns. Public
Next availability requires idle; its internal preparation query does not try to
readmit the already-owned command. Skip capability retains its existing UI
meaning; the command itself admits only from idle.

Guards that previously depended only on active traversal still check only
`NEXT_ACTIVE`. Expanding those guards to every phase would prevent legitimate
source checkpoint capture and acknowledgement.

## Verification and concrete failures

The selected checks cover competing requests during reveal/Profile publication,
valid nested acknowledgement, completion-signal reentry, ordinary write refusal
and retry, stale/unacknowledged Auto sources, Skip's unread/control stops, manual
Next through dissolve, thought reveal versus departure, and fresh-process Load.

The [bounded TLA+ model](../../tools/verification/story_progression/README.md)
records the model/code mapping, finite bounds, checker hash and limitations. Its
eight safety invariants passed over 537,760 distinct states (two source occurrences
plus terminal). It is not automatic verification of Godot code, save contents,
callback completion, or arbitrary stories.

`tools/testing/run_progression_checks.py` selects 11 command methods and six
rendered current-Scene methods. Each process gets isolated storage; create/load
pairs alone share it. The runner requires the exact selected method, nonzero
assertions, passing XML, no script/load errors, and journey completion markers.
The Linux job uses the existing real speech-service setup for the Settings panel
visited by the thought journey. CI artifacts and the implementation PR retain
final execution results.

`tools/testing/test_windows_coverage.py` verifies the shared coverage selector.
Only the reviewed method/declaration changes and exact active-phase predicate
substitutions qualify for the focused job. Unrelated owner edits retain existing
coverage. Model-only changes also run the protocol job.

The historical notification fixture's selected connected test fails on unchanged
master before progression (`invalid_run_plan`: `snapshot.lifecycle is required`).
Its retired private-field references are migrated, but rebuilding its obsolete
snapshot is outside this slice. Current connected Next evidence comes from
`render_scene_transition_create.gd`, which clicks the real Next button and checks
dissolve/input behavior. The baseline failure is not counted as a passing check.

## Deliberately outside this change

No injection campaign, broad language/font matrix, full-week journey, unrelated
shop/audio suite, Windows export, repository-wide comment sweep, save-format
rewrite, or general CI redesign. Existing data-loss handling remains intact.
There is no measured latency claim and no native Windows qualification. Fewer
flags improve the coordination representation; they do not establish a speedup.

## Verification efficiency follow-up

The model now keeps only the latest behavior tag. Its 1,612 reachable states
project onto exactly the same 288 protocol/bookkeeping states as the original
537,760-state model. All eight invariants remain; an executable dump check requires
all 14 behavior witnesses and completed/released ownership. See the model README
for reproduction and bounded-model limitations.

The source/destination write-refusal methods share one Godot process via the exact
`write_refusal_keeps_` filter. XML validation requires both full method names once
each, positive assertion counts, and passing status. A separate/combined then
combined/separate comparison measured mean wall times of 16.265 versus 8.621 seconds
for the same two methods and 66 assertions. Fixtures reset their bridge, profile,
native adapter and file operations between tests. The other nine headless methods
and all six native journeys retain their previous process isolation, including
fresh-process save/load evidence. This reduces 17 test launches to 16.

These are verification improvements, with no game, content or save-format changes.
A possible `stops_` group matches three selected boundary methods, but has not been
qualified in a shared process and remains separate. Broader test suites and
checkout redesign are outside this measured change.
