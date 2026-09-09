# Seven-Day Flow Phase 00: Authority and Work Tracking Implementation Plan

> **Owner decision, 2026-09-08:** Eight-master consolidation is cancelled. Retain
> the original scene-oriented DTL arrangement and implement all promised scene
> mechanics with dialogue deferred. References below to 61-to-8 migration,
> eight-only path/count gates, and deleting the original DTL/UID files are
> superseded and must not be executed. Semantic IDs, exact entry resolution,
> safe scene completion, save/load, and promised branches remain required.
> Existing consolidated files are temporary implementation state, not layout
> authority. See the updated base design sections 4.1, 12.1, and 16.4.

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the approved seven-day specification the unambiguous bounded authority, preserve the old plot material in a noncanonical library, reconcile requirement packets, and create dependency-correct Beads work before runtime changes begin.

**Architecture:** Documentation owns intent and requirements; Beads owns mutable execution status; runtime remains descriptive evidence only. This plan changes documentation, validators, generated index data, and tracker metadata—never game behavior.

**Tech Stack:** Markdown frontmatter, GDScript documentation validators, GUT, Beads, PowerShell isolated-Godot wrapper, exact-path Git commits.

## Global Constraints

- [ ] Required skills: `documentation-and-adrs`, `deprecation-and-migration`, `beads`, `test-driven-development`, `git-workflow-and-versioning`, `superpowers:using-git-worktrees`, and `superpowers:verification-before-completion`.
- [ ] Specification authority is `docs/design/2026-08-07-seven-day-dialogic-flow-design.md`, status `written_spec_status: approved`, with `implementation_authorized: false` until the user approves this suite.
- [ ] Do not begin this plan while `dwm-p2r.7` is mid-mutation. Require a clean committed, accepted, and closed Beads handoff; otherwise stop and report the active work rather than interleave it.
- [ ] Do not begin Plan 03 board work until `dwm-p2r.9` has produced, committed, and closed the approved round/snapshot/result contract. Open status or placeholder UI is not a contract.
- [ ] Do not reopen or rewrite the history of closed `dwm-p2r.11`. Record the new reconciliation as successor work discovered from the approved 2026-08-07 specification.
- [ ] Preserve `story/01` and `story/02` character/narrative canon except for narrow mechanical supersession notices.
- [ ] Copy the named material from the pre-rewrite `story/03` verbatim before replacing that file. The library is noncanonical, not deleted history.
- [ ] Do not edit final narrative prose, localization prose, or runtime files.
- [ ] The dirty paths present at execution start are user-owned unless this plan explicitly names them. In particular, do not stage unrelated `.beads/*.jsonl`, `CLAUDE.md`, `ShopApp.gd`, `story/04-public-project-profile.md`, skill directories, or UID files.

---

## Task Interface Map

| Task | Consumes | Produces |
|---:|---|---|
| 1 | Approved spec, clean `.7` handoff, registered `dwm-oyo` graph | Verified successor authority graph and claimed Phase 00 child |
| 2 | Design/frontmatter and existing doc validator API | Failing-then-green authority/plot-neutrality tests |
| 3 | Pre-rewrite `story/03` | Verbatim noncanonical library plus plot-neutral production template |
| 4 | Approved spec and requirement packets | Reconciled requirements and generated index |
| 5 | Stable eight-file plan suite | Canonical plan digests, design binding, clean Phase 00 handoff |

## Task 1: Verify and adopt the successor authority record

**Specification:** Sections 1–3, 16.1, 18.

**Files:**

- Modify through `bd` only: `.beads/issues.jsonl`, `.beads/interactions.jsonl`
- Inspect: `Prompt.md`
- Inspect: `docs/agent/AGENT_WORKFLOW.md`
- Inspect: `prompt_docs/INDEX.md`

The user authorized durable tracking registration on 2026-08-08, without authorizing runtime implementation. The existing IDs are fixed: epic `dwm-oyo`; Phase 00–06 children `dwm-oyo.1` through `dwm-oyo.7`. All were left open and unclaimed at registration.

- [ ] Run the mandatory context selection commands:

