---
id: req_packet.dating_endings
kind: requirement_packet
schema_version: 1
specification_status: approved
depends_on: ["spec.seven_day_dialogic_flow"]
beads: ["dwm-p2r.7","dwm-p2r.14","dwm-oyo.3","dwm-oyo.6","dwm-oyo.7"]
requirements:
  - {"id":"req.flow.hospital_order","depends_on":["req.run.day_resolution_plan","req.run.lifecycle_states","req.schedule.day7_provenance","req.invitation.solo","req.invitation.group_resolution","req.invitation.run_end","req.save.journal"],"implementation_evidence":[],"verification_evidence":[]}
  - {"id":"req.relationship.axes","depends_on":[],"implementation_evidence":[],"verification_evidence":[]}
  - {"id":"req.relationship.outcome_table","depends_on":["req.relationship.axes"],"implementation_evidence":[],"verification_evidence":[]}
  - {"id":"req.relationship.promotion_valves","depends_on":["req.relationship.axes","req.relationship.outcome_table"],"implementation_evidence":[],"verification_evidence":[]}
  - {"id":"req.relationship.pair_isolation","depends_on":["req.invitation.run_end"],"implementation_evidence":[],"verification_evidence":[]}
  - {"id":"req.ending.primary","depends_on":["req.run.day7_terminal_intent"],"implementation_evidence":[],"verification_evidence":[]}
  - {"id":"req.ending.epilogue","depends_on":["req.ending.primary"],"implementation_evidence":[],"verification_evidence":[]}
  - {"id":"req.ending.playback","depends_on":["req.ending.primary"],"implementation_evidence":[],"verification_evidence":[]}
  - {"id":"req.ending.ids","depends_on":["req.ending.primary"],"implementation_evidence":[],"verification_evidence":[]}
---

# req_packet.dating_endings

Amended 2026-07-19 per `story/05-canon-amendments-2026-07-19.md`; that file wins on amended points.

Reconciled 2026-08-26 with the approved `docs/design/2026-08-07-seven-day-dialogic-flow-design.md` (`spec.seven_day_dialogic_flow`, the typed packet dependency); the approved specification supersedes conflicting mechanical wording.

## Rule req.flow.hospital_order

Days 1 through 6 have two disjoint Hospital-resolution modes. A Schedule-Done/end-of-day Hospital MUST consume the actual ordered committed Schedule produced by that successful Done, supersede every affected committed date before any dating board, and record each resulting Hospital miss exactly once. It MUST NOT substitute a synthetic or caller-authored Schedule.

An immediate post-Minesweeper/Shop condition Hospital while Done is still open is a separate durable condition-Hospital resolution. It MUST NOT call or forge Schedule Done, commit or synthesize a Schedule, charge Schedule motivation, or treat any ScheduleView draft entry as scheduled. Its invitation inputs are the exact issuer-validated, read/accepted, still-unfulfilled source receipts for that causal day; it records one Hospital miss for each source exactly once and derives the optional Sylvia witness only from a qualifying Sylvia source in that frozen set.

Once either Hospital mode is durably admitted, further run input MUST remain blocked until Hospital presentation, any resulting deferred Priscilla-Lavinia resolution/presentation, recovery checkpointing, and day advance have completed; only then may the next desktop become available. Marking an outbox item `published` means the durable resolution owner accepted the exact item and MUST NOT be treated as proof that Hospital or deferred presentation physically completed. On Day 7, the intentional faint remains the explicit terminal exception and uses this exact precedence: enabled Dark mode wins as Dark-mode Alone even when Sylvia's invitation was already read; otherwise Sylvia's exact invitation read/acceptance receipt, committed before the qualifying Minesweeper app-round or Shop action, selects Sylvia Special; otherwise the faint selects Hospital-cause Normal Alone. None of these branches requires or creates a Schedule draft or commit, and none creates an active Day 8.

The Hospital predicates are exact and code-owned: `danger := pressure >= 10 OR health <= 0` evaluated on internal, not display-clamped, values; `sequela` exists only when carried from the previous day's uncleared danger; immediately after a desktop Minesweeper app round or Shop purchase commits its effects, `sequela AND danger` MUST trigger Hospital before another desktop action; on Days 1-6 Schedule Done commits the selected schedule and then runs the single end-of-day condition resolver before any date; and Day 7 Done bypasses end-of-day condition resolution, leaving the real-time pre-Done check as its only faint path. The same idempotent condition receipt owns the danger inputs, trigger result, and pending-Hospital transition; reload MUST NOT reroll or reapply it, and these thresholds and condition names remain hidden from the audience.

## Rule req.relationship.axes

Per-friend relationship state MUST use exactly the four approved axes: signed `affection` clamped to -4 through 10 that never directly sets tier; durable `tier` moving only `Friend -> Ambiguous -> Love` and never regressing; permanent integer `dark` 0 through 4 that never decreases and rises only one point at a time through a terminal Dark relationship outcome or the approved Sylvia Hospital witness; and current `attitude`, overwritten only by that friend's next attended solo challenge or that witness. Initial per-friend state is fixed: affection 0, tier Friend, dark 0, attitude Neutral. Tone MUST derive from permanent dark count (0-1 Sweet, 2-4 Totally Dark), and tier, tone, and attitude remain independent. Affection changes only through the six terminal solo relationship outcomes or the approved witness, every mutation clamps immediately, and no message, miss, invitation, pair board, or ending applies a hidden delta. Affection-computed or regressing tiers, Hate as a durable tier, and any dark maximum other than 4 are retired, and no statistic, threshold, or outcome name is audience-visible.

## Rule req.relationship.outcome_table

