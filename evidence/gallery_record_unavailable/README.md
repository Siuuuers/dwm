# Gallery unavailable-record recovery

This increment follows sections 10.1 and 11.2 of the active
[compact Gallery disposition](../../docs/design/2026-08-24-gallery-maintained-microfiche-registrar-standard-palette-and-state-disposition.md).
Baseline: `9627ee645`. Exact source hashes are in `source-sha256.json`.

## Behavior

- Failed required-record queries, incompatible signatures, digest mismatches,
  missing English locators and missing physical ending timelines produce the
  unavailable-record leaf. A valid record with no reached versions remains
  genuinely unreached.
- Independently trustworthy titles remain visible. Optional media, sentences,
  versions, Practice and record scrolling are absent during required failure.
  Replay is disabled and removed from keyboard focus.
- Date enumeration retains manifest-known Gallery identities separately from
  valid versions. A corrupt known date keeps its row and becomes unavailable;
  unrelated ordinary or unknown rows cannot hide valid dates or endings.
  A valid refresh restores the same selected row without writing player state.
- An ordinary replay refusal stays in the action dock, preserving record copy.
  Focus returns to the selected row without clearing the refusal. Explicitly
  activating a row still refreshes it. Actual start failures retain Retry.
- The unavailable leaf follows the trusted title at native y=24+title-height,
  or y=16 without one, preserving the specified dashed perimeter and hatch.

## Verification

- Final GUT regression: **16 suites, 118/118 tests, 7,587 assertions, exit 0**.
- Windows/OpenGL probe: **18 locale/text-size/palette tuples, 113 images,
  1,360 checks, exit 0**. The new unavailable images supplement the prior media,
  paper, action and retry checks. English and Traditional Chinese captures were
  also inspected visually.
- Independent source review identified the initial cross-record failure leak;
  after its correction and the mixed-record regression, no concrete blocker
  remained in this increment.

The focused tests use real Profile and localization with in-memory storage.
Faults are injected into detached query results and a local manifest copy;
they do not damage actual saves. Profile contents, persisted bytes and replay
starts are checked across failure and recovery.

`runs.jsonl` and `logs/` retain all seven terminal attempts, including the
initial test parse failure, the genuine red regression and the focus-handoff
failure. Both generated public-surface inventories were refreshed before the
final regression. `inventory-review.json` confirms lexical reference changes
only. The 24 existing Dialogic orphan nodes and native Unicode NUL diagnostics
remain visible in the retained logs; no new runtime test failures occurred.

Protected persistence, schema, Minesweeper implementation/tests, excluded Beads
and worktrees were not changed. Artifact and source hashes are checked against
staged Git blobs before publication.

## Remaining scope

`dwm-7wj` remains in progress. This is required-record failure handling, not
full Gallery acceptance. Authored copy/art, meaningful version cues, completion
chronology and full assistive/release acceptance remain. No chronology is
invented from signature hashes. Windows screen-reader output and physical
touch hardware are not certified by these rendering checks.