```powershell
bd prime
bd list --status in_progress --json --readonly
bd ready --json --readonly
bd show dwm-p2r.7 --json --readonly
bd show dwm-p2r.8 --json --readonly
bd show dwm-p2r.9 --json --readonly
bd show dwm-p2r.10 --json --readonly
bd show dwm-7e6 --json --readonly
bd show dwm-oyo --json --readonly
bd list --parent dwm-oyo --status 'open,in_progress,blocked,deferred,closed' --json --readonly
```

- [ ] Stop if `.7` is not at a clean accepted boundary. Do not use a documentation task to conceal unfinished `.7` code.
- [ ] Adopt the existing records; do not create replacements. Verify the epic title, approved design `spec_id`, exclusions, acceptance criteria, seven exact child titles/plan paths, and durable registration note. Any missing, duplicate, reparented, or differently purposed record is a blocker requiring review.
- [ ] Verify and claim in one PowerShell process:

```powershell
$ids = @('dwm-oyo','dwm-oyo.1','dwm-oyo.2','dwm-oyo.3','dwm-oyo.4','dwm-oyo.5','dwm-oyo.6','dwm-oyo.7')
$records = foreach ($id in $ids) { (bd show $id --json --readonly | ConvertFrom-Json)[0] }
if ($records.Count -ne 8) { throw 'SEVEN_DAY_BEADS_RECORD_COUNT' }
bd dep cycles --json --readonly
bd lint @ids --status all --json --readonly
bd update dwm-oyo.1 --claim
bd update dwm-oyo.1 --append-notes 'Phase 00 claimed only after the dwm-p2r.7 clean closed handoff and explicit runtime authorization.'
bd show dwm-oyo.1 --json --readonly
```

- [ ] Verify the exact blocking edges: `00 <- dwm-p2r.7`, `01 <- 00`, `02 <- 00,01`, `03 <- 00,01,02,dwm-p2r.9`, `04 <- 01,02,03`, `05 <- 01,02,03,04`, and `06 <- 00,01,02,03,04,05`.
- [ ] Verify `discovered-from` links from `dwm-oyo` to `dwm-p2r.7`, `.8`, `.9`, `.10`, and `dwm-7e6`. These links preserve provenance; they do not claim those issues are complete.
- [ ] Claim only `dwm-oyo.1` after the stop gate passes. Leave `dwm-oyo.2` through `.7` open.
- [ ] Keep the exact IDs in the Phase 00 issue notes and local review transcript; do not paste mutable status into the design specification.

Expected result when Phase 00 executes: exactly `dwm-oyo.1` is in progress, the successor DAG has no cycles, both external prerequisite edges remain visible, and the pre-existing issues retain their original history. Before that authorized execution, all seven registered children remain open and unclaimed.

- [ ] Commit: none. Beads owns this status mutation; repository JSONL staging follows the project’s Beads sync policy, not an ad hoc mixed documentation commit.

## Task 2: Add authority and plot-neutrality regression tests

**Specification:** Sections 2, 3, 5, 16.1, 17.

**Files:**

- Create: `tests/unit/tooling/test_seven_day_flow_authority.gd`
- Modify: `tests/unit/tooling/test_doc_validator.gd`
- Inspect: `tools/docs/DocFrontmatter.gd`
- Inspect: `tools/docs/DocValidator.gd`

- [ ] Write failing tests that require:

```gdscript
const SPEC_PATH := "res://docs/design/2026-08-07-seven-day-dialogic-flow-design.md"
const PRODUCTION_MAP_PATH := "res://story/03-seven-day-production-map.md"
const LIBRARY_PATH := "res://story/library/03-seven-day-plot-material-library.md"

func test_written_spec_is_approved_but_implementation_is_not() -> void:
	var frontmatter := DocFrontmatter.parse_file(SPEC_PATH)
	assert_eq(frontmatter.get("written_spec_status"), "approved")
	assert_eq(frontmatter.get("self_review_status"), "passed")
	assert_false(frontmatter.get("implementation_authorized", true))

func test_production_map_contains_no_named_plot_cards() -> void:
	var text := FileAccess.get_file_as_string(PRODUCTION_MAP_PATH)
	for retired_heading in [
		"The Programme Table", "The Borrowed Book", "The Public Question",
		"Borrowed Gravity", "Exactly on Time", "Three Versions of the Sky"
	]:
		assert_false(text.contains(retired_heading), retired_heading)

func test_plot_library_is_explicitly_noncanonical() -> void:
	var text := FileAccess.get_file_as_string(LIBRARY_PATH)
	assert_true(text.contains("noncanonical"))
	assert_true(text.contains("The Programme Table"))
```

