# Scene checkpoint reference comparison

Date: 2026-10-27, Hong Kong time.
Status: PR 122 merged and accepted.

## Goal and scope

Continue the first new passage measurement from [am](am-trusted-capture-and-passage-20261027.md). The observable outcome is a faster real Enter transition from line.Day1.031 to line.Day1.photo.default.001, with the same pass choice, Run, encounter History and subsequent Save/Autosave.

Baseline master: `c531f3d487b6d213d4ef4a940832e09f0cf5f95a`.
Initial candidate: `24abf0e30ee8df927879e49d19e43ecedcf0ff32`.
[PR 122](https://github.com/Siuuuers/dwm/pull/122) merged as `12e5c21d381a1e5bd0e0026553daff7582e908cd`.
Its tree exactly matches the final tested tree `5b651ce6169a3a210cd2c2fadb02a4f9a436f105`.

## Runtime change

`SaveManagerNarrativeCheckpointPort._scene_route_candidate_valid()` already checks `_scene_candidate_reference()`. Two explicit checks repeated that work without intervening callbacks. The accepted change runs those explicit checks only for non-scene routes.

The scene-route validator, candidate fingerprints, authority/source callbacks, post-callback checks, write/readback and rollback behavior remain. Public checkpoint projection and restore validation are unchanged. No cache, manager or helper is added.

## Coverage correction

The earlier handoff named checkpoint acknowledgment and owner-composition tests, but neither file was selected by the existing cloud runner. Thus the previous 61-job passes did not execute those files.

This change enrolls them in separate process suites:

- `scene_checkpoint_ack`: all 24 current unit tests. A genuine authored Day1 checkpoint replaces an incomplete schema-5 fixture. Scene input and persisted-field expectations match the current contract. Final callback mutations cover both dating and scene routes, both authority and source callbacks, and narrative/payload/checkpoint-ID mutations. Every refusal must occur before writing and preserve a successful retry.
- `scene_owner_composition`: all 12 rendered integration tests. The fixture records the parent encounter before switching passages and explicitly supplies English to its detached Bridge. History expectations match current deduplication. Callback, acknowledgment, retry and rollback checks remain.

The runner requires exact method names, passing assertions and no skipped cases. Separate processes preserve immutable story-registration ownership.

One obsolete negative Save8 test was removed. Its premise was that current scene identity was not integrated into the save format; current Save9 supports scene saves. Its retained-schema setup was also removed. No skip path was added. Current malformed-input, route mismatch, uncertain-readback and failed-write tests remain.

Public surface inventories reflect removed references from that obsolete test and the changed test line locations. Production source line counts are unchanged.

## Measurement

The new checkpoint-reference comparison inherits the accepted 24-process journey. Both exports receive identical observation wrappers. It measures candidate-reference checks, equality, player-checkpoint projection, restore and named caller phases. The existing saved-state validator wrapper is used once.

The summary reports actual counts rather than asserting the predicted 63-to-47 validation reduction. Complete first-drawing latency and frame gaps determine whether the smaller path helps play. Counters cover input through readiness and the additional one-second observation window. Inclusive costs overlap and must not be summed. Snapshot checks, History inspection, screenshots and hashes occur after passage timing ends. Polling and instrumentation remain inside the measurement.

No Godot process runs locally. Python/YAML syntax, source overlays and inventory edits are checked locally; runtime acceptance belongs to cloud jobs.

## Initial run and fixture correction

The initial matched comparison passed all 24 journeys. It observed reference calls falling from 5 to 3 and saved-state validations from 63 to 47. Final acceptance figures belong to the later run on the corrected head; do not mix runs.

The initial regression exposed a detached test-Bridge locale lookup in seven owner-composition tests. The error was `get_node()` with an absolute path outside the active tree, reached through the History assertion. An explicit English locale override fixes the isolated fixture without attaching a second live Bridge or changing production code. All History assertions remain. The final head is `d795ef8f572f007dab5c8cc08c5a8acccb3df6be`.

## Final measured results

Final tested head: `d795ef8f572f007dab5c8cc08c5a8acccb3df6be`.
Tested tree: `5b651ce6169a3a210cd2c2fadb02a4f9a436f105`.
[Regression 40406598100](https://github.com/Siuuuers/dwm/actions/runs/40406598100): all 63 executed jobs passed; one older comparison skipped. The enrolled unit suite passed all 24 tests with 791 assertions; the rendered owner suite passed all 12 tests with 462 assertions.

[Matched cloud run 40406598015](https://github.com/Siuuuers/dwm/actions/runs/40406598015): all 24 exported journeys passed.

Evidence artifact `12691931474`, `checkpoint-reference-evidence-40406598015-1`.
ZIP SHA256: `8636820e998691d37474ba4d7bfe5745dc95d131817911c9481ba8e6b1cbfea4`.
Raw per-action samples, paired differences, other-action metrics and the 36 boundary-test method results are retained in [checkpoint-reference.json](../evidence/reading_performance_20261027/checkpoint-reference.json).

Milliseconds; medians of four matched samples per variant:

| Measurement | Baseline | Candidate |
| --- | ---: | ---: |
| Input to first correct destination drawing | 1713.126 | 1480.809 |
| Input to complete reveal and input readiness | 1726.759 | 1494.072 |
| Maximum frame gap during the transition | 1709.570 | 1476.522 |
| Candidate-reference work, inclusive | 562.122 | 338.000 |
| Saved-reading validation, inclusive | 815.627 | 611.892 |
| Ordinary Load to complete caption | 492.175 | 486.141 |

Every matched first-drawing, readiness and maximum-gap pair improves. First-drawing savings are 148.360, 442.665, 316.274 and 147.884 ms. Median first-drawing latency falls about 13.6%. The reference checks fall from 5 to 3, equality calls from 10 to 6, player projections from 21 to 13, restores from 62 to 46, and saved-reading validations from 63 to 47 in every sample.

All eight destination screenshots were reviewed. Correct caption, art, History layout and controls remain. The full journey verifies pass choice, same Run, no unselected route encounters, source bytes and subsequent Save/Autosave. Measured process checks pass without script errors or ObjectDB leak reports.

These are descriptive software-rendered Windows runner results. They do not establish a device-wide or frame-rate guarantee. The approximately 1.5-second transition hitch remains. Do not compare absolute timings across separate runner sessions or sum nested spans. Fresh New Account medians are 842.373 versus 864.002 ms, and retained-profile New Account 800.195 versus 806.029 ms; this candidate is not a startup optimization.

## Next focused lead

The three retained candidate-reference checks each compare the persisted checkpoint with both the private retained target and the supplied checkpoint. Both comparisons project the same persisted left side. Final counts show six equality calls and twelve of thirteen player-checkpoint projections in this path.

Measure that repeated left-side projection and audit a single local reuse within one `_scene_candidate_reference()` invocation. Do not cache across callbacks, commits or registration changes. Preserve both target comparisons, private-target fingerprints and public projection/restore behavior. This is a hypothesis for the next experiment, not an implemented or measured saving.

The final remaining validation total is 611.892 ms and restore total is 597.980 ms. Those nested totals do not authorize removing restore validation globally. Keep the now-enrolled callback, no-write retry, rollback and uncertain-acknowledgment tests, plus the complete native passage journey.

No architecture decision currently blocks this next measurement. The user's cloud-only execution, trusted shipped content and minimal-change policy remain. Manually edited DTL error-and-skip remains out of scope.
