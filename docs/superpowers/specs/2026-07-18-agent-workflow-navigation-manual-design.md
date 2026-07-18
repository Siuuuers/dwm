---
id: spec.agent_workflow.navigation_manual
kind: design_specification
schema_version: 1
conversational_design_status: approved
written_spec_status: review_required
self_review_status: passed
implementation_authorized: false
implementation_evidence: []
verification_evidence: []
created_on: 2026-07-18
self_reviewed_on: 2026-07-18
beads_issue: dwm-2oy
---

# Agent Workflow Navigation Manual

## 1. Objective

Create an agent-first, human-readable navigation manual that explains how to find and execute valid project work without becoming an additional source of behavioral, status, design, implementation, or verification authority.

The manual MUST help an agent answer five questions before it changes the repository:

1. Which source owns the information it needs?
2. Which bounded work item, if any, is valid now?
3. Which context must it load for that work item?
4. Which conditions require it to stop?
5. What evidence is required before it may report completion?

## 2. Context

The repository deliberately separates authority among the entry contract, Beads, requirement packets, specifications, implementation plans, code, and executed evidence. This separation prevents a stale summary from silently overriding a newer decision or a passing commit from being mistaken for completion of a larger initiative.

The previous monolithic roadmap format mixed intentions, execution order, commands, and status. Recreating that format would reintroduce duplicate authority and context drift. The approved replacement is a navigation-only guide plus an unordered catalog of capability intentions.

## 3. Authority Boundary

The manual's sole top-of-file YAML frontmatter block MUST contain these five direct scalar entries with the exact values shown. A fenced example or body sentence does not satisfy the contract:

```yaml
document_role: navigation_only
execution_authority: false
status_authority: false
behavior_authority: false
verification_authority: false
```

The manual MUST NOT authorize implementation, select work by itself, mark work complete, define gameplay behavior, prescribe implementation details, or treat an intention as scheduled work.

The authority map is:

| Concern | Owning authority |
|---|---|
| Agent entry and context-selection rules | `Prompt.md` |
| Work status, dependency order, and active assignment | Beads |
| Required behavior and invariants | Approved requirement packets |
| Approved architectural decisions | Approved specifications and decision packets |
| Exact implementation procedure | Approved implementation plans |
| Physical behavior | Code and assets in the inspected worktree or tested commit |
| Verification status | Executed evidence tied to the tested subject |
| Permission to execute a repository mutation | The active system/developer/user instruction hierarchy, including an exact current user authorization or a still-valid, scope-matched user authorization recorded by an approved specification/plan |

If two authorities disagree within their own domains, the agent MUST report the conflict and stop the affected work. It MUST NOT resolve the conflict by choosing whichever document is easiest to follow.

Beads state, the manual, an intention, a requirement, a specification, or a plan MUST NOT grant permission by its own existence. A recorded authorization is usable only when it identifies the approving user, approved scope, approval state, and date; covers the exact requested mutation; and is not revoked by a newer or higher-priority instruction. Ambiguous phrases do not authorize commit, push, history rewrite, deletion, evidence sealing, external messaging, or other separately gated actions. Missing or ambiguous permission is a stop condition, not an invitation to infer consent.

## 4. Entry and Context Flow

`Prompt.md` remains the only initial repository entry point. It receives one resolvable pointer to `docs/agent/AGENT_WORKFLOW.md`.

The guide teaches this flow:

```text
Prompt.md
  -> initialize Beads context
  -> inspect in-progress and ready work
  -> select exactly one valid bounded issue
  -> inspect that issue and its dependencies
  -> load only linked requirement packets and their transitive dependencies
  -> load an approved specification and implementation plan when the requested action requires them
  -> inspect the physical code and tests named by the work item
  -> execute, verify, record evidence, and update Beads only within granted authority
```

The guide MUST explain this flow in plain language immediately after the machine-readable contract.

## 5. Status Model

The manual MUST distinguish these states:

