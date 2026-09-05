# Full startup and save/load loop verification

Run `python tools/save_load_loop/verify.py` after the observer at
`tests/save_load_loop/Observe.gd` is ready. The runner imports a disposable runtime
copy, then launches the real project normally. Its main scene and all production
autoloads remain configured. The only temporary project-setting addition is a
first `SaveLoadLoopObserver` autoload; the receipt includes the exact diff and
hashes both original and modified project configuration.
The Dialogic editor plugin rewrites its timeline directory during import. The
runner records that import diff, then restores the intended original settings
plus observer before runtime; it preserves original and executed project files.

Use `--smoke` for startup-only verification. This sets `DWM_SAVE_LOAD_PHASE=smoke`
and requires `SAVE_LOAD_STARTUP_PASS`; it does not establish a complete save/load
loop. Default phase is `loop`, with the distinct full-loop marker below. Evidence
for these phases is retained separately.

The loop activates the real New Account, opening Continue, Backup and Settings
controls; saves through the real disk owner; applies a registered effect through
the real transaction owner; checks cancelled and stale-target loads; then accepts
a fresh Load and waits for the actual replacement Main scene. It compares saved
gameplay, transaction receipts, retained desktop owners and restored Backup
usability. The stale-target edit is confined to the already proven isolated slot
file, whose exact original bytes are restored before the final Load. These are
programmatic control activations, not a physical-input or visual-rendering test.

`--baseline` omits the observer and runs the original project with `--verbose
--quit-after 8` to identify inherited shutdown diagnostics. It has no save/load
assertion coverage and does not suppress errors. Observer runs also use verbose
runtime diagnostics so their retained-resource names can be compared.

The observer must check `ProjectSettings.globalize_path("user://")` against
`DWM_EXPECTED_USER_ROOT` before production initialization. It reports structured
results with `SAVE_LOAD_LOOP_SUMMARY <JSON>` and completes with the standalone
`SAVE_LOAD_LOOP_PASS` line. A marker cannot override script errors, nonzero exit,
or timeout. The exact Windows root certificate store diagnostic remains logged.
The observer-free baseline also reproduced 56 retained resources at shutdown.
Observer runs may accept only its identical resource list, leaked-instance class
counts, and complete shutdown diagnostic tail. The receipt includes the baseline
log hash, all resource names, and exact accepted text. New resource names, changed
counts, earlier runtime errors and script errors still fail. This scoped baseline
allowance does not establish leak-free shutdown.

The runner redirects APPDATA, LOCALAPPDATA, TEMP and TMP beneath its fresh scratch
directory. It removes inherited DWM_TEST_ROOT and explicitly selects Bootstrap
`final` mode, because a proven test root would otherwise select manual test mode.
Original application user-directory settings remain unchanged. In this project,
the expected user path is `APPDATA/Godot/app_userdata/DWM`. This follows Godot's
[Windows path implementation](https://github.com/godotengine/godot/blob/4.6/platform/windows/os_windows.cpp)
and is checked by the observer rather than inferred from the environment alone.

No `--script` override replaces the game's main loop. Headless GL compatibility
is selected by command line. Runtime directories, all tests and UID/import
sidecars are copied; repository metadata, documentation and prior scratch trees
are excluded. After Godot exits, an absolute containment check precedes removal
of this invocation's copied project/import cache, including exceptional exits.
A preflight check requires at least 500 MiB free before any copy or import.
Isolated user data and complete
logs remain under `.godot/save-load-loop-*`; portable receipts and logs are under
`tools/save_load_loop/evidence`. This proves the observer's real-startup checks,
not GPU appearance or behavior beyond its assertions.
