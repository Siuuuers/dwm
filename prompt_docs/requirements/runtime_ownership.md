---
id: req_packet.runtime_ownership
kind: requirement_packet
schema_version: 1
specification_status: approved
beads: ["dwm-p2r.4"]
requirements:
  - {"id":"req.runtime.sole_owners","depends_on":[],"implementation_evidence":[],"verification_evidence":[]}
  - {"id":"req.runtime.game_state_facade","depends_on":["req.runtime.sole_owners"],"implementation_evidence":[],"verification_evidence":[]}
  - {"id":"req.runtime.commands_signals","depends_on":["req.runtime.game_state_facade"],"implementation_evidence":[],"verification_evidence":[]}
---

# req_packet.runtime_ownership

## Rule req.runtime.sole_owners

ProfileManager MUST own permanent profile state, SaveManager MUST own slot I/O and restore coordination, GameState MUST own the active run facade, DialogicBridge MUST own narrative integration, and AudioManager MUST own live audio.

## Rule req.runtime.game_state_facade

GameState MUST remain the stable gameplay facade and MUST delegate domain behavior to pure RefCounted modules without duplicating their state.

## Rule req.runtime.commands_signals

Runtime mutations MUST use typed command methods returning closed result dictionaries, and observers MUST receive committed state through declared signals.
