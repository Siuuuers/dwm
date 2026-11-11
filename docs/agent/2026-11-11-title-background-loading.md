# Title-first startup

Base: `2d444d08988b6d6bf9e5f29ba97740718a5e4c83`.

## Observable outcome

Show the usable title with the saved language, font and text size before loading
unneeded gameplay resources. Finish those resources while the title remains
visible. An early destination click displays the localized animated Loading
status and runs once when its dependencies are ready.

StartupLoader owns one resource queue and installs the existing real root owners.
ApplicationBootstrap still owns recovery, initialization and final readiness.
MenuScene retains only the pending destination. No replacement profile parser,
proxy gameplay owner or second mutation gate is introduced.

## Required before title

Recover save/new-run storage, bind the authoritative profile, initialize its
language/typography, input, accessibility, audio and window mode. Preserve the
same identity issuer and mutation gate across both phases. Recovery validation
may still load gameplay script dependencies when historical storage needs them.

After the first title draw, load GameState, EffectResolver, SceneRouter, Dialogic
and runtime resources; install owners and advance bootstrap stages across frames.
Queue Settings, Load, Gallery and SceneHost resources for reuse. An early click
moves its queued dependencies ahead of work that has not started. Settings needs
only its resources and the title core; gameplay destinations also await final
runtime readiness. An active threaded load is not interrupted.

## Relevant failure and departure cases

- Save recovery fails: retain the existing recovery UI and retry contract.
- The player clicks twice: retain one action, using the existing transition gate.
- Settings has pending work: complete its existing departure protocol first.
- The title leaves: discard its pending action; the global loader owns requests.
- Quit during loading: finish only the in-flight request before engine teardown.
- Editor import: Dialogic must not re-register a second eager runtime owner.

## Validation

Acceptance results and exact tested revision will be recorded after the candidate
passes focused startup, title lifecycle and exported Windows checks. Linux timing
uses matched profile bytes at the same absolute user path, serial baseline /
candidate / candidate / baseline. Title readiness and full runtime readiness are
separate endpoints. Headless frame gaps are not rendered frame timings.

Skipped: renderer changes, unrelated gameplay refactors, broad language/layout
matrices, external-input injection campaigns, audio-output and physical-GPU
qualification. Existing boundary validation, recovery and accessibility remain.
