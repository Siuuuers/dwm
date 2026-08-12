---
id: req_packet.contacts_invitations
kind: requirement_packet
schema_version: 1
specification_status: approved
beads: ["dwm-p2r.6","dwm-p2r.13","dwm-p2r.14","dwm-oyo.3","dwm-oyo.4"]
requirements:
  - {"id":"req.contact.history_watermark","depends_on":[],"implementation_evidence":[],"verification_evidence":[]}
  - {"id":"req.invitation.solo","depends_on":["req.contact.history_watermark"],"implementation_evidence":[],"verification_evidence":[]}
  - {"id":"req.invitation.group_activation","depends_on":["req.contact.history_watermark"],"implementation_evidence":[],"verification_evidence":[]}
  - {"id":"req.invitation.group_resolution","depends_on":["req.invitation.group_activation"],"implementation_evidence":[],"verification_evidence":[]}
  - {"id":"req.invitation.run_end","depends_on":["req.invitation.solo","req.invitation.group_resolution"],"implementation_evidence":[],"verification_evidence":[]}
---

# req_packet.contacts_invitations

Amended 2026-07-19 per `story/05-canon-amendments-2026-07-19.md`; that file wins on amended points.

## Rule req.contact.history_watermark

Contact history MUST use monotonic per-contact sequence watermarks so generated messages remain ordered, idempotent, and restorable: history is an append-only per-friend log, generation appends at the next sequence, and re-generation at an existing sequence is a no-op (per `story/05-canon-amendments-2026-07-19.md` §13).

## Rule req.invitation.solo

Opening a solo invitation MUST perform Angela's scripted acceptance, validate its full issuer-issued command receipt, derive and persist a distinct `contact_source` child receipt/provenance for the friend/day/action, and make the date available to the Schedule draft. An ID without ledger-verified issuer ancestry is not source proof, and the child receipt MUST NOT be confused with its root command token. There is no separate accept-or-decline reply. An unopened offer expires into exactly one next-day nevermind; an accepted offer left uncommitted by ordinary Done produces exactly one next-day missed-date question; Hospital supersession records the distinct Hospital miss reason without also creating a generic miss. A condition-Hospital resolver MAY supersede a solo offer only from its exact issuer-validated read/acceptance source while that source is still unfulfilled in the same causal day, and MUST produce one idempotent Hospital-miss receipt for that source.

For either lawful Days-1–6 Hospital mode, a qualifying Sylvia source MUST additionally derive and persist exactly one issuer-anchored Sylvia-witness receipt for that invitation. The receipt suppresses only Sylvia's missed-date question for that Hospital event and freezes the next-day scripted caring entry plus the fixed future consequence: affection `+2`, dark `+1`, attitude `Fixated`, and exactly one tier advance capped at Love (`Friend -> Ambiguous`, `Ambiguous -> Love`, `Love -> Love`). It grants no challenge result, relationship outcome, board history, or Perfect mastery. Receipt presence is not effect application: presentation cannot author it, `dwm-oyo.3` may produce or preserve it but MUST NOT apply it, and `dwm-oyo.4` alone MUST validate and consume that exact receipt once to apply the relationship fields and commit the caring presentation/history transaction. A solo offer becomes superseded when its same-window Priscilla-Lavinia group invitation is generated and MUST then produce neither a duplicate nevermind nor an independently schedulable date.

## Rule req.invitation.group_activation

The group offer MUST become available immediately after the third Minesweeper round and MUST require unread solo invitation messages from both participating friends.

## Rule req.invitation.group_resolution

The first participating contact opened MUST assign `inviter_id` for opening variation and date-image position only. The group is the sole invitation exception that requires a reply: replying through either participant MUST issue one exact source receipt bound to canonical participants `["priscilla","lavinia"]`, make the group date available to the Schedule draft, and supersede the corresponding solo offers. That exact pair receipt, not caller-supplied participants, is the only group-date or condition-Hospital source proof. Hospital records one source-level miss for that pair receipt exactly once; its required per-participant follow-up projection MUST NOT fabricate a second acceptance or a duplicate source-level miss.

## Rule req.invitation.run_end

At day end, group-offer message effects MUST follow the existing history rules (busy, nevermind, and judge branches), and a counted Priscilla–Lavinia window MUST resolve on one rule — did Angela solo-date either woman? — per `story/05-canon-amendments-2026-07-19.md` §7. Solo-dating one participant is prevented (no meeting, no count). Solo-dating neither always counts once: group (offer generated, attended), missed (offer generated, accepted then unattended; guilt flavor), private-visible (offer generated, both group messages unread; neutral flavor scene), or private-offscreen (offer never generated; the pair meets with no player-visible scene). Only the three offer-generated outcomes are audience-visible and mark the state/tone combination seen; offscreen private counts invisibly. A prevented window MUST NOT increment the pair counter. When Hospital determines a visible deferred pair outcome, Hospital presentation MUST complete before that pair resolution/presentation, and both MUST complete before day advance reopens desktop input.
