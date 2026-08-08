# Seven-Day Flow Implementation Roadmap

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reconcile the current Godot project with the approved seven-day flow specification through seven reviewable, test-first implementation plans, without inventing final narrative prose.

**Architecture:** Preserve `GameState` as the public facade while moving rules into pure, typed domain modules; keep run and profile persistence separate but transactionally reconcilable; make one closed semantic manifest and `DialogicBridge` the only narrative playback boundary; cut over to eight English DTL masters only after exact label coverage passes.

**Tech Stack:** Godot 4.6.3, GDScript, Dialogic 2.0 Alpha 19, GUT, strict JSON manifests, Beads, PowerShell repository tooling.

**Status:** Proposed. The design is approved; this roadmap and its child plans are not yet approved for execution.

**Design authority:** `docs/design/2026-08-07-seven-day-dialogic-flow-design.md`

**Inventory base:** `9e15c38f9f2eee7edc5a399bdde07823b90cfeb4`

## Global Constraints

- [ ] Do not edit runtime code, scenes, manifests, requirement packets, Beads, or DTL files until the user separately approves this plan suite and grants implementation authority.
- [ ] At execution start, run `bd prime`, select exactly one approved bounded issue, inspect its linked authority, and stop if selection or authority is ambiguous.
- [ ] Treat `dwm-p2r.7` as active pre-existing work. Never close, supersede, or rewrite it implicitly. Plan 00 owns explicit reconciliation with `.7`, `.8`, `.9`, `.10`, and `dwm-7e6`.
- [ ] Preserve every unrelated dirty or untracked path. Use exact-path staging and one logical commit per task.
- [ ] Run every behavior change RED -> GREEN. A test that passes before its intended implementation is not a valid RED unless it proves an existing invariant being preserved.
- [ ] DTL and UI are presentation layers. They emit typed intents or allowlisted semantic signals; they never mutate run/profile state directly.
- [ ] Saves persist semantic IDs, stages, durable transaction/receipt IDs, and validated primitive contexts—not process-local playback tokens, DTL paths, labels, line positions, Nodes, Resources, or arbitrary text.
- [ ] Keep English as the only required narrative locale in this phase. Locale fallback may change language only, never story identity.
- [ ] Do not author final dialogue, character actions, plot premises, mystery answers, backgrounds, portraits, audio, animation, or translations. DTL work is executable plot-neutral structure only.
- [ ] Do not delete the 61 old DTL/UID pairs until the new manifest, all 139 callable labels, every caller, restore handling, and import/headless smokes are green.
- [ ] Keep the six placeholder challenge-result controls available only in explicit development/test builds until the real dating-board seam replaces them; they may never ship as the player outcome selector.
- [ ] Preserve accessibility aids as classification-neutral. Keyboard, controller, screen-reader, pause, remap, and non-gameplay timing assistance cannot invalidate Perfect.
- [ ] Do not push. Commit only when the active execution authorization explicitly permits the exact path boundary.

## Plan Manifest

Execute in this order. A later plan may begin only after every stated dependency is green and committed.

| Order | Plan | Primary specification sections | Depends on |
|---:|---|---|---|
| 00 | [Authority and work tracking](./2026-08-07-seven-day-flow-00-authority-and-work-tracking.md) | 1–3, 16–18 | Approved roadmap |
| 01 | [Dialogic contract and consolidation](./2026-08-07-seven-day-flow-01-dialogic-contract-and-consolidation.md) | 4–5, 9, 12–14, 16.2, 16.4 | 00 |
| 02 | [Calendar, contacts, schedule, and Hospital](./2026-08-07-seven-day-flow-02-calendar-contacts-schedule-hospital.md) | 6.1–6.3, 7, 9, 12.5 | 00; Plan 01 ID contracts |
| 03 | [Relationship, board, promotion, and pair law](./2026-08-07-seven-day-flow-03-relationship-board-pair.md) | 6.2, 6.4, 8, 10.1, 10.4 | 00–02 pure calendar/contact/Hospital contracts; Plan 01 IDs |
| 04 | [Persistence, profile ledgers, and Rehearsal](./2026-08-07-seven-day-flow-04-persistence-profile-rehearsal.md) | 6.5, 10, 14.3–14.4, 16.3 | 01–03 pure contracts; owns profile-backed pair draw and final day-receipt composition |
| 05 | [Day 7, endings, Gallery, and production wiring](./2026-08-07-seven-day-flow-05-day7-endings-gallery.md) | 11–14, 16.2–16.4 | 01–04 |
| 06 | [Integration and release evidence](./2026-08-07-seven-day-flow-06-integration-release-evidence.md) | 15–18 | 00–05 |

## Target File Structure

The child plans list every concrete path they create or modify. Their ownership map is:

