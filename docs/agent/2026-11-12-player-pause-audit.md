# Player-pause audit after PR #284

Measured runtime revision: a621da729fe6cc5d8e47cf3db6e149f3a2850209.
Goal: locate pauses in New Game, Advance, Computer, History and Load before choosing
further surgery. No production code changed. Existing probes supplied the route,
input and correctness checks; the temporary subclass adds first Computer opens.

## Environment and limits

Linux Godot 4.6.3 source checkout; one engine at a time, separate user directories,
shared OS filesystem cache. No physical cache flushing. Xorg dummy display setup
failed because it could not establish local/unix listening sockets. Xvfb was absent
and package installation lacked permission. No rendered or Windows claim is made.

A process-loop gap is not a GPU frame duration or input-to-photon measurement.
These observations locate main-loop work that could cause visible pauses when
reproduced in a rendered build; they do not certify visual smoothness.

The full route manually starts services, loads expected content and precompiles
all route entries before measurement. It uses English and instant text reveal.
Its two helper frame waits and later assertions are included in elapsed times.
The first presentation timestamp precedes the native input-unblocked check.
The added first Computer sample precedes Settings; original Computer samples were
all warmed by Settings. Day7's first-in-visit sample is not process-cold.

## Two full-route sweeps

Each sweep passed 4,289 assertions and produced 870 observations. Together they
cover 1,604 ordinary caption advances and 54 entry changes, plus UI actions.
Sample ranges describe these observed runs, not population latency guarantees.

| Operation | Observed duration | Observed process-loop gap |
| --- | --- | --- |
| Prepared New Game flow | 348–449 ms | 267–334 ms |
| First Computer open, Day1 | 208–212 ms | 207–211 ms |
| First Computer open in Day7 visit | 163–181 ms | 161–179 ms |
| Repeated Computer opens | 15–30 ms | 14–29 ms |
| First Settings open, Day1 | 315–328 ms | 314–327 ms |
| Later Settings opens | 55–71 ms | approximately the same span |
| History, Day1 | 23–30 ms | 22–30 ms |
| History, Day7 | 88–120 ms | 88–119 ms |
| Entry change | 102 ms median | 80 ms median; 183 ms maximum |
| Ordinary caption | 13.836 ms median presentation; 111.286 ms median usable/verified | 8.766 ms median; 12.120 ms empirical 95th percentile; 46.674 ms maximum |
| Warm title Load in the full sweep | 104–105 ms | 97–98 ms |

The largest observed entry gap was Day2.result.A's first caption (182.890 ms),
followed by Day4's first caption (164.617 ms) and the final passage's first caption
(153.697–158.284 ms in the two runs). These are targets for attribution, not proof
that any particular validator or copy caused the gap.

The broad sweep also saw a save-write sample reach 321 ms, with a 281 ms loop gap.
First-save and overwrite/confirmation paths differ; do not treat that maximum as
normal saving cost or combine them into a purported regression.

## Ordinary caption delay is not one frozen frame

The source organically finishes text then blocks input for
`dialogic/text/advance_delay`, default 0.1 seconds; this project does not override
that setting. The presentation observer can finish while input is still blocked;
its inherited wait continues until native input is unblocked. This explains the
roughly 14 ms presentation / 111 ms final-wait split much better than a 100 ms
rendering stall. The timer's exact remainder was not separately instrumented.
Do not remove the accidental-skip guard as a performance fix without deciding the
intended input behavior. Auto/Skip and reveal timing are distinct behaviors.

## Real startup, immediate New Game

Two standalone runs omit DWM_TEST_ROOT and do not precompile expected route data.
They emit the actual menu button signal when title controls become ready, so they
measure control dispatch onward, not pointer hit-testing or physical input.

| Observation | Run 1 | Run 2 |
| --- | --- | --- |
| Title readiness from engine start | 3.389502 s | 3.266245 s |
| Runtime readiness | 5.510766 s | 5.371763 s |
| Complete first caption | 5.878136 s | 5.719846 s |
| Early click to complete caption | 2.488634 s | 2.453601 s |
| Largest loop gap while waiting | 239.929 ms | 218.254 ms |
| First subsequent Computer control dispatch | 134.874 ms | 123.245 ms |

Both verified the exact opening caption and unchanged caption after Computer open.
Early click waits for runtime preparation; it must not be compared directly with
the already-prepared full-route New Game figure.

## Focused fresh-process Load

The existing run_checkpoint_load.py creates an authored checkpoint, then restores
identical seed bytes at the same path for two fresh loader processes. Service and
expected-content setup happen before the timing. Each process measures first Load
and three repeated Loads; confirmation is required for the repeats.

| Observation | First process Load (2 samples) | Repeated Load (6 samples) |
| --- | --- | --- |
| Action to usable caption | 182.372–231.843 ms | 132.489–142.981 ms |
| Commit to usable caption | 182.372–231.843 ms | 123.935–134.374 ms |
| Commit to Ready signal | 147.365–188.714 ms | 96.346–108.315 ms |

Post-draw timing is null headlessly. This focused result has a cleaner endpoint
than the broad sweep's warm title Load and should not be averaged with it.
Creator: 3,748 assertions. Two loaders: 143 assertions each. Full pass total:
12,612 assertions across five selected tests, plus two successful startup probes.

## Next bounded investigations

The largest first-use spikes are Settings/Computer and New Game preparation.
Profile their resource loading, node creation and initial presentation separately;
do not simply shift work into another first-use action.

History supplies a concrete repeated-work lead. The caption owner calls
get_reading_history to obtain rows, then the overlay's admission callback calls it
again solely to compare session/frontier. Each projection rebuilds global indexes,
walks retained blocks, applies text/localization and copies rows. The overlay then
creates labels/separators and parses markup. Three stored checkpoint blocks can
contain many captions; the bound does not imply three display rows.

Next History outcome: open the same admitted history with one full projection,
while preserving the admission check, row order, localization and pause behavior.
First measure both projection spans, row/character counts, pause acquisition and
UI construction. Prefer a lightweight identity check at the existing owner; do
not remove the admission check or introduce another History manager speculatively.
This audit establishes callers and a hypothesis, not a measured doubling or a fix.

## Reproduce

Evidence: tools/player_latency/evidence/2026-11-12-player-pause-audit. Copy its root
journey.gd.txt/startup.gd.txt into .godot/ci/player-pause-audit with .gd extensions;
copy run.py and startup.py beside them. Run the scripts sequentially, then
`python tools/player_latency/run_checkpoint_load.py`. The latter requires absent
owned checkpoint-load output/user roots; preserve earlier evidence before reruns.
Use imported Godot 4.6.3 and retain this runtime revision. Logs, JUnit, samples and
source/seed hashes are preserved; synthetic user save directories are excluded.

No runtime edit, new lint rule, injection campaign, Windows export, artwork raster
check, bilingual matrix or physical display/audio qualification was performed.