- A commit records a bounded repository change. It does not prove that a child issue, parent epic, or product capability is complete.
- A closed child issue means only that its acceptance criteria were satisfied and recorded.
- A parent epic is complete only when Beads marks that epic closed after its required children and gates are complete.
- A specification may be approved while implementation remains absent.
- An implementation may exist while verification remains absent or stale.
- Markdown prose, checkboxes, filenames, and capability intentions never own current work status.

Agents MUST query Beads rather than copy mutable status into the manual.

## 6. Capability Intentions

The manual contains a concise, unordered catalog of desired outcomes under the top-level `capability_intentions` key in the same YAML frontmatter block as the authority declarations. The Markdown body may explain these records but MUST NOT define a second catalog. Each record uses this shape:

```yaml
- intention_id: stable_lower_snake_case_id
  purpose: one plain-language outcome
  authority_links:
    - kind: beads_issue
      target: project-issue-id
```

Rules:

- The catalog MUST NOT use numbered phase labels, sequence numbers, dates, completion claims, task checklists, implementation commands, or copied requirement text.
- `purpose` describes why the capability is desirable, not how to build it.
- Every `authority_links` element has exactly `kind` and `target`, both ordinary nonempty strings.
- `kind` is exactly one of `beads_issue`, `requirement_id`, `specification_id`, `decision_id`, or `plan_path`.
- `target` resolution is deterministic:
  - `beads_issue`: `bd show <target> --json --readonly` returns exactly one issue. Existence does not imply readiness or execution permission.
  - `requirement_id`: `prompt_docs/INDEX.md` maps the exact requirement ID to exactly one packet whose `specification_status` is `approved`.
  - `specification_id`: exactly one specification frontmatter has the matching `id`, `conversational_design_status: approved`, and `written_spec_status: approved`.
  - `decision_id`: `prompt_docs/INDEX.md` maps the exact decision ID to exactly one decision packet whose `specification_status` is `approved` and whose `decision_status` is exactly `accepted`.
  - `plan_path`: the target is one regular repository-relative Markdown file under `docs/superpowers/plans/` with YAML frontmatter containing `plan_status: approved`. A plan without that machine-readable approval is not linkable.
- An empty `authority_links` array means the intention is not executable.
- A nonempty array does not itself authorize work; all links must resolve, the active Beads issue and approval fields still govern, and the separate execution-permission rule still applies.
- Adding or changing an authority link requires validation of the target and a normal reviewed documentation change.

For this contract, a numbered phase label is any case-insensitive match of `\bphase(?:\s+|[-_])?[0-9]+[a-z0-9._-]*\b` anywhere in the manual. Examples rejected by the validator include `Phase 3`, `phase3`, `phase-3`, `PHASE_3`, and `Phase 3A1`. The ordinary words `phase` and `phases` without a number are outside this detector, although the manual SHOULD prefer `work`, `capability`, or `initiative` when those words are clearer.

The initial catalog covers only broad intentions already present in the archived project direction: a usable desktop experience, complete narrative presentation and endings, whole-project quality hardening, and a real playable Minesweeper experience. It MUST NOT reproduce archived implementation instructions.

## 7. Intention Activation

The manual explains that an intention becomes executable only through this lifecycle:

```text
intention
  -> bounded Beads issue
  -> clarified and approved design or decision when needed
  -> approved requirement/specification authority
  -> approved implementation plan
  -> exact scope-matched execution permission from the active instruction hierarchy or a still-valid recorded user authorization
  -> implementation and tests
  -> evidence tied to the tested subject
  -> Beads closure
```

No step may infer the next step's approval or permission. If an intention lacks a required link, approval, or scope-matched permission, the agent MUST identify the missing gate and ask the user for that specific decision rather than implement it. A request to design or review an intention authorizes documentation within that request only; it does not authorize implementation.

## 8. Stop Conditions and Failure Reporting

The manual MUST require the agent to stop affected work when any of these conditions holds:

