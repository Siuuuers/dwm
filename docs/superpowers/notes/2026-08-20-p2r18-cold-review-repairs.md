# dwm-p2r.18 cold-review repairs: a re-entry guard, and one overclaim withdrawn

**Why this file exists.** A cold review of `2026-08-19-p2r18-walk-launches-the-adapters.md` against
the code it describes found two things the note did not survive contact with. One was a real defect
in the dispatch (fixed in `34756475b`, which had no note of its own until this one). The other was a
sentence in the note that was simply false about the code. Both are recorded here rather than folded
silently into the earlier note, because a note that quietly stops being wrong teaches nobody what it
was wrong about.

## Repair 1 — a successful launch is never re-dispatched (`34756475b`)

**The defect.** `resume()` is a public seam any caller may drive again while a stage is still
awaiting. Every other object on that path is idempotent: the ports are idempotent per completion
transaction, and the physical owner is too. `SceneRouter.route_presentation` is NOT. A second
dispatch instantiates a second `PackedScene`, makes it `tree.current_scene`, and `queue_free()`s the
live one — underneath a Dialogic timeline that keeps playing. The walk would look resumable and would
in fact be tearing down the presentation the player is watching.

**The fix.** `_launch_presentation` records the transaction whose presentation is already showing in
`_launched_transaction`, and returns `{}` for a second launch of that same transaction. The field is
cleared wherever the awaiting command is cleared — `complete_presentation_stage()` and
`complete_route_stage()` — so a NEW presentation is never suppressed by a finished one's id.

**A FAILED launch records nothing.** That is the load-bearing half. If a refusal recorded the id, the
pre-existing refused-route retry test would go red, because a refused route is exactly the case that
must re-dispatch on the next `resume()`. Proved by mutation: recording on refusal too turns
`test_a_refused_route_leaves_the_stage_active_and_replays_the_identical_command` red.

`test_a_presentation_already_showing_is_not_launched_a_second_time` is the new coverage.

## Repair 2 — the claim about refusal ordering was false, and is now partly true and partly withdrawn

**What the note said.** *"route id, then router, then port are all validated before `begin()` is
called, so a route that cannot be shown is refused before a timeline starts behind it."* The same
sentence stood verbatim in the `_launch_presentation` docstring.

**Why it was false.** At the time that sentence was written, every `route_presentation` refusal
reachable from the walk was reached only after `_launch_presentation` had already called
`port.begin()` — that is, after a real Dialogic timeline had started. The antecedent of the sentence
was true (those checks really do precede `begin()`); the consequent did not follow from it and was
not otherwise true.

**The split.** `route_presentation` has NINE refusal exits, not four — eight `ok: false` returns
plus one pass-through of the scene's own refusal (`autoload/SceneRouter.gd:112-149`). They are not
alike, and the repair follows the difference. What matters is reachability FROM THE WALK, since most
of them the coordinator can never provoke:

| `route_presentation` refusal | reachable from the walk? | pre-`begin()`? |
|---|---|---|
| `schedule_presentation_ports_unconfigured` | no — the coordinator now refuses first | n/a, see below |
| `invalid_presentation_route` (route not registered) | no — route id whitelisted at `:452-454` | n/a |
| `invalid_presentation_command` (not a dictionary) | no — canonical validated at `:481-484` | n/a |
| `presentation_port_not_ready` | no — `begin()` refuses on the identical condition | n/a |
| `invalid_presentation_route` (canonical disagrees with the arg) | only on a port defect | no |
| `presentation_scene_missing` | **yes** | no, and cannot be |
| `presentation_scene_unconfigurable` | **yes** | no, and cannot be |
| the scene's own `configure_presentation` refusal, verbatim | **yes** | no, and cannot be |
| `presentation_tree_unavailable` | **yes** | no, and cannot be |

So FOUR refusals still start a timeline they cannot show, not three. The last four all need the
canonical command that only `begin()` produces, so lifting them would mean asking the router to
judge a command that does not exist yet. They stay post-`begin()`, and both the note and the
docstring now say so instead of implying otherwise. Note that the fourth of them is the least
tractable: it is a PASS-THROUGH, so its code is not even fixed — the coordinator surfaces whatever
`HospitalScene.configure_presentation` returned. What makes those four survivable is unchanged and
already proved: the stage stays ACTIVE and unreceipted, `_awaiting` keeps the exact command, and
`begin()` is idempotent per completion transaction, so the run resumes at that exact boundary.

