---
id: req_packet.dating_endings
kind: requirement_packet
schema_version: 1
specification_status: approved
beads: ["dwm-p2r.7","dwm-p2r.14","dwm-oyo.3","dwm-oyo.6","dwm-oyo.7"]
requirements:
  - {"id":"req.flow.hospital_order","depends_on":["req.run.day_resolution_plan","req.run.lifecycle_states","req.schedule.day7_provenance","req.invitation.solo","req.invitation.group_resolution","req.invitation.run_end","req.save.journal"],"implementation_evidence":[],"verification_evidence":[]}
  - {"id":"req.ending.primary","depends_on":["req.run.day7_terminal_intent"],"implementation_evidence":[],"verification_evidence":[]}
  - {"id":"req.ending.epilogue","depends_on":["req.ending.primary"],"implementation_evidence":[],"verification_evidence":[]}
  - {"id":"req.ending.playback","depends_on":["req.ending.primary"],"implementation_evidence":[],"verification_evidence":[]}
  - {"id":"req.ending.ids","depends_on":["req.ending.primary"],"implementation_evidence":[],"verification_evidence":[]}
---

# req_packet.dating_endings

Amended 2026-07-19 per `story/05-canon-amendments-2026-07-19.md`; that file wins on amended points.

## Rule req.flow.hospital_order

Days 1 through 6 have two disjoint Hospital-resolution modes. A Schedule-Done/end-of-day Hospital MUST consume the actual ordered committed Schedule produced by that successful Done, supersede every affected committed date before any dating board, and record each resulting Hospital miss exactly once. It MUST NOT substitute a synthetic or caller-authored Schedule.

An immediate post-Minesweeper/Shop condition Hospital while Done is still open is a separate durable condition-Hospital resolution. It MUST NOT call or forge Schedule Done, commit or synthesize a Schedule, charge Schedule motivation, or treat any ScheduleView draft entry as scheduled. Its invitation inputs are the exact issuer-validated, read/accepted, still-unfulfilled source receipts for that causal day; it records one Hospital miss for each source exactly once and derives the optional Sylvia witness only from a qualifying Sylvia source in that frozen set.

Once either Hospital mode is durably admitted, further run input MUST remain blocked until Hospital presentation, any resulting deferred Priscilla-Lavinia resolution/presentation, recovery checkpointing, and day advance have completed; only then may the next desktop become available. Marking an outbox item `published` means the durable resolution owner accepted the exact item and MUST NOT be treated as proof that Hospital or deferred presentation physically completed. On Day 7, the intentional faint remains the explicit terminal exception and uses this exact precedence: enabled Dark mode wins as Dark-mode Alone even when Sylvia's invitation was already read; otherwise Sylvia's exact invitation read/acceptance receipt, committed before the qualifying Minesweeper app-round or Shop action, selects Sylvia Special; otherwise the faint selects Hospital-cause Normal Alone. None of these branches requires or creates a Schedule draft or commit, and none creates an active Day 8.

## Rule req.ending.primary

Day 7 MUST resolve exactly one primary ending ID from validated run state and MUST NOT run a decisive dating board. A personal destination requires the durable ambiguous or love tier and an exact Schedule provenance chain; empty Done selects Alone. The chosen friend's permanent darkness selects Sweet at 0–1 or Totally Dark at 2 or more, while current attitude and earned echoes may vary presentation without changing the destination. Multiple qualified results MUST apply the approved ordered ending sequence.

## Rule req.ending.epilogue

An inter-friend counter-ending MAY follow the primary ending only when both counted Priscilla–Lavinia encounters actually occurred (in group, missed, or private version; a prevented window never qualifies) and MUST NOT replace or change the primary ending ID.

## Rule req.ending.playback

Ending unlock, checkpoint persistence, Dialogic playback, and return-to-menu MUST execute as one idempotent receipt-driven sequence.

## Rule req.ending.ids

Every ending and epilogue ID MUST belong to the closed registered ending manifest aligned with the amended canon catalogue (standalone true-path ending IDs are retired; true-observation postscript IDs register as postscripts, not destinations); unknown or retired IDs MUST fail validation.
