# DWM story progression implementation handoff

Date: 3 November 2026, Hong Kong time.
Repository: https://github.com/Siuuuers/dwm
Audited master: `87a4153836a2d8d47ce36c423d891fc13c3a769d`.
Status: initial source audit complete; no implementation edits, formal models, test runs, commits, or PRs were made for this mission. The inspected checkout was clean when this handoff was prepared.

## Mission

Consolidate story progression command coordination into explicit states, using TLA+ to check the relevant transition rules. Preserve approved gameplay and the existing canonical story-position owner. Start with one complete, reviewable slice; do not rewrite the entire game or add a second story manager.

First observable outcome:

> One accepted progression command owns its transition until completion. Competing commands cannot duplicate that transition. Completion or an ordinary refusal leaves the next valid action available.

The wider progression goal is to restore the same visible beat without repeating gameplay consequences. Include that goal in this slice only where the changed coordination reaches restoration or persistence.

## User decisions and authority

- Work in the cloud. Prefer Linux for development and focused checks. The game targets Windows; Linux results do not establish native Windows behavior.
- The game is unshipped. Obsolete save compatibility and migrations may be removed when they are in scope. Do not silently erase user files or current progress as a side effect.
- Use explicit state machines where they simplify behavior. The user selected story progression as the first system.
- Remove explanatory comments from first-party code and express behavior through precise names and control flow. Preserve necessary legal notices and machine-consumed directives. Keep indispensable design rationale outside executable code. Repository-wide comment removal and its lint rule are a separate slice; do not mix that mechanical sweep into this behavior change.
- Preserve accessible, approved features unless their removal is explicitly authorized. Permission to remove unused code is not permission to silently remove player-facing behavior.
- Use focused, lightweight verification. Broader tests are justified only by the behavior actually affected.
- Trust shipped content after validation at its owning authoring/build boundary. Do not add speculative defensive layers, injection campaigns, or repeated internal schema validation.
- Preserve existing handling that prevents data loss. Disk-write failures and interrupted saves are ordinary operating conditions. Do not add new elaborate recovery mechanisms without a concrete need.
- Parallel agents and isolated worktrees are authorized. Assign independent investigation or disjoint edits; keep shared owners and integration under one coordinator. Available concurrency is finite.
- PR creation and direct merge are authorized after relevant checks and review. Recheck current master and concurrent work before integrating.
- Continue autonomously through routine choices. Ask only when a genuine product or architecture ambiguity affects correctness. Record skipped work and unverified claims.

## Source findings

Use the audited revision to reproduce these observations. Fetch current master and inspect its changes before editing; this handoff is not proof that the source has stayed unchanged.

| Source | Observed responsibility or evidence |
| --- | --- |
| `scripts/narrative/SoloReadingSession.gd` | Owns `scene_index`, `boundary`, story entry, reading ledger, and `next_operation`. Existing boundaries include `line`, `control`, and `between_entries`; other reading families also use notification state. |
| `scripts/narrative/ReadingTraversalOperation.gd` | Constructs and projects traversal source/destination state. Reuse the existing planning logic where applicable. |
| `autoload/DialogicBridge.gd` | Coordinates command admission, playback, acknowledgement, Next, Auto, Skip, and restoration. This is the first consolidation target. |
| `autoload/GameState.gd` | Owns scene decisions and gameplay consequences; includes registered marker advancement. Do not duplicate choices or challenge outcomes in the bridge. |
| `docs/design/2026-10-25-current-scene-state.md` | Specifies current-state ownership, no earlier-save migration requirement, and destination/consequence save semantics. |

Read root `AGENTS.md`, `CLAUDE.md`, applicable nested instructions, and current technical owners before implementation. Follow the root router for any narrative document changes. Historical proposals are evidence of history, not automatic current requirements.

The current Scene document already says that Load restores the full caption, board, choices, outcomes, and values without replaying prior actions. It also separates global reading/Gallery progress from Run state. Do not replace these rules with assumptions from old transaction documents.

PR #175 is already merged: https://github.com/Siuuuers/dwm/pull/175
It preserves the self-talk frame, displays the current thought, preserves thoughts through reveal completion, and places earlier thoughts in History. Do not redo or regress this work.

## First target and the important trap

Inspect these functions and every caller before editing:

- `can_next_current_line`, `request_next`, `_perform_next`, `_perform_caption_next`, `_finish_next`.
- `can_auto_advance_current_line`, `request_auto_step`, `_auto_line_context`.
- `request_skip_step`, `_perform_skip_step`.
- `acknowledge_current_line_presentation`, `_acknowledge_next_source`.
- `request_scene_marker_step` and ordinary manual input entry points.

The bridge repeatedly combines `_next_admitting`, `_next_active`, `_auto_step_in_progress`, `_skip_step_in_progress`, and `_line_ack_in_progress`.

These are not all mutually exclusive by accident. Next can acknowledge its source within an admitted operation. Skip reveals, acknowledges, then evaluates whether it should advance. A single flat `Busy` enum that refuses all nested acknowledgement would break legitimate behavior.

Build a transition table from actual call paths first. Represent an outer command and its necessary internal phases explicitly, without introducing more independently mutable state than the behavior requires. The final state names and representation must follow that investigation; this handoff does not prescribe an unverified enum.

Keep the command's temporary execution phase separate from the durable story cursor. Preserve differences between ordinary advance, explicit Next traversal, Auto, and Skip. Sharing coordination does not mean making their progression semantics identical.

