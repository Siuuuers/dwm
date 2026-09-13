# Day 7 native accessibility evidence

The runtime baseline was `a2f394f89ced57d57f61d5961e81f3de0b8b400a`. The verified GREEN adds the small `Day7PreludeSurface` adapter to that runtime. Subsequent commit `c2e7ec785` contains only ordinary-reply test/evidence and generated reference inventories, so the boundary and full-journey runs use the same production baseline plus this adapter.

This bundle records a Windows UI Automation `InvokePattern.Invoke()` against the real rendered Day 7 `Next` button in Godot 4.6.3. The unchanged baseline reached `Button.pressed` with zero physical contacts but did not navigate. With the adapter, the same native UIA operation navigated exactly once without emitting `Button.pressed` or creating a physical contact.

| Run | PID | Exit | Acknowledgments | Navigations | `pressed` signals | Maximum physical contacts |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Verified RED | 20692 | 1 (`native_pressed_rejected`) | 1 | 0 | 1 | 0 |
| GREEN | 1588 | 0 (`ok`) | 1 | 1 | 0 | 0 |

The probe waits for a real body draw, one successful presentation acknowledgment, an enabled `Next`, and neutral physical contacts before publishing `READY`. The UIA receipt samples the element after `Invoke()` returns. Consequently, `day7-accessibility-green-uia.json` records `enabled:false`: the accepted navigation has already disabled `Next`. It does not show admission of a disabled action.

The small adapter is an inner `Button` subclass. An unbound button keeps generation `-1`, so Gallery retains Godot's built-in Button accessibility behavior. Once Day 7 binds input custody, the button's accessibility update installs a generation-bound `ACTION_CLICK` callback. The surface admits that callback only when its generation is current, the existing source/input gates pass, and the physical-contact ledger is empty, then enters the existing `_on_next` path. Input retirement changes the generation across replacement, focus, visibility, foreground, Pause, cover/restore, retry, acknowledgment, and navigation boundaries; a queued or duplicate action therefore fails closed.

The regression log records 39/39 tests passing with 581 assertions. The focused boundary log records 4/4 tests and 55 assertions covering generation replacement, duplicate invocation, focus, cover, tree Pause, source suspension, held contacts, failed Retry, and unbound Gallery behavior. The current-docs log records all 16 documentation packets, four design authorities, and the agent workflow passing validation. The full-journey log records the real New Account → Lavinia A reply → seven-day progression → Day 7 Auto/failure/Pause/Autosave Load/final manual Next flow. `13-day7-restored-echo.png` is the requested final restored-echo capture from that journey. The run ledger also retains two earlier discovery timeouts; those diagnosed the UIA harness and are not product RED evidence. The verified RED run is the entry named `day7-accessibility-red-verified`.

## Additional verification

The additional accessibility boundary suite passes 4/4 tests with 55 assertions, including independent focus, cover, tree-Pause and source-suspension checks after input retirement has settled. The repository gate passes 14/14 tests with 410 assertions; current documentation validation passes 16 packets, four design authorities and one workflow. The final restored-echo capture was visually inspected.

## Final dispositions for `dwm-bap`

This review closes the four subjects in the original acceptance criteria:

- **Fixed seven-day calendar:** one `SevenDayCalendar` owns the fixed facts; the live facades delegate to it. [Calendar consolidation](../contact_calendar/README.md) and [continued stacking/midnight recovery](../ordinary_midnight/README.md) provide the implementation and verification disposition. `req.contact.fixed_calendar` already links that evidence.
- **Both Priscilla–Lavinia windows:** the continued-game Day 2/Day 6 test and explicit `group_not_inactive` fixtures in `test_contact_invitation_state.gd` verify replacement of the earlier resolved window without losing its history or receipts. The calendar evidence records this disposition.
- **Ordinary echo obligations:** the reply owner preserves the exact semantic reply, witnessed line, detached snapshot, immediate response and one neutral oldest-first echo. [Expiry receipt evidence](../ordinary_expiry_receipt/README.md) covers the invisible idempotency tombstone; [reply recovery](../ordinary_reply_recovery/README.md) proves exact rollback, Retry and cold Load. The original intermittent user-reported save failure remains separately open as `dwm-hsi`; that is not claimed repaired by these tests.
- **Day 7 drain:** [presentation receipts](../day7_presentation_receipt/README.md), [Pause/Load custody](../day7_pause_custody/README.md), [Auto reading](../day7_auto_reading/README.md), and this native accessibility proof cover due Day 6 followups, immutable oldest-first pending echoes, guarded gameplay, first-unsatisfied replay, and the final manual handoff. The fresh full seven-day journey in this bundle passes.

