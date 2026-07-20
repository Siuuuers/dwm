---
id: req_packet.dialogic_skip
kind: requirement_packet
schema_version: 1
specification_status: approved
beads: ["dwm-p2r.8"]
requirements:
  - {"id":"req.dialogic.authority","depends_on":["req.runtime.sole_owners"],"implementation_evidence":[],"verification_evidence":[]}
  - {"id":"req.dialogic.manifest","depends_on":["req.dialogic.authority"],"implementation_evidence":[],"verification_evidence":[]}
  - {"id":"req.dialogic.effects","depends_on":["req.dialogic.manifest"],"implementation_evidence":[],"verification_evidence":[]}
  - {"id":"req.dialogic.visited","depends_on":["req.profile.partition","req.dialogic.manifest"],"implementation_evidence":[],"verification_evidence":[]}
  - {"id":"req.dialogic.skip","depends_on":["req.dialogic.visited"],"implementation_evidence":[],"verification_evidence":[]}
  - {"id":"req.dialogic.content_status","depends_on":["req.dialogic.manifest"],"implementation_evidence":[],"verification_evidence":[]}
---

# req_packet.dialogic_skip

Amended 2026-07-19 per `story/05-canon-amendments-2026-07-19.md`; that file wins on amended points.

## Rule req.dialogic.authority

Dialogic MUST be the sole narrative playhead; runtime code MUST communicate through the validated Dialogic adapter and bridge.

## Rule req.dialogic.manifest

Timeline, marker, effect, variable, and line IDs MUST belong to exact closed manifests aligned with the amended canon (retired true-path timeline IDs excluded; Priscilla–Lavinia group, missed, and private scene variations registered as distinct timelines) before playback or mutation.

## Rule req.dialogic.effects

Narrative effects and variables MUST resolve through typed allowlisted transactions and MUST NOT invoke arbitrary methods by name.

## Rule req.dialogic.visited

Visited line history MUST be permanent profile state keyed by registered stable line IDs and MUST publish only after durable commit.

## Rule req.dialogic.skip

Skip MUST always fast-forward text; the setting MUST choose whether unread lines are eligible or only previously visited lines are eligible.

## Rule req.dialogic.content_status

Phase 2R MUST validate English timeline structure and MUST NOT invent dialogue prose or claim unavailable translated narrative coverage.
