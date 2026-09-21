# Windows automated testing

The `Windows automated tests` GitHub Actions workflow runs on pull requests,
pushes to `master`, and manual dispatch. No local Godot installation
or cloud desktop is required to start these checks.

Each Windows Server 2022 job downloads the standard Godot 4.6.3 editor from the
official release, verifies its SHA256, imports the complete repository, and runs
one bounded GUT suite: Minesweeper, Shop, desktop input/layout, Settings/display,
New Account persistence and serialization, reading/delivery behavior, or
localization and language fallback.
The current production project uses GDScript and does not include a C# project.
This workflow does not compile C# or produce a distributable Windows export.

A supplementary job renders the computer panel on Ubuntu 24.04 using the same pinned
Godot release, Xvfb, and Mesa software OpenGL. The desktop scaling harness
captures 38 states covering the launcher, apps, scrolled content, menus, and
confirmations at baseline and enlarged widths. Geometry assertions, a successful
JSON report, and all 38 nonempty PNG files are required. Its screenshots and logs
are uploaded for visual review; a headless geometry run cannot satisfy this job.
This supplementary renderer does not replace the seven Windows test groups.
The desktop captures include Minesweeper Rules and Assignments overlays in
English, plus Japanese at 150% text size with large targets and high contrast.
The launcher samples also cover the seven procedural pixel icons, the separate
Contacts unread mark, English at 150% in both fonts, and Japanese Readable at
150% with and without high contrast. Icon apertures and complete caption bounds
are checked alongside the existing focus and navigation contracts.
Shop previews use the production procedural art for all 17 ordinary items, with
both catalog pages at 800 and 960 pixels, a sold-out item, and Readable at 150%
with large targets and high contrast. Native pixel checks verify the visible
card and inspector art, and pointer hover changes the right inspector without
a click. Public prices and stock remain controlled test fixtures.

A second rendered pass in the same job reuses Godot and the software display
with separate user data. It requires 19 screenshots and a successful report
from `tests/ui/render_delivery_dialogue.gd`, covering pending and delivered
notices, dialogue review and return to the current line, and dating captions.
The dating samples verify live and reviewed captions over production artwork
in English and both Chinese locales, including enlarged text. The
`delivery-dialogue-render` artifact contains its screenshots, report, and log.

A third pass runs `tests/ui/render_angela_overlay.gd` with its own user data and
requires 10 screenshots plus a successful report. It checks Angela's stat
overlay at normal and narrow pane widths, enlarged text, long conditions,
English and Chinese locales, high contrast, and scrolled content. Its captures
and logs are uploaded as `angela-overlay-render`.

A fourth pass runs `tests/ui/render_japanese_korean_ui.gd`, again with separate
user data, and requires 30 Japanese and Korean UI previews plus a successful
report. Before rendering, `tools/localization/validate_japanese_korean_catalogs.py`
checks catalog IDs, placeholders, and Unicode NFC normalization. The previews
exercise the selectable UI drafts and their pixel fonts; story text continues
to use the English fallback. The `japanese-korean-ui-render` artifact contains
the screenshots, report, and log.

A fifth pass runs `tests/ui/render_font_choices.gd` and requires 30 previews
using the real saved font preference and Settings picker. It checks Pixel and
Readable in all five languages at enlarged text sizes, including the rightmost
footer clock, Minesweeper controls, readable Gallery text, and witnessed captions.
The `font-choices-render` artifact contains its screenshots, report, and log.
All five passes together require 127 nonempty PNG captures; headless geometry
checks cannot replace them.

`tools/testing/Invoke-CloudTests.ps1` lists the exact test scripts. It reuses the
existing isolated runner, which gives each run disposable user data and rejects
requested scripts that never execute. A missing or empty JUnit report also fails
the job. The seven groups continue independently so one failure does not conceal
the other results. Each job has a 20-minute limit.

The `localization` group includes 17 scripts covering Japanese and Korean UI,
catalog extraction, font preparation, Gallery typography, correspondence,
speech and transport, control bindings, Backup resizing, desktop recovery,
and ending recovery. Font tests check explicit style selection, regional glyph
coverage, shared resource isolation, and text measurement. Settings tests cover
font migration, persistence, refused writes, and restoring a candidate font and
size. There are 97 requested scripts across the seven Windows
groups, plus the supplementary rendering job, for eight jobs in total.

The desktop group also covers Angela's stat overlay geometry, preserved stat
values, the existing week tint behavior, and artwork placement in the shell.

