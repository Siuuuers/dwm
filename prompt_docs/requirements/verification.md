---
id: req_packet.verification
kind: requirement_packet
schema_version: 1
specification_status: approved
beads: ["dwm-p2r.1","dwm-p2r.7","dwm-p2r.8","dwm-p2r.9","dwm-p2r.10","dwm-p2r.13","dwm-p2r.15","dwm-wks","dwm-oyo.3","dwm-oyo.7"]
requirements:
  - {"id":"req.test.layers","depends_on":[],"implementation_evidence":[],"verification_evidence":[]}
  - {"id":"req.test.isolation","depends_on":["req.test.layers"],"implementation_evidence":[],"verification_evidence":[]}
  - {"id":"req.test.dialogic_fixture","depends_on":["req.dialogic.manifest","req.test.isolation"],"implementation_evidence":[],"verification_evidence":[]}
  - {"id":"req.test.phase2r_gate","depends_on":["req.test.layers"],"implementation_evidence":[],"verification_evidence":[]}
  - {"id":"req.test.schedule_foundation_gate","depends_on":["req.test.layers","req.schedule.done_commit","req.save.schedule_migration"],"implementation_evidence":[],"verification_evidence":[]}
  - {"id":"req.test.schedule_gate","depends_on":["req.test.schedule_foundation_gate","req.schedule.done_board_fate","req.schedule.warning_queue"],"implementation_evidence":[],"verification_evidence":[]}
  - {"id":"req.test.desktop_amendment_gate","depends_on":["req.test.layers","req.minesweeper.phase_boundary","req.save.desktop_board_continuity"],"implementation_evidence":[],"verification_evidence":[]}
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

## Rule req.test.schedule_gate

One post-composition subject commit MUST pass the foundation gate plus the complete warning queue, shared causal admission, prepared discard and started forfeit, four-participant recovery, real ScheduleView restore/remap, duplicate delivery, and fail-closed corruption.

## Rule req.test.schedule_foundation_gate

One Phase-2R subject commit MUST pass fresh tests for committed Schedule schemas, exact action-registry parity, repeatable ordinary actions, capacity and pair-supersession laws, atomic motivation-charging participant behavior, Day-7 receipt ancestry, exact restore and empty-only migration, the real ordered committed Schedule entering day resolution, duplicate delivery, rollback, and fail-closed legacy or registry corruption. It MUST NOT claim that the later saved view, warning queue, or final four-participant Done composition is already implemented.

## Rule req.test.desktop_amendment_gate

One subject commit MUST pass fresh lifecycle, property, integration, crash-injection, persistence, accessibility, and action-matrix tests for every desktop board phase; first-Reveal charging; generator and verifier capability combinations; isolated RNG; Home, switching, Save, Load, Logout, and Shop; prepared discard; started forfeit; duplicate and stale commands; and technical failure before presentation.

## Rule req.config.version

project.godot MUST contain exactly one canonical config_version=5 assignment and MUST reject malformed or duplicate alternatives.
