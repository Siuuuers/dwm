# dwm-p2r.14: the route door could settle a stage that was showing a scene

**Why this file exists.** The `dwm-p2r.18` cold review found this defect, named it precisely, and
deliberately left it unfixed — the last paragraph of that bead's 2026-08-20 comment records it as
"pre-existing and untouched by these commits, but `34756475b` now hangs the re-entry invariant on
that clearing site", and files it as the maintainer's call rather than as work. This is that call
being taken. It is squarely inside `dwm-p2r.14`'s acceptance criteria, which require the adapters to
"accept only matching completion receipts exactly once".

`dwm-p2r.14`, `.18` and `.19` all remain open. Nothing was closed and nothing was pushed.

## The defect

`DayResolutionCoordinator` has two doors into a completed stage.
`complete_presentation_stage()` is the one a scene's receipt comes through, and it is careful: it
requires a retained port completion, and it binds that completion's `receipt_id` to the awaiting
command's own `completion_transaction_id` before it will settle anything.

`complete_route_stage(transaction_id, receipt)` resolved its command by transaction id — from
`_awaiting`, else from `_registered_history` — and then never asked what that command was waiting
*for*. It has neither of the above checks. So a receipt that is entirely legal for the stage
(`STAGE_CONTRACTS["hospital_if_triggered"]`: owner `hospital_rules`, kind `hospital_resolution`,
`presentation_completion_receipt: null`) passed `_validate_envelope` unchanged, committed, cleared
`_awaiting`, and resumed the walk while the Hospital scene was still on screen and its port had
published nothing at all.

The receipt being *legal* is the whole point. A literal `route_complete` envelope would have been
caught by the kind mismatch, because `route_complete` exists only in `SUBSTAGE_CONTRACTS`. The
reachable case is narrower and quieter: the stage's own contract-perfect envelope.

**One overclaim, withdrawn before it shipped.** The first draft of this note and of the production
comment said the stolen completion also "disarmed the re-entry guard" by clearing
`_launched_transaction`. The fresh-context review showed that does not follow, and it was right. The
stolen completion durably *completes* the transaction, so `get_next_incomplete_stage` can never
re-offer it and `_launch_presentation` is never reached for it again; and a *later* presentation
carries a different id, which the sentinel would not have matched either way. The double dispatch
that `34756475b` closed does not re-open here. The real harm is narrower and worth stating on its
own: the coordinator forgets a scene that is still live, so its model of what is showing silently
stops matching the tree. Recorded here rather than quietly corrected, because a note that stops
being wrong without saying so teaches nobody what it was wrong about.

**Reachability, stated honestly.** This is a latent hazard in a public seam, not a live bug today.
`complete_route_stage` has no production caller: `GameState.complete_day_resolution_stage()`
forwards to it and is itself called only by tests, as
`docs/superpowers/specs/2026-08-03-phase-2r-07-ending-boundary-disk-durability-design.md` already
records. `complete_presentation_stage()` likewise has no production caller yet — Plan 03 owns the
Done dispatch. What makes it worth fixing now rather than later is that in production
*every* awaiting command is a presentation: `GameStateDayResolutionPort.begin_next_stage()` returns
`await_registered_command` only inside its `if not presentation_request.is_empty()` branch. The
route-only shape exists solely in the test fake. So the first production caller to reach this door
reaches it against a presentation, every time.

## The fix

One guard in `complete_route_stage`, before any validation, capture, or mutation: if the resolved
command carries a non-empty `presentation_request`, refuse with `presentation_completion_required`.

`presentation_request` is the right discriminator and the only reliable one. Production sets it only
on the presentation branch, and there is no `kind` field on the production command at all — the
`kind` the test fake carries is the *stage receipt* kind, present on both fake shapes, so
discriminating on it would work in the fake and be a no-op in production. The strongest argument is
narrower than "it is the right field": the guard's predicate is deliberately the *same predicate*
`_launch_presentation` uses, so it fires exactly when the walk considered the command a
presentation. A malformed or empty `presentation_request` slips past both, and correctly — no scene
was ever launched for it. The two copies of that predicate are a known drift risk; they were left as
two rather than extracted, to keep this diff inside its stated scope.

It is asked of the **resolved** command rather than of `_awaiting`, so both lookup paths answer the
same way. The history path looks harmless today — an already-completed stage returns
`duplicate_transaction` before the clears — but only because `get_next_incomplete_stage` pins
`_awaiting` to the same transaction, and because `_registered_history` is never pruned a stale id
from an earlier plan is not a duplicate at all. One refusal for both paths is cheaper than depending
on either fact.

A refusal leaves the run resumable, which is why nothing is rolled back: the guard precedes every
capture and mutation, the stage stays active and unreceipted, `_awaiting` keeps the exact command,
and `_launched_transaction` still names the presentation that is showing.

**One deliberate behavioural change.** Putting the guard above the `duplicate_transaction` early
return means an idempotent replay of an already-completed presentation now answers `ok: false` where
it previously answered `ok: true`. Every other seam in this file is replay-idempotent, so this is an
exception on purpose: a presentation must not be settleable through this door at any point, replay
included. The third test pins it.

