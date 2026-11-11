# Startup attribution and one localization lookup per language

Date: 11 November 2026 (Hong Kong).
Base: `66788afe20e55c759234d5ba67db0fdc0b063315` (PR #262).

## Outcome and scope

Reach the usable title sooner without changing profile preferences, translated
content, validation, recovery or rendering. The startup owner is
ApplicationBootstrap; language-catalog validation belongs to LocalizationSchema.
The retained runtime change hoists `_message_map(catalogs[id])` outside its
per-message loop, after the existing locale-file validation. All placeholder
checks, failure ordering and detached returned data remain unchanged.

Each of five shipped catalogs has 328 messages. The old valid-bundle path builds
1,646 maps (one source map plus 329 per language); the candidate builds six. No
persistent cache, new helper, dependency, lazy initialization or removed boundary
check is needed. Callers remain LocalizationCatalog.load_bundle and the existing
catalog validator command. No saved-data or public signature changes occur.

Relevant failures: incomplete locale coverage, changed placeholder comparison,
altered return values or readiness. Existing positive real-content checks cover
the complete bundle and runtime manager initialization; no injection campaign.

## Investigation before surgery

- Clean source baseline reached enabled New Acc at engine tick 5,854.386 ms;
  launch through exit was 6,045.676 ms, including teardown.
- Separate engine diagnostic: Load Autoloads 4,392.552 ms; Load Game 7.533 ms.
  Main::Start 4,722.410 ms includes nested work; do not add these durations.
  This diagnostic exited 0 and reached readiness but emitted 18 known engine
  StringName teardown errors. It is not a clean acceptance run.
- Verbose log gaps suggest ProfileManager/GameState loading deserves further
  investigation. Their `_ready()` bodies are empty; reachable script bodies and
  preloads are large. Log gaps/static source sizes do not prove compiler time.
- Separate application-stage diagnostic: initialization began at engine tick
  5,765.205 ms. Save setup was 423.929 ms; localization was 311.127 ms. The save
  stage includes scene registration and recovery, not just disk writes.
- After the candidate, a separate stage diagnostic measured localization at
  86.350 ms. These differently timed diagnostic runs are not matched total-startup
  acceptance samples.

The readable-CJK-font ablation was rejected. Eight alternating fresh starts gave
baseline 5,896.993–6,916.211 ms and candidate 5,729.089–6,107.701 ms; host variation
is large relative to the proposed gain. No font or theme changes are retained.
Changing preloads to loads can also move a pause rather than remove it.

## Matched complete operation and isolated validation

Serial B/C/C/B on one Linux host, Godot 4.6.3, imported project, fresh user data
at the identical absolute path each time. No OS-cache flush or runtime wrappers
in complete-startup runs. Startup uses the unchanged ready-control probe, not
physical screen latency. After each startup, a separate process validates the
actual five catalogs three times. JSON reading precedes that isolated timer;
returned bundle equality is asserted afterward. Repeated samples in one process
are correlated and are not extra independent startup samples.

| Measurement | Baseline | Candidate |
| --- | --- | --- |
| Full startup engine ticks, ms | 6914.924 / 5855.250 | 5857.828 / 5817.186 |
| Full startup median, ms | 6385.087 | 5837.507 |
| Isolated validation range, ms | 235.238–380.425 | 14.998–16.665 |
| Isolated validation median, ms | 273.516 | 16.385 |

The isolated validator is about 94% faster in these samples, with identical
successful output. The complete-startup median is lower by 547.580 ms, but the
baseline spread is 1,059.674 ms and one baseline nearly equals the candidates.
Do not advertise a reliable overall launch percentage from this small noisy set.
The change removes measured redundant work; multi-second startup remains.

## Focused checks

- All four complete-startup runs: exit 0, ready marker present, no error/warning.
- Twelve isolated validations: all five catalogs accepted and returned bundle
  exactly equal to input; no error/warning.
- Existing real-catalog semantic test: 7 assertions, pass.
- Existing manager initialization/detached-record test: 13 assertions, pass.
- Independent caller/semantic review; comment/live-transition lint and whitespace
  checks pass. No translated strings, font selection or layout changed, so no
  translation/rendering matrix was added.

[Raw evidence and reproduction files](../../tools/player_latency/evidence/2026-11-11-startup-localization/)
retain the rejected experiment as well as accepted measurements. The catalog
comparison runner was subsequently made reproducible from either checkout by
reading baseline source at the explicit base SHA; measurement used those same
baseline bytes. The temporary diagnostic wrappers were restored before checks.

## Exported Windows attribution

Baseline diagnostic source: `a96e7df5303938bcd1866c1264051aba833678b2`;
its only difference from the base is the temporary workflow.
[Baseline run 42955987877](https://github.com/Siuuuers/dwm/actions/runs/42955987877)
passed release export, isolated startup and the three ordinary release UI journeys
with clean exits. External enabled-title observations were 8.892 / 8.413 / 6.296 s
(capability/creator/fresh-process loader with existing profile). These differ in
profile/cache conditions and include UIA observation overhead.

The separate editor-hosted release-pack diagnostic wrote its startup stage JSON
but did not exit within its three-minute deadline. The job is therefore failed;
its partial stage data is not clean acceptance or title-readiness evidence.
Before the timeout it recorded:

| Editor-hosted Windows pack stage | Time |
| --- | ---: |
| Rendering server setup | 1,987.604 ms |
| Setup window and boot | 403.055 ms |
| Main::Setup2, inclusive | 2,583.233 ms |
| Load Autoloads | 3,469.760 ms |
| Load Game | 161.228 ms |
| Main::Start, inclusive | 3,987.378 ms |

The renderer is D3D12 Forward+ on Microsoft Basic Render Driver (software).
These nested stages must not be added together or subtracted from release UIA
observations. The stage profiler is available in the standard editor host, not the
release template; the same hashed release PCK was used without script injection.
The timeout cause is not established. No renderer default or engine workaround
is changed on the strength of this partial diagnostic.

## Candidate Windows acceptance and final decision

[Candidate run 42956475457](https://github.com/Siuuuers/dwm/actions/runs/42956475457)
completed successfully on `56a4c96f8210100b0bf95b6cad010a455e328221`.
Release export, 137-file pack audit, isolated startup, enabled title, ordinary
opening/Save and fresh-process Load passed. All three release processes exited
cleanly with code 0 and clean player logs. Restored checkpoint matched; global
profile was preserved. Title and restored-opening screenshots were inspected at
1024 by 576: labels, artwork, complete caption and controls are visible.

Candidate external title observations were 8.546 / 8.504 / 6.571 s. These are
unmatched cloud UIA upper bounds, not evidence of a Windows startup speedup. The
candidate diagnostic ran before the release journeys, unlike baseline, and could
warm host caches; do not compare these numbers as an experiment.

The candidate editor-hosted diagnostic exited 0 but emitted the known StringName
benchmark teardown errors. It measured rendering setup 2,094.180 ms, autoloads
3,554.181 ms, and game loading 161.381 ms. Keep this separate from clean release
acceptance. Together the diagnostics point toward engine rendering setup and
script/dependency loading as the remaining investigation areas, without proving
which native-hardware change would help. Neither diagnostic times the full
application initialization within the first rendered frames.

Retain the localized loop-invariant change for its demonstrated reduction in
redundant validation work. The final workflow is restored byte-for-byte to base;
there is no permanent diagnostic job or flag. Final publication adds only this
report/evidence beyond the tested runtime file. Broad matrices, font changes,
renderer changes, native GPU timing, cold-disk and audible playback checks were
not performed. No new session is necessary to continue the next bounded study.
