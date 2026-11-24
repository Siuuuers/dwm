# Retired unused private helpers

Baseline: `164da0e3006de5dd1257788c352d7d42a0f36a9c` (2026-11-03).
This is a bounded implementation cleanup, not retirement of Contacts, day
resolution, identity allocation, or any player-facing feature.

| Removed function | Former purpose | Why removal preserves the current flow |
|---|---|---|
| `ContactInvitationState._find_exact_message_any_friend` | Searched every friend for a message matching its ID, child transaction and sequence. | No callers. The used `_find_exact_message` lookup receives the friend explicitly and remains intact. |
| `GameStateDayResolutionPort._active_commit_receipt_id` | Read the schedule commit receipt ID from the active resolution plan, or returned null. | No callers. Current resolution and ending paths read their required plan/receipt data directly. |
| `DesktopIssuerRootStore._day_advance_candidate_from` | Built an older detached day-advance candidate from a request, root namespace and counter. | No callers. `prepare_causal_day_advance` uses `_day_advance_candidate`; current commit validation and persistence remain intact. |

The exact removed implementations remain available at the baseline revision in
`scripts/domain/contact/ContactInvitationState.gd`,
`scripts/application/run/GameStateDayResolutionPort.gd`, and
`scripts/infrastructure/identity/DesktopIssuerRootStore.gd`.

## Audit and scope

Before deletion, the executable-source and configuration search found only
each definition. That search included script calls, string-based calls, scenes,
resources, tests and tools. Historical logs still mention two symbol names;
those immutable execution records are retained and are not callers. These are private helpers, not Godot lifecycle
callbacks or saved fields. None is registered as a signal callback. The active
paths named above remain. No saved-data migration or deletion is required.

Explanatory comments are removed only from these three files. Legal notices
and machine directives are exempt. The existing external design records remain
the source for rationale. In particular, the identity store's public parameter
names remain unchanged because its public-surface contract includes them.

Inside `_receipts_from_specs`, local names now distinguish `next_counter`,
`issued_receipts`, and `receipt_spec`. Serialized keys, public signatures,
validation and error handling are unchanged. This is a readability change;
no runtime speed improvement is claimed.

## Verification boundary

Compare the remaining executable tokens against the baseline after removing
the three named declarations and normalizing only the three local renames.
Require identical string literals, operators, indentation and remaining names.
Run the existing comment-lint tests and check the diff for whitespace errors.
Cloud CI results belong to the PR; this record does not claim an engine run.

Other candidates remain unapproved until their callers, Godot references and
current behavior have been reviewed. This is not a repository-wide dead-code
or comment-cleanup completion claim.

## Prepared New Game commit

At `a1679544`, SaveManager's private `_commit_prepared_new_run` started the configured Title scene. Its two public callers now share one implementation. Consent retains the single-use token. The configured target and context already belong to SaveManager.

## Initial reading checkpoint

At `2c3b208`, DialogicBridge passed a null reading session through its private `_build_scene_initial_checkpoint` wrapper. Every caller built a fresh session. At that point the public builder reconstructed the scene directly. By `86c50e5`, New Game supplied the current scene to `_build_current_scene_initial_checkpoint`, leaving the receipt-based public builder without callers. It was removed.

## Save recovery dispatch

At `8bcefb84`, both retry entry points reached the same synchronous scene recovery. The private resume wrapper discarded the frame-yield flag. Both autosave/profile settlement callers passed false. The responsive entry point now delegates to the ordinary retry, and reconciliation uses the transaction ID directly after skipping retired load records. Journal conflict checks still precede the first custody or storage mutation.

## Title New Game dispatch

At `bf7827d8`, the responsive commit and retry methods forwarded directly to their synchronous counterparts. Title now calls those owners directly after presenting the busy state. Both aliases had a single production caller and held no saved data.

## Title preparation context

At `a0d2a0e6`, Title supplied five fixed fields to prepare New Game consent. SaveManager discarded them after validation. Commit already uses the registered scene target and its content version. Consent reads the live run and autosave, and its token carries no serialized game data.

## Window startup, Load audio and Title confirmation

At `c1d72301`, window initialization and Load audio copied the entire Global profile to read one preferences group each. Each now receives its own detached group. Window application uses the selected size directly, and its physical output target comes from a fresh capture. New Game consent had identical live-run and autosave messages in all five languages, so Title uses one body per language.

## Starting a Challenge absent from the selected save

The October 26 Load decision assigns Challenge boards and attempt progress to the selected Run. It supersedes the October 9 proposal to reconstruct an absent board from a prior Global attempt. The unbound Profile validator and its transient `start_from_absence` command were removed. Version 5 Profile migration still initializes an empty Dating ledger. Version 6 migration retains recorded attempt progress and receipts. [October 26 decision and implemented behavior](../../../handoff/ai-direct-load-and-settings-back-20261026.md)