```text
scripts/domain/
  calendar/          fixed seven-day slots
  contact/           ordinary, solo, group, and closure state
  relationship/      axes, outcomes, and fixed promotion
  ending/            ordered plan schema, resolver, and Observer rules
  minesweeper/       deterministic board state/generation/metrics
  pair/              counted encounter, pure observation, stable deck rules
  hospital/          condition and Hospital receipts
  rehearsal/         reached-signature access rules
scripts/application/
  run/               Done/day/Hospital/Day7/board coordinators
  pair/              pair challenge and profile-backed deck ports
  presentation/      canonical signature and pair-witness recorder
  rehearsal/         isolated Gallery/Rehearsal session
  transaction/       recoverable run/profile journal coordinator
scripts/narrative/   closed manifest, signal port, completion port, ending adapter
data/manifests/      exact semantic entry/ID/visual/variable registries
schemas/             strict manifest, profile, save, and evidence schemas
dialogic/timelines/en/
  day_1.dtl through day_7.dtl, endings.dtl
tests/               unit, property, integration, scenario, scene, and structural gates
tools/dialogic/      manifest generation/static validation
tools/evidence/      sealed final gate runner and validator
```

## Cross-Plan Contract Vocabulary

All plans use these meanings; an implementation may add internal fields only when the owning plan updates the exact schema and tests.

| Name | Required meaning |
|---|---|
| `entry_id` | Stable callable presentation identity resolved by the closed manifest |
| `ending_id` | Stable Gallery/save identity; one ending may allow several finite `entry_id` forms |
| `transaction_id` | Caller-created idempotency key for one causative command |
| `receipt_id` | State-owner identity proving one accepted command/result |
| `playback_token` | One bridge-issued token binding entry, frozen context, stage, and physical completion |
| `challenge_slot_id` | One of the twelve exact solo IDs defined by the fixed calendar (`solo.priscilla.day_1` through each listed friend/day match) or `pair.priscilla_lavinia.day_2|day_6` |
| `board_result` | `exploded | solved | perfect` only |
| `relationship_outcome` | `hatred | upset | amused | loved | foresight | dark` only |
| `tier` | Durable `friend | ambiguous | love`, monotonic within a run |
| `attitude` | Current reaction overwritten only by an attended solo outcome or Sylvia Hospital witness |
| `tone` | Derived `sweet | dark`; stored dark `0..1` or `2..4` respectively |
| `branch_id` | One post-first-ending restored canonical timeline; branches never share current-attempt pointers |
| `presentation_atom_id` | Stable non-dialogue line/action/visual/silence witness identity |

Every pure command returns the existing repository result shape:

```gdscript
{
	"ok": true,
	"code": &"ok",
	"value": {"candidate": detached_candidate},
	"receipt": detached_receipt,
}
```

Failures use `ok = false`, a stable `StringName` code, and no partially mutated candidate.

## Existing Work Reused, Not Rebuilt

- `RunLifecycle`, `DayResolutionPlan`, and `DayResolutionCoordinator` remain the resumable transaction shell.
- `SaveManager`, `SaveDocumentSchema`, `CheckpointJournal`, isolated storage, and restore participants remain the save foundation.
- `ProfileManager` remains the sole profile publication owner.
- `ContactInvitationState` retains its stateless prepare/commit shape and the original P–L group protocol, after schema correction for both windows.
- `ScheduleRules` remains the pure schedule validator and becomes the production authority instead of the legacy duplicate in `GameState`.
- `DatingEndingRules` is migrated in place into the ordered ending resolver; a second ending authority is forbidden.
- `DialogicBridge` remains the public narrative seam but loses permissive path starts and arbitrary marker payloads.

## Known Pre-Implementation Blockers

- [ ] This suite is intentionally not executable today while `dwm-p2r.7` is mid-mutation. Its existing owner must first reach a clean committed, accepted, and closed handoff; the successor plan may not absorb unknown dirty state.
- [ ] `dwm-p2r.9` must deliver and close a committed exact Minesweeper round/snapshot/result contract before Plan 03. Placeholder UI/open issue status does not satisfy the gate.
- [ ] Plan 00 must reconcile current requirement packets and Beads metadata with the approved specification before any runtime task begins.
- [ ] `GameStateDayResolutionPort` currently emits synthetic empty receipts and must not be treated as production evidence.
- [ ] `ApplicationBootstrap` names configuration stages it does not dispatch; final-mode startup is not yet a valid wiring proof.
- [ ] `tests/smoke_dialogic_timelines.gd` is an unconditional placeholder and cannot count as evidence.
- [ ] No real board engine currently exists. Plan 03 must consume the approved `.9` Minesweeper round contract or stop if that contract remains unavailable.
- [ ] `dwm-7e6` remains the source requirement for full coordinator snapshot production. Plan 02 creates the complete day checkpoint bundle; Plan 04 extends it with active-board, branch, pair-draw, and cross-store fields.

