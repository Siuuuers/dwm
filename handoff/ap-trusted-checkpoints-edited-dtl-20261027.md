# Trusted checkpoints and edited DTL

Date: 2026-10-27, Hong Kong time.
Status: User-approved behavior and next-work instructions. Runtime implementation is pending.

## Scope and precedence

Continue [ao](ao-checkpoint-projection-20261027.md).
This amendment supersedes the earlier instruction to keep all schema-5 refusal behavior.
It also replaces the earlier general nonblocking error-and-skip proposal for manually edited DTL.
Keep the accepted PR 124 evidence in ao. This document does not claim a new runtime result.

## Observable outcome

Show the correct dialogue and art promptly.
Save and Load must preserve the intended reading position, choices and encountered History.
Trust shipped content and correctly constructed internal state.
Handle an unresolved reference when Load or execution needs that reference.
Do not scan all DTL files to detect edits.

## Approved edited-DTL behavior

| Condition | Required behavior |
| --- | --- |
| The saved dialogue ID resolves and the edited content works. | Continue normally. A wording change alone must not prevent Load. |
| The saved dialogue ID resolves, but its choice is invalid. | Ignore the invalid choice and follow the passage's authored default route. |
| The saved dialogue ID does not resolve. | Show an error that identifies the missing ID. Wait for Quit. |
| The required default route does not resolve. | Show a specific error. Wait for Quit. Do not invent another route. |
| Another DTL error prevents continuation. | Show a specific error. Wait for Quit. |

Keep the error visible until the player selects **Quit**. Then close the game.
Do not save the failed state or overwrite the existing save because of the failure.
Apply the dialogue-ID rule to identity resolution, not text equality.
Do not reject an edit only because a file changed.
The default-route exception applies to an invalid choice when the saved dialogue ID still resolves.
There is no general instruction to skip arbitrary broken dialogue, art or control commands.

## Checkpoint simplification direction

A checkpoint is a record of the state needed to resume.
Projection is a representation conversion. It is not a required saving mechanism by itself.

The inspected implementation uses schema 5 for full live reading state and schema 7 for compact saved reading state.
The current compact-input projection restores a session, captures expanded state, projects it to compact state, and restores that result again.
Audit callers before changing this path. Check whether a caller needs conversion, comparison or actual restoration.

Prefer direct construction from the authoritative reading-session state.
Keep each necessary fact with one owner.
Retain the IDs, progress and presentation information needed for correct restoration.
Do not assume that one dialogue ID alone can replace choices, encountered History or held-action state.
Do not retain a field only because an old format contains it.

Remove repeated validation of trusted internal values where the owner already guarantees them.
Do not restore a temporary reading session only to prove the same guarantee again.
Keep required file decoding, the agreed save-format version handling and reference resolution at their owning boundaries.
Deleting a refusal does not implement recovery. Handle a failed lookup before code uses the missing value.

Old negative tests do not make every internal refusal a permanent product requirement.
Revise tests when an approved behavior changes.
Keep evidence that normal saves restore correctly and that failed DTL continuation cannot write a failed state.
Do not delete unrelated storage behavior without a caller review and a concrete player-outcome reason.

## Next work and acceptance

1. Read current master and the relevant owners. Check for work already completed.
2. State one observable result before editing.
3. Trace checkpoint construction, comparison and restoration separately.
4. Remove unnecessary reconstruction or validation with the smallest suitable change.
5. Implement edited-DTL behavior at the responsible Load or execution boundary.
6. Complete compatible caller and test reviews before final acceptance.
7. Run Godot and exported-game tests in the cloud only.

Use focused tests for choice fallback and ID resolution.
Use integration tests for Save/Load ownership and preservation of existing saves after failure.
Use a rendered journey to verify that the error remains visible, Quit closes the game, and a valid default route continues correctly.
Cover an unchanged ID with changed text, an invalid choice with a valid default, a missing saved ID, and an invalid default route.
Keep ordinary reading, History, choices, art and subsequent Save/Autosave coverage.

Measure the complete passage transition before accepting a performance claim.
Use matched baseline and candidate runs with the same observer.
Do not add inclusive nested timings together.
Use ao's accepted measurements as historical evidence, not a substitute for a new matched comparison.

## Handoff state

No blocking product question remains from this discussion.
This update changes documentation only.
The approved fallback and error/Quit behavior still require implementation and cloud verification.
