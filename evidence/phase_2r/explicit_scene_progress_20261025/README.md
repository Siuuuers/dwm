# Explicit Scene progress — 25 October 2026

## Outcome and ownership

GameState stores resolved opportunities as `scene_choices[opportunity_id] = choice`.
It stores completed Challenge occurrences as
`scene_challenge_outcomes[challenge_occurrence] = {challenge_id, outcome}`.
The existing result supplies each value. Missing is distinct from `never_started`.
Separate occurrences of one Challenge are preserved; there is no last-write-wins
reinterpretation of ambiguous recall.

The detached save candidate carries facts and receipts together. Live adoption
follows successful persistence and existing source/lease checks. Current saves
require these maps; older development saves are deliberately unsupported.
Restore, reset, cold compensation and live backup preserve their ownership and
copy boundaries. SceneHost reads choice presence directly instead of copying
all current state and scanning command history every UI refresh.

This is groundwork for compact restoration, not a ledger-free save format.
Existing recall provenance, transition retry, board settlement and native
reading admission still use historical receipts. The existing authenticated
semantic traversal checks facts against receipts until those consumers are
replaced. No performance measurement or speedup is claimed.

## Diagnostic qualification

Six independent Linux cloud/headless Godot 4.6.3 processes passed 41 cases with
606 testcase assertions, plus three fixture setup assertions. Retained JUnit
reports and source hashes are under `linux/`.

Coverage includes schema shapes, missing versus never-started, distinct Challenge
occurrences, receipt/fact mismatch refusal, cold rollback, detached live backups,
registered choice semantics, and all five outcome classifications. An initial
combined diagnostic run mixed incompatible registration fixtures; it is
superseded by these isolated runs. Its new live-backup test also incorrectly
expected silence from an existing notifying API; that assertion was removed,
without changing production notification behavior.

Rendered Windows create/fresh-process Load qualification is pending. The two
new CI matrix selections reuse the existing multiple-thought and Challenge-recall
journeys. Connected recall exercises `never_started`; the five outcomes are
unit-qualified, not five rendered save/load journeys.