## Plan Digest Manifest

These SHA-256 values bind the reviewed child plans. Hash input is UTF-8 without a BOM after normalizing CRLF and CR line endings to LF.

| Child plan | Canonical SHA-256 |
|---|---|
| `docs/superpowers/plans/2026-08-07-seven-day-flow-00-authority-and-work-tracking.md` | `a547e566d17e4f554e5dae918dbedb38de4524519a3edc4c9642b222bfa78cbf` |
| `docs/superpowers/plans/2026-08-07-seven-day-flow-01-dialogic-contract-and-consolidation.md` | `18522440776fd47ddb7ec36261c168a0587aa137d2d044b7d6d5c6b504c259ee` |
| `docs/superpowers/plans/2026-08-07-seven-day-flow-02-calendar-contacts-schedule-hospital.md` | `904fa1632ac47e4444796dceafd53d36c20bd74fcd7d1dee752120958ceac41c` |
| `docs/superpowers/plans/2026-08-07-seven-day-flow-03-relationship-board-pair.md` | `0b73d1a2ca50fc6a1ba729c294d339c7fa8ae103461da07f360d031cbadfddce` |
| `docs/superpowers/plans/2026-08-07-seven-day-flow-04-persistence-profile-rehearsal.md` | `f924abe2d2c862a204d8f68c98a08a0bdff1e33eec7a8d6cad98c19cc7185241` |
| `docs/superpowers/plans/2026-08-07-seven-day-flow-05-day7-endings-gallery.md` | `df581304383e190db2e970992c1564af279d6c380e355a2cea1776903484624f` |
| `docs/superpowers/plans/2026-08-07-seven-day-flow-06-integration-release-evidence.md` | `b326d72c5a72931e90a3b9295e596161ead5de7c123b426b2e7d8b4db65c4d87` |

## Durable Beads Registration

The user authorized tracking registration on 2026-08-08 without authorizing runtime implementation. The successor epic is `dwm-oyo`; its Phase 00–06 children are `dwm-oyo.1` through `dwm-oyo.7`. They were registered open and unclaimed with the dependency graph in Plan 00. Always query Beads for current mutable status rather than treating this historical registration note as live state.

## Execution Protocol

For every child plan:

- [ ] Confirm its dependencies and current HEAD.
- [ ] Run the named characterization/baseline suite and save the result before editing.
- [ ] Treat every checkbox as one bounded action. If a checkbox cannot be completed and verified in roughly 5–15 minutes, split it into smaller RED, implementation, and GREEN checkboxes before changing code.
- [ ] For each task, run only the exact test files named by that task through `tools/testing/Invoke-IsolatedGodot.ps1`. Record the RED command, nonzero exit, and intended assertion/error code; a parse error, missing dependency, or unrelated failure is not an acceptable RED.
- [ ] Execute one task at a time with the mandated skills named in that plan.
- [ ] Run focused RED and inspect that it fails for the intended missing behavior.
- [ ] Make the smallest implementation that satisfies the task contract.
- [ ] Re-run the same focused command for GREEN and require exit code 0 with the exact named test paths, then run the plan's regression cluster.
- [ ] Ask for a fresh-context review of domain ownership, save compatibility, and spec coverage.
- [ ] Fix all P0/P1 findings or record a genuine external blocker; do not waive them.
- [ ] Run `git diff --check`, inspect staged names/modes, and make the exact task commit if authorized. Stage only the task's enumerated paths with the repository exact-path helper or an explicit `git add -- PATH_A PATH_B` command; broad staging is forbidden.
- [ ] Update the one active Beads issue with evidence only after the commit exists.

## Suite Completion Gate

The suite is implemented only when:

- [ ] all seven child plans are complete and their Beads issues are closed;
- [ ] the exact 13 ending identities, 139 public DTL entries, 18 ordinary replies, 12 solo challenge slots, 2 P–L windows, and 8 master DTL paths validate;
- [ ] old-save migration, same-run irreversible overlay, post-milestone branching, and cross-store crash recovery pass;
- [ ] all public DTL entries start by semantic ID and exact label through the real bridge;
- [ ] the five canonical full-run smokes and accessibility smoke pass;
- [ ] the full GUT suite, import gate, documentation gate, Beads preflight, and static ownership scans pass against one identified commit;
- [ ] no final narrative prose was invented;
- [ ] the user reviews the evidence before any release or merge claim.

## Handoff After Plan Approval

Choose one execution mode only after explicit authorization:

1. **Subagent-driven (recommended):** use `superpowers:subagent-driven-development` with a fresh implementer and reviewer per task.
2. **Inline:** use `superpowers:executing-plans` and stop at every named review/commit boundary.

Plan approval is not runtime authorization unless the user explicitly grants both in the same instruction.
