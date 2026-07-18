---
id: req_packet.desktop_minesweeper_handoff
kind: requirement_packet
schema_version: 1
specification_status: approved
beads: ["dwm-p2r.9"]
requirements:
  - {"id":"req.desktop.registry","depends_on":[],"implementation_evidence":[],"verification_evidence":[]}
  - {"id":"req.desktop.host","depends_on":["req.desktop.registry"],"implementation_evidence":[],"verification_evidence":[]}
  - {"id":"req.desktop.logout","depends_on":["req.desktop.host"],"implementation_evidence":[],"verification_evidence":[]}
  - {"id":"req.minesweeper.round_contract","depends_on":["req.save.minesweeper_lock"],"implementation_evidence":[],"verification_evidence":[]}
  - {"id":"req.minesweeper.phase_boundary","depends_on":["req.minesweeper.round_contract"],"implementation_evidence":[],"verification_evidence":[]}
---

# req_packet.desktop_minesweeper_handoff

## Rule req.desktop.registry

The desktop app registry MUST contain exactly minesweeper, contacts, schedule, shop, backup, settings, and logout.

## Rule req.desktop.host

The desktop host contract MUST model one visible cached app with deterministic focus and navigation outputs; Phase 3 MUST own player-facing composition.

## Rule req.desktop.logout

Logout MUST reject while a Minesweeper round is active and otherwise MUST route through the validated return-to-menu lifecycle.

## Rule req.minesweeper.round_contract

The Minesweeper coordinator MUST apply pre-board autosave, save lock, one validated domain result, post-result checkpoint, and lock release through injected ports.

## Rule req.minesweeper.phase_boundary

Phase 2R MUST provide deterministic round fixtures and contracts only; Phase 3 MUST wire the simulator UI and Phase 6 MUST replace only the board adapter.
