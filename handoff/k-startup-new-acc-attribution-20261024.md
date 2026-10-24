# Native launch and New Acc attribution — 24 October 2026

## Result and scope

The reported launch/New Acc delay has a reproducible current-source baseline. Two native Windows cloud processes reached a usable Title and completed the actual New Acc flow, including replacement consent on the second process, with the exact first authored caption visible and the new-run journal settled. **This investigation does not claim a startup or New Acc performance fix.** The previously qualified Save/Load change is already merged in [PR #74](https://github.com/Siuuuers/dwm/pull/74).

The observable outcome is launch-to-usable-Title, followed by actual button input to a fully drawn first caption with an active session and no pending new-run operation. `ApplicationBootstrap` owns initialization; the Title invokes `SaveManager`'s existing prepare/confirm/commit flow. Evidence includes external process timestamps, child monotonic phase timings, actual Button signals, native screenshots, exact authored-caption assertions and clean exits. A helper that merely creates a desktop does not measure this outcome.

These are instrumented **source-project** launches under the pinned Godot 4.6.3 editor executable with the production main scene, default D3D12 Forward Plus and Microsoft Basic Render Driver. The game was not launched through a replacement `--script` entrypoint. The source runtime base is `88e44efbf6d65cc3b70118e73923eb408db98b7e`, whose game code is the same as the merged product after PR #74. Temporary timing hooks and the collection script are isolated on diagnostic branches. This is not `game.exe`, the player's GPU, or an identified installed Steam build. No Steam upload or branch publication occurred.

## Valid baseline

[Run 40091850701](https://github.com/Siuuuers/dwm/actions/runs/40091850701), source `3ed9cf1fd51cc1910d1d2a96fb4eb87784bb822c`, passed. The processes shared one initially empty user directory. “Fresh” means empty user data, not a cold operating-system or disk cache. The second launch retained the completed first account. There are only two observations, not a latency distribution or long-history profile test.

| Measured interval | Fresh profile | Retained profile |
|---|---:|---:|
| Process start → bootstrap start | 10.383 s | 8.321 s |
| Process start → usable Title drawn | 16.427 s | 15.897 s |
| Bootstrap total | 5.981 s | 7.514 s |
| Registered scene creation configuration | 5.367 s | 5.411 s |
| Startup new-run storage reconciliation | 0.0004 s | 0.776 s |
| New Acc input → complete first caption | 13.579 s | 14.050 s |
| Confirmation input → complete first caption | Not applicable | 13.949 s |
| Maximum observed frame gap during action | 8.928 s | 8.713 s |

Retained-profile input reached the consent sheet in 0.043 s. The diagnostic spent 0.058 s capturing it and preparing the pointer before confirming; this dwell is included in the whole input-to-caption interval and excluded from the confirmation-to-caption interval. The maximum frame gap excludes that deliberate dwell. The long frame gaps establish a responsiveness problem, independently of whether a shorter total duration is later achieved.

The first caption is `line.Day1.one`, with the exact authored English text, native text event DONE, full visible ratio, presentation acknowledgement, active session and `_new_run_busy == false`. Both processes exited 0. All five images were reviewed: two Titles, replacement consent, and two complete captions. Both Title images have identical hashes. The actual window became 992×558 through production window sizing on the cloud display; the logical canvas remained 1280×720. It was not silently assumed to remain the requested 1280×720 physical window.

Named New Acc intervals are inclusive and overlap. Fresh preparation of the scene decision took 4.550 s (including one 1.698 s participant-plan preparation). Intent commitment took 0.756 s. Scene resumption took 7.217 s, including 3.640 s settling the durable pair and another 1.720 s plan preparation. Retained equivalents were 5.147, 0.737 and 7.108 s. These values must not all be added together.

The fresh startup compiler counter records 92 calls taking 4.522 s inside bootstrap. During fresh New Acc, 3,146 compiler calls took 1.673 s; many use the existing completed-result cache, so this is **not** evidence of 3,146 timeline reparses. The corresponding configuration counter was 34 calls/2.661 s, with 17 bundle validations/2.201 s. These counters also overlap. They identify repeated synchronous work, not permission to remove validation, ownership boundaries or saved-data obligations.

## Failed first collection and input correction

[Run 40091188748](https://github.com/Siuuuers/dwm/actions/runs/40091188748), source `d20bd9a69b7cec4abc1302d531b7a9131a9f1b9b`, reached Title in 16.684 s but failed its 300-second caption deadline. It observed no New Acc owner phase, no action validation calls and only a 19.339 ms maximum frame gap. That was a collection failure, not a 300-second New Acc performance result; the retained-profile process never ran.

The revised diagnostic first focuses the native window and warps the pointer using viewport coordinates, waits for the actual Button hover state, then injects down/up packets with the window ID. It records pressed/down/up/GUI-event counts and fails quickly if the handler or owner preparation is not reached. In the valid run, every target began unhovered, became hovered, and emitted exactly one press with matching down/up events. No extra scale factor was applied to already-local viewport coordinates. This correction changes only the diagnostic, not player input handling.

## Compiler breakdown and next boundary

A separate fresh-Title-only run, [40092073156](https://github.com/Siuuuers/dwm/actions/runs/40092073156), passed at source `3fbc22320962ec0cba1ccc1fb05dcb1746e9b7a1`. It performed no New Acc action. Its 92 compiler requests were all result-cache misses across seven DTL paths. `timeline.process()` ran 92 times and took **3.026983 s of 3.259659 s enclosing compiler time (92.86%)**. The same files were processed repeatedly for their different registered entries: 25,048 native events were parsed/scanned, while 1,950 selected events were projected.

The other completed compiler intervals were physical reads 0.012474 s, argument encoding 0.023616 s, seven loader/type checks 0.002559 s, timeline construction/from-text 0.011186 s, entry projection/graph checks 0.023379 s and programme encoding/hash 0.039031 s. Remaining enclosing time includes availability/cache operations, result detachment and instrumentation. The Title was drawn at 15.049 s and bootstrap took 4.461376 s. This was a separate runner observation with added instrumentation, **not an optimization candidate or a before/after speedup**.

This identifies repeated whole-timeline processing as the next narrow startup target. A candidate should reduce that repetition during one registration operation while preserving the compiled programmes and all per-entry refusals. A shared process-wide physical-byte cache would extend current assumptions about mutable parser configuration; a registration-local scope avoids retaining that state across independent calls. No such candidate is implemented or qualified in this record.

The pre-bootstrap interval includes native renderer startup, autoload/preload work and diagnostic attachment; it has not been attributed entirely to resources. Title artwork mounting itself took about 0.002–0.004 s inside the measured menu callback, which does not account for earlier preloading. Avoid claiming that artwork or fonts explain the whole startup delay.

The next product change should target one measured owner and compare the complete operation on the same runner. Preserve current physical-source freshness, per-entry marker/callable-label checks, exact indices/hashes, detached results, translation behavior and ordinary current-build save consequences. If sharing parse work, prefer a bounded lifetime whose inputs are understood: the parser's mutable event registry and character-resolution settings mean unchanged source bytes alone do not prove unchanged parsing semantics. Do not retain mutable playback events in a process-wide cache simply to remove repeated work. Rendering a progress frame is a responsiveness change, not by itself a reduction in total loading time.

## Retention and related work

Exact retained logs, process receipts, images and complete original-member manifests are in [the evidence directory](../evidence/phase_2r/startup_new_acc_20261024). Source patches reconstruct the diagnostic against runtime base `88e44efbf6d65cc3b70118e73923eb408db98b7e`; they are evidence, not product patches to merge. The failed first collection is deliberately retained separately from the valid baseline.

The font report remains unresolved after 50 reviewed cloud captures; [PR #75](https://github.com/Siuuuers/dwm/pull/75) retained that investigation and [its handoff](j-font-scale-investigation-20261024.md) specifies the useful missing Steam/player evidence. No further blind font changes are justified by the current captures. For the measured Save/Load improvement and its full qualification, read [handoff i](i-bundle-encoding-handoff-20261024.md).
