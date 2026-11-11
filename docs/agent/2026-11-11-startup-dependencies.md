# Startup dependencies: removal audit and renderer experiment

Date: 11 November 2026 (Hong Kong).
Base: `3a5a02d341eff74f7a23555d6aad53eaeb82a0b2` (PR #263).

## Outcome and ownership

Find work that can be removed before the usable title without moving a pause into
New Game or Settings. Autoloads and ApplicationBootstrap own the startup graph;
Dialogic owns its subsystem/event initialization. A proposed removal needs an
exclusive unused resource, unchanged approved behavior and a measured complete
operation. No production dependency removal was justified by this audit.

## Removal candidates checked

All named preload constants in autoload scripts have local uses. Three transitive
non-font declarations appear unused, with no external constant callers found:

| Declaration | Other startup paths that still need the resource |
| --- | --- |
| DesktopBoardRestoreParticipant.DESKTOP_BOARD_STATE | GameState, ApplicationBootstrap, RunSnapshotSchema |
| DesktopBoardState._REDUCER | DatingAttemptLedger, BoardGenerator, DatingPhysicalOwner |
| SettingsContent.INPUT_REGISTRY | InputManager, ControlsBindingRules |

Deleting these lines would not remove their resources from startup. Duplicate
references are not evidence of repeated resource parsing. No cleanup was shipped
as a performance improvement. The rejected readable-font experiment from PR #263
was not repeated or adopted.

Changing SceneRouter's pause-controller preload to load would also move work:
Bootstrap configures the controller before publishing readiness. Likewise, large
manifest/runtime-adapter/physical-owner dependencies are needed elsewhere during
startup. No owner, behavior or persisted-data contract was removed based on source
size alone.

## Separate Dialogic initialization measurement

A temporary timing-only patch surrounds the existing calls; it does not disable
any subsystem or substitute test content. Linux headless Godot 4.6.3, fresh
isolated profile, normal startup ready-control probe. One diagnostic process:

| Observation | Time |
| --- | ---: |
| Engine tick when Dialogic `_ready()` begins | 5,128.511 ms |
| Collect/create/install all subsystems, inclusive | 29.191 ms |
| Clear initial state | 4.543 ms |
| Build event cache | 59.240 ms |
| Build ending `[clear]` timeline | 0.019 ms |
| Enabled title control observed | 6,101.559 ms |

These initialization spans total 92.993 ms. They do not include the earlier script
loading/compilation and are not separate addends to overall readiness. Individual
subsystem creation samples are retained in the raw log and are nested inside the
collection span. This does not support deleting subsystem registration to solve a
multi-second launch delay.

The original plugin bytes were restored. A separate uninstrumented startup then
reached readiness at 7,057.019 ms and exited 0 with no errors/warnings. Whole-process
launch through exit was 7,199.681 ms; user CPU 5,925.049 ms and system CPU 1,039.480 ms.
CPU figures include teardown and are not per-stage compiler measurements. The
variation reinforces why source file size or one before/after run is insufficient.
No test matrix was run because runtime code remains byte-identical to the base.

## Renderer experiment design

Use the already accepted Windows release ZIP from run 42956475457, source
`56a4c96f8210100b0bf95b6cad010a455e328221`, archive SHA256
`7e1184a24c8e6315ac664b15ddbaefbeaafbb6dc504c6224db0354506d5603ac`.
The package contains PR #263's runtime change; the final merge only changed docs
and restored a temporary workflow. Reusing it avoids import/export/template setup.

One Windows runner, unchanged release harness, serial ProjectDefault /
gl_compatibility / gl_compatibility / ProjectDefault. Fresh profile/output per
process; accessibility Always, audio Dummy. Existing archive/file hash checks and
source-checkout pin remain enabled. Sparse checkout needs only the harness and
manifests. Stop on unsupported rendering or a failed capability journey; do not
install a replacement driver or silently change backend.

Capability checks title, first authored caption, Computer open/close, Backup
availability and clean exit. It is not Save/Load acceptance. Screenshots need
visual review. External UIA observations include polling/provider overhead and
are not input-to-photon timing; caches are not flushed. Renderer defaults remain
unchanged throughout the experiment.

[Retained evidence](../../tools/player_latency/evidence/2026-11-11-startup-dependencies/)
includes the timing patch, raw logs, clean control and temporary workflow. To
reproduce the Linux diagnostic, copy `measure.py.txt` into
`.godot/ci/startup-dependencies/measure.py` in an imported checkout, then run it
from the repository root with Godot 4.6.3 on PATH. Use a fresh output/user directory;
the script restores the plugin source in `finally`.

## Renderer results and decision

[Run 42958691100](https://github.com/Siuuuers/dwm/actions/runs/42958691100)
succeeded. Workflow source `8cfd508425326796844f996d0baa6b5ee91e3937`;
artifact SHA256
`ee99582ce1bb92ed7004d8ccf2f1afe6b30f5de96b99961cb573ca94c55d4904`.
All four capability journeys exited cleanly with code 0 on the pinned release.

| External observation | ProjectDefault | Compatibility |
| --- | ---: | ---: |
| Launch to enabled title, samples | 8660.091 / 8419.634 ms | 6495.440 / 6393.483 ms |
| Launch to enabled title, median | 8539.862 ms | 6444.461 ms |
| New Game to first caption, median | 1157.986 ms | 1137.477 ms |

The observed title median is 2,095.401 ms lower (24.5%) on this runner. First-caption
observations are similar; there is no evidence here that the startup gain moved
into the first New Game. There are only two samples per mode, with no cold-disk
control, so no tail percentile or universal hardware percentage follows.

Actual default backend: D3D12 Forward+ / Microsoft Basic Render Driver. Actual
Compatibility backend: ANGLE OpenGL ES 3.0 over Direct3D 11 / Microsoft Basic Render
Driver. The driver lacks native OpenGL 3.3; Godot automatically selected its ANGLE
fallback and logged that warning. No extra driver was installed. This is not a
native-OpenGL comparison, and it is not native gaming-GPU evidence.

Compatibility title and opening screenshots were reviewed at 1024 by 576: full
labels, both artwork panels, caption and controls are visible. Cross-renderer
screenshots are not pixel-identical; no exact-output claim is made. Renderer
warnings and screenshot hashes are retained with receipts; full screenshots are
in the run artifact.

No runtime setting or dependency was changed. The temporary workflow is removed
from the final tree. The useful follow-up is focused Compatibility qualification
of the actual dissolve shader/connected transition, Settings, Gallery and
Save/Load before adopting a renderer default. The capability probe did not cover
those journeys. This pass establishes a promising renderer candidate and rules
out unsupported dependency deletions; it does not qualify a renderer switch.

Skipped: broad test matrices, repeated font ablation, speculative managers/caches,
old-route deletion, audio and fullscreen qualification, and physical GPU timing.
