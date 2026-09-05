# Title shell verification

Run `python tools/title_shell/verify.py`. The isolated scene uses the actual Menu
scene and a subclass of its production controller that overrides only process
quit with a counter. Locale/profile nodes and external save/route command counters
are small fixtures; the Menu, RoutineClock, shared confirmation and fonts are real.

Checks cover deterministic HH:MM projection, minute alignment, invalid data,
foreground scheduling, tabular digits, persistent clock geometry, nonwrapping
ledger Up/Down, hidden-host Right behavior, and neutral Shutdown confirmation.
All nine locale/font presets must keep complete text within targets, start the
sheet on Cancel, and restore Shut down focus on Escape without issuing owner
commands. Explicit acceptance reaches the intercepted quit seam exactly once.
Fixture Chinese strings exercise font geometry; they are not translation approval.

The real two-process regression in `tests/title_resume/Observe.gd` also cancels
shutdown on actual cold production startup and checks clock persistence, unchanged
run state and restored command focus. Focused evidence is under
`tools/title_shell/evidence`; these headless checks do not prove GPU rendering.