- no in-progress or ready bounded issue exists;
- more than one issue appears in progress and the active selection rule cannot choose exactly one;
- a required authority link is missing, broken, unapproved, or contradictory;
- the requested behavior is absent from approved requirements;
- the implementation plan does not cover the requested mutation;
- execution authority for a gated action is missing;
- a required prerequisite is unavailable;
- the worktree differs from the assumptions bound by the plan;
- verification did not run, failed, ignored a subject, or tested another subject;
- completion would require inventing content or behavior.

A stop report states the physical observation, the owning authority, the blocked action, and the smallest decision or change needed to continue. It MUST NOT disguise missing authority as a technical failure.

## 9. Safe User Prompts

The manual provides short prompt templates for these intentions:

- explain current project status without changing files;
- select and explain the next valid Beads issue;
- turn one capability intention into a design proposal;
- write an implementation plan from an approved specification;
- execute one approved issue and run its evidence gate;
- audit authority drift or broken links;
- explain a failure or blocker in plain language.

Every execution template directs the agent to inspect current authority first. No template grants commit, push, deletion, evidence sealing, or external-system authority implicitly.

## 10. Deliverables

Implementation creates or modifies only the bounded documentation/tooling surface needed for the guide:

- Create `docs/agent/AGENT_WORKFLOW.md`.
- Modify `Prompt.md` with one guide pointer and a bounded rule describing when to consult it.
- Add an automated contract test that proves the pointer resolves and the manual retains its navigation-only declarations.
- Reuse existing documentation validation where possible; do not broaden runtime gameplay scope.
- Record implementation and verification evidence in Beads issue `dwm-2oy`.

## 11. Validation

Automated validation MUST prove:

- the `Prompt.md` pointer resolves to exactly one regular Markdown file;
- the manual has exactly one YAML frontmatter block;
- all five authority declarations exist with their frozen values;
- `capability_intentions` exists only in that frontmatter and is an array;
- capability intention IDs are unique lower-snake-case strings;
- each intention has exactly `intention_id`, `purpose`, and `authority_links`;
- every authority-link element has exactly `kind` and `target`, uses an allowed kind, and passes that kind's frozen resolver;
- the catalog contains no numbered phase labels;
- authority links are either empty or pass their kind-specific resolver; a `beads_issue` link proves only issue existence, while the other four link kinds prove the exact approval state defined above;
- no placeholder markers such as `TBD`, `TODO`, or `My first issue` exist;
- the normal documentation/tooling gate and `git diff --check` pass.

The final verification report MUST state the exact commands, tested subject, pass/fail counts, and any bounded external warnings. A process exit code alone is insufficient when the log can reveal ignored or unparsed tests.

## 12. Non-Goals

This work MUST NOT:

- recreate a master executable roadmap;
- number, schedule, or declare completion of future capability intentions;
- copy behavioral contracts into the manual;
- change gameplay, save, localization, audio, narrative, UI, or Minesweeper runtime behavior;
- create implementation issues for every intention automatically;
- close or alter the active foundation-repair epic;
- read archived roadmap prose as current execution authority;
- commit unrelated worktree changes.

## 13. Acceptance Criteria

The design is implemented when:

1. The final guide defines every authority term before first operational use, provides a copyable startup sequence, and includes a plain-language explanation of each startup step.
2. `Prompt.md` points to it without changing the current work-selection authority chain.
3. The guide contains no numbered future roadmap or executable requirement duplication.
4. A checked-in decision table and automated fixtures cover at least these cases with one exact expected action each: commit present while parent epic is open; one valid ready issue; multiple in-progress issues for which the active selection rule cannot choose exactly one; empty intention links; broken intention link; approved design without approved plan; approved plan without execution permission; test process exits zero while a script is ignored; and verified child closure while its parent remains open.
5. Automated validation catches a broken pointer, altered authority declaration, duplicate intention ID, numbered phase label, unresolved nonempty authority link, and placeholder marker.
6. The user reviews the written guide for plain-language clarity before the documentation issue closes; automated criteria own structure and decisions, while the user review owns readability.
