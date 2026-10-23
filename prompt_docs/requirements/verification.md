---
id: req_packet.verification
kind: requirement_packet
schema_version: 1
specification_status: approved
depends_on: ["spec.seven_day_dialogic_flow"]
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
  - {"id":"req.test.seven_day_evidence","depends_on":["req.test.layers"],"implementation_evidence":[],"verification_evidence":[]}
---

# req_packet.verification

Reconciled 2026-08-26 with the approved `docs/design/2026-08-07-seven-day-dialogic-flow-design.md` (`spec.seven_day_dialogic_flow`, the typed packet dependency); the approved specification supersedes conflicting mechanical wording.

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

## Rule req.test.seven_day_evidence

Seven-day release evidence MUST prove the P0 invariant families - manifest closure with no label fallthrough; seeded seven-day model legality for day bounds, invitation closure, schedule legality, stat ownership, monotonic tiers, and one valid terminal plan; save/restore/continue equivalence to uninterrupted canonical execution outside the explicit post-first-ending pre-challenge regeneration boundary; exactly-once behavior for generation, reply, result, Hospital, pair-count, promotion, ending, and Gallery receipts; promotion valves at the affection 3/4 and 7/8 boundaries with one-step maximum and no relocation; the exhaustive Priscilla-Lavinia window truth table; exhaustive legal one-to-four-step ending plans with every resume cursor; and the Day 7 faint/echo terminal order - plus the release gates: domain, save, manifest, and receipt suites on every relevant change, the complete headless GUT suite on every pull request, DTL label and manifest smokes whenever timeline, locale, manifest, calendar, or ending entries change, all full-run smokes before release, approved accessibility assistance preserving Perfect validity, and recorded engine and addon versions, worktree identity, commands, counts, diagnostics, and bounded third-party exceptions in release evidence.
