---
schema_version: 1
document_id: agent_workflow
document_role: navigation_only
execution_authority: false
status_authority: false
behavior_authority: false
verification_authority: false
capability_intentions: [{"intention_id":"desktop_experience","purpose":"Provide a usable desktop experience in which registered applications open, retain appropriate same-day presentation state, and remain accessible.","authority_links":[]},{"intention_id":"narrative_experience","purpose":"Present the intended story, relationships, hospital sequence, dates, and endings coherently through approved narrative content.","authority_links":[]},{"intention_id":"whole_project_hardening","purpose":"Make the complete game stable, accessible, secure against unsafe data execution, and honestly verified for release decisions.","authority_links":[]},{"intention_id":"playable_minesweeper","purpose":"Provide a deterministic, accessible, genuinely playable Minesweeper experience that feeds the existing game outcomes through approved contracts.","authority_links":[]}]
---

# Agent Workflow Navigation

This guide explains how to find valid work. It does not authorize work or define game behavior. If it conflicts with a source that owns the disputed fact, stop and report the conflict.

## Plain-language glossary

- **Authority:** the one designated source that owns a particular kind of project truth.
- **Frontmatter:** the machine-readable block between the two `---` lines at the top of a Markdown file.
- **Authority link:** a typed reference from an intention to one existing approved source; it is not execution permission.
- **Prompt:** the repository entry contract that tells an agent how to select context.
- **Beads:** the task tracker that owns live issue status and dependency order.
- **Bounded issue:** one Beads task with a specific scope and acceptance criteria.
- **Dependency:** an authority record or work item that must be satisfied before the dependent work can proceed.
- **Epic:** a parent Beads issue that remains open until its required child work and gates are closed.
- **Intention:** an outcome worth considering; not scheduled work.
- **Requirement packet:** an approved document that owns required behavior or constraints.
- **Specification:** an approved design explaining boundaries and decisions.
- **Accepted decision:** a reviewed choice packet whose exact status pair is approved and accepted.
- **Plan:** an approved, hash-bound procedure for implementing a specification.
- **Worktree:** the physical files currently present, including uncommitted changes.
- **Instruction hierarchy:** the active system, developer, and user instructions that determine what actions are permitted.
- **Execution permission:** exact authority to perform the requested mutation.
- **Evidence:** recorded output proving what ran against one identified worktree or commit.

## Sixty-second startup

1. Read `Prompt.md` and follow its current selection rule.
2. Use the Beads executable preflight in `Prompt.md`, run `& $bdExecutable prime`, inspect in-progress work, and run `& $bdExecutable ready --json --readonly` only when no valid work is already in progress.
3. Select exactly one bounded issue and inspect it with `& $bdExecutable show <issue-id> --json --readonly`.
4. Load only that issue's approved requirement packets and transitive dependencies; load an approved specification or implementation plan only when the requested action requires it.
5. Inspect the named physical files and current worktree before proposing mutations.
6. Confirm that the requested mutation has exact scope-matched execution permission.
7. Run the required evidence and inspect logs before reporting completion.

In plain language: start with the entry contract, ask Beads what is actually active, read only the authority for that one job, compare it with the real files, and never confuse a plan or commit with verified completion.

| Startup step | Why it exists |
|---|---|
| Read the prompt | It supplies the current context-selection contract. |
| Inspect Beads | It prevents stale prose from being mistaken for live status. |
| Select one issue | It keeps authority and mutations inside one reviewable boundary. |
| Load linked authority | It supplies required behavior, design, dependencies, and procedure without loading unrelated history. |
| Inspect physical files | It detects drift between the approved plan and the worktree. |
| Confirm permission | It separates a ready task from authority to mutate files or external state. |
| Inspect evidence | It prevents a process exit code, stale log, or wrong tested subject from becoming a false completion claim. |

## Authority map