**On `presentation_port_not_ready`, which looks like a counterexample and is not.** It is a property
of the PORT, not of the route, and `is_ready()` is a pure two-null-check accessor
(`HospitalPresentationPort.gd:223-224`), so it IS knowable before `begin()`. It is deliberately not
pre-checked, for the reason the 2026-08-19 note gave and this note initially dropped: `begin()`'s
first line refuses on the identical condition (`HospitalPresentationPort.gd:111-112`), so the router
branch is unreachable from the walk and a pre-check would be pure redundancy. Un-lifted because it
is already unreachable — not because it cannot be lifted.

**The first one was knowable all along, and the capability to ask was already declared.**
`is_schedule_presentation_ports_configured` was listed in `PRESENTATION_ROUTER_METHODS`, implemented
on the real `SceneRouter`, implemented on `FakePresentationRouter`, and reachable through an uncalled
`FakePresentationRouter.set_ports_configured()` — and the coordinator never called it. It is now
called, immediately before `begin()`.

**Corrected on second review:** an earlier draft of this paragraph went on to claim the capability
agreement in `test_the_real_router_satisfies_the_capability_the_coordinator_requires` was "pinning a
method that production could not have been broken by." That is FALSE. `route_presentation` calls
`is_schedule_presentation_ports_configured` as its own first guard (`autoload/SceneRouter.gd:113`)
and did so well before this work, so the method always had exactly one production caller — the router
itself. Break it and the router mis-gates in production with no coordinator involved. What was
missing was a caller in the WALK, which is a narrower and less alarming statement than the one the
draft made.

**A distinct code, for the same reason the others are distinct.**
`presentation_router_ports_unconfigured` is NOT `presentation_ports_unconfigured`: the latter means
THIS coordinator has no ports, the former means the ROUTE SURFACE has none. A mis-composed graph has
to say which half is missing, or it is debugged by guesswork — the rule the earlier note already set
for `presentation_ports_unconfigured` versus `presentation_ports_conflict`.

## Repair 3 — the re-entry sentinel could be matched by a legal command

**The defect, found by the cold review of Repair 1.** `_launched_transaction` starts as `""`, and the
guard compared a command's `transaction_id` against it directly. A presentation command carrying NO
transaction id therefore matched the UN-LAUNCHED sentinel: `_launch_presentation` returned `{}`, and
`resume()` reads `{}` as "nothing to launch" and pauses on `await_registered_command`. The walk would
report a presentation in progress with no scene and no timeline behind it — the only FAIL-OPEN path
in a function where every other refusal fails closed.

**Refused at the cause, not at the collision.** Guarding the comparison with
`_launched_transaction != ""` would have removed the symptom and left the defect: `resume()` keys
`_registered_history` on that same id (`:410`), so a blank one also makes every later completion
address the wrong entry. `_launch_presentation` now refuses an empty `transaction_id` outright with
`invalid_presentation_transaction`, before the sentinel comparison it would otherwise have collided
with.

**Reachability, stated honestly.** No producer in the tree emits a blank id today, and `resume()`
indexes `command["transaction_id"]` directly so a MISSING key errors earlier. This is a latent hazard
in new code rather than a live bug, and it is fixed because the cost is one check and the failure
mode is silent.

**The RED run reproduced the hazard, not merely a missing code.** 24 tests, 23 passing, one red,
252/254 asserts — and the two assertions that PASSED under RED are the telling ones: the port was
never asked to begin and the router was never asked to route, while the walk still answered
`await_registered_command`. That is the fail-open exactly as described.

**Mutation — the placement is load-bearing.** Moving the blank-id refusal to AFTER the sentinel
comparison: 24 tests, 23 passing, one red, 252/254, failing identically to the RED run, because the
blank id reaches the sentinel first and returns `{}`. Reverted.

`test_a_presentation_command_with_no_transaction_id_is_refused` is the new coverage, and
`FakeDayResolutionStatePort.set_blank_transaction_id()` is the seam that models the producer defect.

## Repair 4 — a test docstring that contradicted its own helper

`test_committed_schedule_presentation_resume.gd`'s Hospital cut said *"This cut restores from BYTES
ONLY"*, while `_crash_from_document()` fifteen lines below disclosed at length that it deliberately
re-installs the consequence source's condition and board-fate memos. Both cannot be true. The
narrower claim is the accurate one and is the one the test actually proves: the FLAG and the PLAN
come from bytes only. The docstring now says that, and names the two things that do cross the cut —
those memos (kept because DEVIATION-6 re-derives Hospital miss ids from the condition receipt, so a
fresh receipt would move the intent for reasons unrelated to `pending_hospital`) and `_registry` /
`_fingerprint`, which `before_each` loads once rather than rebuilding per boot. Neither carries
either half. `dwm-p2r.19`'s acceptance criteria carried the same overstatement and was corrected
with it.

## What did not change

