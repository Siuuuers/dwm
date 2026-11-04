# Story progression command coordination

This bounded model checks the temporary command protocol in
`autoload/DialogicBridge.gd`. It does not introduce a second story cursor or
verify the Godot implementation automatically. `SoloReadingSession` continues to
own story position; gameplay and storage retain their existing owners.

## Transition mapping

| Model action/state | Production counterpart |
| --- | --- |
| `Begin("next", request)` | `_perform_next`: retain the frontier and enter `NEXT_ADMITTING` only from `IDLE` |
| `Begin("auto", request)` | `request_auto_step`: enter `AUTO`, then `_auto_line_context` checks the supplied source |
| `Begin("skip", request)` | `request_skip_step`: enter `SKIP`, then `_perform_skip_step` captures the source |
| `Prepare` | Existing source/context, pause, boundary and command eligibility checks; refusal returns without advancing |
| `BeginAck` / `EndAck` from Next | `_acknowledge_next_source`: `NEXT_ADMITTING` → `NEXT_ACKNOWLEDGING` → `NEXT_ADMITTING` |
| `BeginAck` / `EndAck` otherwise | `acknowledge_current_line_presentation`: save `IDLE`, `AUTO` or `SKIP` on the synchronous stack, enter `ACKNOWLEDGING`, run `_record_line_presentation`, restore the parent |
| `ActivateNext` | Legacy caption/marker traversal acquires its existing lease and enters `NEXT_ACTIVE` |
| `Advance` | Abstract successful direct Scene dispatch or durable/native traversal; Auto/Skip use their existing `advance_one_event`/registered-marker paths |
| `EndAck("fatal")` | `_record_line_presentation` latches `_line_ack_fatal_failure`; further acknowledgement and progression cannot commit |
| `PublishError` | `_record_line_presentation` defers the existing `ApplicationBootstrap.show_content_error` call after latching the failure; publication follows synchronous command ownership return |
| `Refuse` | Existing ordinary failure/refusal return; no new recovery policy |
| `FinishNext` | `_finish_next`: return to `NEXT_ADMITTING` before completion signals; the outer command still owns the transition |
| `Return` | `_perform_next`, `request_auto_step` or `request_skip_step` returns to `IDLE` |
| `CompetingNext` | `_perform_next`: same retained frontier coalesces throughout all Next phases, a different frontier conflicts, another owner refuses |

Public acknowledgement cannot enter during Next. Only the private source helper
can do that. The helper also serves Computer opening while idle; that call uses
ordinary public acknowledgement. Recursive acknowledgement cannot enter either
acknowledgement phase. Renderer acknowledgement during Auto/Skip restores that
outer phase, including publication of a newly displayed destination before the
outer method returns.

The model's `parent` represents a synchronous local variable, not another mutable
production owner. `owner`, `pc`, counters and `last_event` are verification bookkeeping.
`pc` distinguishes the call location before execution from the return path:
`NEXT_ADMITTING` occurs both before traversal and while completion signals run.

## Bounds, properties and assumptions

The checked configuration contains two distinct source occurrences and one
terminal position. Requests can refer to either source. Source numbers represent
occurrences, not reusable caption IDs; restoration and backward traversal are
outside this model. Next can start with source readiness already satisfied (for
example, control continuation); Skip must acknowledge and Auto admission requires
an acknowledged source.

The safety invariants check:

- At most one outer command owns the protocol, with phase/owner consistency.
- Acknowledgement has a permitted parent and preserves that parent's ownership.
- Each modeled source advances at most once.
- An obsolete requested source or a blocked boundary does not advance.
- An idle protocol has released its command and retained request.
- A fatal acknowledgement disables further acknowledgement and advancement.
- A visible fatal error follows command ownership release.

The successful `Advance` action abstracts existing source/boundary checks and
native execution as one operation. Those guards are assumptions about the mapped
production paths, not a proof that the code implements them. Executable checks
must cover the mapping. The model permits boundary availability to change at any
time, but does not model replacement of the live source during a command. Stale
requests here mean a request whose occurrence differs from the current source.

Acknowledgement has three outcomes: success, retryable refusal, or fatal refusal.
A fatal result latches permanently in this bounded run. It neither retries the
write nor advances the source. An owned command takes its existing return path;
an idle acknowledgement has already released ownership when its result returns.
`PublishError` represents the deferred error screen, not storage recovery.

