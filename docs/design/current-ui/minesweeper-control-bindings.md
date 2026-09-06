# Minesweeper saved toggle binding

This local checkpoint starts from `436be0c3b529ed7cbb0ab77641e6940447f0da3d`
and advances `dwm-eei.5`. The accepted Toggle Flag / Reveal control now uses the
existing `game_toggle_board_mode` mapping published by ProfileManager through
InputManager. The grid previously checked F directly. Defaults remain physical
F and the controller's west button; a saved replacement takes effect immediately.

The action belongs to the focused, visible, admitted grid. Reveal or Drag becomes
Flag; Flag becomes Reveal. It changes presentation mode only. It does not reveal
or flag a cell, issue a board command, change the projection, move focus, or reset
manual pan. Existing pointer, touch, confirm, roving-focus and dock behavior is
retained. Active pointer/touch/confirm gestures refuse a toggle without canceling
their original gesture.

Matching uses Godot's `is_action_pressed(action, false, true)` with explicit
keyboard/controller event types. Extra modifiers and keyboard echo do not match.
The canonical Controls rules still disallow authored modifier chords; this
checkpoint does not broaden the binding vocabulary. See the official
[Godot 4.6 InputEvent reference](https://docs.godotengine.org/en/4.6/classes/class_inputevent.html#class-inputevent-method-is-action-pressed).

InputManager assigns a monotonically increasing generation to each newly observed
physical contact. Duplicate packets retain the generation; release removes it.
The detached contact snapshot contains transient input identity only, independent
of action mappings. A controller disconnect retires only that device's contacts.
These values are not stored in Profile or run saves.

The grid retains held generations when focus, visibility, processing, application
foreground, interaction admission, projection custody, bindings or Pause custody
change. A contact held across one of these boundaries must be released. Multiple
simultaneously held toggle buttons produce one change until those contacts lift.
The ALWAYS input owner can observe releases while the grid is disabled or paused.
Godot's [Node processing notifications](https://docs.godotengine.org/en/4.6/classes/class_node.html#class-node-constant-notification-enabled)
cover the case where disabling a Control leaves its focus intact.

ComputerDesktop forwards one retained input owner through the cached
MinesweeperApp to its grid. Existing callers use the application's InputManager;
isolated callers may inject it explicitly. Replacing a retained input owner is
refused. An unbound grid has no functional toggle shortcut. This introduces no
new gameplay owner or Bootstrap board construction.

Review reproduced a related Controls capture failure. A key held in the parent
viewport and released inside the capture Window remained in the parent's input
ledger. Returning to the grid then lost the first fresh press. SettingsContent
now passes its existing input service to SettingsControlsSheet, whose parent,
capture and confirmation tracking paths forward events to the shared observer
before consuming them. Duplicate parent delivery is harmless. The regression
performs real memory-backed Profile capture/commit and proves both release
retirement and the first fresh grid press.

Verification is bound to exact tested working bytes and repository-filtered Git
blobs in [the evidence summary](../../../evidence/minesweeper_bindings/summary.json).
The suites use engine-routed SubViewport and embedded Window events, real Profile
and InputManager, the real Rules sheet, and the cached Desktop/App route. They
also cover controller defaults/rebinding, exact-modifier refusal, overlapping
contacts, hidden-app reopen, processing/focus/Pause boundaries, native Back,
public-fact/cell/focus/pan invariance, and the existing Controls/Settings/Pause and
desktop-save regressions. Memory storage and disposable Godot user directories
protect player data. Initial failures remain in the evidence.

The change reuses the existing action registry, Profile transactions and UI
components. No polling loop, new input dispatcher, replacement save format or
runtime feature flag was introduced. Layout and font assets are unchanged; no
new visual acceptance is claimed from these input tests.

This is not complete Controls or Minesweeper acceptance. Quick Save, Quick Load
and New Board still require their real contextual consumers and owner admission;
the pre-existing New Board path is not repaired by this toggle slice. Challenge
grid support remains component-level until the real challenge host is supplied.
Gameplay/content integration, other unfinished UI families and final combined
acceptance remain in the active overall goal. No merge or push is included.
