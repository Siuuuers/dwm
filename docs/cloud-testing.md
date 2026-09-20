# Windows automated testing

The `Windows automated tests` GitHub Actions workflow runs on pull requests,
pushes to `master`, and manual dispatch. No local Godot installation
or cloud desktop is required to start these checks.

Each Windows Server 2022 job downloads the standard Godot 4.6.3 editor from the
official release, verifies its SHA256, imports the complete repository, and runs
one bounded GUT suite: Minesweeper, Shop, desktop input/layout, or Settings/display.
The current production project uses GDScript and does not include a C# project.
This workflow does not compile C# or produce a distributable Windows export.

`tools/testing/Invoke-CloudTests.ps1` lists the exact test scripts. It reuses the
existing isolated runner, which gives each run disposable user data and rejects
requested scripts that never execute. A missing or empty JUnit report also fails
the job. The four groups continue independently so one failure does not conceal
the other results. Each job has a 20-minute limit.

Open the run under the repository's **Actions** tab to see its outcome. Each job
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
and display transactions through test ports. They do not establish pixel-perfect
rendering, GPU behavior, audible output, real monitor/DPI behavior, or release
packaging. The existing `tests/manual/verify_window_mode_native.gd` needs an
isolated, non-headless Windows desktop to test the physical window. Do not label
headless success as completion of that native check.

References: [Godot 4.6 command line](https://docs.godotengine.org/en/4.6/tutorials/editor/command_line_tutorial.html),
[official 4.6.3 release assets](https://github.com/godotengine/godot-builds/releases/expanded_assets/4.6.3-stable),
and [GitHub Actions](https://docs.github.com/en/actions).