| Question | Source to inspect |
|---|---|
| How does an agent enter and select context? | `Prompt.md` |
| What work is active, ready, blocked, or closed? | Beads |
| What behavior is required? | Approved requirement packets |
| What design was approved? | Approved specifications and accepted decisions |
| What exact implementation procedure was approved? | Approved implementation plans |
| What physically exists? | The inspected worktree or tested commit |
| What is verified? | Executed evidence tied to that subject |
| May this mutation be performed? | The active instruction hierarchy and exact scope-matched user authorization |

No entry in this table implies another. Beads readiness does not approve a design. An approved design does not approve implementation. A passing test does not close a Beads issue. This guide never grants permission.

## Reading status correctly

- A commit records one bounded repository change.
- A closed child issue reports only that child's accepted scope.
- A parent epic remains incomplete until Beads closes the parent after its required children and gates.
- An approved specification may have no implementation.
- Implemented code may have missing or stale verification.
- Query Beads for mutable status; do not copy status into this guide.

## Capability intentions

The frontmatter contains an unordered catalog of desired outcomes. These entries explain purpose only. They do not prescribe order, implementation, or completion.

An empty `authority_links` array means the intention is not executable. Ask to design and link one bounded capability. A nonempty array still requires every target to resolve, one valid Beads issue, approved requirements and plan, and exact execution permission.

## Activating one intention

Use this lifecycle: intention → bounded Beads issue → clarified and approved design or decision → approved requirements → approved implementation plan → exact execution permission → implementation and tests → evidence tied to the tested subject → Beads closure.

Each arrow is a separate gate. Never infer the next gate from the previous one.

An approved plan is the exact plan file whose path and canonical-text SHA-256 digest are recorded by one approved specification. If its valid UTF-8 text changes after newline normalization, treat approval as stale and stop for review; newline-only checkout conversion does not change approval.

## Decision table

| decision_id | exact action |
|---|---|
| commit_parent_open | Report the bounded commit; report the parent as open. |
| one_ready_issue | Inspect the issue and its dependencies; mutate only with scope-matched permission. |
| multiple_active_ambiguous | Stop, list the issue IDs, and request one selection. |
| intention_links_empty | Treat it as intent only and request design authority. |
| authority_link_broken | Stop and identify the broken link. |
| design_without_plan | Do not implement; prepare a plan only when requested. |
| plan_without_permission | Stop and request exact execution permission. |
| ignored_script | Treat verification as failed, fix discovery, and rerun. |
| child_closed_parent_open | Report the child closed and the parent open. |

## Stop report

When blocked, report four things: the physical observation, the owning authority, the action that cannot continue, and the smallest decision or correction needed. Do not disguise missing permission as a technical error.

Stop the affected work when no valid in-progress or ready bounded issue exists; multiple active issues cannot be reduced to one by the entry rule; an authority link is missing, broken, unapproved, or contradictory; requested behavior is absent from approved requirements; the approved plan does not cover the mutation; exact execution permission is missing; a prerequisite is unavailable; the worktree differs from the plan's bound assumptions; verification did not run, failed, ignored a script, or tested another subject; or completion would require inventing content or behavior. Report unaffected observations separately, but do not continue the blocked mutation.

## Adding a new idea

Describe the player-facing outcome and the problem it solves, then ask the agent to compare it with current authority and identify architecture-changing questions. Keep it as an unlinked intention while exploring. When the idea is clear, create one bounded issue, record approved behavior and design in their owning documents, write and approve an exact implementation plan, and grant execution permission separately. Never turn the intention text itself into implementation instructions.

## Safe prompts

- “Inspect current project status from Beads and explain it without changing files.”
- “Select and explain the next valid bounded issue; do not implement it.”
- “Turn this capability intention into a design proposal and stop for my review.”
- “Write an implementation plan from this approved specification; do not execute it.”
- “Inspect current authority first; then execute this exact bounded issue using only its approved requirements and plan, run its evidence gate, and preserve unrelated changes.”
- “Audit authority links and contradictions without changing runtime files.”
- “Explain this blocker in plain language and identify the smallest decision needed.”

These prompts grant only what they say. They never imply commit, push, deletion, evidence sealing, external messages, or history changes.
