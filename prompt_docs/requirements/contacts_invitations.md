---
id: req_packet.contacts_invitations
kind: requirement_packet
schema_version: 1
specification_status: approved
beads: ["dwm-p2r.6"]
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

Solo invitations MUST distinguish unread, reply_required, replied, and superseded history. A solo offer becomes superseded when a group invitation is generated that day. At day resolution the single nevermind message MUST fire for any un-replied solo offer — whether unread or opened-unanswered — and MUST NOT fire for a superseded offer or a replied offer (amended 2026-07-21 per `story/05-canon-amendments-2026-07-19.md` §13; supersedes the earlier "only for an opened unanswered offer" wording).

## Rule req.invitation.group_activation

The group offer MUST become available immediately after the third Minesweeper round and MUST require unread solo invitation messages from both participating friends.

## Rule req.invitation.group_resolution

The first participating contact opened MUST assign inviter_id for opening variation and date-image position only; replying to either participant MUST make the group date schedulable.

## Rule req.invitation.run_end

At day end, group-offer message effects MUST follow the existing history rules (busy, nevermind, and judge branches), and a counted Priscilla–Lavinia window MUST resolve on one rule — did Angela solo-date either woman? — per `story/05-canon-amendments-2026-07-19.md` §7. Solo-dating one participant is prevented (no meeting, no count). Solo-dating neither always counts once: group (offer generated, attended), missed (offer generated, accepted then unattended; guilt flavor), private-visible (offer generated, both group messages unread; neutral flavor scene), or private-offscreen (offer never generated; the pair meets with no player-visible scene). Only the three offer-generated outcomes are audience-visible and mark the state/tone combination seen; offscreen private counts invisibly. A prevented window MUST NOT increment the pair counter.
