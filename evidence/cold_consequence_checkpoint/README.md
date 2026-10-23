# Cold consequence checkpoint verification

2026-09-13; `dwm-634.5`; baseline `32e874b14`.

## Contract and change

A transient checkpoint whose issued proof is absent must be reproducible by
the same builder that prepares new checkpoints. This is a self-consistency
contract, not authentication of arbitrary caller-authored content. It preserves
the existing builder's header/source acceptance rules rather than introducing
stricter rules only after eviction. Completed-action Autosave recovery is unchanged.

The existing construction body is now a pure private helper. Public preparation
still checks readiness and then remembers its successfully built record.
Cold commit keeps the existing receipt-equality, canonical round-trip, shape
and record-key checks; it then validates the stored consequence state and
rebuilds the record. The entire rebuilt record must match the normalized input.

Initial admission needs one inverse step: its newly attached admission receipt
was absent from the original preimage. On the detached state returned by
validation, both receipt fields are cleared only when `sequence_committed`
has admission receipt equal to the current record receipt. A repeated admission
with an older admission receipt preserves it. The same existing preimage builder
then handles later stages and terminal cleanup. No receipt/hash construction law
is duplicated, and rejected cold candidates cannot change the proof cache or
transient records. The normal exact-issued-record fast path is unchanged.

## Verification

The first red run exposed the missing boundary, but shared state caused later
mutation cases to encounter an already-poisoned slot. The amended red run uses
independent ports and evictions: all six inconsistent inputs were accepted by
the old implementation. It ended with 28/29 tests passing and 23 failed assertions.
Both development runs are retained in the run ledger.

The fixed checkpoint/State/coordinator/retry group passed 105 tests / 1,522
assertions. The surrounding publication, save-validation, continuation and
Minesweeper integration group passed 150 tests / 4,753 assertions.
The final focused port run passed 29 tests / 765 assertions after extending
the fixtures to cover every currently supported ordinal: 0, 1, 2, 8, 9, 10, 11, 12.
Ordinal 1 uses the production admission-ready payload builder with fixture
action contents; this proves its transport shape, not a full gameplay replay.
Ordinal 11 comes from the third `board_fate` publication callback.

The tests cover initial and repeated admission, exact later/terminal records,
numeric-type and value changes, inconsistent header/receipt fields, altered
digests and IDs, invalid ordinal/stage pairing, original retry after refusal,
and valid changed content reaching the existing occupied-slot conflict rule.
Independent production review found no blockers.

The regenerated inventories retain all 239 GameState and 74 SaveManager public
contracts; only call-site locations changed, and the dynamic-reference sets are
identical. The repository gate passed 14 tests / 410 assertions. Across the final
focused, integration and repository suites, this is 269 distinct tests / 6,700
assertions (the final port rerun replaces its earlier 750-assertion version).

All runs use `Invoke-IsolatedGodot.ps1` serially with temporary user directories.
The archived logs and `runs.jsonl` retain commands and actual exits. No player
save directory is used. Existing Dialogic orphan and malformed-string fixture
diagnostics are retained rather than hidden.

## Native gameplay and timing limits

Four Windows/OpenGL runs completed Expert App win/loss and Dating win after
persisting the authored Day-1 Lavinia reply in Simplified Chinese. One used the
baseline port; two used the unchanged final candidate; the diagnostic run added
only the two prints in `branch-diagnostic.patch` and enabled the existing
`DWM_CHECKPOINT_PROFILE=1` environment variable. These are automated production
paths, not physical OS click-to-paint measurements or a whole-UI locale audit.
The diagnostic patch has zero context lines; reproduce it with
`git apply --unidiff-zero evidence/cold_consequence_checkpoint/branch-diagnostic.patch`
in an isolated checkout and reverse it after the diagnostic process exits.

The adjacent baseline/current controls used the same arguments but generated
different boards and history lengths:

| Observation | Baseline control | Current control |
| --- | ---: | ---: |
| App win settled | 831.744 ms | 1,915.408 ms |
| App loss settled | 850.086 ms | 1,748.839 ms |
| Dating win settled | 435.297 ms | 1,011.422 ms |
| App initial reveal | 242.307 ms | 233.645 ms |
| App later new-board reveal | 438.640 ms | 941.374 ms |
| App later routine median | 54.064 ms (228 inputs) | 64.082 ms (233 inputs) |
| Dating first reveal | 271.376 ms | 690.859 ms |
| Dating later routine median | 18.574 ms (51 inputs) | 46.406 ms (15 inputs) |

The slower current observation is retained, not presented as a speedup or
explained away as proven machine noise. Timing also varies on unchanged paths,
and the changing workloads prevent causal attribution from this pair.
The follow-up diagnostic established **14 exact-issued fast commits and zero
cold commits** during the same three outcomes. Therefore the new reconstruction
work did not execute during that run's terminal delays (App win 1,581.773 ms,
loss 1,682.671 ms; Dating win 991.234 ms). Both independent code reviews also
found no hot ownership/cache change. This supports the correctness closeout;
it is not a claim of timing parity or an explanation of every source of lag.

The final production file was restored byte-for-byte after both temporary
baseline replacement and diagnostic insertion. Its SHA-256 is
`3892e03966d5c3120fee9ff2609c9e5fd5f7deba430078139136a04829347030`.
The final inventory/repository checks ran after restoration. `runs.jsonl`
contains all 12 attempts: 10 passes and the two explained red development runs.

The next bounded performance candidate is `dwm-634.6`: remove redundant metadata
from already-compacted routine receipts while preserving transaction IDs,
fingerprints, exact retry results, first-reveal proofs and recovery behavior.
Read-only ablation of the fixed 423,637-byte Chinese save suggests 95,850 bytes
(22.63%) can be removed across its three ledger snapshots. Runtime improvement
is unmeasured and requires separate implementation and comparison.

The performance parent `dwm-634.3` remains open: this correctness change adds
validation only to cold records and does not claim to remove terminal latency.
