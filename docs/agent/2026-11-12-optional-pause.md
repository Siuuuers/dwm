# Optional pause resource loading: rejected trial

Base: `f8a5cc3e5ff54fbdd2c5ddfd05c94bbb3d05d3a8` (PR #297).
Outcome sought: shorten early title-to-usable-caption loading without worsening
first pause Save/Settings opening. ProductionPauseController owns host creation;
StartupLoader and MenuScene own existing resource prefetch. No runtime change retained.

## Scope and dependency audit

Independent read-only audit traced literal preload and scene resource edges.
SettingsApp pulls shared SettingsContent and its controls/reset/recovery UI into
SceneRouter's eager dependency graph. Caption does not independently preload that
complete graph. Title already prefetches Setting.tscn, sharing SettingsContent.
SettingsApp's small wrapper scene/script are not explicitly prefetched.
BackupApp code is already pulled by PauseQuickCommands; deferring its scene alone
has little unique scope. Leave Backup alone, with no new loader/cache/manager.

Trial: replace only the SETTINGS PackedScene preload with its resource path and
load it at the existing `_ensure_settings_host` instantiation. Existing host reuse,
services, callers, title prefetch, saves and exports stay unchanged. Relevant failure
cases: first opening stalls; Save starts creating Settings; opening/resuming changes
the caption; reopening fails. Existing manual lazy-settings test informed the probe.

## Matched experiment

Sequential fresh processes A/B/B/A, Godot 4.6.3, Linux headless. At first usable
caption, open pause Save, resume, open Settings, resume, reopen Settings, resume.
All times below are milliseconds. Save-first order is intentional and identical.

| Run | Engine start to title | Click to usable caption | Largest startup frame gap | Save | First Settings | Reopen Settings |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| base-a | 3596.302 | 2398.755 | 207.329 | 26.112 | 220.483 | 56.247 |
| candidate-a | 3023.689 | 2338.554 | 282.070 | 21.962 | 246.219 | 63.664 |
| candidate-b | 2899.347 | 2148.217 | 262.013 | 20.864 | 256.993 | 61.061 |
| base-b | 2964.815 | 2251.296 | 158.611 | 22.776 | 199.847 | 56.055 |

Reject the candidate. Click-to-caption ranges overlap; candidate first Settings
openings and largest startup frame gaps are both worse than either baseline run.
This small sample does not establish exact regression sizes, but supplies no reason
to accept the tradeoff. Restore both production lines. Do not add a lint rule banning
preload: eager loading remains useful when it prevents a later first-use pause.

## Verification and limits

All four runs exited 0 without ERROR lines. Runner checked exact authored caption;
probe waited for presentation acknowledgement, reveal completion and unblocked input.
It asserted Save/Settings open and resume success, no Settings host after Save,
Settings visibility on both openings, and unchanged caption after each resume.
`git diff --check` passed. Candidate patch is evidence only, not applied runtime code.

Fresh process does not mean cold OS cache. Direct production APIs and headless
visibility checks are not physical input, rendered layout or Windows performance
acceptance. No broad suite, export, injection tests or settled-case expansion after
this rejection. No claimed player-visible improvement.

Reproduce: copy the evidence startup.gd and run.py to `.godot/ci/optional-pause`;
run `python .godot/ci/optional-pause/run.py early <unique-label>`. Candidate patch
is applied only for B runs; restore it before A runs. Each label uses fresh user data.

Stop this preload-trimming branch of investigation. The next useful performance
work needs a reproducible player-visible pause, preferably a rendered Windows trace;
further headless micro-trials without one are unlikely to justify their overhead.
