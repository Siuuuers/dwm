# Beads Agent Context

Beads is this repository's shared task system. Keep agent-local checklists local; put shared work, blockers, and durable handoffs in Beads.

## Start Or Resume

- If an issue was assigned, inspect only that issue first: `bd show <id> --readonly`.
- Otherwise use `bd ready --limit 10` and claim atomically with `bd ready --claim --json` or `bd update <id> --claim`.
- Create and claim a Beads issue before editing code. Do not use markdown TODO files, TodoWrite, or TaskCreate as the shared source of truth.
- Keep reads narrow: apply status, label, parent, and limit filters; use `bd status --no-activity` when activity history is unnecessary.
- Use `--json` for programmatic parsing. Prefer concise human output when an agent only needs to read the result.

## Persistent Memory

Historical memories are intentionally loaded on demand instead of being injected into every session.

1. Search only for the active issue or relevant subject: `bd memories <keyword>`.
2. Retrieve a matching record with `bd recall <key>`.
3. Treat the live issue, linked specification, and repository state as authority. A memory can be superseded.
4. Store only durable discoveries with `bd remember --key <stable-key> "<fact>"`; update an existing key instead of adding another progress snapshot when possible.

Do not load every memory by default.

## Shared-Workspace Rules

- Do not use `bd edit`; use non-interactive `bd update` flags.
- Use atomic claims. Batch related writes with `bd batch` when one transaction accurately represents the work.
- Do not delete, compact, repair, or migrate the shared Beads database while other agents are active.
- Do not use `git stash`. Do not place worktrees under `.godot` or `.kilo`.
- Do not commit, push, or run Dolt remote sync without explicit user or orchestrator authority.

## Finish

Run the required checks, close only work that is genuinely complete with `bd close <id> --reason "<evidence-backed reason>"`, and report remaining blockers and the worktree state.
