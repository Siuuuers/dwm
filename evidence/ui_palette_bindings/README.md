# Installed palette and fixture repairs — 2026-09-13

`dwm-vky.6` binds StatHud to the installed run's Dark flag and makes StatHud and
the desktop use the existing High Contrast / colour-differentiation tuples.
Day 1 Standard colours stay exact; High Contrast has no week tint and CVD presets
keep hue/saturation while room lightness changes. Next-run preferences do not
recolour the current run. Silent installation refreshes at the existing bootstrap
and live-session-ready signals, including when the day has not changed.

`verified-20260913.log` records **55/55 tests and 1,708 assertions** across nine
suites. Coverage includes all 16 tuples across seven days, readable foreground
contrast, live preference changes, unchanged gameplay snapshots, and installation
signals. These are automated theme and host checks, not a new visual art approval.
The 24 Dialogic teardown orphans are the existing isolated-runtime baseline.

The same run verifies three bounded test repairs:

- `dwm-bee`: omitted/default and nonempty pair-witnessed forms reach the run owner.
  `pair-forwarding-mutant-20260913.log` deliberately omits the forwarding argument:
  the intended test fails on both exact-value assertions. Production bytes were
  restored, and the final normal run passes.
- `dwm-uq4`: SaveManager checkpoint fixtures include the current lifecycle and
  schedule-view members; the bootstrap test pins the current exact stage order.
- `dwm-dzn`: TemporaryStorage normalizes Windows separators before its containment
  comparison. Missing roots and traversal remain rejected. Tests stop after failed
  isolated fixture creation, and temporary environment overrides are restored.

`runs.jsonl` preserves isolated Godot 4.6.3 commands and exit codes. No live player
data was used, and no historical sealed evidence was rewritten.
