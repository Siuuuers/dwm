---
id: req_packet.documentation_tooling
kind: requirement_packet
schema_version: 1
specification_status: approved
beads: ["dwm-p2r.1","dwm-p2r.2"]
requirements:
  - {"id":"req.docs.packet_schema","depends_on":["req.docs.authority"],"implementation_evidence":[],"verification_evidence":[]}
  - {"id":"req.docs.generated_index","depends_on":["req.docs.packet_schema"],"implementation_evidence":[],"verification_evidence":[]}
  - {"id":"req.docs.legacy_disposition","depends_on":["req.docs.packet_schema"],"implementation_evidence":[],"verification_evidence":[]}
  - {"id":"req.beads.execution","depends_on":["req.docs.authority"],"implementation_evidence":[],"verification_evidence":[]}
  - {"id":"req.codegraph.removal","depends_on":["req.docs.generated_index","req.beads.execution"],"implementation_evidence":[],"verification_evidence":[]}
---

# req_packet.documentation_tooling

## Rule req.docs.packet_schema

Every active packet MUST use schema_version 1 frontmatter, a registered packet kind, unique IDs, and exactly one Rule section for every registered requirement.

## Rule req.docs.generated_index

prompt_docs/INDEX.md MUST be generated deterministically from validated packets and MUST match the generator output byte-for-byte.

## Rule req.docs.legacy_disposition

Every archived legacy heading and zero-heading authority document MUST receive exactly one validated migrated, retained, or rejected_as_incorrect disposition before deletion.

## Rule req.beads.execution

Execution MUST resume the sole unblocked in-progress bounded Phase 2R child or claim the earliest ready child by the approved explicit execution rank, and MUST record requirement IDs and evidence links in Beads `metadata.phase2r`. Numeric issue display order MUST NOT override that rank, and blocked in-progress children MUST NOT be selected. `metadata.phase2r` is the sole Phase-2R execution namespace; the keys `scope`, `exclusions`, `evidence_links`, `requirement_ids`, and `verification_commands` MUST NOT also appear at metadata top level.

## Rule req.codegraph.removal

Repository CodeGraph data and CodeGraph-first active instructions MUST be removed only after documentation context lookup, rg inspection, and Beads execution tracking are independently proven; the global installation MUST remain untouched.
