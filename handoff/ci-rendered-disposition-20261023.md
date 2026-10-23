# Benchmark and rendered CI disposition — 23 October 2026

Read-only audit of candidate `c4df86694353a3c970c97423283b3ba2ef877f06`.
This document records source classification, not new engine acceptance. The
coordinator owns workflow changes and the combined cloud campaign.

## Current workflow selections

| Job or step in `windows-tests.yml` | Disposition and reason |
| --- | --- |
| `public-surfaces`, `focused-tests`, `windows-export` | Keep current. Preserve the six scene suites and existing owner/contract checks. |
| `checkpoint-performance`, `seven-day-history-producer`, `history-comparisons`, `seven-day-history` | Historical chain. The producers require old desktop/calendar gameplay; dependent comparisons consume those exact old payloads. Move the complete producer/consumer chain together, including provenance and aggregate checks. |
| `rendered-hospital-reading` | Historical. Hospital manual-refusal and saved-fixture journey uses retired health/calendar entry. |
| `rendered-timed-hold` | Historical. Its startup requires ComputerDesktop before old Schedule/Dating progression. |
| `rendered-ending-reading` | Historical. `verify_ending_reading_journey.gd` waits for ComputerDesktop, seeds lifecycle Day7 and a retained Schedule view, then enters a legacy two-step Sylvia ending. `verify_ending_auto_journey.gd` inherits that setup. |
| `rendered-journeys`: `Render witnessed-version register fixtures` and `Render admitted Gallery caption collection`, with their uploads | Keep current. These inject explicit test catalogues into retained Gallery/Bridge/Profile owners; they do not require old New Account gameplay. Rename the job to describe retained Gallery fixtures after splitting. |
| `rendered-journeys`: `Exercise complete rendered journeys in fresh isolated profiles`, `Exercise real Solo reading Save and fresh-process Load`, `Exercise authored Solo selectors through physical Save and fresh-process Load`, with their uploads | Historical. `run_cloud_journeys.py` covers old condition/Hospital, calendar ending, Dating and Practice. The two Solo helpers open Schedule, append `solo:priscilla:day1`, use Schedule Done and require old Dating mount. |
| `rendered-desktop`: `Verify rendered startup and Logout consent`, with its upload | Historical. It invokes `verify_playable_startup.gd` with old startup/day/logout expectations. Current Title create/load covers actual shipped authored startup; it is not an exact Logout equivalence claim. |
| Remaining `rendered-desktop` steps | Keep current component coverage initially. They exercise production shell/layout, delivery/caption rendering, HUD retirement, JA/KO catalogues, fonts and literal ownership. Do not discard this whole mixed job as historical. |

The desktop-scaling and JA/KO UI renderers explicitly mount `SHELL.IsolatedDesktop`
and bind fixture owners. They contain retained Schedule component samples using
`ScheduleActionRegistry.load_current()` and `training`/`working`/`rest` appends,
but do not enter through old New Account. This is component rendering, not
evidence that legacy Schedule is in the current player journey. Keep their other
samples and assertions; if a current run exposes a retired-registry dependency,
split only those Schedule samples with an explicit historical mapping rather
than dropping the entire mixed script. Font rendering inherits helper functions
but overrides `_run()` and mounts its own board/Settings surfaces; it does not
execute the parent's Schedule sample.

## Evidence inspected

[Canonical run39873079868](https://github.com/Siuuuers/dwm/actions/runs/39873079868)
is failed, and is not current-candidate acceptance.

- Desktop job `120154297845`: `Install Godot and software display` timed out
  after 12 minutes. All desktop/JA-KO/font renderers were skipped. The final
  UI literal audit then exited 127 without Godot. This run supplies no renderer
  failure evidence for those scripts; do not classify them from the job's red
  status alone.
- Gallery job `120154298163`: witnessed-version register passed 18 tuples.
  Caption collection reached 95 captures but failed `status exceeds dock height`.
  That is a retained UI geometry failure, not a retired-startup reason to remove
  the check. Later changes require their own current result.
- Hospital, ordered-ending and timed-hold jobs reached their journey steps and
  failed; source inspection establishes their obsolete entry/setup requirements.

The historical substrate is PR5 source
`e5db010715c187cc775341d204391f527dc334ea`, tree
`24773c04fc11d821839449df9f67995b47d98f55`. Its recorded
[run37535856887](https://github.com/Siuuuers/dwm/actions/runs/37535856887)
passed all 26 jobs. Reuse that recorded evidence for unchanged historical scope;
this audit did not redownload its artifacts or rerun its source. Preserve source
and tree assertions in any manual historical lane. Exact historical scripts and
original controls remain available there, rather than altering their mechanics
to fit current gameplay.

Source inspection commands (static only):

```sh
git show c4df86694353a3c970c97423283b3ba2ef877f06:.github/workflows/windows-tests.yml
git show e5db010715c187cc775341d204391f527dc334ea:.github/workflows/windows-tests.yml
git diff e5db010715c187cc775341d204391f527dc334ea c4df86694353a3c970c97423283b3ba2ef877f06 -- tests/manual/benchmark_minesweeper_click_latency.gd tests/manual/benchmark_seven_day_history.gd tests/integration/verify_timed_hold_journey.gd tests/integration/verify_hospital_reading_journey.gd
```

GitHub job APIs used for this audit are `/actions/runs/39873079868/jobs` and
`/actions/jobs/120154297845/logs`, `/actions/jobs/120154298163/logs` in this repo.

## Current counterparts and remaining scope

Existing `current_title` runs actual rendered Title → authored Day1 → Computer
→ manual Save and a separate fresh-process Load. It checks visible text, reading
checkpoint, gameplay, scene, receipts, Profile, slot bytes and hydrated artwork.
Existing `scene_apps` runs purchase/navigation, caption-input Challenge admission,
physical board preservation and Save/fresh Load in separate processes. Both are
already selected in the canonical matrix. Keep their strict passing-case and
no-skipped-coverage guards.

These current journeys replace obsolete startup selection, not every historical
mechanic or performance obligation. Reuse the qualified ending recovery evidence
from the main handoff for unchanged ending runtime. Uninterrupted authored-week
coverage and multi-minute late Save/Load pauses remain unqualified/unsolved.
Reconciliation alone claims neither performance improvement nor full-week pass.
Run one coherent current cloud integration/export campaign after compatible
audits and edits, then review any actual current fixture or product failures.
