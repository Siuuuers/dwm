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

An agent MUST start with `docs/agent/2026-09-23-next-session-handoff.md` and its execution map, inspect Beads execution context and the selected current issue, then load that issue's approved requirement packets, transitive dependencies, applicable approved design/plan, and generated index lookup. The handoff and map are navigation only; Beads owns status and dependencies. If live Beads is unavailable, the retained export may support continuation, with that limitation stated explicitly and no claim of Dolt synchronization. This owner-directed entry change retires the obsolete Prompt-first selection workflow without changing requirement IDs or task records.

## Rule req.docs.status_separation

Specification status, implementation status, issue status, and verification evidence MUST remain separate fields and MUST NOT imply one another.

## Rule req.docs.amendment_reconciliation

An accepted scoped design amendment MUST be registered as explicit authority, reconciled into requirement and decision packets and affected Beads metadata, and paired with reviewed hash-bound plan amendments before execution. Historical plan bytes MUST remain immutable evidence. Specification approval and plan approval MUST remain separate, and runtime work MUST remain blocked until its implementation plan is explicitly authorized.
