---
id: req_packet.authority_context
kind: requirement_packet
schema_version: 1
specification_status: approved
beads: ["dwm-p2r.1"]
requirements:
  - {"id":"req.docs.authority","depends_on":[],"implementation_evidence":[],"verification_evidence":[]}
  - {"id":"req.docs.context_order","depends_on":["req.docs.authority"],"implementation_evidence":[],"verification_evidence":[]}
  - {"id":"req.docs.status_separation","depends_on":["req.docs.authority"],"implementation_evidence":[],"verification_evidence":[]}
---

# req_packet.authority_context

## Rule req.docs.authority

The approved Phase 2R specification, active requirement packets, and frozen interface registry MUST be the only sources of intended behavior; generated indexes and Beads MUST NOT redefine behavior.

## Rule req.docs.context_order

An agent MUST load Prompt.md, Beads execution context, the active Phase 2R issue, the phase packet, referenced packets, transitive dependencies, and the generated index lookup in that order.

## Rule req.docs.status_separation

Specification status, implementation status, issue status, and verification evidence MUST remain separate fields and MUST NOT imply one another.