The producer, the identity derivation, the matrix rows, the completion path, the resume behaviour,
every port contract, and `SceneRouter` itself. `FakePresentationRouter` still RECORDS rather than
DECIDES — its `route_presentation` deliberately does not consult its own `_ports_configured` flag,
which is what makes the new test sharp: the expected refusal can only come from the coordinator
asking, never from the fake refusing.

## Proven by mutation

**Repair 1** (recorded at `34756475b`): record `_launched_transaction` on refusal as well as on
success → `test_a_refused_route_leaves_the_stage_active_and_replays_the_identical_command` goes red.

**Repair 2**, both mutations applied to production source alone with the coordinator suite re-run:

1. **The check absent** — its RED run, before the production edit existed. 23 tests, 22 passing,
   **exactly one red**, 240/244 asserts. All four of the new test's own assertions failed: the code
   came back `await_registered_command`, the port HAD been asked to begin, and the router HAD been
   routed. This is the direct evidence that the coordinator previously ignored the router's readiness
   entirely.
2. **The check present but moved AFTER `begin()`.** 23 tests, 22 passing, **exactly one red**,
   243/244 asserts — and the single failing assert is `the port was never asked to begin`. The
   refusal code assertion still PASSES under this mutation, which is the discrimination that matters:
   the mutation does not change WHAT the coordinator answers, only whether a timeline was started
   before it answered. Nothing but the check's ORDER can make that assert green.

Reverted after each.

## Observed gates, all at the final tree — exit 0, no `SUITE_NOT_EXECUTED`, no script-load failures, orphans 24

Baselines are at `34756475b`, the parent of this work.

| Gate | Baseline | Observed | Delta |
|---|---|---|---|
| `hospital_dating_adapter_gate` (18 scripts) | 241 / 5211 | **243 / 5231** | +2 / +20 |
| Step 7.7 `hospital_order_green` (11) | 148 / 2030 | **150 / 2050** | +2 / +20 |
| guarded-path regression (5) | 69 / 2988 | **71 / 3008** | +2 / +20 |
| Step 8.8 `presentation_day7_green` (12) | 164 / 1947 | **164 / 1947** | unchanged |

Repairs 1–2 accounted for the first `+1 / +10` (measured at `773fef66a`: adapter gate 242 / 5221,
Step 7.7 149 / 2040, guarded-path 70 / 2998). Repair 3 adds the second, and its test costs the same
`+1 / +10` for the same reason — eight assertions of its own plus two from the shared `_wired()`
fixture. Repair 4 is comment-only and moved nothing, which was confirmed rather than assumed: the
adapter gate and the doc-tooling gate were re-run across the documentation corrections alone and came
back byte-identical at 242 / 5221 and 24 / 1635.

### Every delta accounted for

`test_day_resolution_coordinator.gd` was run ALONE rather than having its delta inferred:
**22 / 234** at `34756475b`, **23 / 244** after Repair 2, **24 / 254** after Repair 3. Three of the
four gates list that suite and nothing else that changed, so each moves by exactly its delta. Step
8.8 does not list it and was RUN rather than assumed unchanged: 164 / 1947, identical. **No
pre-existing test changed.**

## Honest limits

- **Four router refusals still start a timeline they cannot show.** Named in the table above.
  Making them pre-`begin()` would require either a second router capability that can validate a route
  without a command, or splitting `route_presentation` into a check phase and a show phase. Neither is
  a cleanup, and neither is done here.
- **This note was itself wrong on first writing, and was corrected by a cold review the same day.**
  It claimed four refusal branches where there are nine, classified three post-`begin()` refusals
  where there are four, omitted the scene-configure pass-through entirely, and overstated the
  consequence of the uncalled capability. Recorded rather than quietly amended, for the same reason
  the 2026-08-19 note recorded its own vacuous first-version test: a document that silently stops
  being wrong teaches nobody what it was wrong about.
- **The new check is proved against the fake, not the real router.** `FakePresentationRouter` reports
  unconfigured while still routing, which no real router does; that inconsistency is deliberate and
  is what isolates the coordinator's behaviour. The REAL `SceneRouter`'s refusal on the same condition
  is proved separately in `tests/integration/test_schedule_presentation_bootstrap_wiring.gd`
  (`assert_false(fresh.is_schedule_presentation_ports_configured())`), and the capability agreement
  between the two objects in `test_hospital_dating_adapter_negative_contract.gd`. No single test walks
  the real coordinator into the real router on this path — the same limit the earlier note already
  recorded for the dispatch as a whole.
- **Everything the earlier note lists under its own Honest limits still stands**, unchanged:
  production still cannot reach a presentation site (DEVIATION-5), there is still no real
  producer-to-real-scene end-to-end walk, and `complete_presentation_stage()` still has no production
  caller.
