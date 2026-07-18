---
id: req_packet.dating_endings
kind: requirement_packet
schema_version: 1
specification_status: approved
beads: ["dwm-p2r.7"]
requirements:
  - {"id":"req.flow.hospital_order","depends_on":["req.run.day_resolution_plan"],"implementation_evidence":[],"verification_evidence":[]}
  - {"id":"req.ending.primary","depends_on":["req.run.day7_terminal"],"implementation_evidence":[],"verification_evidence":[]}
  - {"id":"req.ending.epilogue","depends_on":["req.ending.primary"],"implementation_evidence":[],"verification_evidence":[]}
  - {"id":"req.ending.playback","depends_on":["req.ending.primary"],"implementation_evidence":[],"verification_evidence":[]}
  - {"id":"req.ending.ids","depends_on":["req.ending.primary"],"implementation_evidence":[],"verification_evidence":[]}
---

# req_packet.dating_endings

## Rule req.flow.hospital_order

Hospital consequences MUST resolve in the deterministic order frozen by the approved design before dating or ending playback.

## Rule req.ending.primary

Day 7 MUST resolve exactly one primary ending ID from validated run state using the frozen priority and threshold rules.

## Rule req.ending.epilogue

An eligible inter-friend epilogue MAY follow the primary ending but MUST NOT replace or change the primary ending ID.

## Rule req.ending.playback

Ending unlock, checkpoint persistence, Dialogic playback, and return-to-menu MUST execute as one idempotent receipt-driven sequence.

## Rule req.ending.ids

Every ending and epilogue ID MUST belong to the closed registered ending manifest; unknown IDs MUST fail validation.
