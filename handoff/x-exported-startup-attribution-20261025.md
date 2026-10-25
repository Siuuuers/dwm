# Exported startup attribution — 25 October 2026

## Result

The measurement phase is complete. No performance change is qualified for merge.
No product code, save format, Steam package or live Steam branch was changed.

The largest named game autoload preparation interval is ApplicationBootstrap:
0.962–1.001 s in two fresh-profile launches. GameState is next at 0.639–0.680 s.
The constructors themselves are cheap. Loading dependencies and initializing
members before the constructor account for most of these intervals.

Before the first diagnostic constructor, another 2.204–2.755 s elapses. This
interval still needs engine-level attribution. Do not call it renderer time.

The user asked which part before bootstrap costs most and what each owner does.
The table below answers that question at the measured boundary. It does not
identify a single slow leaf resource or an exclusive CPU function.

## Source and scope

- Product baseline: `47234a3395a4566e840140f1849da55a65d15521` (master after PR100).
- Runtime directories match the previously exported source `cf60203f077ad0bb39a0d2b06068988153fb53c3`.
- Engine: checksum-pinned Godot 4.6.3 standard, Windows x64 release templates.
- Renderer: D3D12 Forward Plus, Microsoft Basic Render Driver.
- Default profile: English, pixel font, 100% text size, normal reveal, Auto off.
- All Godot execution occurred on Windows cloud runners. No local engine run.
- Fresh means empty isolated user data, not a cold OS or disk cache.
- These are instrumented exports, not the installed Steam build or the user's GPU.

Read [the earlier handoff](w-startup-investigation-20261025.md) for the already
merged registration parse reuse. Do not implement it again.

## Three experiments

