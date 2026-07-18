---
id: req_packet.persistence
kind: requirement_packet
schema_version: 1
specification_status: approved
beads: ["dwm-p2r.3","dwm-p2r.5"]
requirements:
  - {"id":"req.profile.partition","depends_on":["req.runtime.sole_owners"],"implementation_evidence":[],"verification_evidence":[]}
  - {"id":"req.save.snapshot","depends_on":["req.runtime.game_state_facade"],"implementation_evidence":[],"verification_evidence":[]}
  - {"id":"req.save.journal","depends_on":["req.save.snapshot"],"implementation_evidence":[],"verification_evidence":[]}
  - {"id":"req.save.minesweeper_lock","depends_on":["req.save.snapshot"],"implementation_evidence":[],"verification_evidence":[]}
  - {"id":"req.save.restore_atomic","depends_on":["req.save.snapshot","req.profile.partition"],"implementation_evidence":[],"verification_evidence":[]}
  - {"id":"req.save.migration","depends_on":["req.save.snapshot"],"implementation_evidence":[],"verification_evidence":[]}
  - {"id":"req.save.test_isolation","depends_on":["req.test.isolation"],"implementation_evidence":[],"verification_evidence":[]}
---

# req_packet.persistence

## Rule req.profile.partition

Permanent preferences, gallery unlocks, visited history, and input mappings MUST live in ProfileManager and MUST NOT be stored as active-run fields.

## Rule req.save.snapshot

A run snapshot MUST contain only strict primitive JSON representing the exact narrative and decision state at a compatible checkpoint.

## Rule req.save.journal

Checkpoint persistence MUST use monotonic bounded journals with canonical serialization, integrity validation, and crash reconciliation.

## Rule req.save.minesweeper_lock

Entering a Minesweeper board MUST autosave the pre-board checkpoint and disable manual saving until result application or trusted rollback releases the lock.

## Rule req.save.restore_atomic

Restore MUST prepare every participant, apply silently, roll back all applied participants on failure, and publish signals only after the complete candidate commits.

## Rule req.save.migration

Legacy saves MUST migrate through explicit schema versions, reject active Day 8, and restore the nearest earlier compatible checkpoint when an exact checkpoint is unavailable.

## Rule req.save.test_isolation

Persistence tests MUST inject storage beneath the GUID-scoped test root and MUST NOT read, write, reconcile, or remove production user data.
