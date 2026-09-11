# September 11 Minesweeper and Backup playtest fixes

Tracked as `dwm-1sj`. This batch follows the user's confirmed choices: fit the entire board automatically, keep text scaling separate, and repair both Chinese title/Schedule options.

## Behavior

- Chord is available on an eligible revealed number in Flag mode.
- A settled desktop round permits a different difficulty and Space/New Board through the existing configuration transaction. Selecting a tier itself costs nothing; the next first Reveal still uses the normal eligibility and payment rules. Pending or unsettled outcomes remain protected.
- Desktop and dating worksheets fit all cells into their board well. Local cell coordinates and hit testing remain unchanged; only rendering scales. Cell borders remain visible when scaled down.
- Both Chinese catalogs now contain the five initial title labels. Corrupted Schedule action/warning placeholders have real translations. The authored DWM / Welcome! :) wording is preserved.

## Measured causes and changes

Board generation was already below one millisecond. The remaining click work was primarily repeated receipt serialization and checkpoint validation. Issuer writes now compose unchanged canonical receipt fragments; transient consequence commits reuse only exact, detached records previously prepared by the owner. Changed or unknown inputs retain full validation. The preterminal and completed-outcome durable saves remain in place.

Backup restore planning repeatedly loaded and validated the complete localization catalog solely to obtain font paths. Presentation roots now query the catalog already validated by LocalizationManager at initialization. An authoritative selected-file preparation also replaces the redundant preliminary Backup inspection; file revisions and admission are still checked before commit.

Timing evidence uses isolated copies of the September 11 player-data snapshot and real native Godot callbacks. Timings vary with disk activity and CPU scheduling; they are observations, not frame-time guarantees. Live player saves were not modified.

## Validation

- Chinese title/Schedule plus font/preparation/admission suites: 53 tests, 1,398 assertions passed.
- Backup quick actions, pause host and completed-load continuation: 24 tests, 495 assertions passed.
- Real native Chinese title/Schedule verification passed; four rendered images inspected.
- Real Minesweeper pointer, flag-mode chord, terminal difficulty, Space, costs and difficulty/text-size containment passed; scaled grid-line acceptance is checked separately.

- Issuer atomic-write/retry suite and continuation journal suite passed. Final continuation-cache/checkpoint run: 30 tests, 282 assertions passed.
- Minesweeper focused coverage: 176 cases passed across the focused runs. Final native run checked every internal grid line at 150% text, including actual 960x540 and 640x360 window sizes; screenshots inspected.
- Full standalone Backup operations suite passed, including save/delete, stale confirmations, fallback selection, current/warm/cold restore, and injected finalization failure. Its old fixture setup was updated to the existing current-schema helper and nine participants; the historical fixture itself was not edited.
- Four fresh processes passed the completed/interrupted round recovery cases. A completed outcome survives restart; a rejected completion save restores the exact prior playable action.

## Timing observations

| Operation | Before | After |
| --- | ---: | ---: |
| Ordinary Reveal | 67-78 ms | 35-45 ms |
| First Reveal | about 370 ms | 183-201 ms |
| Winning click | 1,006 ms | 862 ms |
| Losing click | 885 ms | 727 ms |
| Open Backup | 353-455 ms | 67-70 ms |
| Prepare selected Load | 337-405 ms | 22-23 ms |
| Commit selected Load | 1,738-2,206 ms | 1,205 ms |

The final Load optimization removes repeated equality walks over unchanged continuation history. Only internal writers that clone the current document and replace exactly one transaction may supply that transaction hint. Generic and cold paths retain full type-aware comparison, and the changed operation still passes through the canonical writer. The hint-only implementation was retained after measurement; an additional field-fragment cache was not needed.

Completion and Load still perform synchronous durable writes and therefore are not instantaneous. The remaining history/storage scaling work stays under `dwm-634`; this batch changes neither recovery format nor required save boundaries.

## Evidence

Logs under `.godot/phase2r_logs/`:

- `issuer-fastpath-retry.log`, `checkpoint-transient-cache.log`, `continuation-transaction-hint.log`, `final-continuation-cache.log`
- `board-latency-fresh-transient-cache-win.log`, `board-latency-fresh-transient-cache-loss.log`
- `backup-latency-baseline.log`, `backup-latency-participants.log`, `backup-latency-font-reuse.log`, `backup-latency-transaction-hint-profile.log`
- `chinese-title-schedule-final-tests.log`, `chinese-title-schedule-native.log`
- `ms-ui-pixels.log`, `backup-load-regression.log`, `backup-operations-current-fixture.log`
- `recovery-{completed,interrupted}-{write,read}-20260911-ui-backup-final.log`

Native acceptance harnesses are `tests/manual/verify_minesweeper_ui_controls.gd` and `tests/manual/verify_chinese_title_schedule.gd`. Run them through the isolated native wrapper with `--phase2r-bootstrap-mode=final`. Evidence captures remain under isolated test roots; the Chinese captures are also retained in `.godot/phase2r_logs/chinese-title-schedule/`.
