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
production owner. `owner`, `pc`, counters and `reached` are verification bookkeeping.
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

The successful `Advance` action abstracts existing source/boundary checks and
native execution as one operation. Those guards are assumptions about the mapped
production paths, not a proof that the code implements them. Executable checks
must cover the mapping. The model permits boundary availability to change at any
time, but does not model replacement of the live source during a command. Stale
requests here mean a request whose occurrence differs from the current source.

Acknowledgement can succeed or refuse. Ordinary command refusal is also enabled.
No fairness assumption is imposed, and there is **no eventual-completion claim**.
Native completion, storage settlement, fatal recovery, rendering, exact save
contents, and arbitrary-sized stories are not verified. `BoundaryChange` remains
available, so TLC's absence of a deadlock is not evidence that a native callback
will arrive. Focused runtime checks are required alongside this model.

## Reproduce

Use Java 17 or newer. Download the checker outside the repository:

```sh
curl --fail --location https://github.com/tlaplus/tlaplus/releases/download/v1.8.0/tla2tools.jar --output /tmp/tla2tools.jar
printf '%s  %s\n' c57d4d7bbee3ed2c89c32cb9c60cac728f751e80e2570bc4b7368ae39291fc21 /tmp/tla2tools.jar | sha256sum --check
java -XX:+UseParallelGC -cp /tmp/tla2tools.jar tlc2.TLC -workers 2 -coverage 1 -metadir /tmp/dwm-progression-states tools/verification/story_progression/StoryProgression.tla
```

The release asset used here reports `TLC2 Version 2026.11.02.164701`, revision
`dc6a944`; the SHA-256 above pins the actual bytes. Do not silently substitute a
changed asset under the same release URL.

`-coverage 1` reports action coverage. To inspect concrete reachable states, add
`-dump /tmp/dwm-progression-reachable`; TLC appends `.dump`. `reached` records useful
behaviors, including each command's advancement, nested acknowledgement,
coalescing/conflict, stale refusal, and the Next completion-signal phase. These
witnesses prevent interpreting an inert model as successful progress.

Checked on 3 November 2026: all eight configured invariants passed; 2,794,946
states generated, 537,760 distinct states, depth 37, zero states left on the queue.
The run with a state dump completed in 10 seconds in the cloud Linux environment.
Inspection of that dump found all 14 behavior tags listed above across reachable
states, including both direct and active Next advancement, and a state with both
source occurrences completed and ownership released. This is model evidence,
not a game performance measurement.
