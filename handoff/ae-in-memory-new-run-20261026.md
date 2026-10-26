# AE: In-memory New Run and assignment retirement

Date: 2026-10-26 (Hong Kong).
Status: approved direction and completed read-only audit. Runtime implementation is pending.

## Start here

Read AGENTS.md, CLAUDE.md, and the applicable owners. Check current master and open PRs before editing.

Inspected master: `ff5b327a5433867f33c85644e3173d15cdef01d0`.
Design/archive branch: `codex/new-run-design-20261026`.
Design/archive commit: `5edf5b2bbf301a4261fee5deaa177941fdf1397b`.
That branch contains documentation and archived source only. Do not report its direction as implemented.

Read the [decision record](../docs/retired-features/new-run-assignment/README.md).
The [archived PairDeckDraw source](../docs/retired-features/new-run-assignment/PairDeckDraw.gd.txt) is byte-identical to the inspected master. It is non-executable historical material. Windows exports exclude docs/.
The story owner has a scoped amendment in `story/09-priscilla-foundation-amendment.md` on the design branch.

## Observable outcome

New Acc starts at the same authored Day 1 entry, from fresh mutable defaults, without writing an initial Autosave or drawing a Sweet/Dark assignment. Player preferences and global progress remain intact. A later normal save and Load restore the current run and visible beat.

SaveManager currently coordinates creation. GameState owns gameplay defaults. The manifest owns the authored first target. Profile owns preferences and global progress. Reuse these responsibilities. Do not add another manager without a concrete need.

Evidence: matched cloud Windows click-to-first-complete-caption measurements, and automatic tests of the connected player journey. Fewer lines or a template copy alone do not prove a speed improvement.

## Owner decisions

- Prioritize reading speed and normal gameplay.
- Trust the shipped story content. Check authored content during the build/test process, not repeatedly during reading.
- Defer manually edited content handling. Do not build more external-tampering checks.
- Remove the initial Autosave requirement for New Run.
- Do not recover interrupted New Run creation. The player can start another run.
- Keep the New Run template separate from player settings.
- Temporarily retire run-level Sweet/Dark assignment. Preserve documents and related source for possible future work.
- Start every run at the same authored entry. Choices and Challenge results determine subsequent progression.
- Preserve ordinary save/load and gameplay correctness. This decision does not retire saving later progress.
- Use cloud-only Godot/Windows execution. Local source inspection and static/Python checks are acceptable.
- Parallel investigations, isolated worktrees and direct PR merges are authorized. One coordinator owns integration and publication.
- Ask only for a material unresolved design decision. Do not ask the owner to reapprove the decisions above.

Working recommendation, not an explicit owner answer: leave the previous Autosave unchanged until a later real save replaces it. Do not delete it merely because New Run starts. This is the non-destructive default.

The exact save-trigger inventory still needs a caller audit. Logout and session-exit paths exist, as do a gameplay autosave caller and deferred-save paths. Do not state that only logout/day advance save without checking all callers.

## What needs fresh state

| Item | Current implementation | Simplification direction |
|---|---|---|
| Run identity | Fresh run ID plus issuer receipt | Retain a fresh run identity; assess durability machinery separately |
| Branch identity | Fresh branch ID and receipt | Trace save/load consumers before removing or deriving |
| Day identity | Fresh causal-day ID and receipt | Trace day and board consumers before removing or deriving |
| Desktop generation | Constant zero, with issued receipt | Value is a default; receipt may become unnecessary |
| Creation transaction | Durable issuance before allocation | No longer justified by interrupted-creation recovery alone |
| Initial occurrence/playback/admission | Reuse creation transaction | These are not separate random draws |
| Initial checkpoint | run ID plus `:1`, sequence 1 | Derive if still needed |
| Gameplay | Small literal constructor with fresh containers | Keep a single default owner |
| Board RNG | Starts at zero | Generate a board only when needed |
| Assignment nonce | Four random bytes for first form, later alternation | Remove with assignment |
| Save document/time/hashes | Built during New Run | Create at a real save point |
| Settings/global progress | Existing profile | Preserve; exclude from pristine run template |

`GameState.make_scene_new_run_gameplay` starts at line 4224 in the inspected revision. It supplies money/counters zero, empty inventory/choices/outcomes, rounds left 2 and pressure 3.