The approved seven-day design §9.3 requires modality-invariant semantic receipts. It does not require the non-dialogue Day 7 fallback to invent Dialogic line/visited identities or expose unavailable modes. The surface assigns the complete detached body to one plain `Label` before its real draw and keeps it in history; existing short/long-body and 100/125/150% draw tests therefore cover instant-text presentation. Auto and native accessibility do not create alternate receipt conditions; after the same durable presentation acceptance, they use the existing navigation handoff. Dialogic Skip and the unavailable shared TTS capability retain their separate scopes; retired shortcut actions are not revived here.

`req.contact.echo` and `req.run.day7_echo_drain` now link their implementation and verification evidence. No requirement rule body, sealed plan, digest, save schema, or excluded `dwm-634` task was changed. Historical incomplete rows in earlier evidence bundles describe their contemporaneous checkpoints; this final disposition supersedes those rows without rewriting them.

## Reproduction

Run these from the repository root in two PowerShell terminals. Start Terminal 2 immediately after Terminal 1; the driver polls the exact log for at most 15 seconds.

Terminal 1:

```powershell
$godotArgs = @(
  '--display-driver', 'windows',
  '--rendering-method', 'gl_compatibility',
  '--rendering-driver', 'opengl3',
  '--accessibility', 'always',
  '--position', '60,60',
  '-s', 'res://tests/integration/verify_day7_accessibility.gd',
  '--', '--phase2r-bootstrap-mode=test_manual'
)
& .\tools\testing\Invoke-IsolatedGodot.ps1 `
  -SuiteId 'day7-accessibility-native' `
  -LogName 'day7-accessibility-native.log' `
  -GodotArgs $godotArgs `
  -KeepRoot
```

Terminal 2:

```powershell
& .\tools\testing\Invoke-Day7AccessibilityAction.ps1 `
  -LogPath '.\.godot\phase2r_logs\day7-accessibility-native.log' `
  -OutputPath '.\.godot\phase2r_logs\day7-accessibility-native-uia.json'
```

The game process is started with `--accessibility always`, which makes the accessibility tree available without changing project settings.

## Primary Godot 4.6.3 sources

- [`DisplayServer.accessibility_update_add_action`](https://docs.godotengine.org/en/4.6/classes/class_displayserver.html#class-displayserver-method-accessibility-update-add-action)
- [`Node.get_accessibility_element`](https://docs.godotengine.org/en/4.6/classes/class_node.html#class-node-method-get-accessibility-element)
- [Screen reader integration](https://docs.godotengine.org/en/4.6/tutorials/ui/creating_applications.html#screen-reader-integration)
- [Command-line `--accessibility` option](https://docs.godotengine.org/en/4.6/tutorials/editor/command_line_tutorial.html)
- [Godot 4.6.3 `BaseButton` accessibility click implementation](https://github.com/godotengine/godot/blob/4.6.3-stable/scene/gui/base_button.cpp#L82-L108)
- [Godot 4.6.3 AccessKit action storage and dispatch](https://github.com/godotengine/godot/blob/4.6.3-stable/drivers/accesskit/accessibility_driver_accesskit.cpp#L117-L203)
- [Godot 4.6.3 AccessKit click-action mapping](https://github.com/godotengine/godot/blob/4.6.3-stable/drivers/accesskit/accessibility_driver_accesskit.cpp#L951-L960)
- [Godot 4.6.3 notification order](https://github.com/godotengine/godot/blob/4.6.3-stable/core/object/object.cpp#L975-L991)
- [Godot 4.6.3 Windows AccessKit/UI Automation linkage](https://github.com/godotengine/godot/blob/4.6.3-stable/platform/windows/detect.py#L385-L406)

## Provenance limits

This evidence proves one native Windows UI Automation Invoke against the exact process ID, native window handle/title, and button element selected by the driver. It is not a human screen-reader session and does not establish behavior for Narrator speech, other assistive technologies, or non-Windows platforms. The journey capture shows surrounding application behavior; it is not evidence that the journey's final manual Next used UIA.

## Final documentation closure check

The first closure documentation run rejected the new owner link because Bead metadata and the generated index had not yet been updated. The archive retains that failure. After binding the three requirement IDs in the existing `dwm-bap` metadata and regenerating the index, `day7-closure-docs-final` passes all 16 packets/four authorities/workflow and `day7-closure-gate-final` passes 14/14 tests with 410 assertions. All 13 run records and their exact logs are archived, including the two earlier UIA discovery timeouts.

`SHA256SUMS.txt` covers the captured artifacts and run ledger; it excludes this edited report.