| Run | Controller | Result |
|---|---|---|
| [40198504876](https://github.com/Siuuuers/dwm/actions/runs/40198504876) | `592838492136437633e41377504a060b114dde13` | 17 rendered processes passed: independent baseline/menu/font/minimal packages, both launch orders, fresh/retained New Acc, separate first-open screen journeys |
| [40199783167](https://github.com/Siuuuers/dwm/actions/runs/40199783167) | `f845caebcc331c4ada4470e96b856b0e490a77ee` | Failed renderer qualification; preserve this failure |
| [40200659481](https://github.com/Siuuuers/dwm/actions/runs/40200659481) | `fac5e0cd87ca48acb4318a32f79312a16f1a21c1` | Four rendered processes passed, with 30 ordered constructor events in each process |

Controllers are isolated on `codex/startup-attribution-20261025`. Do not merge
their automatic diagnostic workflows or source overlays into product code.
The exact source at each controller commit reconstructs the experiment.

Successful journeys require actual Button down/up/pressed events, a drawn usable
Title, the exact fully revealed `line.Day1.one`, an active session, an idle New Acc
owner, no incomplete creation journal operations, and exit code zero. Retained
New Acc must show and accept the replacement consent. Screen opening uses a
separate fresh profile, so it cannot warm the New Acc measurement.

This is diagnostic journey coverage. It is not a new complete gameplay or
Save/Load regression qualification. The normal reveal duration remains included.

## Initial exported baseline

Seconds, forward/reverse order blocks on the same runner:

| Interval | Fresh | Retained |
|---|---:|---:|
| Launch to first probe tree entry | 7.149 / 7.017 | 5.395 / 4.822 |
| Launch to bootstrap start | 7.285 / 7.143 | 5.526 / 4.941 |
| Bootstrap total | 1.365 / 1.364 | 4.023 / 3.669 |
| Launch to usable Title | 8.714 / 8.570 | 9.612 / 8.672 |
| New Acc input to full first caption | 21.266 / 20.413 | 22.130 / 20.873 |

Fresh pre-bootstrap work is about 83–84% of Title startup. New Acc remains a
separate larger operation. Baseline New Acc maximum observed frame gaps are
13.160–13.876 s fresh and 12.734–13.518 s after retained confirmation.
There is no startup frame-gap sample before the first frame; do not invent one.

Inside bootstrap, save initialization takes 0.977–0.981 s fresh and
2.116–2.285 s retained. Readiness publication takes about 7 ms fresh but
1.188–1.342 s retained. Localization takes 0.278–0.296 s. Physical and structural
registration together take 0.566–0.607 s **inside** save initialization.
Do not add nested durations to their parents.

The minimal window reaches a usable draw in 2.572/2.675 s. This is a combined
engine/minimal-project result, not a pure renderer measurement.

## Menu and font decisions

| Variant | Fresh Title change, forward/reverse | Retained Title change, forward/reverse |
|---|---:|---:|
| Menu-only deferral | −228 / −573 ms | −812 / −260 ms |
| Font-only deferral | −186 / −398 ms | −734 / +175 ms |

Menu deferral shifts about 199 ms to first opening Gallery: 53.892 to 253.281 ms.
The first-open sequence is Settings, Backup, Gallery; these screens can share
warmed resources. Fresh Title plus New Acc improves about 369/426 ms, but retained
confirmation-to-caption varies and is slower in both candidate comparisons.
This is a possible small change, not the main startup fix or a precise speedup.

Font deferral succeeds structurally: SC/HC fonts are absent from the cache at
probe entry and Title in the candidate, and present in baseline/menu. It retains
Japanese/Korean story fallback and Settings language-name coverage. However,
fresh New Acc is slower by 775/689 ms; Title plus New Acc is worse by 589/291 ms.
Do not promote this candidate as a responsiveness optimization on this evidence.
The test fixture `tests/scene/test_shop_card.gd` references the retired candidate
constants and must change with them if this experiment is used later.

## Why the first observer was late

[Godot 4.6.3 Main::start](https://github.com/godotengine/godot/blob/4.6.3-stable/main/main.cpp#L4400)
loads and constructs all autoloads, then adds them to the root. Thus the first
autoload's `_enter_tree()` runs after all constructor preparation.

The second diagnostic puts an `_init()` stamp in the first, dependency-free
probe, then stamps begin/end for each of the 14 production autoloads. Existing
AudioManager, SystemTtsCoordinator and WindowModeManager constructor bodies and
signatures are preserved in wrappers. Stamps use Engine metadata only.

For each owner, **preparation** is the preceding constructor end to this
constructor begin. It includes dependency loading, script/member initialization
and engine bookkeeping. Dependencies can already be cached from earlier owners.
These are order-dependent intervals, not independent total costs of each service.

## Autoload attribution

Two fresh profiles on the second runner; milliseconds:

| Owner or interval | Pair 1 | Pair 2 | Responsibility |
|---|---:|---:|---|
| Launch to first probe constructor | 2755 | 2204 | Engine/platform and other work before the observer; not split internally |
| ApplicationBootstrap preparation | 962.449 | 1001.310 | Composition dependencies for persistence, restore, dialogue, boards, shop and retained calendar services |
| GameState preparation | 679.524 | 638.525 | Mutable gameplay state and associated rules/schema dependencies |
| DialogicBridge preparation | 355.236 | 354.086 | Controlled dialogue playback, captions, narrative admission and checkpoints |
| ProfileManager preparation | 334.397 | 323.616 | Preferences, global read/Gallery records and profile validation dependencies |
| SceneRouter preparation | 334.262 | 328.443 | Scene transitions, publication holds and pause dependencies |
| SaveManager preparation | 211.043 | 203.790 | Save/checkpoint schema and interrupted-operation recovery dependencies |

The remaining preparation intervals are small. The 15 constructor bodies total
only 0.148/0.122 ms. All ordered intervals reconcile to launch-to-bootstrap within
one millisecond of UTC clock resolution. Complete rows are in the JSON summary.

This runner reaches bootstrap at 6.007/5.450 s fresh and Title at 7.037/6.414 s.
These are **not speedups** against the first runner. Source behavior is unchanged;
runner variation and instrumentation prevent that interpretation.

## Failed renderer experiment

The comparison uses the same baseline/minimal exported bytes, with a CLI renderer
override. The cloud machine lacks native OpenGL 3.3. Godot falls back to
`opengl3_angle`, using ANGLE over Direct3D 11. The first compatibility journey
reaches the exact caption and exits zero, but logs `ERROR: 2 resources still in
use at exit`. Strict validation rejects it and stops the remaining comparisons.
The cause of the shutdown error is not established. Do not call this a qualified
renderer speedup or change the production renderer from this run.

## Next bounded investigation

Start with ApplicationBootstrap's measured preparation graph. Identify the
dependencies still required by Title/recovery and those used only after New Acc,
Load or another screen. Its 89 preload expressions are a static count, not 89
independent disk reads. Trace alternate owners before removing an edge. Measure
the complete journey after any change so the pause is not merely moved.

Separately, engine-level timing is needed for the 2.2–2.8 s before the first
constructor. Godot's built-in benchmark measurements are compiled for editor
builds, so an editor-based attribution would need a separate scope label; it
must not replace exported release timings.

DTL lazy loading is not a one-line change. DialogicEntryManifest authenticates
all 92 registrations across seven files; SoloReadingSession also compiles all
entries on configuration. Current-day History needs whole metadata topology but
only current-day native nodes. Preserve the global fingerprint, selected-day
physical validation, Contacts parent frames and Gallery replay coverage. Missing
selected content must fail before progress changes. Do not bypass validation
with a fabricated success result.

No user design decision blocks the next dependency audit. No automatic reset or
old-save migration is authorized by this timing experiment. Keep the feature
backlog outside this task.

## Evidence

See [retained evidence](../evidence/phase_2r/exported_startup_20261025/README.md).
All 54 images from the two successful runs were hash-checked. The 17 distinct
initial-run images and six distinct trace-run images were visually reviewed.
The failed renderer run remains separately identified. No cloud job is pending.