## Evidence

**RED was observed, not manufactured.** The first two tests were written first and run against
unmodified production source. `complete_route_stage` returned
`{"code":"plan_complete","ok":true,"value":{"checkpoint_id":"run-1:13"}}` — it completed the entire
plan while the scene was on screen — the stage read `completed` instead of `active`, and the
follow-up `complete_presentation_stage()` returned `unknown_transaction: no stage is awaiting a
presentation`, proving `_awaiting` had been wiped and the port could no longer settle its own work.
26 tests, 24 passing, exactly the 2 new ones red, 267/272.

**A third test was added because a comment overclaimed.** The production comment asserted the
`_registered_history` fallback was covered, and nothing tested it.
`test_a_presentation_left_in_history_is_refused_by_the_route_door_too` now drives that path, and the
comment was trimmed to what the assertions actually check — the refusal is what changes there, not
the outcome, since before the guard that path returned an OK `duplicate_transaction`.

**A fourth mutation, and the test it condemned.** The fresh-context review observed that
`test_a_refused_route_completion_leaves_the_presentation_showing_and_still_settleable` asserted its
central claim by reading rather than by execution: it took the route count immediately after the
refusal, with nothing dispatching in between, so that count was 1 either way. It was checked rather
than argued — clearing `_launched_transaction` on the refusal path, the exact defect the test's own
docstring names, left **all 27 tests green**. The test now drives `resume()` and lets the
suppression itself be the evidence, and that mutation is red below.

**Mutations, each proving a different claim, all reverted.** Suite alone was 24 / 254 before and is
27 / 283 after.

| Mutation to production source | Observed | What it proves |
|---|---|---|
| guard reads `_awaiting` instead of the resolved command | 27 tests, 26 passing, **one red**, 281/283 — the history test | the history lookup path is genuinely covered rather than merely claimed in a comment |
| guard moved after `_commit_completion` | 27 tests, 24 passing, three red, 279/283 | only the guard's ORDER keeps the stage unmutated and the walk unadvanced |
| condition inverted, so it refuses non-presentations | 27 tests, 22 passing, five red, 270/283 — including the two pre-existing route-completion tests | the guard is narrow and does not over-refuse a legitimate route completion |
| refusal path also clears `_launched_transaction` | 27 tests, 26 passing, **one red**, 281/283 — and it is the re-dispatch test | the refusal really does leave the live scene remembered; before the review this mutation was green |

**Observed gates at the final tree.** Baselines at `5579b44c6`. All exit 0, no `SUITE_NOT_EXECUTED`,
orphans 24.

| Gate | Baseline | Observed | Delta |
|---|---|---|---|
| `hospital_dating_adapter_gate` (18 scripts) | 243 / 5231 | **246 / 5260** | +3 / +29 |
| Step 7.7 `hospital_order_green` (11) | 150 / 2050 | **153 / 2079** | +3 / +29 |
| guarded-path regression (5) | 71 / 3008 | **74 / 3037** | +3 / +29 |
| Step 8.8 `presentation_day7_green` (12) | 164 / 1947 | **164 / 1947** | unchanged |
| doc tooling (5) | 24 / 1635 | **24 / 1635** | unchanged |

Every delta is accounted for: the coordinator suite alone moved 24 / 254 → 27 / 283, exactly
+3 / +29; the three gates that list it moved by exactly that and nothing else in them changed; and
Step 8.8 does not list it and was RUN rather than assumed. No pre-existing test changed.

## Honest limits

- **A sibling defect was filed, not fixed: `dwm-p2r.20`.** `complete_route_stage` still drops
  `substage_id` when it builds the stage record it hands `_commit_completion`, so a substage
  completion arriving through this door is validated against `STAGE_CONTRACTS[stage_id]` rather than
  `SUBSTAGE_CONTRACTS[kind]` — and it fails *open* that way, because
  `RunLifecycle.complete_active_stage` skips owner validation for substage records. That is a
  stage/substage confusion rather than the route/presentation one, and this change makes it *harder*
  to notice by steering every production-shaped command to the door that handles it correctly. A
  note bullet was too weak for that; it is a bead.
- **The stale-history clobber for pure route commands is untouched.** `_registered_history` is never
  pruned, and `complete_route_stage`'s success path clears `_awaiting` and `_launched_transaction`
  unconditionally, so a non-presentation command resolved from history could in principle clear a
  *different* live awaiting command. Bounded today by the duplicate early return and by
  `get_next_incomplete_stage` pinning `_awaiting`, and moot for the production shape, which is
  always a presentation and now refused.
- **The discriminator lives in two places.** The guard and `_launch_presentation` carry byte-identical
  predicates rather than sharing one; correctness depends on them staying identical. Extracting a
  shared helper would touch a function repaired twice this week and was judged outside this scope.
- **Still no production caller.** Nothing in the walk drives either door yet. This hardens the seam
  ahead of Plan 03's Done dispatch; it does not make anything reachable.
