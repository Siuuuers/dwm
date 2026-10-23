# A — bottom clock and upper transport, 16 October 2026

## Accepted bounded outcome
Owner correction PR36 comment6216232681 and Director6216351764 supersede the former full-width six-button allocation and A's rejected six188px-button proposal. Local audience time now occupies x1128..1280/y656..720 in the1280×720 logical canvas. Skip/Auto/Next sit immediately above at the right (y592..656); History/Save/Load remain below at left. Existing command widths, input/admission owners and time semantics remain.

RoutineClock is reused in the reading rail. It remains a nonfocusable, pointer-ignoring, foreground/minute-based local civil-time readout, with localized accessibility and selected font size/style. Ordinary and ending views share WitnessedCaptionLayer. No new time service, gameplay clock, saved clock or expiry owner.

The caption window moves upward64px without losing height; the blank upper-row left area retains background Accept. Title reuses its existing host strip as the footer, moves unchanged-height hosted content upward64px and corrects the backdrop origin. This keeps Settings/Backup/Gallery content out of the footer. ComputerDesktop is unchanged.

## Exact source and execution
- Product base:2b88fb432592776466ac221a359d96fb63e62788.
- Tested source:f67a17fb4f6aed3ed25c0c5194a51f5c6bc59133; tree:a7d65ecf14a0a0c437ed318ecdc9ae8f2133ee57.
- Windows Godot4.6.3 standard/PowerShell engine run:[38908745202](https://github.com/Siuuuers/dwm/actions/runs/38908745202), job116998896096.
- All engine checks passed:15 GUT tests/7702 assertions;346 separate Title-shell checks; RoutineClock standalone pass. All isolated exits0, no engine errors in selected logs.
- Transport12/7522; caption-clear1/33; dating-scroll1/42; rendered clock1/105.
- That workflow's subsequent census step failed decoding UTF-8 source with Windows CP1252. The overall engine workflow is **failure**, not green; its successful original test evidence is retained unchanged.
- [Verification-only Windows run38909370099](https://github.com/Siuuuers/dwm/actions/runs/38909370099), job117001019932, **success**. Explicit UTF-8 parsing verifies exact source-derived XML census, no failures/errors/skips, original ZIP and34 manifest members,12 retained source files byte-for-byte against tested GitHub source, Title result, routine-clock and child exits. No engine rerun.
- Independent local Python verification agrees. Godot/PowerShell were executed only in Windows cloud.
- Original final ZIP:743552bytes, SHA25609ee7b6cfaaeb7e881a4e30d7f5b8f8addeae2aee9f2dbba150983f35740a4a9.
- Tracked source matches the pin except the two documented disposable-index gitlink deletions for checkout credential cleanup. Import generated an untracked test_scene_clock_layout.gd.uid; that generated metadata is recorded in final-status, not claimed as a tracked-source edit.

## What the tests and images establish
Three English100% pixel-font captures at992×558 show actual Title, registered ordinary Day7 and registered ending. All were visually reviewed: bottom-right clock, upper-right transport, readable captions, no caption/control collision and no remaining old top-strip gray band. The journey starts directly at the registered Day7 target for bounded presentation coverage; it is not a full-week rerun.

The existing state owner disables Next on these ordinary text/ending states. The fixture verifies that clicking disabled Next does not fall through to background Accept, then uses normal caption Accept to reach the ending. This change relocates controls without broadening Next capability. No enabled-Next story traversal or OS-native input claim.

Transport checks cover all five locales, both font styles and text presets; selected caption-clear and long-dating-scroll checks preserve native reading state and scrolling. Title's346 checks use actual Menu with fake external owners, headless. Rendered coverage is the stated English tuple only, not every locale/resolution, exported gameplay, whole accessibility or whole-game acceptance.

## Diagnostic history and unresolved finding
- Run38907487004/job116994630438, sourcebe2f5259: transport12/7522 and RoutineClock passed; rendered fixture wrongly attempted unavailable Next. Title printed its pass marker but strict harness failed because its resource regex truncated quoted paths containing spaces and omitted two bundled WAVs. Fixed the existing tools/backup_ui/verify.py extraction, without ignoring errors.
  Original diagnostic-1.zip:172209bytes; SHA25629b96fad9fd25357df62d070452c4855e75321555e05be6ce149da3e8b0edffc;24 members independently verified.
- Run38908007688/job116996405870, sourceb64c077d: transport/caption-clear/dating-scroll/Title/RoutineClock passed; all three layout views reached. The exploratory terminal Accept→Title tail timed out (107/108 assertions). Original diagnostic-2.zip:743681bytes; SHA25609cf4bdf8c83269b96d695f3ce9d6bdac09b6ea1ec778a6f38a7f992f62c4d45;34 members independently verified.
- **Direct terminal return remains unresolved.** This diagnostic starts at target.Day7 and does not save the ending before accepting. Accepted run141 traversed the week and saved ending before final Accept. No matched baseline establishes whether the new failure is inherited, caused by this layout, or specific to the new setup. Do not label it fixed or pre-existing. Its original failing test body/logs are retained in diagnostic-2.zip.
- The final layout test deliberately stops after the three assigned views. Removing the extra return tail from this bounded layout fixture is not a fix or acceptance of that observed return path. Existing run141's acceptance retains its narrower original scope.

## Files and compatibility
Twelve changed files: Menu script/scene; shared caption script/scene; transport rail; focused rendered clock fixture; existing transport, Title, caption-runtime and dating-style tests; manual transport capture; existing disposable UI dependency scanner. Caller audit replaces Button-only child enumeration with six explicit command IDs where necessary and updates affected geometry expectations. No SaveManager, schema, history, bridge, scene registration, actual board layout, issuer or transaction logic changed.

## Next owners
A: apply C6215647495's Load-window correction in existing Bridge/caption presentation owners, scoped to active occurrence and full-line restoration, preserving longer scrollback/frontier/effects. Extend existing Day4 Load coverage, no duplicate journey or save-format rewrite. Carry the unresolved direct-terminal-return diagnostic into the next concrete supported-path triage; do not silently mark it closed.

C: review this actual UI diff and the three new captures; its diagnosis/preparation is already complete.
After bounded UI fixes, A implements B's corrected partner-fork TEST packet: Auto advances normally through authored expiry; Yes selects Sylvia, passage selects Lavinia. No Auto hold, extra timer, No or confirmation.

PR36 remains draft/unmerged. Integration remains3ae6d9138fb53c388380c78550cf6082eafc0ea3; master remains0c8b2384415d71bd3de4ff7408640bbf60b63740. Broad CI remains unresolved. No release.
