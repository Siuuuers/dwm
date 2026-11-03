# Retired placeholder challenge panel

Baseline: `d3c291ff250784581beef1244a328ac486f5db88` (2026-11-04).
The stable inventory prerequisite was implemented and merged in PR #184.

## Removed group

- `scripts/ui/MinesweeperChallengeOverlay.gd`
- `scripts/ui/MinesweeperChallengeOverlay.gd.uid` (`uid://cenjvxriaf4o0`)
- `scenes/dating/MinesweeperChallengeOverlay.tscn`
- Its entry in `tests/smoke_load_scenes.gd`.
- Its three exclusive locale keys, `challenge.title`, `challenge.true_path`, and
  `challenge.dark_mine`, in all five UI catalogues.

The exact original files remain at the baseline revision. This placeholder
panel exposed debug result controls and a `challenge_finished` dictionary with
path, affection_delta, dark_point and entered_true_path. It was not the live
Minesweeper worksheet. The narrative scene-host UI amendment dated 2026-08-13
identifies it as a debug picker with retired result language and retires debug
result/outcome buttons.

## Reachability and retained behavior

Before deletion, executable/configuration references to the class, paths and
UID were confined to its own script, scene and UID, plus the smoke-load list.
The audit included scripts, scenes, autoloads, addons, authored timelines, data,
schemas, project settings, tests and tools; resource, signal, inheritance and
dynamic loading paths were reviewed. The scene has no signal connections and
no external resource instantiates it. Historical requirements and evidence are
retained as historical records, not treated as executable callers.

SceneRouter routes dating to DatingScene. DatingScene builds the existing
WORKSHEET under ChallengeOverlayHost. Bootstrap's current authored flow uses
SceneHost. None of these active owners changes. Shared localization components and all remaining catalogue entries remain intact. No saved fields or supported runtime interfaces change.

## Verification scope

Run project import, catalogue validation, the remaining scene-load smoke, and both read-only public
inventory checks. Confirm no executable references to the removed paths/class/UID
remain. No new test framework or replacement placeholder is needed.

This deletion does not alter retained challenge input, completion or story
progression code. Skip gameplay journeys, localization matrices, shop/audio suites,
TLA+, export and performance benchmarks for this bounded deletion. Automatic CI
selection and actual results are reported separately in the implementation PR.
No runtime speedup is claimed.

## Separate follow-ups

The DatingScene audit found a suspended Observer UI group with explicit design
and absence-test evidence. It is outside this deletion. Terminal-choice cleanup
also encounters an old selectable PlayableDatingCapabilityProbe expecting a
released choice and focused Continue button, contrary to current automatic-flow
design. Resolve that probe separately; retain live input guards. Pre/post draw
acknowledgement helpers and their application/history owners remain unchanged.
