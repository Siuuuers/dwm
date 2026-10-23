# Run152 native review-current acceptance

## Decision and exact scope

Accept the bounded native Windows review-current return on source
`845ec12c83cecfab1bfe3b5b4a194537c783aa7e`, tested PR merge
`bd4a3806769954663c46aed1064a076a0276865e`. This is not a new runtime fix.
Only the existing Godot native-caption fixture and PowerShell driver changed
relative to `b082a4517f0814d901e7218fb55042d6da2d26ec`.

The reviewed driver checks nine independent expected pre-invocation states,
process/window identity, visible target text, an unambiguous enabled InvokePattern
and a distinct review target. It rediscovers targets but never retries an
activation or substitutes a direct callback. The installed Dialogic fixture checks
event/reveal/history state after the native actions. No new input, persistence,
History or completion owner was added.

Downloaded raw invocations and all nine native tree records independently match
that sequence. Six native actions reveal/advance the first three captions. The
seventh invokes review-current, returning from offset1 to live. Its full before
and returned snapshots are equal: event3, visible characters0, reveal generation7,
Text.text_finished count3, timeline-ended count0 and both native histories. Live
visibility/focus return. Two fresh actions then reveal the fourth caption and
advance once to event4, leaving the guard caption revealing with finished count4.

The observed reveal position is zero characters, with elapsed-time reveal disabled.
It is not an arbitrary mid-sentence or real-time timing proof. Review entry was
fixture setup through the existing presentation owner; native entry/navigation
was not tested. Text-finished/timeline-ended counts are not gameplay consequence
counters. This is an English synthetic mounted fixture, not full screen-reader
speech/navigation or authored production-route acceptance.

## Cloud and visual review

Run152 attempt1 completed successfully, with all26 jobs successful. All13 downloaded
primary XML reports were parsed: 2,602 executions, 2,598 unique classname/name pairs,
zero failures/errors/skipped primary cases. The four deliberate duplicates remain.
The empty/whitespace storage-refusal controls each have83 cases:80 intended
storage-root refusals and3 storage-free passes. Their exit1 is expected and separate
from the primary tally. Conditional skipped CI setup steps are not test skips.

The four retained-history comparison jobs and aggregate succeeded. Broader rendered
journeys were checked through job/step results; their screenshots were not newly
visually accepted here. Four native captures were inspected: review-return,
returned-live, fresh-advance and fresh-successor. These show the short outlined
caption stack and its transitions without evident clipping. This is not all-locale,
arbitrary-artwork or whole-layout certification. The native log contains a graphics
fallback warning, so this is not a claim of a warning-free environment.

## Retention and task disposition

The receipt binds all13 downloaded artifact ZIP hashes and raw primary report
hashes. The separate conversation attachment `dwm-run152-acceptance.zip` retains
all native trees/invocations/runtime/logs/12 PNGs, the13 primary reports and both
negative-control reports/logs, with a file manifest and offline verifier. Raw bundle
paths are relative to that attachment, not claims that all bytes were mirrored to
this repository. Original GitHub artifacts expire on11 October2026. The small
normalized review-state record is retained in the repository; originals remain in
the bundle. Historical repository receipts are unchanged.

No Bead closes. Current broad clauses remain unfinished, and the connector did not
return the known large Beads export for a fresh recount. Last recorded accounting
is23 unfinished; no live Dolt query/sync or status/dependency mutation occurred.
Resume the current handoff's clause-level reading remainder, not this accepted
proof. No architecture-changing question was identified. This records-only
publication has structural/offline artifact review, not a new engine run. No
independent subagent review is claimed.
