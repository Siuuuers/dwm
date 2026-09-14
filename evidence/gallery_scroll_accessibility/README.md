# Gallery scroll callback and Windows provider boundary

Native diagnostic baseline: `9af2485a1`. This checks the active compact Gallery
requirement that an overflowing Record details region expose scroll state and
position, and disappear as a named scroll target when its copy fits.

## Local callback correction

Godot supplies one request argument to every registered accessibility callback,
including a null value when there is no payload. Gallery registered forward/back
page callbacks with an additional bound direction, but the method accepted only
that direction. Requests therefore failed with an argument-count error. The
method now accepts the supplied request before its bound direction. Page size,
clamping, focus and interaction guards are unchanged. See the pinned
[Godot 4.6.3 dispatch](https://github.com/godotengine/godot/blob/4.6.3-stable/drivers/accesskit/accessibility_driver_accesskit.cpp#L117-L201).

The regression calls the actual registered Callable shape, immediately and
deferred, with null and ScrollUnit payloads. RED reproduced two failing tests
out of eleven, including the deferred expected-one/received-two argument error.
It also checks actual offset movement, boundary clamping, retained external
focus, and the noninteractive/fitting-copy guards.
Final verification passed **4 suites, 36/36 tests, 799 assertions, exit 0**,
covering paper behavior, real Gallery navigation and record metadata, and the
public-surface inventory. No inventory regeneration was needed.
Independent review found no blocker in the callback correction or its protocol
coverage, and confirmed that the native provider failure remains separate.

## Windows UIA limitation: dwm-wuk

Native Windows/OpenGL inspection found **no ScrollPattern** on overflowing
GalleryRecordPaper. The same process's built-in ScrollContainer produces the
same result: both expose Pane and ScrollItemPattern. Its separate VScrollBar
exposes RangeValuePattern, which is not a scroll interface on the record region.
The provider query fails as unsupported; this is not a passing scrolling check.

Godot correctly forwards scroll position, ranges and actions. Its bundled
[AccessKit versions](https://github.com/godotengine/godot/blob/4.6.3-stable/thirdparty/README.md#accesskit)
include accesskit_windows 0.32.1, whose
[Windows provider registry](https://github.com/AccessKit/accesskit/blob/accesskit_windows-v0.32.1/platforms/windows/src/node.rs#L1200)
implements ScrollItem but not ScrollPattern/IScrollProvider. This agrees with
the installed-engine comparison. The local callback correction cannot supply
that missing platform interface. No engine fork, hidden control, new scrollbar,
or misleading alternative role was added.

The final diagnostic also proves the named Record details target disappears
when its copy fits, its actual offset clamps to zero, the visible sentence
remains in the accessibility tree, and Return retains focus. These passing
absence/copy checks do not make the unsupported scroll interface pass.

## Reproduction and evidence

`diagnostic/probe-gallery-scroll.gd` mounts the real paper and a native reference
control using fixture text. Run it with `Invoke-IsolatedGodot.ps1`, native Windows
OpenGL, `--accessibility always`, `--phase2r-bootstrap-mode=test_manual`, and a
kept isolated root. Run `diagnostic/probe-gallery-scroll.ps1 -LogPath <live-log>`
from the same worktree while the fixture waits. It authenticates the PID/window
and confines phase commands to the isolated test root. `runs.jsonl` retains the
exact invocations used during diagnosis, before the scripts were archived here.

The observer explicitly reports `ok: false` when ScrollPattern is unavailable.
Fixture exit 0 means its diagnostic phases terminated, not that UIA scrolling
passed. The first attempt expired after an exact-name lookup failed; subsequent
probes trim the provider's trailing name whitespace. All terminal attempts and
available native reports are retained. The final source hashes identify the
local callback fix and its tests; native provider diagnostics precede that fix.

Existing Dialogic orphan nodes and native Unicode NUL diagnostics remain in the
logs. Protected persistence, schemas, Minesweeper and their tests were untouched.
Full Gallery accessibility acceptance remains open under `dwm-7wj` and `dwm-wuk`.
