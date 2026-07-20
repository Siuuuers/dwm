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

Contact history MUST use monotonic per-contact sequence watermarks so generated messages remain ordered, idempotent, and restorable.

## Rule req.invitation.solo

Solo invitations MUST distinguish unread, reply_required, replied, and superseded history and MUST emit the single nevermind message only for an opened unanswered offer at day resolution.

## Rule req.invitation.group_activation

The group offer MUST become available immediately after the third Minesweeper round and MUST require unread solo invitation messages from both participating friends.

## Rule req.invitation.group_resolution

The first participating contact opened MUST assign inviter_id for opening variation and date-image position only; replying to either participant MUST make the group date schedulable.

## Rule req.invitation.run_end

At day end, group-offer message effects MUST follow the existing history rules (busy, nevermind, and judge branches), and a counted Priscilla–Lavinia window MUST resolve exactly one of group (attended), missed (accepted then unattended; guilt flavor), private (no participant engaged; neutral flavor), or prevented (Angela solo-dated a participant; no encounter) per `story/05-canon-amendments-2026-07-19.md` §7, incrementing the pair counter once for each occurring version and never for a prevented window.
