# Empty Gallery announcement

Baseline: `c11690e5c`. This implements the factual empty-state announcement in
section 12.2 of the [compact Gallery disposition](../../docs/design/2026-08-24-gallery-maintained-microfiche-registrar-standard-palette-and-state-disposition.md).

The existing empty sentence was visible but always marked LIVE_OFF. Gallery
now requests a polite announcement once per visible entry. Hidden setup does
not consume it; Profile, locale, preference and focus refreshes do not repeat
it. Closing and reopening permits one new announcement. Populated records,
technical failure, exact Replay targets and Replay failure announcements keep
their existing behavior. The production change adds eight lines to GalleryScene.

## Verification

- GUT RED reproduced the missing polite announcement in all three locales:
  45/48 assertions passed, with precisely three expected LIVE_OFF failures.
- Focused verification passed 18/18 tests and 533 assertions.
- Final regression passed **17 suites, 120/120 tests, 7,635 assertions, exit 0**.
- Native Windows/OpenGL checks passed with **both observer and fixture exit 0**
  in English, Simplified Chinese and Traditional Chinese. Each run subscribed
  before showing the initially hidden Gallery and proved:
  - no public empty sentence or live event before opening;
  - one localized Text element, Polite live setting, Return focus, no record
    items or additional buttons, and exactly one matching announcement event;
  - the same visible sentence with LiveSetting Off and no new event after
    focus, locale, Profile and preference refreshes;
  - one additional polite announcement after closing and reopening;
  - unchanged real Profile contents and persisted in-memory bytes.

The observer authenticates the process, native window, exact worktree and
fixture arguments. Its command/completion files are restricted to that run's
isolated test root. A dedicated MTA thread owns the event subscription and
removal. Qualifying events require the expected PID, exact localized name,
Text role and Polite live setting; raw events are retained separately.

Use `Invoke-IsolatedGodot.ps1` with the native arguments recorded in `runs.jsonl`,
then run `Invoke-GalleryEmptyAccessibility.ps1` against that live fixture log.
The fixture accepts `--gallery-test-locale=en`, `zh_CN`, or `zh_HK`.

## Evidence and limits

All ten terminal runs are retained, including the GUT RED and two native helper
failures. The first exposed a managed UIA LiveSetting conversion failure;
the helper now reads that property through the native COM interface. The second
already proved the opening announcement but failed at PowerShell's null backup
path conversion during atomic command replacement; an explicit NullString
fixed that binding. Neither attempt is reported as a full native pass.

Generated GameState/SaveManager inventories change lexical call references only;
the archive script checks that all other inventory data is identical. The 24
existing Dialogic orphan nodes and native Unicode NUL diagnostics remain in the
logs. No protected persistence/schema/Minesweeper source or tests were edited.
Independent review found no remaining blocker in the four owned source/test
files or the three final native evidence records.

This evidence proves the Windows accessibility event and semantic projection,
not a complete screen-reader narration session or all Gallery release criteria.
`dwm-7wj` remains in progress for authored archive content, meaningful version
cues, durable chronological version ordering and broader acceptance. The
chronology dependency belongs to the excluded persistence work.
