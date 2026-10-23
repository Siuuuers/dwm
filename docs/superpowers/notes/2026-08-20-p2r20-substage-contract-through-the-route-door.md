# dwm-p2r.20: the route door completed substages against no contract at all

**Why this file exists.** The fresh-context review of `dadb8680a` found this while checking that
change, and it was filed rather than folded in, because it is a stage/substage confusion and that
fix was scoped to route/presentation. This is that bead worked.

`dwm-p2r.14`, `.18` and `.19` all remain open. Nothing was closed and nothing was pushed.

## The defect, in both directions

`DayResolutionCoordinator.complete_route_stage` read `stage_id` off the resolved command and nothing
else. A substage command carries its *parent's* `stage_id` — `resume()` adds `substage_id` as an
extra key rather than replacing it — so:

**It failed closed.** The pre-check called `_validate_envelope(parent_stage_id, receipt)`, so a
legitimate `schedule_entry_complete` envelope died on `kind mismatch for execute_schedule_actions`.

**It failed open, which is the serious half.** It built the record for `_commit_completion` as
`{stage_id, transaction_id}` with no `substage_id`, so that function's selector
(`_validate_substage_envelope` when `substage_id != ""`) took the stage branch. The parent stage's
own aggregate envelope therefore *passed*. And then `RunLifecycle.complete_active_stage` skips
`_validate_owner_receipt` entirely when `record["kind"] == "substage"`, trusting this caller to have
already chosen the right table. **So a substage completed through this door met no contract check
whatsoever**, and persisted whatever bytes it was handed.

`complete_presentation_stage` has always forwarded `substage_id` correctly. This was one door of two
disagreeing about what the record is.

## Reachability: the whole door is sealed, not just this path

`GameStateDayResolutionPort.begin_next_stage` is the only production producer of
`await_registered_command`, and it enters that branch only when `presentation_request` is non-empty.
Since `dadb8680a`, `complete_route_stage` refuses exactly that with
`presentation_completion_required`. So **every** production command this door could be handed is
refused before any of the above runs — substage or top-level.

An earlier draft of this reasoning said "a `surviving_date` substage always carries a
`presentation_request`". That is not quite true — a *superseded* date has an empty presentation site
and completes immediately, never awaiting. The correct claim is the stronger one above, and it is
what the tests say.

This is therefore a sealed-defect fix: it guards the door against its next caller. That is the same
footing as the `SUBSTAGE_CONTRACTS` docstring, which records that the table was dead for a whole
phase because a validator selection was assumed rather than made.

## The fix, and why it deletes code instead of adding it

The obvious repair was to mirror the selection in the pre-check. The review rejected that, and it was
right: `_commit_completion` makes this exact selection itself, and makes it **before** it captures
anything (`:563-565` validates, `:566` is the first `capture()`). So the pre-check bought no earlier
refusal, no different result bytes, and no different call log — only the opportunity for the two
copies to disagree, which is precisely what this defect was.

So the pre-check is **deleted**, and the record gains its `substage_id`:

```gdscript
	var completed := _commit_completion({
		"stage_id": str(command["stage_id"]),
		"substage_id": str(command.get("substage_id", "")),
		"transaction_id": transaction_id,
	}, receipt)
```

One validator, one selection. Read off the **resolved** command, so the `_registered_history`
fallback answers the same way — the same reason the presentation refusal above it is asked of
`command` rather than `_awaiting`.

Worth recording that this is the *opposite* disposition from the one taken an hour earlier, when a
shared-predicate extraction was declined on scope grounds. The difference is real rather than
convenient: that change would have **added** an abstraction; this one **removes** a duplicate that
had already produced a defect.

## Test support: a parameter that had been dead since it was written

`FakeDayResolutionStatePort.seed_playing_day` declared its third parameter `_schedule` and never read
it; `begin_or_resume` hardcoded `{"entries": []}`. **Every plan the unit suite has ever built had
zero substages**, which is why the coordinator's substage branches were unreachable from it and why
this survived. The parameter is now honored. Backward compatible: both pre-existing call sites pass
`[]`, yielding the byte-identical empty aggregate.

Three further fake corrections, all so it stops modelling things production does not do:

- `_registered_command` and the `complete_immediately` branch now both return a **substage-kind**
  envelope for a substage instead of the parent's aggregate — the pre-Task-7 conflation the
  production port removed. The `complete_immediately` half was missed on the first pass and caught by
  the review.
