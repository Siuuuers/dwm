# Unshipped development-save policy — 29 September 2026

## Synchronous snapshot validation clarification — 25 October 2026

Run9 normalization already creates a detached snapshot, and installed story
registration returns a detached bundle. Production semantic validation reads these
synchronously. It does not yield, publish gameplay state, or advance playback.
Repeated copies and before/after hashes solely to detect an injected callback
mutating these inputs are not supported gameplay requirements.

Keep the ordinary pre-call checks for registration, shape, receipts, current
physical Profile proof, historical frames, and native anchors. Keep returned
snapshots detached from caller inputs. Review this boundary if production semantic
validation introduces mutation, asynchronous work, or gameplay publication.
This clarification does not authorize removing semantic validation itself.

## Terminal validation clarification — 25 October 2026

Current supported gameplay does not require two complete ledger traversals inside
one synchronous terminal/source-reading validation. The concrete production issuer
root only reads its loaded state during terminal reconstruction. That interval has
no yield, signal publication, write, or allocation commit. The source checkpoint
may use the ledger authenticated earlier in that same call.

Keep source-checkpoint shape, registration, occurrence, immutable-frame and caption
checks. Independent public calls and later restore phases still validate fresh.
There is no persistent validation cache or public skip flag.

The injected root proxies in PR #80 deliberately changed Profile/root state inside
this otherwise read-only interval. Those tests demonstrated an additional callback
contract, not a reachable ordinary gameplay failure. Their requirement for a second
ledger traversal is superseded here. Concurrent external file edits and injected
mid-call owner mutations are not supported gameplay requirements. Invalid state
present before a public validation call must still be refused.

If production reconstruction later yields, publishes signals, writes state, or
introduces mutable callbacks, review this local reuse boundary. This clarification
does not remove source-reading validation, Save ownership, or ordinary gameplay
correctness. Runtime qualification is recorded separately from this policy.

## Current amendment — 24 October 2026

The [startup and Load handoff](../../handoff/a-startup-load-handoff-20261024.md) records the latest approved contract and supersedes the compatibility and deterministic-recovery requirements below. Only valid current-build saves are supported; old development saves may be discarded. Malformed/incomplete data, migration, repair and recovery are not product requirements.

Backup lists basic slot metadata without preparing restoration. Save and Delete do not require the existing file to be restorable. Load applies the selected current snapshot; it never substitutes an older compatible checkpoint. Ordinary gameplay correctness still applies: exact board and dialogue state, complete-line presentation, and no repeated rewards or consequences. File-operation failure is reported simply. SaveManager remains the canonical owner.

The remaining sections preserve the earlier decision for provenance. This amendment is a policy record, not test evidence.

## Owner-confirmed decision

The owner confirmed on 29 September 2026 (Hong Kong) that DWM has not shipped
and that older development saves must not constrain the ongoing redesign.
Compatibility decisions within the already-delegated project work are engineering
decisions; they do not require another legacy-save permission interview.

This decision covers obsolete development Run documents and Profile formats,
including their historical caption, visited and achievement data. A successor
may require a clean start. Migration, backfill and continued readers for those
superseded formats are optional, and may be omitted when they add unnecessary
complexity. Do not retain a compatibility layer solely to rescue unshipped data.

## Consequences for the next implementation

- The next narrative/save format can describe its required semantic session and
  immutable entry frames directly. It need not support existing Run7 or Profile
  development records merely because they predate that format.
- The proposed legacy-History gap versus unavailable-History choice is retired
  as a required product decision. No legacy caption reconstruction or gap UI is
  required solely to support superseded development formats.
- An incompatible change still needs a deliberate version/contract boundary.
  Unsupported data must be recognized and refused, rather than silently treated
  as current data or supplied with invented captions, receipts or achievements.
  A migration that is deliberately retained must have explicit admission and
  verification rules; optional support is not permission for guessed conversion.
- Within each supported format, ordinary older checkpoints remain supported by
  the selected save/load contract. Exact boards, chronology, monotonic Profile
  history, branch isolation, journal integrity, atomic writes and deterministic
  recovery continue to be correctness requirements. In particular, loading an
  earlier same-format checkpoint must not erase its newer Profile ledger.

This removes an obsolete-format obligation. It does not change authored story
rules, approve production dialogue, or weaken the correctness of a format we
choose to support. Existing test evidence and historical fixtures remain useful
records of the source they tested.

## Supersession and implementation status

This owner decision supersedes mandatory preservation/migration of unshipped
Run7 and Profile development saves in the current handoff, reading next-slice
proposal and earlier Beads notes. It narrowly amends the migration obligation in
`req.save.migration` and section 14.4 of the seven-day Dialogic-flow design;
their current-format durability and recovery rules continue to apply.

This records update does not change runtime schemas, supported readers, stored
files or task statuses. A later implementation should remove compatibility work
when it actually simplifies the selected design, with tests for the resulting
supported format and explicit refusal boundary. The remaining Solo Dating
wording/staging selector question is independent of this decision.
