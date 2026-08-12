---
id: req_packet.runtime_ownership
kind: requirement_packet
schema_version: 1
specification_status: approved
beads: ["dwm-p2r.4","dwm-p2r.7","dwm-p2r.13","dwm-p2r.14","dwm-p2r.16","dwm-oyo.3"]
requirements:
  - {"id":"req.runtime.sole_owners","depends_on":[],"implementation_evidence":[],"verification_evidence":[]}
  - {"id":"req.runtime.game_state_facade","depends_on":["req.runtime.sole_owners"],"implementation_evidence":[],"verification_evidence":[]}
  - {"id":"req.runtime.commands_signals","depends_on":["req.runtime.game_state_facade"],"implementation_evidence":[],"verification_evidence":[]}
  - {"id":"req.runtime.schedule_ownership","depends_on":["req.runtime.sole_owners","req.runtime.game_state_facade"],"implementation_evidence":[],"verification_evidence":[]}
---

# req_packet.runtime_ownership

## Rule req.runtime.sole_owners

ProfileManager MUST own permanent profile state, SaveManager MUST own slot I/O and restore coordination, GameState MUST own the active run facade, DialogicBridge MUST own narrative integration, and AudioManager MUST own live audio.

## Rule req.runtime.game_state_facade

GameState MUST remain the stable gameplay facade and MUST delegate domain behavior to pure RefCounted modules without duplicating their state.

## Rule req.runtime.commands_signals

Runtime mutations MUST use typed command methods returning closed result dictionaries, and observers MUST receive committed state through declared signals.

## Rule req.runtime.schedule_ownership

The immutable action registry MUST own Schedule action facts; pure Schedule rules MUST own validation and projection; the Schedule view/controller MUST own saved uncommitted view state and warnings; and GameState MUST own the atomic gameplay facade. `ScheduleDoneCommandPort` is only the public view/warning command facade and MUST delegate a warning-free departure without reordering its participants.

The shared `DesktopConsequenceCoordinator` MUST own final causal admission and forward recovery for both departure classes without merging their contracts. A Schedule-Done departure owns the actual Schedule commit, prepared-board discard or started-board forfeit, Schedule-derived day-resolution start, and ordered publication. An admitted post-Minesweeper/Shop condition departure owns the committed action, condition result, projected board fate, uncommitted-view departure, and exact destination-outbox production, but MUST NOT call the Schedule-Done command/commit or Schedule-derived day-resolution-start interfaces. Its separate condition-Hospital resolution owner MUST durably accept that exact intent, consume only its frozen issuer-validated accepted/read unfulfilled invitation sources, derive one miss per source and any Sylvia witness, drive Hospital then any deferred pair then day advance, and keep input blocked until physical completion is durably checkpointed.

An outbox `published` transition MAY occur only when the designated resolution owner durably accepts the exact intent and receipt. It is not a scene invocation, presentation-completion receipt, day advance, or input-unlock signal. Hospital and Dating scenes MUST remain presentation adapters and MUST NOT become mutation, delivery-acknowledgment, or lifecycle owners.
