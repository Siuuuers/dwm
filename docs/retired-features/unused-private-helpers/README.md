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
