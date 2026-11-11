# Remove the unused native History layer

Base: `b1622ad44e12d358b6165bc13c3aa1e3fcadc643` (PR #291).

Outcome: mounting the active caption style omits the unused Dialogic example
History panel; the existing player-facing History still opens, scrolls and closes
without changing reading state. WitnessedCaptionLayer owns that overlay.

## Before editing

Fetched master and reviewed the current Scene contract, style construction,
native History widget/subsystem, custom History owner, callers and relevant tests.
Independent read-only audit agreed: no production or test caller opens the native
widget. Its hidden button did not stop theme construction, signal subscriptions
or its per-frame callback. No save fields depend on the widget. Choices still has
callers; other layers were not removed without equivalent evidence.

## Change

Remove only layer 17 and its resource references from witnessed_caption_style.tres.
Keep stable remaining IDs, the editor latest-layer counter, native History data,
addon example assets, input delay and all custom History code. The retired-feature
record explains ownership and persistence scope. No new runtime code or lint rule.

## Matched whole-operation measurement

Linux Godot 4.6.3 headless; sequential fresh processes, same authored checkpoint
seed restored to the same absolute user path, no profiling flags. Order A/B/B/A.

| Run | First Load action to usable | Repeat Load commit to usable |
| --- | ---: | --- |
| Baseline A | 261.337 ms | 124.690 / 122.352 / 121.740 ms |
| Candidate A | 199.660 ms | 119.092 / 121.789 / 119.106 ms |
| Candidate B | 184.057 ms | 124.067 / 119.872 / 120.721 ms |
| Baseline B | 218.032 ms | 120.262 / 117.064 / 118.480 ms |

First-load sample medians: 239.685 → 191.859 ms (~20% lower). Only two samples per
version; baseline spread is large and prior-session results overlap this candidate.
This supports a possible first-use benefit, not a stable 20% promise. Repeat-load
results overlap. The definite improvement is omitting an unused instantiated layer,
its theme and ongoing callback. No rendered/Windows smoothness claim.

## Final focused checks

- Two candidate Load processes: 143 assertions each; exact restored caption and
  input readiness, saved reading state and global discoveries preserved.
- Deferred first caption mount: 27 assertions; preferences, text and native state.
- Custom History journey: 159 assertions; five opens, scroll/accessibility paging,
  closes, input readmission and unchanged History contents.
- Total candidate: 472 assertions. All XML cases passed; all commands exited 0;
  no ERROR lines. Two baseline Load processes also passed 143 assertions each.
- `git diff --check` passed. Independent caller audit completed before final checks.

Evidence contains logs, XML and scratch runners. Copy runners to `.godot/ci/style-trim`;
`load.py <fresh-label>` expects the seed from
`tools/player_latency/run_checkpoint_load.py` under `.godot/ci/checkpoint-load/results`.
`caption.py <fresh-label>` uses a fresh user directory. `history.py <fresh-label>`
uses the existing authored Day7 seed from the prior player-pause audit and expects
`history-probe.gd` copied to `.godot/ci/history-admission/probe.gd`.

Skipped broad matrix, exported build, rendered screenshots, injection tests and
new lint rules. Fresh processes do not imply cold OS caches. No input-design
change, extra cache, helper or manager was introduced.
