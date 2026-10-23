# Ordinary reply save-failure recovery evidence

Captured 2026-09-14 with Godot 4.6.3 Mono on the Windows/OpenGL compatibility
renderer. The first three native records ran at
`f8c16c1ee713d9a76a1dbec77e68bf1e63010177`. After the checkout was
fast-forwarded, the readiness runs, final reviewed pair, legacy check, focused
suites and repository gate ran at
`a2f394f89ced57d57f61d5961e81f3de0b8b400a`. Both used the corresponding
working-tree probe at `tests/integration/verify_ordinary_reply_save.gd`.

This is acceptance evidence for the existing ordinary-reply recovery path. It
changes no production code and does not establish the cause of the originally
reported failure. It does not repair or close `hsi`, and it includes no
`dwm-634` work.

## Final reviewed journey

`ordinary-reply-retry-reviewed-20260914.log` records a real New Account and
visible Lavinia reply. The probe creates an empty directory at the isolated
autosave transaction-marker pathname, so the production `FileOps.write_bytes`
receives a real native file-open failure. The log records
`ORDINARY_REPLY_FAILURE` with `write_not_committed`; the probe additionally
checks the underlying `write_failed`, full Contacts rollback, byte-identical
autosave, removal of the blocker, and restoration of the exact original
`FileOps` object.

The visible failure retains the exact pending command and drawn line. One real
Retry then commits exactly one pending echo and one receipt bound to that
command, with its three owned history messages each present once. A later frame
settle produces no duplicate. The run exits 0.

The reviewed retry used isolated root
`fe220e18-bfc7-49c3-9e18-3aad421ea8d6`. The reviewed cold-load command names
that run's exact printed `user_dir` as `--reply-seed-root` and runs in distinct
isolated root `ad46d67f-1f27-4098-8d31-9c3908115efc`. It enters through Login,
loads the real Autosave, and compares canonical full Contacts, pending echo,
command and receipt binding with the prior proof. It also checks the Autosave
hash and verifies that Contacts offers no duplicate choice or stale pending
command. `ordinary-reply-cold-reviewed-20260914.log` exits 0.

The archived proof is byte-identical in both reviewed roots (SHA-256
`dae8b93465c96bad802bff1872b00d9cb58b7fbf0f77ce458a56ad9540507d64`).
Process freshness and seed provenance come from the two separate ledger records
and their distinct roots; the in-game probe does not independently attest the
operating-system process boundary.

Reviewed artifacts:

- [Before reply](renders/reply-01-lavinia-before-click.png)
- [Save failure with Retry retained](renders/reply-03-save-failure-retained.png)
- [Successful Retry](renders/reply-04-retry-saved.png)
- [Cold Load restored](renders/reply-05-cold-restored.png)
- [Canonical recovery proof](ordinary-reply-recovery-proof.json)

The failure and cold-restored captures were visually inspected. The PNGs are
actual viewport captures; they do not add hardware-input or
assistive-technology coverage.

## Run record

[runs.jsonl](runs.jsonl) preserves the exact arguments, exit codes and isolated
roots for every recovery, readiness, legacy, focused and repository-gate run:

| Suite | Exit | Result |
| --- | ---: | --- |
| `ordinary-reply-native-retry` | 0 | Initial fault/Retry success |
| `ordinary-reply-native-cold-load` | 0 | Initial separate cold-load success |
| `ordinary-reply-native-retry-final` | -1 | Harness dereferenced `current_scene` during the asynchronous New Account transition |
| `ordinary-reply-retry-ready` | 0 | First bounded-readiness Retry success |
| `ordinary-reply-cold-ready` | 0 | First bounded-readiness cold-load success |
| `ordinary-reply-retry-reviewed` | 0 | Final reviewed fault/Retry success |
| `ordinary-reply-cold-reviewed` | 0 | Final reviewed separate cold-load success |
| `ordinary-reply-legacy-b` | 0 | Existing reply-B journey still succeeds |
| `ordinary-reply-focused` | 0 | 20/20 tests, 374 assertions |
| `reply-recovery-repo-gate` | 1 | 13/14 tests; both generated inventories were stale |
| `reply-inventory-game` | 0 | GameState inventory regenerated |
| `reply-inventory-save` | 0 | SaveManager inventory regenerated |
| `reply-recovery-repo-gate-final` | 0 | 14/14 tests, 410 assertions |

The `-1` entry is retained as a probe-readiness failure. It reached neither the
fault injection nor a product failure and is not presented as evidence about
the reported cause. The readiness repair waits on startup and on the live,
visible desktop after `SaveManager._new_run_busy` clears, with bounded failure.
The final pair verifies that repaired probe. The focused log reports 24 existing
Dialogic orphan nodes while all selected tests pass. Native logs retain their
Unicode/NUL diagnostics.

