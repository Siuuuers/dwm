---
id: req_packet.verification
kind: requirement_packet
schema_version: 1
specification_status: approved
beads: ["dwm-p2r.1","dwm-p2r.8","dwm-p2r.10"]
requirements:
  - {"id":"req.test.layers","depends_on":[],"implementation_evidence":[],"verification_evidence":[]}
  - {"id":"req.test.isolation","depends_on":["req.test.layers"],"implementation_evidence":[],"verification_evidence":[]}
  - {"id":"req.test.dialogic_fixture","depends_on":["req.dialogic.manifest","req.test.isolation"],"implementation_evidence":[],"verification_evidence":[]}
  - {"id":"req.test.phase2r_gate","depends_on":["req.test.layers"],"implementation_evidence":[],"verification_evidence":[]}
  - {"id":"req.config.version","depends_on":["req.test.isolation"],"implementation_evidence":[],"verification_evidence":[]}
---

# req_packet.verification

## Rule req.test.layers

Verification MUST cover pure domain contracts, persistence adapters, on-tree scene behavior, scenario integration, and the final requirement-linked evidence gate.

## Rule req.test.isolation

Every Godot process MUST run under a GUID-scoped root with redirected APPDATA, LOCALAPPDATA, log path, and a proven descendant user directory.

## Rule req.test.dialogic_fixture

The Dialogic fixture smoke test MUST validate registered timelines, safe markers, structural branches, effects, and transitions without inventing narrative prose.

## Rule req.test.phase2r_gate

Phase 3 MUST remain blocked until every active Phase-2R-blocking requirement has fresh passing evidence and all required scenes instantiate and free on-tree.

## Rule req.config.version

project.godot MUST contain exactly one canonical config_version=5 assignment and MUST reject malformed or duplicate alternatives.