`FatalEventuallyVisible` states that a latched fatal acknowledgement eventually
produces a visible error. This is conditional on **weak fairness of `Return` and
`PublishError`**: a continuously enabled synchronous return must execute, and a
continuously enabled deferred error publication must run. These assumptions model
stack unwinding and a serviced main loop with an available Bootstrap error host.
They do not promise progress if the process terminates, the main loop stops, or
the error host is unavailable. No fairness is imposed on acknowledgement outcomes,
command start, traversal, storage, or native completion. There is no general
story-completion or storage-recovery claim.

Native completion, filesystem behavior, rendering the error screen, exact save
contents, and arbitrary-sized stories remain outside the model. In particular,
this model does not explain or repair an inconsistent transaction marker. The
successful `PublishError` action assumes the mapped UI call works; focused runtime
checks must verify that seam. `BoundaryChange` remains available, so absence of a
deadlock alone is not evidence that a native callback will arrive.

## Reproduce

Use Java 17 or newer. Download the checker outside the repository:

```sh
curl --fail --location https://github.com/tlaplus/tlaplus/releases/download/v1.8.0/tla2tools.jar --output /tmp/tla2tools.jar
printf '%s  %s\n' e20447644bfabd29d6bd0fc2c0eb1473fb301c1a0e4dfe1961938ce5a191edbf /tmp/tla2tools.jar | sha256sum --check
java -XX:+UseParallelGC -cp /tmp/tla2tools.jar tlc2.TLC -workers 2 -coverage 1 -dump /tmp/dwm-progression-reachable -metadir /tmp/dwm-progression-states tools/verification/story_progression/StoryProgression.tla
python tools/verification/story_progression/check_witnesses.py /tmp/dwm-progression-reachable.dump
python -m unittest discover -s tools/verification/story_progression -p 'test_*.py'
```

The release asset used here reports `TLC2 Version 2026.11.03.180953`, revision
`309e489`; the SHA-256 above pins the actual bytes. Do not silently substitute a
changed asset under the same release URL. On 4 November 2026 that official URL
returned the new SHA above, replacing the earlier pin
`c57d4d7bbee3ed2c89c32cb9c60cac728f751e80e2570bc4b7368ae39291fc21`
(`2026.11.02.164701`, `dc6a944`). The earlier result below remains historical;
the extended model is checked with the explicitly updated pin.

`-coverage 1` reports action coverage. `-dump` writes reachable states and appends
`.dump` to the supplied filename. The witness checker requires all 18 event tags
(the original 14 plus three acknowledgement outcomes and error publication),
a state with both sources completed and command ownership released, and fatal
states both before command release and after visible error publication. It also
reports the number of model states after dropping `last_event`. Run it only after
TLC succeeds; the checker does not replace invariant checking.

`last_event` holds the latest instrumented behavior, rather than accumulating
history. No command guard or safety invariant depends on this field. Across the
complete state graph it witnesses each command's advancement, nested
acknowledgement, coalescing/conflict, stale refusal, ordinary refusal, and the Next
completion-signal phase. The 18 required tags are explicit in
`check_witnesses.py`; parser self-checks cover the pinned checker's small state-dump
format. Changes to that format or the two-source completion condition require an
intentional checker update.

Historical pre-extension check on 3 November 2026: all eight configured invariants passed; 8,366 states
generated, 1,612 distinct states, depth 16, zero states left on the queue. The
executable witness check found all 14 tags and completed/released ownership.

| Model instrumentation | Distinct states | States excluding witness instrumentation |
| --- | ---: | ---: |
| Accumulated event history | 537,760 | 288 |
| Latest event only | 1,612 | 288 |

The before/after dumps had exactly equal sets of all remaining field/value
combinations, with zero missing or extra projections. This was an exact-set
comparison, not an inference from equal counts. Those projections include the
protocol and its other verification bookkeeping; they are not an enumeration of
all game states. The optimization removes witness-history combinations without
changing the modeled protocol or eight invariants. This is model-checking
evidence, not a game performance measurement.

Extended check on 4 November 2026: all ten invariants and both temporal
properties passed with the updated checker pin; 7,916 states generated, 1,514
distinct states, depth 16, zero states left on the queue. All 18 event witnesses,
normal completed/released ownership, fatal owned return, and fatal visible error
after release were reachable. The dump contained 3,028 records (1,514 unique
states), with 328 distinct projections excluding `last_event`. Four Python parser
and witness checks passed. The eight original safety invariants and fourteen
original witness tags remain required.