- `_substage_receipt` derives `entry_receipt_id` from the substage id's fourth field, as production
  does, instead of a fixed literal. Without that, no test could tell an implementation that routed
  one entry's receipt to another entry's substage.
- Honest framing: the `_registered_command` change is documentation, not correctness. Nothing in the
  coordinator or any test reads `owner_id`/`kind` back off a registered command.

The domain boundary is what it accepts: `DayResolutionPlan.create` reads exactly
`schedule_entry_id`, `slot_index` and `action_kind` off each entry and discards the rest, so a
three-key entry is the honest minimum rather than a half-built `ScheduleStateSchema` aggregate.

## Evidence

**RED first, observed, no script errors.** 30 tests, 27 passing, exactly the 3 new ones red,
294/305 asserts. The legitimate substage envelope was refused with
`invalid_receipt: kind mismatch for execute_schedule_actions`; the parent aggregate was accepted
(`ok: true`, walk advanced) and the substage read `completed`.

**A first RED run that errored was not accepted as RED.** The persisted-receipt assertion cast a
null receipt to `Dictionary` and threw. A RED run must fail on its claim, not on the harness, so the
helper was made cast-safe and RED was re-observed clean.

**Mutations, each proving a different claim, all reverted.** Suite alone 27 / 283 before,
30 / 305 after.

| Mutation to production source | Observed | What it proves |
|---|---|---|
| drop `substage_id` from the `_commit_completion` record | 30 tests, 27 passing, **3 red** (all three new), 294/305 | the argument dict is the fix, not the validator |
| `_commit_completion` always uses the STAGE validator | 27 passing, **3 red**, 294/305 | the substage branch is load-bearing *from this door* |
| `_commit_completion` always uses the SUBSTAGE validator | 5 passing, **25 red**, 196/253 | top-level stages still answer to `STAGE_CONTRACTS`; the door was not widened |
| read `substage_id` off `_awaiting` instead of the resolved command | 29 passing, **1 red**, 303/305 — the history test | the `_registered_history` path is genuinely covered |
| delete `_launched_transaction = ""` | **30 / 305, all green** | reported, not hidden: see Honest limits |

The fourth of those is the one worth dwelling on. The review *predicted* it would stay green and
recommended adding a history test; that test was added, and it is now the only thing that mutation
turns red. Reviewing the RED before writing the production line is what bought that.

**Observed gates.** Baselines at `dadb8680a`. All exit 0, no `SUITE_NOT_EXECUTED`, orphans 24.

| Gate | Baseline | Observed | Delta |
|---|---|---|---|
| `hospital_dating_adapter_gate` (18 scripts) | 246 / 5260 | **249 / 5282** | +3 / +22 |
| Step 7.7 `hospital_order_green` (11) | 153 / 2079 | **156 / 2101** | +3 / +22 |
| guarded-path regression (5) | 74 / 3037 | **77 / 3059** | +3 / +22 |
| Step 8.8 `presentation_day7_green` (12) | 164 / 1947 | **164 / 1947** | unchanged |
| doc tooling (5) | 24 / 1635 | **24 / 1635** | unchanged |

Every delta accounted for: the coordinator suite alone moved +3 / +22, the three gates listing it
moved by exactly that, Step 8.8 does not list it and was RUN rather than assumed. Deleting the
pre-check changed no existing test, which was the review's prediction and is now observed.

## Honest limits

- **`_launched_transaction = ""` in this function has zero test cover, before and after.** Deleting
  it leaves everything green. It is unreachable on every path that exists: a command with a
  presentation is refused earlier, and a history-resolved command whose stage is already completed
  returns `duplicate_transaction` before the clears. The line is defensively correct and was left
  alone as pre-existing, but nobody should believe it is proven.
- **Two sibling gaps filed rather than fixed.** `dwm-p2r.21`: `GameState` exposes only the route
  door, so the sole publicly reachable completion seam currently refuses every production command.
  `dwm-p2r.22`: a replayed substage completion never reports `duplicate_transaction`, because the
  duplicate scan walks `stages` and not `substages`.
- **The live substage path is not unit-coverable with this fake.** A surviving-date presentation
  settling through `complete_presentation_stage` is the only substage path production reaches, and
  `FakeDayResolutionStatePort.presentation_stage_receipt` cannot model it — `_stage_id_for` scans
  `stages` only. It is covered in `test_committed_schedule_presentation_matrix.gd` and
  `..._resume.gd`, so it is not unproven; but the unit suite does not hold that contract.
