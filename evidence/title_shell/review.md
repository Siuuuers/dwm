# Title shell usability independent review

Reviewed 2026-09-05. No remaining material finding for this bounded milestone.
The reviewer authored no production code or tests in this milestone.

## Scope and findings

Read `scripts/ui/MenuScene.gd`, `scenes/menu/MenuScene.tscn`,
`scripts/ui/desktop/DesktopConfirmation.gd`, and the new
`scripts/ui/desktop/RoutineClock.gd`, with the existing Backup and Settings
host lifecycle. Design comparison used the historical accepted shared-shell
dossier §§5 and 10 as design references, not as implementation approval gates.

- The persistent 960×64 strip keeps the routine clock at its right. Unhosted
  Return and heading are absent; hosting exposes the ordinary Return and literal
  destination heading without changing clock geometry.
- Clock input requires integer hour, minute and second values in range. Invalid
  input replaces the value with `--:--` and localized unavailability. Foreground
  eligibility controls reads and the one-shot minute timer. Tabular font digits
  follow the 24/30/36 logical presets. The label has no focus, pointer action or
  routine live announcement.
- Five-row ledger Up/Down clamps at its endpoints. Unhosted Tab intentionally
  cycles; this review does not describe every traversal as nonwrapping.
- Shutdown is a neutral trusted sheet: no Warning glyph node or governing
  warning edge, Cancel first, Back cancels, exact Shut down focus restored.
  Existing Backup sheets retain Warning by default. The existing synchronous
  operation/recovery guard prevents departure while Backup owns custody; this
  adds no save, delete or asynchronous shutdown transaction.
- One material finding was fixed: shared Return retained Backup Tab/Down paths
  after switching to Settings. Menu now explicitly assigns the visible Settings
  first/last controls and resets directional routes. The real two-process
  observer verifies Backup → Settings, Right → Return, Tab/Down → LanguageOption,
  Close, cached reopen and Return, with unchanged profile state.

## Evidence readback

Independently read the final receipts and recomputed every listed source hash:

| Receipt | Result | Current bindings |
| --- | --- | --- |
| `tools/title_shell/evidence/result.json` | 326 focused checks pass | 34/34 |
| `tools/title_resume/evidence/result.json` | 103 checks: seed 44, resume 59; import and both processes exit 0 | 2403/2403 |
| `tools/backup_ui/evidence/ui/result.json` | 3870 checks pass | 55/55 |
| `.godot/routine-clock-myw7yd9d/result.json` | Actual clock component suite passes, including exactly one initial foreground read | 3/3 |

The title receipt SHA-256 is
`4b1d228e557230f1091b953e537a81d2ec2700820a26fd372069b91a805150e0`;
focused title receipt is
`fadb4325a694f1683dfdbdfc6d6d9b31e20bf0fe9c08a0024b67656cb53d781e`;
Backup UI receipt is
`60797dea009e0abdf3503ed71f2d0df869e8238bf27348c209f6104a82ec4e37`.

Focused tests use the actual Menu, clock, sheet and fonts with fixture owners
and an intercepted quit seam. The restart test uses original production startup
and two distinct processes sharing only isolated scratch user storage. These
headless tests do not certify physical input devices, GPU rendering or assistive
technology operation. The full-process receipt retains the exact inherited
observer-free shutdown diagnostic allowance; it does not establish leak-free
shutdown. Environment diagnostics remain logged.

Dark entitlement, title artwork, New Acc replacement policy, complete Gallery
hosting, legacy Settings internal layout/reset dialogs, and canvas matte styling
remain outside this milestone. Existing title save/load transaction limits are
not enlarged by this review.
