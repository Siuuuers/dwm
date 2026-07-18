---
id: req_packet.run_lifecycle
kind: requirement_packet
schema_version: 1
specification_status: approved
beads: ["dwm-p2r.4","dwm-p2r.7"]
requirements:
  - {"id":"req.run.day_range","depends_on":[],"implementation_evidence":[],"verification_evidence":[]}
  - {"id":"req.run.lifecycle_states","depends_on":["req.run.day_range"],"implementation_evidence":[],"verification_evidence":[]}
  - {"id":"req.run.day_resolution_plan","depends_on":["req.run.lifecycle_states"],"implementation_evidence":[],"verification_evidence":[]}
  - {"id":"req.run.day7_terminal","depends_on":["req.run.day_resolution_plan"],"implementation_evidence":[],"verification_evidence":[]}
  - {"id":"req.run.no_day8","depends_on":["req.run.day7_terminal"],"implementation_evidence":[],"verification_evidence":[]}
---

# req_packet.run_lifecycle

## Rule req.run.day_range

The active run day MUST be an integer from 1 through 7; Day 8 MAY appear only as rejected migration or negative-test input.

## Rule req.run.lifecycle_states

The lifecycle MUST use closed, validated states for desktop, route resolution, narrative playback, terminal ending, and return-to-menu transitions.

## Rule req.run.day_resolution_plan

Day completion MUST produce one deterministic resolution plan before applying Hospital, dating, ending, or next-day effects.

## Rule req.run.day7_terminal

Resolving Day 7 MUST enter a terminal ending flow and MUST return to the main menu after ending playback.

## Rule req.run.no_day8

No successful runtime transition, save, restore, or user-visible flow MUST create an active Day 8.
