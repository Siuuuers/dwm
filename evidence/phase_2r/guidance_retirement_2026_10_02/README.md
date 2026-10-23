# Guidance retirement — 2 October 2026 (Hong Kong)

`Prompt.md`, `CLAUDE.md` and `docs/agent/AGENT_WORKFLOW.md` are retired from PR #1.
Their exact originals remain in Git at `96f95c67db6c7358b5f846651fef5c88babfbf92`.
The root README now points to the current handoff and execution map. The handoff
preserves the useful working principles; Beads continues to own task status and dependencies.

[Run118](https://github.com/Siuuuers/dwm/actions/runs/36937492913) passes the focused
Windows check on exact source `e18f832deca10f7d000a45e470ce5c48c9b68b56`:
56 GUT cases across eight scripts, both documentation CLIs, and the active-instruction
PowerShell fixture. All 191 Beads records, including 23 unfinished tasks, are byte-identical.
No live Dolt query or synchronization is claimed. Runtime acceptance remains Run114.

Runs115–117 are retained setup diagnostics, not acceptance. The archives contain
raw job/API records and artifacts, verified against their original ZIP digests and
every extracted member. See [receipt.json](receipt.json) for exact boundaries and hashes,
and [the acceptance summary](run118/acceptance-summary.json) for discovery and preservation checks.
The included audit helpers run only read-only Python/Git checks over downloaded evidence.

The tested source is the PR branch, not a merged checkout. Master's newer root
`AGENTS.md` still links to `CLAUDE.md`; future integration must repoint that technical
route to the current handoff while preserving its story routes. Master and story are
unchanged by this cleanup. The PR remains draft and unmerged.