Current first target is already `target.Day1`, independent of Sweet/Dark.
`ApplicationBootstrap` reads `DialogicEntryManifest.first_target_id()`.
The manifest currently reads `tests/templates/scene_sequence/seven_day_order.json`. Despite that directory name, this is production input. Keep one owner for the start reference; do not create a second competing definition.

Share immutable story definitions. Give each run its own mutable containers. A small constructor can be as suitable as copying a template. Measure the complete operation.

## Confirmed active overhead

1. `SaveManager._prepare_scene_new_run_decision` (line 567) prepares participant plans at line 602 and discards their values. `_resume_scene_new_run` (line 656) prepares them again at line 673.
2. `prepare_new_run_action` and `_commit_prepared_new_run` call legacy `ProfileManager.prepare_new_run_consumption` at lines 761 and 832. This reads/validates Profile, constructs a legacy preference-consumption candidate, serializes and hashes it. The scene branch then prepares a different scene-assignment profile. The earlier candidate currently provides baseline/staleness checks, not the final scene creation content.
3. `_prepare_scene_new_run_decision` builds and serializes an Autosave document at lines 604-616. `_resume_scene_new_run` parses that text again at line 670 to obtain the live snapshot.
4. `_settle_new_run_pair` (line 1124) coordinates allocation, Autosave and Profile persistence/proof. “Pair” means Autosave/Profile, not story characters. It also has a dynamic startup-recovery caller near line 1020.
5. `_validate_scene_creation_chronology` (line 3331) walks successful creations and proves profile assignments. Assignment retirement removes its story purpose.

These functions are active, not dead. The new contract permits their removal or simplification as a coherent change.

## Critical coupling

`scene_assignment` is both assignment data and a discriminator for the scene-based runtime. Deleting only the field breaks behavior.

- GameState checks its presence around lines 653, 842, 3032, 3326, 3407, 4064, 4084, 4121, 5637 and 5906.
- ApplicationBootstrap checks it around lines 953 and 2565.
- RunLifecycle scene admission/ending paths require it.
- GameState around line 3288 derives `dark_mode` from its form.
- RunSnapshotSchema validates it.
- SceneEventContract embeds its hash and ties it to initial admission.
- GameState snapshot validation compares it with the Profile assignment ledger.

Replace runtime-family discrimination with the appropriate existing authoritative scene/lifecycle fact. Do not preserve a fabricated Sweet/Dark assignment to satisfy old checks. Trace real consumers of dark_mode. Preserve local Challenge variations and authored choice branches.

Existing saved fields and Load callers need coherent treatment. Do not reset or strand saved progress simply to make the new schema pass.

## Unused-code audit limits

`SaveManager.start_new_run` (line 908) has no ordinary product caller found in the inspected runtime directories. Title uses `prepare_new_run_action`. Tests still call the legacy method, sometimes dynamically. Its fallback remains reachable without a configured scene target. This is a legacy/test-path candidate, not proven globally dead code.

Check dynamic calls, signals, injected participants, scene resources and tests before deletion. This was a focused New Run audit, not an exhaustive whole-repository audit. Do not remove every old .tscn based on this report.

There are 32 project .tscn files under scenes/ at the inspected revision, including UI components. A .tscn is a node-tree definition, not a story entry. Many entries use one SceneHost. A template does not itself reset the live node tree, dialogue cursor, audio or gameplay state.

## Implementation sequence

1. Reconcile current master with this branch and the story-owner amendment.
2. Trace scene-assignment discrimination and the normal save/load consumers together. Establish the replacement scene-runtime fact.
3. Use the existing default owner and canonical authored first target. Create fresh mutable state once.
4. Remove assignment generation/profile consumption from New Run. Remove the now-unneeded chronology/nonce/proof work.
5. Remove initial Autosave and creation-recovery work from this path. Pass in-memory state directly to activation. Avoid serializing solely to parse the result again.
6. Simplify duplicate plans and legacy preparation. Retain only live initialization work that still has a purpose.
7. Update normal save/load and relevant tests together. Remove tests of retired creation-recovery promises rather than preserving obsolete machinery to satisfy them.
8. Finish independent caller/test reviews, run cloud acceptance tests, and measure against the same baseline. Merge only the verified candidate.

