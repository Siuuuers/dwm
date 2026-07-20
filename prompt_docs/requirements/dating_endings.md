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

Amended 2026-07-19 per `story/05-canon-amendments-2026-07-19.md`; that file wins on amended points.

## Rule req.flow.hospital_order

Hospital consequences MUST resolve before dating or ending playback in the deterministic order approved in `story/05-canon-amendments-2026-07-19.md` §8: a Day-7 neglect faint (fired only by the Minesweeper app-round or Shop purchase check) qualifies the Sylvia Special only when a Sylvia date was schedulable with Done unpressed, and otherwise resolves the Alone hospital variant.

## Rule req.ending.primary

Day 7 MUST resolve exactly one primary ending ID from validated run state: destination eligibility requires the ambiguous or love tier, tone is selected solely by the decisive Day-7 board (deliberate dark-mine click selects Totally Dark, any other finish selects Sweet), and multiple qualified results MUST apply the Core Story Bible's four-layer ending order.

## Rule req.ending.epilogue

An inter-friend counter-ending MAY follow the primary ending only when both counted Priscilla–Lavinia encounters actually occurred (in group, missed, or private version; a prevented window never qualifies) and MUST NOT replace or change the primary ending ID.

## Rule req.ending.playback

Ending unlock, checkpoint persistence, Dialogic playback, and return-to-menu MUST execute as one idempotent receipt-driven sequence.

## Rule req.ending.ids

Every ending and epilogue ID MUST belong to the closed registered ending manifest aligned with the amended canon catalogue (standalone true-path ending IDs are retired; true-observation postscript IDs register as postscripts, not destinations); unknown or retired IDs MUST fail validation.
