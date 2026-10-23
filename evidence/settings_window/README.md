# Shared Settings Window Mode verification

The checkpoint starts from `53829764cb4bdfc2f8a3d77bab073296205b8e96`.
[summary.json](summary.json) binds tested source hashes, repository-filtered Git
blobs, the final combined run, and the native probe. All isolated invocation
records and initial failures are retained in [invocations.jsonl](invocations.jsonl)
and `logs/`.

The native Windows process proves Borderless against the actual current-screen
usable rectangle, Windowed at 1280 × 720, and one real Profile revision and
publication through WindowModeManager. [native-window.json](native-window.json)
records each check and entry/final native geometry. The entry window is restored
before exit. Profile storage is memory-only; audio is a silent fake adapter.

The combined suites cover physical port refusal/readback, shared output
transactions, real WindowModeManager, composite Profile restoration, actual
Bootstrap gate and dependency wiring, and the shared Settings scene. Existing
audio, Controls, localization, Profile migration, Pause, save/restore, and desktop
recovery regressions run on the same candidate.

Review and verification found and addressed these concrete issues:

- Window gate configuration initially omitted the identity Bootstrap requires.
  The regression now invokes the actual final-mode gate-injection stage.
- Failed initialization could retain one coordinator binding while retrying
  another. The retained Profile/coordinator identities are now immutable.
- Fatal physical recovery initially blocked the coordinator's earlier saved
  capsule. Recovery attempts that capsule while keeping fatal custody latched.
- The first composite restore fixture used a nonexistent legacy field. It now
  supplies the actual `legacy_run_state.settings.fullscreen` migration input.
- Six desktop crash-recovery fixtures omitted the new window startup owner.
  They now compose the real manager with isolated physical-window data.

Independent review of the bounded implementation and compensation paths is
recorded with the checkpoint's Beads notes. Native availability is currently
verified only on Windows. Headless and unverified backends explicitly disable
Window Mode and provide no native-output success claim. The eight ordinary
restore journal participants plus identity allocation and the save schema remain
unchanged.

Logs retain existing certificate-store, Unicode NUL, expected localization,
and fixture orphan diagnostics. This is not leak-free, audible-quality,
typography, or complete gameplay acceptance. The overall UI goal remains active.
No player data, merge, or push was used.
