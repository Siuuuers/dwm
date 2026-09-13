# Witnessed reading rail: first increment

Captured on 2026-09-14 with Godot 4.6.3 Mono on Windows. The branch starts at
`d6a011b7cd0fef850a58d91fbff7bc0f5b7620a2`. This increment mounts the canonical
six-control rail and connects its Skip control to the existing guarded
`DialogicBridge.request_skip_step` owner. `dwm-vky.14` remains in progress.

## Behavior implemented

The fixed rail is `History | Skip | Auto | Save | Load | Next`, with the
approved six hit regions at the bottom of the Witnessed canvas. Skip alone is
enabled when the current native caption and bridge admit it. The other five
controls are disabled, unfocusable intermediate placeholders; their presence
does not establish implementation or acceptance of their command owners.
Auto displays the actual profile preference, including when its command is
unavailable. Skip first commits Auto Off and refuses to start if that write
fails. Its session generation is never saved.

The session-owned Skip pump delegates one step per frame. The bridge retains
the pre-reveal visited read, exact frontier checks, durable visited mark and
next-boundary classification. It stops at unseen prose in read-only mode and
before Return, choices or challenge boundaries. Rehearsal cannot use this
path to mutate visited history, and its rail is hidden. Normal Accept stops
Skip before calling native Dialogic input. Pause, custody, foreground and
timeline changes retire pending transport input; ordinary new text retires
the button generation while allowing the Skip session to continue.

`WitnessedTransportButton` admits fresh concrete key, controller, mouse and
touch contacts through the existing InputManager ledger. The focused key and
controller path accepts either `ui_accept` or the configured Dialogic Accept
action. Logical `InputEventAction`, emulated input, programmatic `pressed`,
stale releases, stale accessibility callbacks and duplicate activations do
not create commands. Windows native accessibility uses a generation-bound
`ACTION_CLICK` callback with neutral physical contacts.

## Verified results

| Run | Result | Scope |
| --- | --- | --- |
| `witnessed-transport-focused-4` | 35/35 tests, 887 assertions | Controller, input component, geometry/material and native bridge integration at that checkpoint |
| `witnessed-transport-regression` | 88/88 tests, 5,156 assertions | Final production rail/controller plus surrounding caption, Pause and run-presentation behavior |
| `witnessed-transport-ordering` | 17/17 tests, 322 assertions | Latest integration tests: real focused Skip Enter press/release and normal Accept cancellation before native advance |
| `witnessed-transport-captures` | Exit 0; three native captures | Actual mounted Dialogic style, all six controls, English and both Chinese variants at 150% |
| `witnessed-transport-native-accessibility-6` | Exit 0; one activation, zero `pressed` signals, zero physical contacts | Windows UI Automation Invoke against the real rendered rail button |
| `witnessed-transport-tooling-final` | 14/14 tests, 410 assertions | Reproducible public inventories and documentation validator |
| `witnessed-transport-docs-final` | 16 packets, four design authorities, one workflow | Current documentation validation |

These suites overlap; their test counts are not additive. The last integration
run adds the physical mounted-button and normal-Accept ordering checks after
the broader regression run. Production code did not change between them.

All three screenshots were visually inspected:
[English](renders/en-150.png), [Simplified Chinese](renders/zh-CN-150.png),
[Traditional Chinese](renders/zh-HK-150.png). Captions are synthetic fixtures;
the scene/style and rail are production components. The five disabled controls
and the provisional local translations are intentional limitations of this
checkpoint.

The native provider proof is the `-6` UIA JSON and its matching log. The driver
checks the live process, repository/script arguments and exact native window
title/handle, then selects the one matching Button in that window. It invokes
`Windows.UIAutomation.InvokePattern.Invoke`; it does not call the GDScript
callback directly. This proves one Windows native provider action, not a human
screen-reader session, speech output or support on another operating system.

## Diagnostic history and limits

`runs.jsonl` and `logs/` retain all 20 runs, including failures. Initial focused
runs exposed a type-inference error, a Dialogic string-property mismatch and
input-fixture/mapping issues. They are development diagnostics, not a frozen
baseline RED: one early test edit overlapped its running process. Subsequent
controlled runs used frozen source until terminal exit.

The first two native accessibility probes and the Day-7 control probe omitted
`--accessibility always` and found empty accessibility trees. The third probe
incorrectly checked consumed engine arguments; the fourth timed out while the
session was interrupted, without an Invoke attempt. The fifth found the actual
native name `Skip: Skip · Off`, which differed from the driver's expected
`Skip`. The sixth corrected these harness issues and passed. None of the
preceding discovery failures is presented as a product accessibility RED.

The first tooling check rejected stale generated call-site references. Both
inventories were regenerated. Public symbol records and contracts are
unchanged; only `call_sites` and one dynamic `day` reference moved with source
lines. The subsequent tooling and current-docs checks pass.

GUT reports detached Dialogic fixture nodes (1,656 orphan observations in the
broader regression, 432 in the final integration and 24 in tooling). This is
not a claim of leak-free shutdown. Native logs also retain Unicode/NUL
diagnostics. No whole-tree pass, whole-game completion, performance improvement
or excluded `dwm-634` completion is claimed.

## Remaining work

The Bead still requires canonical session History, guarded full Auto,
Backup-owned Save/Load, exact-variant one-shot Next, their arbitration and
complete acceptance evidence. Shared TTS remains a separate unfinished
capability. The legacy addon History opener is hidden to avoid a seventh rail
command; this increment does not implement the replacement History view.

The current component-local `COPY` table provides readable three-locale labels
but does not satisfy the registered-localization contract. A bounded follow-up
can add eight dedicated `witnessed.transport.*` catalog keys and bind the rail
to the existing LocalizationManager through CaptionLayer, preserving the
short Chinese On/Off copy. This need not touch save schemas or `dwm-634` owners.

## Reproduction

Use `tools/testing/Invoke-IsolatedGodot.ps1` from the checkout root. Exact
arguments and distinct isolated APPDATA/LOCALAPPDATA/DWM_TEST_ROOT paths are in
`runs.jsonl`. Serialize engine processes.

For the native provider check, run these in separate PowerShell terminals,
starting the second immediately after the first:

```powershell
& .\tools\testing\Invoke-IsolatedGodot.ps1 `
  -SuiteId witnessed-transport-native -LogName witnessed-transport-native.log `
  -KeepRoot -GodotArgs @(
    '--display-driver','windows','--rendering-method','gl_compatibility',
    '--rendering-driver','opengl3','--accessibility','always',
    '--position','60,60','-s','res://tests/manual/witnessed_transport_capture.gd',
    '--','--native-invoke')
```

```powershell
& .\tools\testing\Invoke-WitnessedTransportAccessibilityAction.ps1 `
  -LogPath .godot/phase2r_logs/witnessed-transport-native.log `
  -OutputPath .godot/phase2r_logs/witnessed-transport-native.uia.json
```

Text artifacts are archived as UTF-8 with LF line endings. `SHA256SUMS.txt`
covers the archived logs, ledger, native receipts and original PNG bytes; it
excludes this report and the checksum file itself.
