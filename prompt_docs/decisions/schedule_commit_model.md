---
id: decision.schedule_commit_model
kind: decision_packet
schema_version: 1
specification_status: approved
decision_status: accepted
beads: ["dwm-0hi"]
requirements: []
depends_on: []
evidence: ["On 2026-08-11 the user approved every recommended Schedule ruling in one batch.","The approved design is unreleased, so receiptless nonempty legacy Schedule state has no player-compatibility promise.","The accepted seven-day specification distinguishes immediate post-action Hospital from Done-committed Hospital; this packet preserves that distinction without inventing a hidden Done."]
scope: ["Schedule draft and committed-state separation.","Done-time motivation and capacity rules.","Immediate condition-Hospital versus Done-committed Hospital ownership.","Action-registry authority, Day-7 provenance, migration, and subsystem ownership."]
affected_requirement_ids: ["req.schedule.state_models","req.schedule.action_registry","req.schedule.validation","req.schedule.done_commit","req.schedule.day7_provenance","req.schedule.warning_queue","req.schedule.done_board_fate","req.flow.hospital_order","req.run.day_resolution_plan","req.runtime.schedule_ownership","req.save.schedule_state","req.save.schedule_migration","req.minesweeper.causal_departure","req.test.schedule_foundation_gate","req.test.schedule_gate"]
blocking_requirement_ids: []
recommended_investigation: ["Verify the reconciled registry, persistence, transaction, and warning contracts through the hash-bound implementation roadmap before runtime authorization."]
---

# Schedule Commit Model

The accepted model spends no motivation while drafting and charges exactly one motivation per committed entry only when Done succeeds. A Days 1–6 condition-triggered Hospital departure while Done is still open is not a hidden Done: it discards the uncommitted view without committing or charging it and enters the distinct receipt-driven condition-Hospital resolution. Days 1 through 6 expose seven Schedule boxes with at most two date entries; Day 7 is empty or one solo destination at slot zero. Training, Working, and Rest remain repeatable as distinct draft entries. Route, effects, and cost come from an immutable registry. Empty legacy Schedule state may normalize to the new empty defaults, while nonempty receiptless legacy Schedule state fails closed. Phase 2R owns pure committed Schedule and provenance, the desktop contract owns board fate and the shared consequence transaction, and the seven-day Schedule composition owns the saved view, warnings, thin Done command facade, and separate pre-Done condition-Hospital handoff. The shared consequence coordinator alone performs final causal admission and orders the four-participant Done departure; it does not turn a condition action into Schedule Done.
