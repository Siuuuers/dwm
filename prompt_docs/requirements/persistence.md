---
id: req_packet.persistence
kind: requirement_packet
schema_version: 1
specification_status: approved
beads: ["dwm-p2r.3","dwm-p2r.5","dwm-p2r.9","dwm-p2r.13","dwm-p2r.15","dwm-p2r.16","dwm-oyo.3","dwm-oyo.4"]
requirements:
  - {"id":"req.profile.partition","depends_on":["req.runtime.sole_owners"],"implementation_evidence":[],"verification_evidence":[]}
  - {"id":"req.save.snapshot","depends_on":["req.runtime.game_state_facade"],"implementation_evidence":[],"verification_evidence":[]}
  - {"id":"req.save.journal","depends_on":["req.save.snapshot"],"implementation_evidence":[],"verification_evidence":[]}
  - {"id":"req.save.desktop_board_continuity","depends_on":["req.save.snapshot"],"implementation_evidence":[],"verification_evidence":[]}
  - {"id":"req.save.schedule_state","depends_on":["req.save.snapshot","req.schedule.state_models"],"implementation_evidence":[],"verification_evidence":[]}
  - {"id":"req.save.schedule_migration","depends_on":["req.save.schedule_state","req.save.migration"],"implementation_evidence":[],"verification_evidence":[]}
  - {"id":"req.save.restore_atomic","depends_on":["req.save.snapshot","req.profile.partition"],"implementation_evidence":[],"verification_evidence":[]}
  - {"id":"req.save.migration","depends_on":["req.save.snapshot"],"implementation_evidence":[],"verification_evidence":[]}
  - {"id":"req.save.test_isolation","depends_on":["req.test.isolation"],"implementation_evidence":[],"verification_evidence":[]}
---

# req_packet.persistence

## Rule req.profile.partition

Permanent preferences, gallery unlocks, visited history, and input mappings MUST live in ProfileManager and MUST NOT be stored as active-run fields.

## Rule req.save.snapshot

A run snapshot MUST contain only strict primitive JSON representing the exact narrative, desktop-board, Schedule view, committed Schedule, Hospital-resolution variant/delivery, and decision state at a compatible stable checkpoint.

Schedule-derived day resolution and pre-Done condition-Hospital resolution MUST persist as closed, discriminated variants. Whenever either variant selects Hospital, it MUST retain a common closed Hospital recovery record containing the causal day identity, the canonically ordered exact issuer-validated accepted/read still-unfulfilled source receipts/provenances, one Hospital-miss receipt/provenance per source, optional Sylvia-witness receipt/provenance, recovery stage/cursor, and stage-gated Hospital-admission or durable-acceptance, Hospital-presentation, optional deferred-pair, and day-advance receipts. Every null/non-null receipt slot MUST agree with the validated variant and cursor.

The Schedule-derived variant MUST additionally retain the ledger-verified successful Done/commit ancestry and actual ordered committed Schedule and MUST reject a synthetic or caller-authored Schedule and post-action condition ancestry. The condition-Hospital variant MUST instead retain the exact committed action and condition receipt/provenance and MUST reject Schedule commit/Done ancestry, draft-as-scheduled facts, and any promotion of the ScheduleView. Both variants MUST reject scene objects, callbacks, and caller-authored IDs. A persisted Sylvia-witness receipt in either variant is unapplied handoff truth, not a relationship-effect or caring-history application receipt; restore MUST preserve it until the separately owned `dwm-oyo.4` transaction consumes it exactly once. All nested values MUST remain strict primitives and validate before restore mutation.

For destination delivery, `published=true` means only that the designated durable resolution owner accepted the exact outbox item and receipt. Separate persisted completion truth MUST prove Hospital presentation, any deferred pair resolution/presentation, and day advance; restore MUST keep input blocked and resume the first incomplete stage rather than treating acceptance as presentation or redelivering already completed effects.

## Rule req.save.journal

Checkpoint persistence MUST use monotonic bounded journals with canonical serialization, integrity validation, and crash reconciliation. An admitted condition-Hospital journal MUST recover forward through exact source closure/misses, optional witness, durable delivery acceptance, Hospital presentation, deferred pair, and day advance; retry MUST neither duplicate an effect nor reopen desktop between stages.

## Rule req.save.desktop_board_continuity

Minesweeper MUST NOT impose a lifetime save lock. Manual Save, quick Save, Logout, app switching, and crash recovery MUST serialize or restore the latest stable exact candidate or board state without finishing, refunding, rerolling, or forfeiting it.

The canonical identity issuer's namespace, monotonic counter, root-receipt ledger, and allocation receipts MUST live outside selectable run snapshots and MUST NOT roll back when an older save is selected. A selected Load preserves source identities only as provenance and durably allocates its fresh branch, desktop-generation, and causal-day identities before live restore publication; duplicate restoration of the same transaction reuses that allocation.

New Run and selected Load MUST also use a durable continuation-operation journal outside every selectable snapshot. The journal MUST record the operation token, semantic source locator and integrity hash, exact recovery stage, allocation receipt, and candidate fingerprint before an irreversible allocation or participant mutation. Startup reconciliation MUST either resume the same verified source and allocation or fail closed; an in-memory restore journal or a root counter alone is insufficient.

## Rule req.save.schedule_state

Canonical committed Schedule and saved-but-uncommitted ScheduleView MUST be separate, strictly validated restore participants. Restore MUST preserve nested detachment, same-day view identity, pending warning activation, the date-seen latch, consumed warning receipts, and condition-departure receipt ledger without treating draft entries or a condition-departure receipt as canonical scheduled actions or Schedule commit ancestry.

## Rule req.save.schedule_migration

A legacy save with missing or empty Schedule state MAY normalize to the new empty defaults. Any nonempty pre-amendment Schedule representation MUST fail closed with `unmigratable_legacy_schedule`, leave the source unchanged, and MUST NOT invent registry facts, IDs, ancestry receipts, warning state, or commit transactions. Migration MUST NOT infer condition-Hospital source, miss, witness, delivery-acceptance, presentation-completion, deferred-pair, or day-advance truth from a pending-Hospital flag, a Schedule draft, or an outbox boolean; incomplete nonempty state without the required primitive ancestry MUST fail closed.

## Rule req.save.restore_atomic

Restore MUST prepare every participant, apply silently, roll back all applied participants on failure, and publish signals only after the complete candidate commits.

## Rule req.save.migration

Legacy saves MUST migrate through explicit schema versions, reject active Day 8, obey the explicit Schedule migration boundary, and restore the nearest earlier compatible checkpoint only for failure classes that lawfully permit checkpoint fallback.

## Rule req.save.test_isolation

Persistence tests MUST inject storage beneath the GUID-scoped test root and MUST NOT read, write, reconcile, or remove production user data.