## Execution sequence

1. Pin the current master SHA. Inspect open PRs and changed relevant owners. Fetch source without unnecessary historical assets. Reuse an available checkout only after checking its state.
2. Trace command admission, internal acknowledgement, runtime callbacks, success, refusal, and cleanup. List affected callers, fixtures, tests, configuration, and public inventory consumers. Include scene/signal connections, not only textual function calls.
3. Write a small transition table and concrete failure list. Start with competing requests for the same caption, stale Auto callbacks, valid nested acknowledgement, and cleanup on ordinary refusal. Distinguish demonstrated mechanisms from hypothetical failures.
4. Create a bounded TLA+ model of the selected coordination protocol. Keep story content abstract and small. Use the existing toolchain if present; otherwise choose the minimum pinned model-checker setup. Do not add a framework to the game.
5. Consolidate the existing bridge coordination. Preserve story position, traversal planning, and gameplay consequence owners. Remove replaced flags/branches only after all callers are migrated. Avoid a generic event bus, manager hierarchy, or event-sourced save rewrite.
6. Complete independent caller and test reviews, then run one coherent focused acceptance set. Early diagnostic runs are appropriate when they resolve an uncertainty.
7. Open a scoped PR, report exact validation and limitations, and merge after relevant checks and review. Keep the model and implementation mapping in the same reviewed slice.

## Model and implementation evidence

TLA+ verifies the modeled behavior under its chosen constants and assumptions. It does not automatically verify Godot code, rendering, or arbitrary system sizes. Record the mapping from model actions to real functions and the finite bounds used.

Candidate properties, refined against the actual transition table:

- At most one outer progression command owns a transition at a time.
- Internal acknowledgement is allowed only in the phases that require it.
- One accepted source transition cannot apply its destination twice.
- A blocked choice, control, or dissolve boundary cannot be crossed by an inadmissible command.
- A request tied to an obsolete visible source cannot advance a replacement source.
- Successful completion and ordinary refusal release temporary ownership.

Check reachability of meaningful states so a model that permits no progress cannot pass vacuously. If asserting eventual completion, state callback and storage assumptions explicitly; a missing external completion cannot be wished away with fairness. Intentional terminal or failure states must be distinguished from deadlocks.

## Focused acceptance

Select existing tests by their bodies and changed behavior, not filenames alone. Candidate starting points are:

- `tests/integration/test_dialogic_next_traversal.gd`
- `tests/integration/test_scene_next_notification.gd`
- `tests/integration/test_scene_day_reading.gd`
- `tests/unit/test_solo_reading_session.gd`
- `tests/ui/render_scene_transition_base.gd`

These are candidates, not a mandate to run every suite or proof that each targets the current production path. Some cover legacy families or adversarial fixtures. Inspect and choose relevant cases; add no new injection campaign.

Required evidence for the selected implementation:

| Boundary changed | Evidence |
| --- | --- |
| Command admission and phases | TLC result with bounds/properties plus focused executable transition tests, including valid nested acknowledgement and competing requests |
| Connected native playback | One representative journey exercising the affected manual/Auto/Skip paths and a control stop; confirm self-talk changes only on actual departure |
| Persistence or restore coordination, if touched | Focused fresh-process Save/Load check showing the same beat and no repeated consequence |
| Input or visible transition behavior, if touched | Relevant mounted/rendered input check, including blocked advancement during dissolve |

The initial shared-owner consolidation needs more evidence than a later isolated amendment. Do not delete relevant regression coverage merely because TLC passes. Avoid full language/font matrices, full-week journeys, shop tests, Windows export, or unrelated workflows unless the actual diff reaches their protected behavior. Update coverage selection only when necessary and check the selector itself if modified.

No performance claim follows from fewer flags, shorter files, or an enum. If claiming a speedup, compare the same complete operation before/after, including relevant cold/warm conditions. Otherwise report maintainability and coordination changes only.

## Completion and reporting

Done means the selected production coordination path uses explicit, reviewed phases; replaced flags and callers are removed or migrated; the bounded model passes; relevant implementation checks pass; and the PR records the model/code mapping and limitations.

Report the base and final SHAs, changed behavior, removed code, selected tests and outcomes, TLC bounds/results, remaining risks, skipped tests with reasons, and PR/merge links. Do not claim Windows qualification or performance improvement without evidence.

Stop and ask only if preserving current behavior requires choosing between conflicting product rules, an apparently dead path is still player-accessible, or a proposed change would lose current data beyond the agreed compatibility scope. A failed check is a debugging task, not automatically a design question.

## Deferred missions

Repository-wide comment removal and a syntax-aware comment lint rule; broader obsolete-code deletion; save-format surgery; challenge internals; shop/audio/layout changes; wider CI restructuring; and formal models for other systems. Do not bundle them into this first progression PR.

## Prompt for the next conversation

Implement this DWM story progression handoff. First recheck current master and related open work. Start with the existing DialogicBridge command coordination, preserve SoloReadingSession as the story-position owner, and model legitimate nested acknowledgement before replacing flags. Use TLA+ plus focused implementation checks. Work in the cloud, delegate independent audits where useful, and finish the scoped PR through merge when checks pass. Preserve approved player behavior; ask only about a concrete blocking design ambiguity. Report exactly what changed, what passed, and what was skipped. This handoff records planning and source audit only, not an already implemented change.