# Startup investigation handoff — 25 October 2026

## Task

Reduce the time from process start to a visible, usable Title screen.
Measure the delay before changing the code.
Keep the feature inventory for a later discussion.
Use short, controlled English for updates and handoffs. This document follows
ASD-STE100 principles. It does not claim formal compliance certification.

The user reports a long launch and many resource messages. The exact elapsed
time, installed BuildID, renderer and data state of that report are not known.
Do not infer them from the most recent upload.

## Current version

- Master at this handoff's source review: `1a909f369df972f3083e5246dcfb294566004c4d`.
- Game source in the new Steam package: `cf60203f077ad0bb39a0d2b06068988153fb53c3`.
- Steam BuildID: **26196642**. Executable: `game.exe`. AppID: 5199120.
- [Upload run](https://github.com/Siuuuers/dwm/actions/runs/40191013566) passed export,
  package checks, isolated executable startup, preview and upload.
- No Steam branch was set live. Check the installed build before comparing it.
- [Functional CI](https://github.com/Siuuuers/dwm/actions/runs/40187985765) passed
  50 jobs. The archived timing comparison was intentionally skipped.
- These passes establish tested behavior. They do not establish fast startup.

## What the evidence establishes

The following timings are historical Windows cloud source-project measurements.
They used Godot 4.6.3 with D3D12 Forward Plus and Microsoft Basic Render Driver.
They are not measurements of Steam BuildID 26196642 or the player's GPU.

| Measurement | Result | Meaning |
|---|---|---|
| Earlier process start to bootstrap start | 10.383 s fresh; 8.321 s retained | Large interval before application stage timing. Includes engine/renderer work, autoload/preload work and diagnostic attachment. Its internal costs were not separated. |
| Earlier full launch to usable Title | 16.427 s fresh; 15.897 s retained | Baseline before registration parse reuse. |
| Earlier registration compiler detail | timeline.process: 3.027 s of 3.260 s | Repeated processing was 92.86% of compiler time, not 92.86% of total launch time. |
| Qualified parse-reuse launch comparison | Fresh 16.436 to 11.911 s; reversed order 16.838 to 12.802 s | This optimization already exists. Do not implement it again. |
| Qualified parse-reuse bootstrap interval, first comparison | Fresh 5.962 to 1.917 s; retained 7.422 to 3.325 s | Registration work decreased. A substantial delay remained outside this stage interval. |

Read [the baseline attribution](k-startup-new-acc-attribution-20261024.md), then
[the qualified parse-reuse result](m-registration-parse-qualified-20261024.md).
Read [the later New Acc result](n-newacc-qualified-save-attribution-20261024.md)
only when separating New Acc from launch. Do not use Load timings as launch timings.
Do not add overlapping measurements.

The current compiler shares parsed source within one registration validation.
See `DialogicEntryManifest.gd` and `DialogicRuntimeAdapter.gd`.
Historical loader messages were not a physical disk-read counter. Repeated calls
can use cached resources. Log volume alone does not identify the slowest owner.

## Static resource findings

The review sorted file sizes under art, assets, audio, data, fonts, dialogic,
autoload and scenes. It excluded .import and .uid files. These are source bytes,
not PCK member sizes, decoded memory or measured startup costs.

| Resource | Source bytes | MiB |
|---|---:|---:|
| assets/ui/contacts/fonts/source-han-sans-sc-regular.otf | 16,529,832 | 15.76 |
| assets/ui/contacts/fonts/source-han-sans-hc-regular.otf | 16,519,524 | 15.75 |
| assets/ui/contacts/fonts/source-han-sans-kr-regular.otf | 4,632,304 | 4.42 |
| assets/ui/contacts/fonts/source-han-sans-jp-regular.otf | 4,562,224 | 4.35 |
| audio/bgm/menu_theme.ogg | 2,335,340 | 2.23 |

The installed scene registration JSON is 536,893 source bytes (0.51 MiB).
It can be costly to validate even though it is smaller than a font.

`scripts/ui/UiTypography.gd` preloads the English, Simplified Chinese and
Traditional Chinese faces. Its locale/style font method also loads selected
faces on demand. Story text adds fallback faces. Do not remove glyph coverage
to obtain a faster result. Check the English and Simplified constants' callers
before deciding whether they are needed.

`ApplicationBootstrap.gd` has 89 preload expressions. This is a static count,
not a count of independent disk reads. `project.godot` declares 14 autoloads.
The bootstrap also configures restore, day-resolution and board services before
publishing readiness. Some retained services concern the older calendar flow.
Check their current callers before deferring or removing them.

## Ranked hypotheses

1. Eager script and resource dependencies do too much work before Title.
   Inspect the autoload graph, typography dependencies and gameplay services.
2. Renderer and native engine initialization account for a material part of the
   pre-bootstrap interval. The software-rendered cloud result cannot identify
   the cost on the player's GPU.
3. Remaining registration, validation and retained-data initialization add
   synchronous application work. Measure the current version before editing.

These are hypotheses. No current resource has a measured claim to be the slowest.
The two large font files are investigation candidates, not proven causes.
Title art mounting was only about 2–4 ms in the old menu callback. That timing
does not include any earlier resource preload.

## Next session procedure

1. Read AGENTS.md and CLAUDE.md. Verify current master and the installed BuildID.
2. Use the exact current exported package. Record its hashes, renderer, display,
   locale, font mode and profile state. Keep the feature backlog out of scope.
3. Measure process start to bootstrap entry, each bootstrap stage, first drawn
   Title and first accepted Title input. Record maximum frame gaps.
4. Separate clean user data from retained current-format data. Do not delete or
   convert the player's data. Fresh user data does not mean a cold OS cache.
5. Attribute pre-bootstrap time. Compare a minimal engine window with the real
   application on the same runner. Use narrow diagnostic variants to isolate
   font dependencies and gameplay preloads. Do not sum nested resource times.
6. Measure New Acc to the first complete caption separately. A startup change
   must not merely move the whole pause to the next click without reporting it.
7. Choose one measured owner. Compare baseline and candidate on the same runner
   in both orders. Repeat enough to report variation, not only the best time.
8. Verify the affected behavior: usable Title, language/font coverage, New Run,
   Save/Load and exact first caption. Run Godot only in the cloud.

Load only what Title needs before its first usable frame where the measured
dependencies allow it. This is a candidate design, not permission to remove
save correctness, required initialization or user-visible failure handling.
A progress screen can improve feedback. It does not itself reduce total time.

## Stop conditions and open evidence

Ask for the installed BuildID and approximate delay if the player's result must
be reproduced. Ask whether the pause is before the window, in a blank window,
or after New Acc. Continue independent cloud measurement while waiting.

Keep old-data startup failure separate from slow startup. The current build has
no migration policy for older development saves or operation journals.
Do not silently reset Profile data to make a timing test pass.

This session reviewed code, resource sizes and existing evidence only. It did
not run a new timing experiment, change game code or claim a new speedup.
