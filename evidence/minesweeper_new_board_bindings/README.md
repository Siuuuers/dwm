# New Board bindings — 2026-09-13

Evidence for the bounded `dwm-eei.5.1` consumer repair. Minesweeper now reads the
existing `game_new_board` action instead of hardcoded Space. Saved keyboard and
controller mappings reach the existing owner command on an active desktop board
and on a settled board without Grid focus. The old binding stops triggering.

Both routes share the existing InputManager physical-contact ledger. A contact
held through rebinding, focus return, an information sheet, or Pause cannot become
a new command. The settled Panel observes the event idempotently before reading
that ledger because its `_input` can run before InputManager's `_input`.
Published action availability and owner costs remain authoritative; canonical
challenge docks still reject the desktop-only New Board action.

Verification:

- `clean-red-20260913.log`: four expected behavioral failures before the fix.
- `regression-20260913.log`: **187/187 tests, 4,538 assertions**, 15 suites covering
  input bindings, contact release, zoom and gestures, Grid/Panel/App/Worksheet,
  canonical docks, and real desktop first-reveal and round transactions.
- `native-rebind-20260913.log`: Godot 4.6.3 Windows/OpenGL run using isolated data.
  Real flag-mode Chord, completed rounds, tier change, saved G rebinding, old Space
  refusal, a fresh board without Grid focus, and unchanged normal round costs pass.
  Existing full-board Fit, text-size and resize checks also pass in this harness.
- `runs.jsonl` preserves invocation records, including intermediate failures.

Controller events were injected through Godot's real input routing. Physical
gamepad acceptance remains manual. Logs retain the existing 24 Dialogic orphans
and native NUL diagnostics. This closes neither the broader Controls/Quick-context
parent `dwm-eei.5` nor the separate outcome-latency parent `dwm-634`.