Settings → Accessibility → Font style selects Pixel (the default) or Readable
for all game text. The preference is saved independently of language and text
size. Pixel uses the existing regional Fusion masters; Readable uses Source
Sans 3 and regional Source Han Sans faces, including the bundled Japanese and
Korean subsets. Their existing OFL notices and asset provenance are retained.
The divider's enlarged vector grip keeps its original drag target and input
behavior. The footer clock stays visible in the final rightmost slot, even when
Minesweeper controls and large-target navigation share the bar. The largest
English Pixel header uses a second statistics row when complete labels cannot
fit on one row; it retains full text size and the original wording.

The `reading_delivery` group covers Minesweeper delivery notice lifecycle and
input behavior, witnessed caption input and transport, and the dating caption
style. It includes targeted pause, auto, skip, and speech regressions to verify
that reading controls retain their existing behavior, plus scene-art binding
checks for the shared artwork layout.
Font changes are also exercised in late-game cards and Gallery replay while
preserving their current text, reading delay, and replay ownership.

The `new_account` group also runs `tests/integration/verify_new_acc_latency.gd`
in a separate isolated process. It exercises the real New Account button for a
fresh account, then Logout and confirmed account replacement, and verifies that
both reach the active Day 1 desktop. The job requires its correctness marker
and records button-to-desktop time and maximum frame gap in microseconds for both
cases. `new-account-latency.json` and the probe log are uploaded with the test
results. Timings are diagnostic evidence; there is no fixed latency threshold
that could fail merely because a shared runner is slower.

The New Account encoding change was measured against its predecessor with Godot
4.6.3 headless on the same Linux host, using three separate processes per case
and identical isolated starting data. Median button-to-visible-desktop time fell
from 653.830 to 522.322 ms for fresh accounts and from 806.935 to 652.466 ms for
replacement accounts (about 20% and 19%). Replacement confirmation was automatic,
so these numbers exclude human decision time. They do not predict another
computer's loading time. The optimization keeps persisted bytes and transaction
validation unchanged; newline-terminated retained JSON uses native escaping for
the five standard JSON short control escapes, while other controls retain the
checked encoder. Compatibility tests pin the original 1,177-case byte/refusal
signature and exercise nested save text beside floating-point preferences.

Open the run under the repository's **Actions** tab to see its outcome. Each Windows job
uploads import logs, GUT logs, an execution record, and JUnit XML for seven days,
including when a test fails. Downloads/checkout failures may occur before logs
exist; their cause remains in the job log. Private-repository Actions usage is
subject to the account's configured allowance and spending settings.

To run an identical group from PowerShell on Windows after importing the project:

```powershell
$env:GODOT_CONSOLE_PATH = 'C:\Godot\Godot_v4.6.3-stable_win64_console.exe'
& $env:GODOT_CONSOLE_PATH --headless --path . --import
./tools/testing/Invoke-CloudTests.ps1 -Suite minesweeper
```

The runner invokes GUT with `-gconfig=`, an explicit comma-separated `-gtest` list,
`-gexit`, `-glog=2`, and `-gjunit_xml_file`. Add regression scripts to the relevant
group when behavior changes. This is focused regression coverage, not the full
repository suite or its separate narrative/evidence release gates.

Checkout currently needs a narrow workaround for two legacy `.claude/skills`
gitlinks that have no `.gitmodules` URLs. After checkout, the workflow removes
only those two entries from the disposable runner's index; it leaves the source
commit and working files intact, and verifies that Git can enumerate submodules.
This permits checkout's normal post-job credential cleanup to complete. The
temporary credential has only `contents: read` permission. No index change is
committed or pushed, and this workaround can be removed when those repository
gitlinks are repaired.

Headless tests can verify scene geometry, focus, commands, preserved game state,
and display transactions through test ports. The supplementary Linux screenshots
provide rendered layout evidence, but do not establish Windows GPU behavior,
audible output, real monitor/DPI behavior, or release packaging. The existing
`tests/manual/verify_window_mode_native.gd` needs an
isolated, non-headless Windows desktop to test the physical window. Do not label
headless success as completion of that native check.

References: [Godot 4.6 command line](https://docs.godotengine.org/en/4.6/tutorials/editor/command_line_tutorial.html),
[official 4.6.3 release assets](https://github.com/godotengine/godot-builds/releases/expanded_assets/4.6.3-stable),
and [GitHub Actions](https://docs.github.com/en/actions).
