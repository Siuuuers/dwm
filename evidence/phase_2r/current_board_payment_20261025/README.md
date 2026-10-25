# Current board payment — 25 October 2026

## Observable outcome

Discarding yesterday's ordinary board clears its payment status. Today's unpaid
Debug preparation can reuse ordinal 1 without inheriting yesterday's charge.
Its first Reveal consumes exactly one daily round. Paid replacement preparation,
certification and restoration retain payment and do not debit again.

DesktopBoardState owns the required Scene `round_paid` Boolean. GameState owns the
allowance; first Reveal projects and commits both through the existing checkpoint
transaction. Dismissal, departure, reset and day renewal clear the Boolean.
Legacy board snapshots retain their existing contract. Previous development Scene
shapes without the new required field are refused; no migration is added.

## Failure and ownership checks

A failed final reread must retain the original unpaid board and allowance. Retrying
that action commits once; an acknowledged repeat does not debit again. Paid F5 and
difficulty replacements keep their existing identity/ordinal and frozen recipe.
The board's live command ledger and rollback snapshots remain complete.

Independent review checked current snapshot constructors, projections, remapping,
restore, completion, dismissal and departure callers. Initial diagnostics caught
and corrected a typed-variable parse error and fixture omissions before the final
runs. Superseded diagnostic runs are not counted below.

## Linux cloud qualification

Candidate source tree: `2bb35f4eeecff60a4c0ad537428a4a16e2099518`.
Published candidate: `145adb3ca8ea31092550b0f9e69070024cf17ec7` (PR90).
Godot 4.6.3; 208 cases, 2,282 testcase assertions, all passing:

- Six unit suites: 200 cases / 1,876 assertions.
- Day/payment integration: five cases / 214 assertions.
- Three-process create, Load/complete/save, and settled Load: three cases / 192 assertions.

The three connected executions share one isolated storage root and run within one
shell namespace. Their retained proof files record distinct OS process IDs. They
use production owners and physical Save9 storage; they are headless integration
checks, not desktop clicking. Day/payment integration uses production generation
and GameState with the existing checkpoint test seam. Both canonical public
inventories were regenerated after source and test edits.

Reports, connected proof files and SHA-256 digests are in `linux/`.
Full Windows cloud workflow [40160795575](https://github.com/Siuuuers/dwm/actions/runs/40160795575) passed on the published candidate. PR90 merged as `ca54a79c390271ab8ac0ec6511787ade80bc0319`.

Selected Windows reports and inspected restored-board/post-Load shop screenshots
are in `windows/`. Retained archive digests match GitHub metadata. The archived
matched timing lane was skipped for incompatible historical save shape; it is
not a passing performance measurement.

## Remaining work

This fixes current payment inference. It does not remove paid-start proofs or
command history, separate player capture from full live backup, or implement
compact direct reading restoration. It makes no performance claim.

First-board frozen-spec retention must be coordinated with replacing the old
validator's assumption that a wrapper containing `spec` is a replacement. Adding
it alone relaxes original-layout validation. Current replacement specs already
remain frozen. Do not add a new historical marker merely to preserve that obsolete
inference. Scene completion returns directly to GameState before the legacy
coordinator's source-action/round-recovery path; audit actual Scene consumers.
