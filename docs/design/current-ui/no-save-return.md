# No-save Return to Title

This implements the accepted Shared Shell section 12.6 in stages under `dwm-eei.3`.
The all-ten-family UI goal remains active. Return is not yet mounted in production.

## Required result

The confirmation keeps Cancel focus, Back cancels, the sheet owns Warning, and
Return owns Danger. Confirming must prepare Title before discarding the live
continuation. A failed preparation preserves the original scene and Pause.

No new Autosave, Quick save, numbered save, fallback, saved-time change, Logout,
board reset/result/reward/refund, completion, day advance, relationship effect or
Gallery receipt belongs to this operation. Existing save and Profile bytes remain
unchanged. Title uses pending-next-run palette, truthful clock and New Acc focus.
Only the application lifecycle and route owners perform abandonment/publication.

## Implementation decision

Keep shared autoload services alive and retire the session explicitly. Reloading
Title leaves the old live owners intact. Restarting the application discards the
source before successor preparation can be proved and runs write-capable startup
recovery. Rebuilding every autoload would duplicate immutable binding work.

One process-local operation can hold an exact source revision, prepared Title and
dedicated `session_abandonment` mutation-gate lease. It needs no new player-save
format or durable abandonment journal. Admission checks incompatible work before
any discard; Cancel remains available before retirement. Partial retirement keeps
the same operation in covered recovery, with no false Continue or fresh operation.

## Prepared routing and input prerequisites

SceneRouter's existing restore preparation proves a registered PackedScene only.
The Return path instead retains an actual off-tree Menu instance and opaque token,
bound to the exact live source and a route revision that rollback cannot rewind.
Validation checks that source before retirement; publication mounts the retained
instance under abandonment custody. Successful publication also advances the
restore-route generation, refusing older prepared route tokens while admitting
fresh plans. An unresolved semantic route restore refuses
Return rather than being erased; its original owner can finalize or roll it back. Off-tree instantiation is not a claim that
Menu has completed `_ready`, rendered layout or the whole Return transaction.

InputManager retires the exact suspension handle under abandonment custody. It
preserves the physical-contact ledger and monotonically increasing contact IDs,
quarantines held contacts and the closing frame, and does not fabricate release
packets. Repeating the same retirement does not quarantine later fresh input again.
Retired suspension IDs cannot be reacquired. The coordinator must recheck state
after callbacks and keep source/successor interaction covered until complete.
Title consumption of this custody still needs combined native validation.

If authority changes while the prepared Menu enters the tree, routing removes and
frees that attempted target and invalidates its preparation. Its `_ready` callbacks
have already run, so reusing that instance would not restore pristine preparation.
The stale-token result does not promise same-token Retry. The complete Return
coordinator still needs an explicit forward-recovery policy after retirement;
this prerequisite must not be wired as a complete discard-and-Retry transaction.

## Remaining owner integration

The next stage must invalidate installed GameState session/snapshot admission and
SaveManager's transient Current/prepared capabilities without resetting canonical
facts, emitting a save-related signal or changing durable records. It must retire
ordinary Hospital playback and its physical completion tokens before teardown can
emit a native end signal. Existing `abort_current_entry` does not own that ordinary
playback. Input, Audio and Pause require retirement rather than ordinary resume.
Freeing the old scene disposes its visual caches; retained service caches need their
own narrow invalidation. Title publication follows proven retirement.

| Boundary | Required proof |
| --- | --- |
| Preparation fails | Original source, focus and Pause survive; no owner retirement or save write. |
| Source changes | Old token cannot publish or abandon a replacement scene. |
| Partial retirement | Source remains covered; exact operation can recover without fabricated completion. |
| Success | Same prepared Title mounts once; old session/input/native callbacks are unusable. |
| Persistence | All nine saves/fallbacks, saved times and durable Profile facts remain unchanged. |
| Subsequent play | A fresh New Acc or Load works; abandoned Current cannot be saved or resumed. |

The current qualified Pause source is ordinary Hospital at a real native Text
frontier. Its shipped timeline has no reading caption; native fixtures identify
synthetic prose explicitly. Dating, challenges, ordered endings, Logout's stable
board capture and external Schedule/save compatibility remain separate unfinished
work. No presentation fixture can establish those missing owner/content contracts.

## Session fence integration map

The read-only owner audit identified GameState as the narrow session-generation
owner: it already owns validated run installation. A future monotonic process-local
handle must distinguish inactive state from a later active run; an active boolean
alone cannot reject an old callback after Load/New Acc. It must not be serialized
or rewound by restore rollback. Keep raw `capture_run_snapshot_input()` available
for dormant-state inspection and introduce capability-bearing production capture,
rather than changing its widely used Dictionary shape.

Production capture and prepared-commit consumers include Bootstrap's retained
providers, GameStateDayResolutionPort, GameStateDesktopBoardPort,
SaveManagerCheckpointPort, SaveManagerNarrativeCheckpointPort, prepared restore,
Backup/Quick candidates and schedule commits. DayResolution and Minesweeper
completion callbacks, presentation commands, and causal/consequence continuations
must bind the originating handle and revalidate it. In particular, narrative
checkpoint boundary keys currently omit run identity; that process-local cache
must be scoped or invalidated. A new generation must not revive old candidates.

This map is unfinished implementation work, not an implemented session fence.
The routing/input prerequisite alone proves neither abandoned snapshot refusal
nor unchanged durable storage under a complete Return operation.

## Prerequisite checkpoint validation

The final focused batch passes 38 tests and 541 assertions across six suites:
prepared Title routing, input retirement, existing native Pause input, mutation
custody, startup route holding and real-owner startup publication faults. New
regressions were observed failing before implementation. Review additionally
reproduced retired-handle reacquisition, pending-restore overlap and old restore
route-token admission; each has a passing regression. The earlier test parser
failure is retained separately from intended failing-behavior evidence.

The evidence package records source hashes, exact invocations, all test attempts
and isolated production Title/New Acc plus cold resume checks. There are no new
visual assets or rendered-capture claims in this checkpoint. The actual prepared
Menu mounts in route tests with explicit presentation-service fixtures; production
startup/resume is a separate regression, not a complete Return exercise. Existing
Dialogic orphan/shutdown and Unicode diagnostics remain acknowledged. See
[evidence/return_title_prerequisites/summary.json](../../../evidence/return_title_prerequisites/summary.json).