`board_result` (`exploded | solved | perfect`) and `relationship_outcome` (`hatred | upset | amused | loved | foresight | dark`) MUST remain disjoint persisted enums, with `perfect_reasons` a nonempty subset of `efficiency_gt_100 | no_flag` only when the board is perfect. The date never presents a relationship menu; actual Minesweeper play produces the result through the fixed consequence table: an explosion resolves through the hidden per-mine assignment (Hatred affection -1 attitude Hostile; Upset 0 Upset; Amused +1 Amused) generated as one independent uniform one-third draw per eligible ordinary mine, fixed with the board before reveal, never rerolled by reload, and never consulting friend, day, tier, affection, dark, attitude, route, or prior outcome; a non-Perfect clear resolves Loved (+2, Affectionate); a Perfect clear resolves Foresight (+2, Seen); and the deliberate special mine after a clear resolves Dark (+2, dark +1, Fixated) while retaining the already-earned Solved or Perfect board truth. A clear first commits board truth alone and enters `CLEARED_AWAITING_TERMINAL_CHOICE`; exactly one terminal relationship-outcome receipt then applies affection, dark, and attitude, and saving in the post-clear phase restores that phase so Loved/Foresight and Dark can never both pay out. The special mine has no numerical label and is non-interactable until the board has cleared, and every attended challenge overwrites the friend's current attitude.

## Rule req.relationship.promotion_valves

Affection is fuel; the fixed calendar challenge windows are the only normal valves. Immediately after the challenge in the friend's fixed third invitation slot (Priscilla Day 4, Lavinia Day 5, Sylvia Day 4), Friend MAY advance to Ambiguous when affection is at least 4; immediately after the fixed fourth slot (Priscilla Day 6, Lavinia Day 6, Sylvia Day 5), Ambiguous MAY advance to Love when affection is at least 8. Each valve advances at most one tier and is evaluated after committing the challenge result and before presenting its post-challenge dialogue. A missed, unread, prevented, or Hospital-superseded fixed window MUST NOT move elsewhere, the fourth valve cannot repair a missed or failed third valve, and raw affection never bypasses a durable tier or directly unlocks Day 7. Appearance/incident-card and attended-ordinal promotion gates are retired. Sylvia's witnessed-Hospital promotion remains the only approved exception to these fixed solo challenge valves.

## Rule req.relationship.pair_isolation

The Priscilla-Lavinia pair board MUST keep exactly three terminal results (Perfect, Solved, Exploded) with no colored or special mine and no relationship-outcome layer; it controls only encounter legibility and mastery evidence and MUST NOT change Angela's affection, dark, tier, attitude, or invitation consent, nor the pair's own desire, state, or tone. A generic Priscilla-Lavinia ending identity is retired: the pair's ending identities are exactly its Sweet, Dark, and Observer entries in the closed ending manifest.

## Rule req.ending.primary

Day 7 MUST resolve exactly one frozen ordered ending plan of one through four semantic steps from validated run state before playback and MUST NOT run a decisive dating board. A personal destination requires the durable ambiguous or love tier and an exact Schedule provenance chain; empty Done selects Alone; and the chosen friend's permanent darkness selects Sweet at 0-1 or Totally Dark at 2 or more, while current attitude and earned echoes vary presentation without changing the destination. The resolver MUST order multiple qualified results by the approved sequence, keep any counted Priscilla-Lavinia steps last, and reject a plan combining causally incompatible evidence (a solo Priscilla or Lavinia Observer cannot coexist with a counted pair ending in one run). The retired two-slot primary-plus-optional-epilogue plan shape MUST NOT be produced, persisted, or migrated forward; the first ordered step is the run's achieved ending even when later ordered steps remain.

## Rule req.ending.epilogue

Steps after the first MUST follow only as later entries of the same frozen ordered plan, each gated independently: an inter-friend counter-ending only when both counted Priscilla-Lavinia encounters actually occurred (in group, missed, or private form; a prevented window never qualifies), and Observer postscripts only through their own approved gates. The Sylvia Special prelude is never a later step: when present it is deliberately the first step of its exact Special-then-forced-Dark chain, with Sylvia Totally Dark following it. A later step MUST NOT replace or change the identity committed by an earlier step, and abandoning later steps does not revoke an earned earlier completion.

## Rule req.ending.playback

Each plan step MUST own a stable `step_id`, semantic ending ID, callable entry ID, role, frozen presentation context, playback mode, prerequisite receipt IDs, and transaction token, advancing `pending -> playing -> completed` where only a physical completion carrying the matching token commits completion and moves the cursor: starting a label never advances, duplicate matching completion is an idempotent no-op, and mismatched completion cannot advance. Ending unlock, checkpoint persistence, Dialogic playback, Gallery discovery, and return-to-menu MUST execute as one idempotent receipt-driven sequence, Gallery discovery commits only for semantic identities that physically completed, and the run reaches Completed/Menu only after every planned step and its Gallery receipt are durable.

## Rule req.ending.ids

Every ending and postscript ID MUST belong to the closed registered ending manifest of exactly thirteen semantic identities - Angela-Priscilla Sweet/Dark/Observer, Angela-Lavinia Sweet/Dark/Observer, Angela-Sylvia Sweet/Dark/Special, Priscilla-Lavinia Sweet/Dark/Observer, and Alone - each presented only through its finite allowed entries and closed `ending_form` values; unknown or retired IDs MUST fail validation. Standalone true-path ending IDs, `true_count` gates, and a generic Priscilla-Lavinia identity are retired; Sweet, Dark, Observer, and Special remain internal semantic classifications while discovered Gallery entries use authored audience-facing titles.
