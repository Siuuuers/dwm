---
id: req_packet.authority_context
kind: requirement_packet
schema_version: 1
specification_status: approved
beads: ["dwm-p2r.1","dwm-0hi"]
requirements:
  - {"id":"req.docs.authority","depends_on":[],"implementation_evidence":[],"verification_evidence":[]}
  - {"id":"req.docs.context_order","depends_on":["req.docs.authority"],"implementation_evidence":[],"verification_evidence":[]}
  - {"id":"req.docs.status_separation","depends_on":["req.docs.authority"],"implementation_evidence":[],"verification_evidence":[]}
  - {"id":"req.docs.amendment_reconciliation","depends_on":["req.docs.authority","req.docs.status_separation"],"implementation_evidence":[],"verification_evidence":[]}
---

# req_packet.authority_context

## Rule req.docs.authority

Approved specifications, accepted scoped design amendments, accepted decision packets, active requirement packets, and frozen interface registries MUST be the only sources of intended behavior. Generated indexes, plans, implementation status, and Beads MUST NOT redefine behavior.

## Rule req.docs.context_order

An agent MUST load Prompt.md, Beads execution context, the active Phase 2R issue, the phase packet, referenced packets, transitive dependencies, and the generated index lookup in that order.

## Rule req.docs.status_separation

Specification status, implementation status, issue status, and verification evidence MUST remain separate fields and MUST NOT imply one another.

## Rule req.docs.amendment_reconciliation

An accepted scoped design amendment MUST be registered as explicit authority, reconciled into requirement and decision packets and affected Beads metadata, and paired with reviewed hash-bound plan amendments before execution. Historical plan bytes MUST remain immutable evidence. Specification approval and plan approval MUST remain separate, and runtime work MUST remain blocked until its implementation plan is explicitly authorized.
