# Gallery input repair

Base: `630eb274f1b66d78de1ca924459f81f5f0ee72c4`. This is an independent
`dwm-7wj` increment under the active Gallery disposition sections 8 and 9.

Gallery now projects Right/Left paths between the selected record and the
currently available version selector/Replay. Tab and Shift-Tab traverse the
same available controls, including existing Practice and the shell Return.
Locale, text-size and shell refreshes rebuild that graph. When a refresh makes
Replay unavailable, focus returns to the selected surviving record; active
playback retains its existing custody. Scrolling a row by touch drag now reaches
the index owner and cancels a held pointer selection. A deferred reveal also
checks a replaced/freed row before accessing it.

Only GalleryScene and GalleryRecordButton production code changed. No excluded
`dwm-634*` or `dwm-6fl` implementation, tests, branches or worktrees changed.

## Verification

- Initial behavioral RED: all four cases failed, including blocked Right,
  broken reverse Tab, lost focus after refresh and swallowed ScreenDrag.
  Immediate remount also exposed a stale deferred typed-row callback.
- One intermediate attempt failed to parse after the callback argument became
  Variant; explicit numeric local types fixed that error. Its failed log is
  retained, not counted as a passing regression.
- Focused repaired run: 20/20 tests, 557 assertions.
- Final six interaction cases: 6/6, 108 assertions, both headless and with the
  Windows OpenGL compatibility renderer. They inject keyboard, D-pad and drag
  events through a real SubViewport into the production Gallery. Real Profile,
  localization and replay owners use isolated memory storage and a test replay
  bridge. One Profile subclass deliberately refuses its reached-record query;
  this proves unavailable/recovered focus behavior without erasing saved history.
- Final combined regression: **83/83 tests in 12 suites, 6,861 assertions,
  24 existing Dialogic orphans, exit 0**. This includes Gallery typography,
  registrar, replay, artwork, title hosting, localization and inventory tooling.
- Both public inventories regenerated successfully. Their only changes are
  lexical references to the new fixture: GameState `records[51].call_sites`
  adds its Practice stub's `capture_run_snapshot_input`; SaveManager
  `records[38].call_sites` adds two Profile/localization initializer calls.
  These are not new semantic coverage claims for those owners. Implementations
  and required manifests are unchanged.
- Independent source review found no blocking findings. Source and owned text
  pass `git diff --check`.

The eight terminal attempts and their logs are retained in `runs.jsonl` and
`logs/`, including failures. Log line endings and trailing whitespace are normalized; all diagnostic text
is retained. Text is archived as UTF-8 LF; source and artifact
hashes are in `source-sha256.json` and `sha256.json`.

The row now passes unconsumed input to its parent while consuming left-button
selection itself; the index accepts scroll events at its boundary. Godot's
[Control input propagation documentation](https://docs.godotengine.org/en/4.6/classes/class_control.html#class-control-property-mouse-filter)
describes the relevant routing behavior.

## Limits

The drag case combines synthetic mouse-down and ScreenDrag to exercise routing
and cancellation; it is not a physical touchscreen/emulation certification.
No hardware controller, assistive technology or exported package was tested.
This change retains the existing plural selector, Practice and artwork behavior;
it does not claim the full registered record desk. Durable newest-first version
chronology and authored record sentences/cues remain unresolved in `dwm-7wj`.
The older typography image proof is retained at its original checkpoint.
