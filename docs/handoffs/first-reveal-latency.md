# Next speed investigation: the first Minesweeper reveal

Find out where time goes between clicking the first covered cell in the scene computer and drawing the revealed board.

[PR #343](https://github.com/Siuuuers/dwm/pull/343) reduced a fresh-board lifecycle read from 50.6 to 3.5 µs. Its single baseline/candidate pair timed the complete click at 104 and 109 ms respectively. That pair leaves the player-visible effect unresolved. [PR #344](https://github.com/Siuuuers/dwm/pull/344) updated the first-reveal tests for the saved scene board.

## Reproduce and measure

1. Start on current `master` and record the SHA. Reuse `create_computer_board()` in `tests/integration/scene_computer_child.gd`. It opens the real computer, focuses cell 323, clicks it and checks the revealed set. Run rendered Linux Godot 4.6.3 with the same renderer, viewport, starting save and board layout for each comparison.
2. Start a temporary monotonic timer when the grid receives the reveal input. Stop at the first `RenderingServer.frame_post_draw` after the panel applies the active board containing the revealed cell. Keep setup, input-helper waits and screenshot capture outside the interval. Log the input-to-handler-return time separately so a frame wait is distinguishable from game work.
3. Take several fresh-process samples and list the individual times and median. If the delay repeats, time board generation/reduction, checkpoint work and updating the visible grid within that same click. Use the trace to choose one change. If frame pacing accounts for the spread or no repeatable cost emerges, record that finding and stop.
4. Compare any candidate against the baseline in alternating order under the same conditions. Report the full input-to-draw samples alongside the affected phase. Verify the clicked cell is revealed, the caption stays put and the same board restores in a fresh process. Run `tests/unit/test_scene_first_reveal.gd` for duplicate clicks and checkpoint retry.

Bring back the revision, reproduction command, timings and outcome. A smaller helper time alone does not establish a faster first reveal.
