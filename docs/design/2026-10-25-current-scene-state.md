# Current Scene state — 25 October 2026

## Approved result

Load restores the exact full caption, current board, selected choices, Challenge
outcomes and gameplay values. It does not replay prior gameplay actions.
Earlier development saves need no migration. Reject incompatible required state.

Start makes a Challenge available. Finish resolves never-started, unfinished,
won, lost or perfect and enters the corresponding registered dialogue. The
internal `won` value is the player's solved result. Perfect takes precedence
where registered. Keep the exact active board and required reward/counter state.

All selected choices remain in the Run. Current entry and stable caption locate
progress after branches converge. Resolve a branch only when all its inputs are
known; do not precompute a future Challenge result. Existing choices/outcomes
and the installed reading catalogue own current-day History.

## Single current-state owner

The Scene section contains registration identity, current occurrence, current
entry, notification, current Challenge descriptor and an optional Contacts
return frame. Board and attempt data remain with their existing physical owners.
Choices and outcomes remain in gameplay. Do not duplicate them in Scene.

The current Challenge descriptor contains its registered Challenge ID and stable
playable identity. Derive the physical command from these current facts. Do not
construct historical receipts to satisfy old validators.

Contacts keeps its behavior, message data, invitation rules and UI. The owner
explicitly approved adapting only its shared Scene return bookkeeping. Store one
parent frame, with its registered return target. Nested Contacts remain refused.
Retain the closed board through Contacts as before.

## Save transaction

For choices, recalls, Contacts and Challenge Finish, prepare the destination and
consequences before the durable Run write. Save them together. Adopt the native
destination only after success. A failed write leaves the source and an exact
live retry candidate. A changed choice cannot silently commit the older choice.
After a successful write, fresh Load restores the destination directly.

The current Run file omits command receipts and applied transaction-ID arrays.
Live retries and rollback retain transient operation state. Load starts a fresh
live retry session. Safe writes and exact selected-file revision checks remain.

Physical Profile writes and Run writes are separate operations. Preserve active
attempt references and Load branch allocation so a selected earlier board is
not replaced by newer Profile progress. Validate current physical facts, not
all historical closures. Global reading and Gallery records never rewind.

## Ordinary passage completion

The owner approved converting the existing umbrella block in Day7, entry
`ending.alone.normal`, into ordinary Scene playback. Preserve its 22 captions and
line IDs exactly. Passive Start precedes `.001`; Finish follows `.022`.
`passage.umbrella` identifies this complete block. Finish unlocks Gallery and
returns to title. This bounded conversion does not author the planned second
ending or change other route rules.

Completed lifecycle plus the registered final caption defines completion. No
separate ending plan, retained source checkpoint or ending selector is needed.
Profile-first Finish write and safe retry remain; Gallery replay is read-only.

## Qualification

PR #97 contains the coordinated candidate. Cloud native generation must produce
registration and API inventories before final acceptance. Import, unit,
integration, rendered fresh-process Load and exported-startup checks must pass.
A smaller file or less historical validation does not establish a speedup.
No local Godot test qualifies this change.
