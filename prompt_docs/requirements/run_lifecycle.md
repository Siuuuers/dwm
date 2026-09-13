---
id: req_packet.run_lifecycle
kind: requirement_packet
schema_version: 1
specification_status: approved
depends_on: ["spec.seven_day_dialogic_flow"]
beads: ["dwm-p2r.4","dwm-p2r.7","dwm-p2r.13","dwm-p2r.14","dwm-oyo.3","dwm-oyo.6","dwm-oyo.7","dwm-bap"]
requirements:
  - {"id":"req.run.day_range","depends_on":[],"implementation_evidence":[],"verification_evidence":[]}
  - {"id":"req.run.lifecycle_states","depends_on":["req.run.day_range"],"implementation_evidence":[],"verification_evidence":[]}
  - {"id":"req.run.day_resolution_plan","depends_on":["req.run.lifecycle_states","req.schedule.done_commit"],"implementation_evidence":[],"verification_evidence":[]}
  - {"id":"req.run.day7_terminal_intent","depends_on":["req.run.day_resolution_plan","req.schedule.day7_provenance","req.flow.hospital_order"],"implementation_evidence":[],"verification_evidence":[]}
  - {"id":"req.run.day7_terminal","depends_on":["req.run.day7_terminal_intent","req.ending.playback"],"implementation_evidence":[],"verification_evidence":[]}
  - {"id":"req.run.no_day8","depends_on":["req.run.day7_terminal_intent"],"implementation_evidence":[],"verification_evidence":[]}
  - {"id":"req.run.day7_echo_drain","depends_on":["req.run.lifecycle_states"],"implementation_evidence":["scripts/domain/contact/Day7FollowupState.gd","scripts/domain/contact/OrdinaryReplyEchoState.gd","scripts/application/contact/Day7PreludeOwner.gd","scripts/ui/Day7PreludeSurface.gd","autoload/GameState.gd","autoload/ApplicationBootstrap.gd"],"verification_evidence":["tests/unit/test_ordinary_correspondence_runtime.gd","tests/unit/test_day7_presentation_guards.gd","tests/unit/test_day7_prelude_surface.gd","tests/unit/test_day7_prelude_input.gd","tests/unit/test_day7_auto_reading.gd","tests/unit/test_day7_accessibility_action.gd","tests/integration/verify_playable_startup.gd","tests/integration/verify_day7_accessibility.gd","evidence/day7_presentation_receipt/README.md","evidence/day7_pause_custody/README.md","evidence/day7_auto_reading/README.md","evidence/day7_accessibility/README.md"]}
---

# req_packet.run_lifecycle

Reconciled 2026-08-26 with the approved `docs/design/2026-08-07-seven-day-dialogic-flow-design.md` (`spec.seven_day_dialogic_flow`, the typed packet dependency); the approved specification supersedes conflicting mechanical wording.

## Rule req.run.day_range

The active run day MUST be an integer from 1 through 7; Day 8 MAY appear only as rejected migration or negative-test input.

## Rule req.run.lifecycle_states

The lifecycle MUST use closed, validated states for desktop, Schedule-derived route resolution, pre-Done condition-Hospital resolution, narrative playback, terminal ending, and return-to-menu transitions. A durably admitted condition-Hospital state MUST block all further run input and MUST remain active across restart until Hospital presentation, any required deferred Priscilla-Lavinia resolution/presentation, recovery checkpointing, and day advance have completed. Durable outbox acceptance is an intermediate recovery state, not presentation completion and not permission to reopen desktop input.

## Rule req.run.day_resolution_plan

A successful Schedule Done MUST produce one deterministic resolution plan from the actual ordered committed Schedule before applying its end-of-day Hospital, dating, ending, or next-day effects. Production MUST NOT substitute a synthetic empty Schedule.

An immediate post-Minesweeper/Shop condition Hospital on Days 1 through 6 is a separate durable resolution and MUST NOT be represented as Schedule Done or as a Schedule-derived day-resolution plan. It advances only from the committed action and condition receipt plus the exact issuer-validated read/accepted unfulfilled invitation sources; it commits no Schedule, charges no Schedule motivation, and cannot promote draft entries to scheduled state. It MUST nevertheless finish its Hospital, optional Sylvia witness, deferred pair, and day-advance sequence exactly once before returning to desktop.

## Rule req.run.day7_terminal_intent

Resolving Day 7 through Done MUST consume the validated Schedule commit and Day-7 provenance chain, durably record exactly one typed terminal intent, and enter terminal lifecycle state without another dating board or an active Day 8. The explicit pre-Done condition-faint exception instead consumes its committed action/condition ancestry and qualifying pre-action Sylvia source, if any, and MUST NOT create Schedule ancestry. Either handoff MUST contain no caller-selected ending ID or presentation form.

## Rule req.run.day7_terminal

`dwm-oyo.6` MUST consume the typed terminal intent, freeze the valid ordered ending plan, complete its exact playback sequence, and return to the main menu. Phase-2R or `dwm-oyo.3` terminal-intent evidence MUST NOT be presented as evidence that this final playback rule is complete.

## Rule req.run.no_day8

No successful runtime transition, save, restore, or user-visible flow MUST create an active Day 8.

## Rule req.run.day7_echo_drain

Day 7 MUST first present the due Day 6 follow-ups, then hand the immutable remaining pending-echo list to the unavoidable fallback entry and drain every item oldest first; desktop app and Shop controls, Done, and every faint-capable action MUST remain unavailable until all matching presentation-atom receipts are durable, and an interruption resumes at the first unsatisfied echo. Day 7 has no ordinary three-choice message and no dating challenge, so no legal ending or Hospital transition can strand a chosen ordinary reply without one visibly experienced echo.