- [ ] Add tests that `story/01` and `story/05` link to the approved spec in bounded supersession notices and that `docs/design/README.md` lists the new authority ladder.
- [ ] Run RED:

```powershell
& .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'seven_day_authority_red' -LogName 'seven-day-authority-red.log' -GodotArgs @('-s','res://addons/gut/gut_cmdln.gd','-gtest=res://tests/unit/tooling/test_seven_day_flow_authority.gd,res://tests/unit/tooling/test_doc_validator.gd','-gexit')
```

Expected RED: missing library, named plot material still present in `story/03`, and missing supersession/authority links. Any parse error or unrelated test failure is an invalid RED and must be diagnosed first.

## Task 3: Move named material and rewrite the production template

**Specification:** Sections 3, 5, 7, 13, 16.1.

**Files:**

- Create: `story/library/03-seven-day-plot-material-library.md`
- Modify: `story/03-seven-day-production-map.md`
- Modify: `story/01-core-story-bible.md`
- Modify: `story/05-canon-amendments-2026-07-19.md`
- Modify: `docs/design/README.md`

- [ ] Copy the complete pre-rewrite contents of `story/03-seven-day-production-map.md` into the library file beneath this header:

```markdown
# Seven-Day Plot Material Library

> Status: noncanonical idea library. Preserved verbatim from the production map
> on 2026-08-07. Nothing in this file defines calendar, route, state, or ending
> mechanics. Material becomes canonical only through a later explicit approval.
```

- [ ] Confirm the copied body is byte-equivalent after newline normalization. Do not “clean up” wording while moving it.
- [ ] Replace `story/03` with a general template containing only:

  - authority and usage notes;
  - the fixed Days 1–7 structural slot table;
  - one plot-neutral ordinary-message card schema;
  - one solo invitation/date card schema;
  - one P–L encounter card schema;
  - one Hospital/follow-up card schema;
  - one ending-layer card schema;
  - stable semantic-ID fields, causal inputs, variation layers, echo atoms, allowed signals, visual IDs, and verification checklist;
  - a statement that events, premises, locations, mystery anchors, and final prose live elsewhere.

- [ ] The template must not name a mystery object, location, date premise, or character-specific beat. Character IDs may appear only in the fixed calendar table required by the approved mechanics.
- [ ] Add a short mechanical supersession notice to `story/01` and `story/05`. Link the approved design; do not delete historical reasoning or character prose.
- [ ] Update `docs/design/README.md` with this authority order: approved seven-day spec -> nonconflicting story canon -> derived plot-neutral production map -> noncanonical idea library -> recovered historical docs.
- [ ] Run GREEN for the Task 2 tests.

- [ ] Commit boundary:

```text
docs: separate seven-day mechanics from plot material
```

Stage only the five documentation paths plus `test_seven_day_flow_authority.gd` and the intentional validator test change.

## Task 4: Reconcile requirement packets and generated index

**Specification:** Sections 6–17, especially 16.1–16.3.

**Files:**

- Modify: `prompt_docs/requirements/contacts_invitations.md`
- Modify: `prompt_docs/requirements/dating_endings.md`
- Modify: `prompt_docs/requirements/dialogic_skip.md`
- Modify: `prompt_docs/requirements/persistence.md`
- Modify: `prompt_docs/requirements/run_lifecycle.md`
- Modify: `prompt_docs/requirements/runtime_ownership.md`
- Modify: `prompt_docs/requirements/verification.md`
- Modify generated: `prompt_docs/INDEX.md`

- [ ] Add one requirement ID for every enforceable contract family, preserving existing IDs when their meaning remains compatible. At minimum the packets must own:

  - fixed message/invitation calendars and expiry/echo law;
  - read-as-acceptance solo lifecycle and original group-only reply lifecycle;
  - schedule draft versus Done commit and max-two ordering;
  - exact Hospital predicates, miss closure, Sylvia witness, and Day 7 precedence;
  - relationship axes, outcome table, fixed promotion valves, and P–L isolation;
  - board truth, terminal special mine, mastery, attempt/branch/Rehearsal law;
  - thirteen ending identities and ordered ending steps;
  - closed semantic manifests, frozen contexts, acknowledged signals, stable line/atom IDs, and eight masters;
  - schema migration, cross-store recovery, and fail-closed behavior;
  - P0/model/headless/accessibility release evidence.

