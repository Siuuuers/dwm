# Witnessed rail: registered localization

This 2026-09-14 increment starts at `5306cbf5ca281ae57acf88f1d501440f02687cde`.
It moves the six rail captions and On/Off words from a component-local table
into eight dedicated `witnessed.transport.*` entries in each strict catalog.
The existing LocalizationManager owns lookup and committed language changes.

All prior catalog records remain unchanged. English grows from 277 to 285
records; both Chinese catalogs grow from 201 to 209. The legacy subset
fingerprint is byte-identical. `full_catalog_validation.json` is refreshed
from the current files, with checked SHA-256 values.

CaptionLayer binds the rail to the installed manager. The rail validates its
eight required labels and withholds command admission until usable registered
copy exists. A mismatched newly bound language remains blank and disabled
until its matching theme is configured. CaptionLayer preflights that rail
configuration before mutating its own caption tuple, so an uncommitted locale
request cannot produce a mixed caption and rail. Initial preferences apply
before the installed run palette/day; a Chinese Day-7/Midnight mount therefore
keeps all three facts. Live language changes keep the same nodes and dialogue
position while retiring old input, without marking the line visited.

## Verification

| Run | Result | Scope |
| --- | --- | --- |
| `witnessed-transport-localization-focused-2` | 46/46 tests; 1,235 assertions | Real catalog lookup, immutable subset, rail and native Skip integration before the atomicity review fix |
| `witnessed-transport-localization-atomicity-red` | 18/19 tests; three failed assertions | Controlled intermediate-branch reproduction of CaptionLayer accepting an uncommitted locale and changing its tuple/theme |
| `witnessed-transport-localization-regression` | 89/89 tests; 5,253 assertions | Final catalog, rail, native Skip, caption, Pause and run-presentation suites |
| `witnessed-transport-localization-captures` | Exit 0; three native renders | Real initialized catalog owner and mounted style, all three locales at 150% text size |
| `witnessed-transport-localization-native` | Exit 0; exactly one activation | Windows UI Automation Invoke with zero `pressed` signals and zero physical contacts |
| `witnessed-transport-localization-catalog` | Exit 0 | Strict current catalog validation and hash report generation |
| `witnessed-transport-localization-tooling` | 14/14 tests; 410 assertions | Reproducible public inventories and documentation validator |
| `witnessed-transport-localization-docs` | Exit 0 | 16 packets, four design authorities and one workflow |

Counts overlap and are not additive. The controlled atomicity RED is from this
increment before its review fix, not a claim that the preceding rail commit
already enforced catalog ownership. The first focused run is also retained:
one test script had an untyped expression, and a fixture passed display-style
hyphenated locale IDs to an API requiring canonical underscore IDs. The
corrected run uses the actual manager contract. No production locale aliases
were broadened.

The new captures were visually inspected:
[English](renders/en-150.png), [Simplified Chinese](renders/zh-CN-150.png),
[Traditional Chinese](renders/zh-HK-150.png). Their text fits all six plates.
Caption text is a synthetic fixture. These renders exercise registered rail
copy, not authored narrative translation. The real-manager mounted tests also
cover language changes without advancement and an initial Chinese
Day-7/Midnight scene. Older caption-only fixtures intentionally lack a valid
rail catalog owner and are not full-rail localization evidence.

`native-uia.json` records the real Windows Invoke against PID 38424, its exact
repository/script arguments and owned window. The matching native log reports
one activation, zero `pressed` signals and zero contacts. This is provider
activation evidence; it is not a human screen-reader speech session.

## Unresolved global audit

`UiLiteralAudit.gd` still fails before writing either disposition file at
`scenes/desktop/ComputerDesktop.tscn:87`, the existing `New message` notification
title. The same tool was run on unchanged master `5306cbf5c` and failed at the
same location. Both logs and exact arguments are archived. Neither the desktop
scene nor the auditor changed in this increment.

This is tracked as **`dwm-vky.15`**. The global scene/script disposition files
were not regenerated or presented as passing. The follow-up must verify real
presenter ownership or fix untranslated literals; blanket classification is
not an acceptable repair. This failure does not contradict the dedicated
catalog, live rail and native evidence above, but it prevents a whole-UI
literal-audit completion claim.

## Other limits and remaining work

The regression reports 1,464 detached-node/orphan observations from Dialogic
fixtures; tooling reports 24. Native logs retain Unicode/NUL diagnostics.
This is not leak-free, whole-tree or whole-game acceptance. GameState and
SaveManager public records remain unchanged; their generated references were
refreshed after test/source movement.

The registered-copy portion of `dwm-vky.14` is now implemented. That Bead
remains in progress: canonical History, guarded Auto, Backup Save/Load,
exact-variant Next and complete command acceptance still require work. Shared
TTS is also unfinished. No excluded `dwm-634` task, implementation, branch or
worktree was changed. Earlier evidence describing local rail copy as
provisional remains a historical checkpoint and is superseded by this bundle
for that subject only.

`runs.jsonl` retains all 13 wrapper runs, including the two literal-audit
failures and intermediate development failures. Reproduce with the exact
arguments in that ledger using `Invoke-IsolatedGodot.ps1`, one engine at a
time. The native UIA driver and two-terminal procedure are documented in
[the preceding rail bundle](../witnessed_transport/README.md#reproduction).
The capture helper now initializes the real ProfileManager and
LocalizationManager inside the wrapper's isolated root before mounting.

Text artifacts use UTF-8/LF; PNG bytes are original. `SHA256SUMS.txt` covers all
archived logs, ledger, UIA receipt and renders, excluding this report and the
checksum file itself.