Do not broaden into startup renderer/font changes in the same candidate. Independent read-only investigations can run while cloud tests execute.

## Ordinary behavior to verify

- Fresh New Acc and New Acc with a previous save reach the same authored start.
- Starting does not write/replace Autosave or reset preferences/unlocks/read history.
- Two sequential New Runs do not share mutable inventory, flags or reading state.
- Opening audio/background comes from the authored entry and behaves correctly.
- Choices, Challenge activation/results, inventory and day advance still work.
- Normal logout saves the new run; subsequent Load restores it without replaying consequences.
- Existing saved progress remains usable under the selected save changes.
- Apply the exact approved confirmation sentence below. Preserve all other UI wording and placement; do not add save-explanation copy.

These are normal player journeys. No new injected-crash or external-tampering test program is requested.

## Prior merged performance work

PR #110 is merged:
https://github.com/Siuuuers/dwm/pull/110

Tested candidate: `baa4b41cf5c852c144a9537150763462dcc73995`.
Merged master: `ff5b327a5433867f33c85644e3173d15cdef01d0`.
Their product trees match.

Windows acceptance run: `40285967588`, successful.
Matched comparison run: `40285967600`, attempt 2, successful: 24 processes and 64 screenshot hashes.

Matched medians:
- Fresh New Acc: 14.6380555 s to 6.428032 s.
- Retained New Acc: 15.149381 s to 6.5418865 s.
- Load: 7.701106 s to 3.150288 s.

These measure the previous trusted-runtime change, not this proposed New Run simplification.
Do not add nested phase times or claim savings before measurement.

One prior attempt on the same candidate emitted an intermittent shutdown resource warning after the caption completed. The unchanged rerun passed. Cause remains unresolved; do not claim it was fixed or suppress it.

[Prior results and next investigations](https://github.com/Siuuuers/dwm/blob/c56162334b7c20da22d39509a598333e0c0ab06b/handoff/ad-trusted-runtime-performance-results-20261026.md).
[Raw evidence and report](https://github.com/Siuuuers/dwm/blob/c56162334b7c20da22d39509a598333e0c0ab06b/evidence/phase_2r/trusted_runtime_20261026/README.md).

The evidence branch is separate. Do not merge raw evidence as a product change.

## Session boundary

A new session is useful now: the prior performance batch is merged, the replacement design is recorded, and implementation can start from one clear outcome. Use this handoff and the pinned design record. Do not repeat the old design interview.

This handoff changes documentation only. No runtime removal, new cloud test result or further speedup is claimed.

## Follow-up: confirmation and template ownership

Final owner approval, 2026-10-26: retain the New Acc confirmation. Change only its existing message sentence to this exact text:

> The beginning is still here. Shall we enter again?

Keep all other UI wording, button labels, placement and layout unchanged. Do not add the previously suggested save-explanation sentence or rename the buttons. This final instruction supersedes the earlier copy recommendations. Runtime UI changes remain pending.

The owner also approved the minimal lookup and template ownership described below. No further interview is required for that design.

Approved template ownership and lookup:
- Reuse GameState.make_scene_new_run_gameplay for fresh mutable gameplay defaults. Do not create a settings clone or a generic template manager.
- Keep starting-content selection with DialogicEntryManifest and its canonical authored data.
- Currently first_target_id reads the first day binding from seven_day_order.json. target.Day1 resolves in scene_story_registration.json to entry_id Day1 and label Day1.
- Therefore one stable start-target reference is sufficient at the top level. Its existing target mapping resolves entry/label and the entry manifest resolves the localized source. Do not duplicate a caption ID, DTL path, music, background and settings in the New Run template.
- A start entry/label is preferable to a first displayed-caption ID: entry initialization must establish presentation before the first visible line. The exact refactor must preserve current first-caption behavior and apply required opening commands/state.
- Background, portraits, music and transitions belong to authored content/presentation definitions. Use existing prepared lookups; add no competing asset map solely on an unmeasured speed assumption.
- Keep manifest version/fingerprint metadata under its current owner rather than copying it into author-maintained start defaults.
- A physical relocation of production story-order data out of tests/templates is optional cleanup, not a prerequisite or measured speed improvement.

The confirmation sentence and minimal lookup design are owner-approved. The runtime has not yet been changed. Physical file relocation remains optional cleanup.