- [ ] Explicitly retire old requirements that demand `.true` ending IDs, Day 7 boards, computed/regressing tiers, solo invitation reply menus, dark max 5, Hospital no-miss behavior, generic P–L ending identity, or one-file-per-fragment timelines.
- [ ] Add the approved specification as a typed dependency in every changed packet. Do not duplicate its prose; requirement text must be atomic and testable.
- [ ] Export a fresh read-only Beads snapshot using the repository tool, regenerate `prompt_docs/INDEX.md`, and run the docs gate:

```powershell
& .\tools\beads\Export-BeadsSnapshot.ps1 -OutputPath '.godot/beads/phase2r-all.json'
& .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'seven_day_docs_index' -LogName 'seven-day-docs-index.log' -GodotArgs @('-s','res://tools/docs/generate_index.gd','--','--beads-snapshot=res://.godot/beads/phase2r-all.json')
& .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'seven_day_docs_gate' -LogName 'seven-day-docs-gate.log' -GodotArgs @('-s','res://tools/docs/validate_docs.gd','--','--beads-snapshot=res://.godot/beads/phase2r-all.json')
```

- [ ] Inspect the generated diff. A requirement/index mismatch, broken link, or stale Beads binding blocks runtime work.
- [ ] Commit boundary:

```text
docs: reconcile requirements with approved seven-day flow
```

## Task 5: Bind the proposed plan suite and close Phase 00

**Specification:** Sections 16–18.

**Files:**

- Modify: `docs/design/2026-08-07-seven-day-dialogic-flow-design.md`
- Inspect: all eight `docs/superpowers/plans/2026-08-07-seven-day-flow-*.md` files

- [ ] Verify every plan contains the required header, exact files, checkbox tasks, RED/GREEN commands, expected results, commit boundaries, specification mappings, and no unfinished placeholder tokens or unresolved alternative.
- [ ] Recompute the seven child-plan and roadmap canonical SHA-256 values after UTF-8 decode and CRLF-to-LF normalization. Require exact equality with the digest manifest already recorded in the roadmap and the roadmap digest already recorded in design frontmatter. If any digest differs, stop and create a separately reviewed plan-amendment commit; never silently rewrite the approved binding during execution.

```yaml
implementation_plan_path: "docs/superpowers/plans/2026-08-07-seven-day-flow-implementation-roadmap.md"
implementation_plan_status: proposed
implementation_authorized: false
```

- [ ] Run the Task 2 authority tests, docs gate, `git diff --check`, and a link/path scan.
- [ ] Commit boundary:

```text
docs: plan seven-day flow implementation
```

- [ ] Update the Phase 00 Beads issue with commit IDs and validation commands, then close only that child. Leave implementation children open and blocked on plan approval.
- [ ] Stop and ask the user to review the plan suite. Do not infer runtime permission from written-spec approval.
- [ ] After explicit runtime approval and before claiming Phase 01, invoke `superpowers:using-git-worktrees`: compare `git rev-parse --git-dir` with `--git-common-dir`, guard against submodules, prefer a native worktree facility, and otherwise ask consent before `git worktree add`. For a project-local fallback, use `.worktrees/` only after `git check-ignore -q .worktrees` succeeds. Start from the exact approved-plan commit, run the full current baseline, and stop for direction if it is not clean. Never create an implementation worktree around uncommitted `.7` work.

## Phase 00 Verification Gate

- [ ] `test_seven_day_flow_authority.gd` passes.
- [ ] `validate_docs.gd` and generated-index comparison pass.
- [ ] The library contains the complete preserved old map and is marked noncanonical.
- [ ] `story/03` is plot-neutral and contains no named plot cards.
- [ ] All changed requirement IDs resolve through `prompt_docs/INDEX.md`.
- [ ] Beads has one acyclic successor epic with seven bounded children.
- [ ] The design still says `implementation_authorized: false`.
- [ ] Only exact planned documentation/test/index paths were committed; unrelated dirty work remains untouched.