The first repository gate failed only its reproducibility check because the
working probe moved generated call-site references. Regeneration succeeded for
both inventories, then the final gate passed 14/14 tests and 410 assertions.
Comparison with `a2f394f89` found all 239 GameState and 74 SaveManager records
identical when `call_sites` were excluded; no contract changed.

## Reproduce

Run serially from the repository root. The wrapper creates a fresh isolated
`APPDATA`, `LOCALAPPDATA` and `DWM_TEST_ROOT` for every invocation.

```powershell
$ledger = '.godot/phase2r_logs/ordinary-reply-recovery-runs.jsonl'
$native = @(
  '--display-driver', 'windows',
  '--rendering-method', 'gl_compatibility',
  '--rendering-driver', 'opengl3',
  '--position', '-20000,-20000',
  '-s', 'res://tests/integration/verify_ordinary_reply_save.gd'
)

& .\tools\testing\Invoke-IsolatedGodot.ps1 `
  -SuiteId ordinary-reply-retry-reviewed `
  -LogName ordinary-reply-retry-reviewed-20260914.log `
  -EvidenceLogPath $ledger -KeepRoot `
  -GodotArgs ($native + @('--', '--phase2r-bootstrap-mode=final',
    '--reply-retry-proof', '--reply-choice=A', '--render-evidence'))

$retry = Get-Content $ledger | ForEach-Object { $_ | ConvertFrom-Json } |
  Where-Object suite_id -eq 'ordinary-reply-retry-reviewed' |
  Select-Object -Last 1

& .\tools\testing\Invoke-IsolatedGodot.ps1 `
  -SuiteId ordinary-reply-cold-reviewed `
  -LogName ordinary-reply-cold-reviewed-20260914.log `
  -EvidenceLogPath $ledger -KeepRoot `
  -GodotArgs ($native + @('--', '--phase2r-bootstrap-mode=final',
    '--reply-recovery-resume', "--reply-seed-root=$($retry.user_dir)",
    '--render-evidence'))

& .\tools\testing\Invoke-IsolatedGodot.ps1 `
  -SuiteId ordinary-reply-legacy-b `
  -LogName ordinary-reply-legacy-b-20260914.log `
  -EvidenceLogPath $ledger `
  -GodotArgs ($native + @('--', '--phase2r-bootstrap-mode=final',
    '--reply-choice=B', '--render-evidence'))

& .\tools\testing\Invoke-IsolatedGodot.ps1 `
  -SuiteId ordinary-reply-focused `
  -LogName ordinary-reply-focused-20260914.log `
  -EvidenceLogPath $ledger `
  -GodotArgs @(
    '-s', 'res://addons/gut/gut_cmdln.gd',
    '-gtest=res://tests/unit/test_contacts_ordinary_reply_ui.gd,res://tests/unit/test_ordinary_reply_command_port.gd,res://tests/unit/test_ordinary_reply_echo_state.gd',
    '-gexit'
  )

$gate = @(
  '-s', 'res://addons/gut/gut_cmdln.gd',
  '-gtest=res://tests/unit/tooling/test_public_surface_inventory.gd,res://tests/unit/tooling/test_doc_validator.gd',
  '-gexit'
)

& .\tools\testing\Invoke-IsolatedGodot.ps1 `
  -SuiteId reply-recovery-repo-gate `
  -LogName reply-recovery-repo-gate-20260914.log `
  -EvidenceLogPath $ledger -GodotArgs $gate

foreach ($inventory in @(
  @{ Id = 'game'; Script = 'res://autoload/GameState.gd'; Required = 'game_state_required_surface.json'; Output = 'game_state_surface.json' },
  @{ Id = 'save'; Script = 'res://autoload/SaveManager.gd'; Required = 'save_manager_required_surface.json'; Output = 'save_manager_surface.json' }
)) {
  & .\tools\testing\Invoke-IsolatedGodot.ps1 `
    -SuiteId "reply-inventory-$($inventory.Id)" `
    -LogName "reply-inventory-$($inventory.Id)-20260914.log" `
    -EvidenceLogPath $ledger `
    -GodotArgs @(
      '-s', 'res://tools/runtime/generate_public_surface_inventory.gd', '--',
      "--script=$($inventory.Script)",
      "--required=res://evidence/phase_2r/runtime/$($inventory.Required)",
      "--output=res://evidence/phase_2r/runtime/$($inventory.Output)",
      '--search-root=res://autoload', '--search-root=res://scripts',
      '--search-root=res://scenes', '--search-root=res://tests'
    )
}

& .\tools\testing\Invoke-IsolatedGodot.ps1 `
  -SuiteId reply-recovery-repo-gate-final `
  -LogName reply-recovery-repo-gate-final-20260914.log `
  -EvidenceLogPath $ledger -GodotArgs $gate
```
