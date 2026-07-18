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

## Rule req.contact.history_watermark

Contact history MUST use monotonic per-contact sequence watermarks so generated messages remain ordered, idempotent, and restorable.

## Rule req.invitation.solo

Solo invitations MUST distinguish unread, reply_required, replied, and superseded history and MUST emit the single nevermind message only for an opened unanswered offer at day resolution.

## Rule req.invitation.group_activation

The group offer MUST become available immediately after the third Minesweeper round and MUST require unread solo invitation messages from both participating friends.

## Rule req.invitation.group_resolution

The first participating contact opened MUST assign inviter_id for opening variation and date-image position only; replying to either participant MUST make the group date schedulable.

## Rule req.invitation.run_end

At day end, two untouched group offers MUST produce both busy messages; any opened unanswered group offer MUST preserve history and produce nevermind messages, while a replied offer MUST use the non-replied participant judge branch.
