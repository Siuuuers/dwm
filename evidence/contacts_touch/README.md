# Contacts touch inspection — dwm-vky.13

2026-09-13, isolated branch `feat/contacts-touch-inspection`, source base
`83ca186e4`, installed Godot 4.6.3 mono. This implements Contacts long-press
inspection from Section 8 of the September 12 UI amendment.

The baseline engine probe reproduced opening a thread on long-press release,
drag/cancel/multitouch activation and old input surviving Pause/custody loss.
The corrected baseline harness explicitly installed the semantic controller
Accept event required when no SDL controller is connected: 36 checks, 15
failures, actual process exit 1 (`contacts-touch-baseline-final-20260913.log`).

Only `ContactsRow.gd` changes production behavior. A nonfocusable child consumes
native touch and its tagged emulated mouse packets; physical mouse packets
continue to the existing Button. The row uses the existing InputManager contact
ledger/custody signal and a one-shot 500 ms timer. Inspection uses the existing
focus, quiet underline and public description. It issues no presentation query,
open/read command or reply, and creates no persisted state or per-frame work.

Movement over 8 logical pixels, another touch anywhere, focus loss, app hide,
Pause and source-custody loss retire the gesture. A fresh tap after release
rearms. Same-frame retirement prevents native focus callbacks from hiding and
reopening the app, or moving focus away and back, then reviving the old press.
The timer and release check use the same monotonic elapsed-time boundary.

Final verification, all actual process exits 0:

- Windows/OpenGL3 probe: **49 checks**, including the native capture. Actual
  `Input.parse_input_event` packets pass through the engine, with touch-to-mouse
  emulation both enabled and disabled. The probe observes tagged synthesized
  mouse packets, six-pixel jitter on an offset row, long multitouch cancellation,
  hide/reopen, real InputManager suspend/resume, Pause, window-focus
  notifications, both synchronous focus callback cases, pointer click,
  keyboard/controller Accept and Back.
- Five Contacts/presentation/input suites: **26/26 tests, 7,381 assertions**.
  Existing pending-reply, appearance, scene and contact-generation coverage
  remains green after the final focus-retirement edit.
- Both public inventories regenerated. SaveManager is unchanged; GameState's
  lexical census adds five `contacts` references from this row/test, without
  any GameState source or public-contract change. Inventory/documentation gate:
  **14/14 tests, 410 assertions**.
- Independent final source review found no remaining concrete defect.

`contacts-touch-inspection.png` shows long-press inspection on unread Lavinia,
with no selected thread or transcript. It is an isolated real app with a
read-counting memory presentation port, not a seven-day gameplay capture.
Synthetic engine input and injected semantic controller mapping do not claim
physical touchscreen, connected controller or screen-reader hardware acceptance.
The probe starts with an empty thread; existing transcript/pending-reply coverage
is supplied by the surrounding suites.

Earlier logs retain a GDScript inference-error attempt (its stuck probe child
was explicitly stopped, actual exit -1), then the reproduced focus-callback
failure and passing repairs. The final logs retain existing Unicode/NUL and
24 GUT fixture-orphan diagnostics, with no script errors. `runs.jsonl` records
exact commands, isolation roots, timestamps and exits. Log copies trim trailing
whitespace only. No player save data was used.

This closes the bounded touch task, not `dwm-vky`, the broader goal, or the
separate active `dwm-634.2` Minesweeper latency amendment.
