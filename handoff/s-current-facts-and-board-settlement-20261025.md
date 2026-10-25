# Current facts and board settlement — 25 October 2026

Latest continuation: [current board facts and live retries](t-current-board-facts-and-live-retries-20261025.md).
The successor records qualified PR90/PR91 work and the next reading-restoration task.

Writing reference: [ASD-STE100, Issue 9](https://www.asd-ste100.org/assets/files/ASD-STE100_ISSUE9.pdf).

## Main blocker and next task

Payment status is the next blocker for compact saves. The board currently derives payment status from command history.
The same `capture()` method supplies player saves and live rollback backups.
Removing command history from `capture()` would also remove the retry state that rollback needs.

Investigate current payment status and retry ownership together. Use DesktopBoardState as the owner of current board facts.
Keep the existing BoardSpec shape during this task. Do not redesign its nonce or proof fields.
No new product decision is required.

## Completed recall change

PR88: https://github.com/Siuuuers/dwm/pull/88

Merge revision: `b824a99b913e8b2d84a25b52eeed60a42e4c98c9`.
Qualified runtime: `cfd54e5d47cb515d27cf94c64e739e8b87176906`.
Passing full workflow: https://github.com/Siuuuers/dwm/actions/runs/40154201762.

Current Challenge recall reads `scene_challenge_outcomes`. It refuses missing or ambiguous occurrences.
Its result contains `{kind, outcome, target_id}`. The result no longer contains `closure_command_id`.
Current recall does not read newer Profile attempts.

Historical Load validation still compares each recall with earlier commands. The enclosing validator authenticates these commands first.
The private comparison uses issuer counters to exclude later closures. The change removes redundant wrappers and repeated closure reconstruction.

Unit tests cover all five outcome mappings. The rendered create/Load test covers `never_started`.
Retained screenshots show readable captions and controls.

## Completed board settlement change

PR89: https://github.com/Siuuuers/dwm/pull/89

Qualified candidate: `6b341e0cde34d57791a40c3fee5c66bc75ff85ce`.
Passing full workflow: https://github.com/Siuuuers/dwm/actions/runs/40156027730.
The full workflow passed. The final evidence commit changes no qualified runtime or test behavior.

The earlier candidate was `708b711a3e7d6ad363adc225957fc6952e6f2347`.
Its workflow was https://github.com/Siuuuers/dwm/actions/runs/40155149867.
That workflow failed because a legacy fixture used the changed current-board contract.
The current candidate corrects the fixture.

DesktopBoardState owns `settled_inspection`. GameState saves this fact with ordinary-board rewards and daily counters in one transaction.
Current Scene board snapshots omit `terminal_receipts`. Current completion and departure no longer write that history.
Remapping does not add the omitted field.

Visibility changes and Load preserve settlement. Replacement, dismissal, first Reveal, and day renewal clear settlement.
Structural projection copies preserve the current format. These copies do not acquire payment authority.
The legacy board schema, terminal history, and settlement detection remain unchanged.

Current save contracts reject previous Scene save shapes. No migration is required.
Payment proofs and round retry receipts remain. This change does not complete compact direct restoration.
No measured speed improvement is claimed.

## Evidence and acceptance limits

- [Recall evidence](../evidence/phase_2r/scene_recall_facts_20261025/README.md)
- [Settlement evidence](../evidence/phase_2r/current_board_settlement_20261025/README.md)

The original settlement diagnostics passed 194 cases with 1,943 testcase assertions.
The additional isolated run passed six cases with 218 assertions.
Together, these runs passed 200 cases with 2,161 assertions.
The corrected localization diagnostics passed 178 cases with 28,178 testcase assertions.
Setup added nine assertions.
The full Windows workflow also passed.
Its retained subset contains 184 cases with 28,886 testcase assertions.

The connected settlement test uses three OS processes with one isolated storage root.
The first process saves an unfinished board. The second process loads that board, completes it, applies rewards, and saves it.
The third process loads the settled board. It retries completion twice without additional rewards.

The Windows runner also includes the rendered same-day Supportz test.
That test checks two completions, retained shop eligibility, old completion retries, and a purchase after Load.
Do not describe the headless test as physical desktop clicking. Do not count a skipped archived timing test as a pass.

## Approved payment investigation

Give each required payment fact one owner before removing paid-start history.
Use a current `round_paid` Boolean for payment status.
This Boolean records whether the current round has consumed its allowance.
A paid replacement can use phase `PREPARING` or `PREPARED_UNSTARTED`.
Thus, phase alone cannot determine whether first Reveal must charge a round.

Preserve current payment status through preparation, certification, F5 replacement, visibility changes, and Load.
Preserve the frozen BoardSpec from the first board onward.
Do not reconstruct BoardSpec from current inventory, pressure, or selected difficulty during Load.
Reward difficulty currently falls back to the historical paid-start receipt when no replacement spec exists.

Payment status is false for `NONE` and an unpaid shell. It is true for an active board and a paid shell.
Preparation and certification must retain the incoming payment status.
Dismissal and day departure must clear payment status. This prevents the next round from receiving a free first Reveal.

Inspect these owners before changing the save shape:

- `DesktopBoardState._validate_scene_payments` builds payment anchors from historical `command_receipts`.
- `DesktopBoardState._validate_payment_slots` identifies paid replacements through matching round ordinals.
- `MinesweeperRoundCoordinator` separates the first debit from a paid replacement Reveal. It returns retained first-Reveal results for acknowledged retries.
- `DesktopFirstRevealSnapshotComposer` binds the debit, board, and checkpoint result.
- Presentation and register queries need the current spec. GameState also needs it to determine reward difficulty.
- `DesktopContinuationRemapper` must preserve current state without creating historical receipts.

Keep failed writes and uncertain acknowledgments from adopting live state.
Do not create synthetic admission or payment records during Load.

`GameStateDesktopBoardPort.publish(_publication)` currently checks configuration and returns success. It does not consume the archived payload.
This makes the old publication payload a possible removal target.
Inspect live retry callers before changing the result contract. Keep transaction custody during this change.
Do not charge again on retry.

Separate player-save facts from transient retry state. Preserve transient retry state during live rollback.
Load must start a fresh command session at the restored identity and revision.
Commands from before Load must fail when they are stale.

Trace the capture consumers before changing this boundary:

- `ApplicationBootstrap._capture_live_desktop_snapshot` supplies GameState snapshots and live rollback data.
- `DesktopBoardRestoreParticipant.capture` and `rollback_silent` preserve state when Load fails.
- `MinesweeperRoundCoordinator._ledger_lookup` uses command results for live retry and conflict checks.
- `MinesweeperRoundCoordinator._commit_cost_free_under_lease` uses complete backups for reversible changes.
- `DesktopBoardFatePort` uses complete backups when board departure fails.
- `SaveManagerCheckpointPort.rollback` preserves the existing file-write rollback behavior.

A compact player save must not replace these complete live backups.

Use `test_desktop_paid_replacement.gd` as an existing test reference.
Qualify these behaviors:

- A failed first-Reveal write permits a correct retry.
- Paid F5 and difficulty replacement preserve the round ordinal.
- Save and Load preserve a paid shell and a paid `PREPARING` position.
- A paid certified board permits Reveal after Load without another debit.
- Failed replacement preparation preserves the original board and retry inputs.
- A failed final reread preserves the original board and retry inputs.
- Load of a settled board does not repeat rewards.
- A later adoption failure restores the board and its retry records.
- A later Load participant failure restores the previous live board.
- A publication retry does not charge again after a successful write.

Keep the current forfeit behavior in `DesktopBoardFatePort._fate_for_snapshot`.
It must treat paid preparation as a started board.

## Confirmed next-day defect

A runtime probe reproduced the payment-history collision on master and the current candidate.
Master was `b824a99b913e8b2d84a25b52eeed60a42e4c98c9`.
The candidate was `6b341e0cde34d57791a40c3fee5c66bc75ff85ce`.
Thus, this defect existed before the settlement change.

Day renewal retains board command receipts and resets `minesweeper_app_rounds_finished_today`.
The next round uses ordinal 1 in the same Run with a new causal day.
`_validate_payment_slots` matches payment anchors by Run and ordinal. It does not check the causal day.
The new unpaid Debug preparation fails with `paid_start_receipt_required`.
Both runs retained two available rounds.

The probe uses real board generation, first Reveal, live ordinal allocation, and day renewal.
It uses the existing test checkpoint and native-entry connections. The fixture directly supplies Debug Key.
It does not test rendered interaction or complete Save/Load.
Each run passed 27 assertions that confirm the defect. These assertions are not acceptance results for corrected behavior.

Retain [the defect evidence](../evidence/phase_2r/current_board_settlement_20261025/payment_collision/README.md) for the next task.
Explicit current payment status should remove this historical inference. The correction is not implemented.

Use this sequence for the regression test:

1. Pay for Day1 round 1.
2. Reach Day2 with Debug Key.
3. Start Debug preparation for the new unpaid round 1.
4. Check that preparation starts without payment.
5. Complete board preparation.
6. Reveal a cell.
7. Check that the Reveal consumes exactly one Day2 round.

Do not add a migration workaround.

## Remaining direct-restore work

Reading restoration still needs admission receipts, occurrence, ordinal, predecessor, and notification context.
Reconstruct the current caption or held control from authored DTL and saved facts.
Prepare native presentation before activation. Confirm native presentation before enabling input.

Restoring only the caption is insufficient. Preserve the exact active board, choices, outcomes, economy, inventory, penalties, daily counters, and reward claims.
Do not rewind global read or Gallery records.

Follow [the approved Save/Load design record](../docs/design/2026-10-25-save-load-validator-audit.md).
Keep current choices. Do not invent Day7's missing second authored endpoint.
Do not add an ending selector. Remove approved optional metadata only after replacing its consumers.

## Later owner discussion — 25 October 2026

These notes record the later discussion. They do not claim new runtime changes or test results.

### Day renewal and payment

The owner confirmed that day renewal discards the unfinished board.
Clear that board's payment status when the board is discarded.
Start the new unpaid board with payment status false.
Do not add a day field solely to infer board payment.
Do not consult yesterday's payment receipts to determine today's payment status.
Keep required Run and board identity checks for their separate purposes.

GameState owns the daily allowance. DesktopBoardState owns current board payment status.
Commit the allowance debit and payment status together.
A failed operation must not leave these values inconsistent.
The payment collision described above remains unfixed.

### Temporary Load backup

The owner proposed a backup before Load and accepted the explanation of an in-memory backup.
Use existing owners to preserve the live state that Load can change.
Do not introduce a hidden disk save slot or a new backup manager for this purpose.
A disk backup would add another write and could require the same failing Load path.

Run identity checks establish whether data belongs together.
They do not make updates across owners occur as one indivisible operation.
Two saves from the same Run can also contain different progress.
A partial Load can therefore mix states even when each source has a valid identity.

Prepare and validate the requested save before changing live state.
Keep input paused while installing the prepared state.
Capture the necessary live backup before the first live change.
Discard the backup after successful activation.
If installation fails, restore the previous live state before enabling input.
Use the existing controlled rollback path. Do not replay gameplay effects or start another normal Load.
If rollback fails, keep input blocked. Do not expose a partially restored game.

A player save preserves the facts needed to resume later.
A live backup must also preserve relevant pending operations and genuine retry results.
Audit actual callers before retaining each temporary field.
Do not require all historical receipts merely because the current backup contains them.

Retry handling prevents the same operation from charging or mutating state twice.
A retry is another attempt at the same operation, not an ordinary second player action.
Successful Load starts a fresh command session.
Failed Load must preserve the prior session state needed to continue safely.

### Testing and completion status

The owner requested explanation only during this discussion.
Do not run new tests or benchmarks solely for these questions or this documentation update.
Defer final acceptance and performance measurement until the planned implementation is ready.
This request does not establish that untested implementation is qualified.

The original PR83 optimization is complete.
The broader compact-save replacement remains incomplete.
Payment status, separate live backups, direct reading restoration, and approved payload omissions still need work.
Passing functional tests does not establish smooth Save/Load performance.
The original Windows diagnostic timings are historical source-project measurements.
They are not current installed-game timings.
Do not claim a new speed improvement without a matched complete-operation measurement.

## Work instructions

Check live master before starting. Do not repeat merged work.
Use separate processes and storage roots for incompatible fixture registrations.
Run fresh-process tests inside one shell namespace in this cloud environment. This makes process-ID comparisons meaningful.
Keep `DWM_TEST_ROOT` inside the checkout for test bootstrap selection.

Regenerate both canonical public inventories after the final source and test changes. Their caller metadata includes line positions.
Complete independent audits before the final candidate run.
Use Windows cloud CI for native rendered acceptance.
Retain artifact digests, selected reports, and inspected screenshots.
