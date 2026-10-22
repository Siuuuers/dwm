# Parameterized retained-cloud performance audit

These task-local launchers accept mandatory `--run-root`, `--repo`, `--source`,
`--checkout`, `--master`, `--run-id`, and `--run-number` arguments. Run
`python run_audits.py --help` or `python run_join.py --help` for syntax. Run the
component launcher first, then the join only after the independent rendered,
storage and reading component reports exist. Both require an actual completed,
successful attempt-1 broad run, matching generic evidence audit and source
provenance, 23 jobs and 13 GUT XML reports. No future run is assumed or accepted.

All 13 inner files are byte-identical to the retained Run127 tool set. The new
`helper-provenance.json` records these immutable identities and embeds the original
manifest unchanged, including historical origin identities and the two previously
accepted output limitation wording corrections. No executable inner assertion or
bounded visual, timing, process-identity, or export claim was changed.

Preflight rechecks actual raw metadata hashes, the generic audit's run binding,
exact Git commit identities, ordered merge parents and every source/checkout tree
difference. Only the existing `AGENTS.md`, `docs/*`, and `story/*` merge differences
are allowed. The unchanged lazy helper also reads four worktree files; preflight
requires their bytes to match the specified checkout. No checkout or worktree
mutation is performed. Artifact manifests must resolve their retained `local_zip`
paths; moving a run directory alone does not rewrite those paths.

Logs, copied helpers, copied launcher/provenance records, partial diagnostics and
final reports are written only below the specified run's `audit` directory. The
launchers refuse to overwrite generated evidence or changed copied helpers.
Earlier partial diagnostics must be deliberately retained before any rerun.
Historical Run127 evidence is never a target or mutated by preparation.

Use normal Python without optimization. Only evidence and Git objects are read;
no Godot, PowerShell, downloaded executable or repository source is executed. The
independent non-GUT join remains separate from final broad acceptance, and does not
establish the Settings F5 increment or whole-UI visual acceptance by itself.
