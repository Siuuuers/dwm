---
id: req_packet.schedule
kind: requirement_packet
schema_version: 1
specification_status: approved
beads: ["dwm-p2r.7","dwm-p2r.12","dwm-wks","dwm-p2r.13","dwm-p2r.14","dwm-p2r.15","dwm-p2r.16","dwm-oyo.3"]
requirements:
  - {"id":"req.schedule.state_models","depends_on":["req.runtime.commands_signals"],"implementation_evidence":[],"verification_evidence":[]}
  - {"id":"req.schedule.action_registry","depends_on":["req.runtime.sole_owners"],"implementation_evidence":[],"verification_evidence":[]}
  - {"id":"req.schedule.validation","depends_on":["req.schedule.state_models","req.schedule.action_registry","req.invitation.group_resolution"],"implementation_evidence":[],"verification_evidence":[]}
  - {"id":"req.schedule.done_commit","depends_on":["req.schedule.validation","req.runtime.game_state_facade","req.run.lifecycle_states"],"implementation_evidence":[],"verification_evidence":[]}
  - {"id":"req.schedule.day7_provenance","depends_on":["req.schedule.done_commit","req.invitation.solo"],"implementation_evidence":[],"verification_evidence":[]}
  - {"id":"req.schedule.warning_queue","depends_on":["req.schedule.state_models","req.contact.history_watermark","req.minesweeper.round_contract"],"implementation_evidence":[],"verification_evidence":[]}
  - {"id":"req.schedule.done_board_fate","depends_on":["req.schedule.done_commit","req.minesweeper.causal_departure"],"implementation_evidence":[],"verification_evidence":[]}
---

# req_packet.schedule

Approved 2026-08-11 by `decision.schedule_commit_model`, refining the accepted desktop, Minesweeper, Shop, and Schedule amendment without authorizing runtime implementation.

## Rule req.schedule.state_models

Schedule MUST keep two detached models. The saved, uncommitted ScheduleView has exactly `{day, causal_day_instance, entries, date_entry_seen, pending_warning, consumed_warning_receipts, condition_departure_receipts}`; each draft entry has exactly `{draft_entry_id, day, slot_index, action_id, action_kind, participants, source_receipt_id}`. `condition_departure_receipts` is a saved append-only recovery ledger keyed by source condition receipt ID. It is excluded from the optimistic editable-view fingerprint, survives day replacement, and makes a condition-driven departure byte-idempotent after pending-transaction cleanup or later view progression; an identical key reuses the exact receipt and changed bytes fail closed. A condition-departure receipt proves only the idempotent replacement of the uncommitted view: it is not a Schedule commit, does not make a draft entry scheduled, and cannot serve as Hospital source proof. Each canonical committed entry has exactly `{schedule_entry_id, schedule_entry_provenance, day, slot_index, action_id, action_kind, participants, source_receipt_id, commit_transaction_id, state:"committed"}`. The provenance MUST validate as a deterministic child of the ledger-verified Done transaction. Route, effects, and motivation cost MUST NOT appear as caller- or save-authoritative entry facts.

## Rule req.schedule.action_registry

One immutable, versioned action registry MUST bind every `action_id` to its allowed day or window, kind, canonical participants, repeatability, motivation cost, route, effects, and source-receipt class. A changed contract MUST use a new action ID or registry version; caller dictionaries, naming conventions, and restored entry payloads MUST NOT redefine those facts.

## Rule req.schedule.validation

The same fail-closed rules MUST validate draft candidates, whole drafts, committed state, route projection, and restore. Days 1 through 6 allow at most seven entries and at most two date entries in audience-chosen slot order; there is no Day-4 Priscilla slot rule. Training, Working, and Rest MAY repeat when represented by distinct draft entries. The Priscilla-Lavinia group has canonical participants `["priscilla","lavinia"]`, supersedes its corresponding solo offers, and cannot coexist with them. Day 7 is empty or contains one eligible solo destination at slot zero. Candidate success MUST imply whole-state validity.

## Rule req.schedule.done_commit

Adding, removing, or reordering draft entries MUST spend and reserve no motivation. Home, app switching, Save, Logout, and same-day reopening MUST preserve the draft. Successful Done is the only operation that MAY atomically validate the current draft, charge exactly one motivation per committed entry, create detached committed entries, and freeze their real order into day resolution. An immediate post-Minesweeper/Shop condition Hospital MUST NOT invoke this operation, mint a Done or commit receipt, charge motivation, synthesize an empty Schedule, or reinterpret the draft; closing or replacing its departed-day view is not a commit. Any failure MUST preserve motivation, canonical state, and the draft; duplicate delivery MUST return the original receipt without reapplying effects.

## Rule req.schedule.day7_provenance

A Day-7 destination MUST prove the layered chain `eligible offer -> acceptance/read receipt -> Schedule commit receipt -> terminal provenance/intent -> ending plan`. Phase 2R owns the ancestry through terminal provenance, the seven-day Schedule composition durably records the typed intent, and `dwm-oyo.6` alone resolves that intent into the final ordered ending plan. Planned state, date-completed receipts, and board-completion receipts do not exist for Day 7. Empty Done MUST emit the exact `empty_done` terminal cause; `dwm-oyo.6` maps that cause to Alone.

## Rule req.schedule.warning_queue

Schedule warnings apply on Days 1 through 6 only and MUST follow the accepted amendment's exact order: unread invitation, accepted date, then base Minesweeper. The date-seen latch survives removal, app caching, Save, Logout, and restore, and resets only when the day is replaced or a selected Load replaces the view. Each Done attempt presents at most one warning. Warning fingerprints and consumed receipts remain separate; pending activation restores exactly, and failed navigation consumes nothing. A pre-Done condition Hospital is not a Done attempt and MUST NOT fabricate or consume a warning receipt.

## Rule req.schedule.done_board_fate

Warnings MUST resolve before Done proceeds. Once Done proceeds, one recoverable causal transaction under the shared mutation gate MUST win the final causal-sequence/revision compare-and-swap before any Schedule, board-fate, or day-resolution live mutation. A losing compare-and-swap MUST preserve all four owners and the Schedule view byte-for-byte. After admission, forward recovery MUST commit Schedule, silently discard a prepared-but-unstarted board or forfeit a started board, and begin day resolution before publication. Paid board costs remain, while no board result, reward, invitation round, or completion notice is fabricated.
