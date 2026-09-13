# Desktop click and serialization work

2026-09-13; base `0af1448d7`; Godot 4.6.3 mono; `dwm-634.3`.

This increment removes the redundant full Panel pull after an accepted,
nonterminal routine board command. Presentation still checks the exact owner
identity, revision, phase and projection before allocating a command, then reads
the authoritative result afterward. The Panel composes its result using public
metrics derived from that same post-command snapshot. After reading assignment
and round facts, it consumes a one-shot handoff that requires a final exact
owner snapshot comparison. A same-revision restore forces the strict refresh.
First Reveal, terminal
settlement, refusals, and explicit pull retain their existing paths.

The Foresight/no-flag rules are shared with the normal register query. Returned
values remain detached. The retained command context is bound to the exact
adopted projection; it is not save state or command authority. The full snapshot
stays private to PresentationPort and is discarded when the handoff is consumed.

A separate small change uses native sorting for canonical JSON dictionaries
whose normalized keys are all printable ASCII. Any other key retains the old
UTF-8 comparator, including control, Unicode and malformed internal strings.
The exact-version Godot [Array implementation](https://github.com/godotengine/godot/blob/4.6.3-stable/core/variant/array.cpp#L675)
and [String comparison](https://github.com/godotengine/godot/blob/4.6.3-stable/core/string/ustring.cpp#L405)
establish case-sensitive lexical ordering for this restricted range.

## Measurements and checks

The fixed save in `../checkpoint_json_fast_path/baseline-autosave.json` is
456,379 bytes, SHA-256
`f2435ab5c2fbc0ef94a27540040878dac030b382614306ea6070c8b1215df542`.
Five iterations per version produced identical canonical bytes; median emission
was 69.625 ms before and 66.241 ms after the ASCII sort change. This is a small
serialization improvement, not a claim that terminal latency is solved.

Headless full-flow observations, with `DWM_CHECKPOINT_PROFILE=1` and the same
`--profiling` flag on both versions:

| Boundary | Before | After |
| --- | ---: | ---: |
| App routine reveal median | 30.154 ms | 22.639–22.743 ms |
| App later-history reveal median | 35.150 ms | 27.741–28.260 ms |
| App win to settled | 1.478 s | 1.262–1.286 s |
| App loss to settled | 1.205 s | 1.120–1.137 s |

One fresh baseline process and two fresh final processes were measured. Each
includes App win/loss; final Dating runs cover one win and one loss. Early
routine medians use 15 inputs each; later-history counts are 210 before and
196/201 after. Seeds, histories and save sizes vary. This is a small sample,
not an OS input-to-paint guarantee or proof that every terminal difference was
caused by this patch. The fixed-file serializer result and the owner-read counts
provide the controlled checks. App settlement remains visibly slow.

Canonical compatibility, strict parsing, checkpoint validation/retries and the
continuation operation journal passed 100 tests / 4,524 assertions. The
1,177-value compatibility signature remains unchanged. Added cases pin ASCII
case/number/prefix order, control and Unicode key order, and first structural
refusal. An initial test used an unsupported eight-digit GDScript escape;
replacing it with `String.chr` fixed the test fixture. The failed run is retained.

The three focused register/Panel/Presentation suites pass 61 tests / 1,158
assertions. They retain stale-owner, first-reveal, terminal and retry coverage,
and add exact fast-result versus strict-pull equality, detached return values,
one-shot consumption, and a valid same-revision restored history during a
configuration getter. The counting owner proves six explicit owner state reads
become four, configuration reads become two from three, and two full board
projections are removed. Internal coordinator state captures remain.

The surrounding coordinator unit/integration and desktop-host suites pass
88 tests / 1,081 assertions. Together with the canonical and three focused
board suites, these are 249 distinct tests / 6,763 assertions; overlapping
development reruns are not added to that total.

Repository inventory/document gates add 14 tests / 410 assertions, for
**263 distinct tests / 7,173 assertions**. Regenerated inventory records retain
all 239 GameState and 74 SaveManager contracts; only call-site locations changed.

Two native Windows/OpenGL processes exited 0:

- Full Expert App win/loss and Dating loss benchmark; App settlement observed at
  1.268/1.120 seconds. This run confirms the native renderer path, not hardware
  mouse timing or an accessibility audit.
- Actual New Account, pre-expiry Slot 1 Save, Schedule Done, Day 2 Autosave Load,
  and older Slot 1 Load; the earlier Day 1 message was restored correctly.

`runs.jsonl` records all 17 attempted runs, including the three development
failures explained above. The corresponding logs are retained beside it.
Existing Dialogic test-process orphan reports and malformed-string fixture
diagnostics are not new findings from this patch. No production save folder was
used; all runs used the isolated wrapper.

An initial overlapping test run caught a missing explicit `bool` type before
the source patch was ready; it is not a valid pre-change regression run. Another
fixture initially rewrote a run ID without updating its receipt, correctly
causing strict fallback refusal. The final fixture uses a valid earlier board
history with the same current public revision and verifies the restored view.

The initial `--profiling` click run produced ordinary benchmark/checkpoint
timings, but no usable function-level profiler report. It is a baseline run,
not evidence attributing the settlement pause to any individual method.

## Remaining work

App terminal settlement still needs measurement and simplification. Read-only
audits identified repeated detached payload copies in consequence preparation,
and repeated canonical traversal of a large `board_fate` publication in
`DesktopPublicationLedger`. The issuer root already composes cached canonical
fragments; a deferred receipt still must become durable before its source save.
These candidates are not implemented or claimed fixed by this increment.

Cold publication replay must continue distinguishing integer `1` from float
`1.0`; raw Dictionary equality is insufficient. Keep the independent publication
digest, exact physical reread, and all recovery/failure boundaries when measuring
the next change. Beads remains the task authority.
