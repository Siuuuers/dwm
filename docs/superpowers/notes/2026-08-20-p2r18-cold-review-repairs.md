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

**Why it was false.** `SceneRouter.route_presentation` has four refusal branches, and at the time
that sentence was written every one of them was reached only after `_launch_presentation` had already
called `port.begin()` — that is, after a real Dialogic timeline had started. The antecedent of the
sentence was true (those three checks really do precede `begin()`); the consequent did not follow
from it and was not otherwise true.

**The split.** The four refusals are not alike, and the repair follows the difference:

| `route_presentation` refusal | property of | pre-`begin()`? |
|---|---|---|
| `schedule_presentation_ports_unconfigured` | the router OBJECT the coordinator already holds | **now yes** |
| `presentation_scene_missing` | the ROUTE | no, and cannot be |
| `presentation_scene_unconfigurable` | the ROUTE | no, and cannot be |
| `presentation_tree_unavailable` | the ROUTE | no, and cannot be |

The last three need the canonical command that only `begin()` produces, so lifting them would mean
asking the router to judge a command that does not exist yet. They stay post-`begin()`, and both the
note and the docstring now say so instead of implying otherwise. What makes that survivable is
unchanged and already proved: the stage stays ACTIVE and unreceipted, `_awaiting` keeps the exact
command, and `begin()` is idempotent per completion transaction, so the run resumes at that exact
boundary.

**The first one was knowable all along, and the capability to ask was already declared.**
`is_schedule_presentation_ports_configured` was listed in `PRESENTATION_ROUTER_METHODS`, implemented
on the real `SceneRouter`, implemented on `FakePresentationRouter`, and reachable through an uncalled
`FakePresentationRouter.set_ports_configured()` — and the coordinator never called it. So the
capability agreement asserted in
`test_the_real_router_satisfies_the_capability_the_coordinator_requires` was pinning a method that
production could not have been broken by. It is now called, immediately before `begin()`.

**A distinct code, for the same reason the others are distinct.**
`presentation_router_ports_unconfigured` is NOT `presentation_ports_unconfigured`: the latter means
THIS coordinator has no ports, the former means the ROUTE SURFACE has none. A mis-composed graph has
to say which half is missing, or it is debugged by guesswork — the rule the earlier note already set
for `presentation_ports_unconfigured` versus `presentation_ports_conflict`.

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
| `hospital_dating_adapter_gate` (18 scripts) | 241 / 5211 | **242 / 5221** | +1 / +10 |
| Step 7.7 `hospital_order_green` (11) | 148 / 2030 | **149 / 2040** | +1 / +10 |
| guarded-path regression (5) | 69 / 2988 | **70 / 2998** | +1 / +10 |
| Step 8.8 `presentation_day7_green` (12) | 164 / 1947 | **164 / 1947** | unchanged |

### Every delta accounted for

`test_day_resolution_coordinator.gd` was run ALONE at both trees rather than having its delta
inferred: **22 / 234** at `34756475b`, **23 / 244** here — one test, ten asserts (eight of the new
test's own, two from the shared `_wired()` fixture). Three of the four gates list that suite and
nothing else that changed, so each moves by exactly `+1 / +10`. Step 8.8 does not list it, so it is
unchanged. **No pre-existing test changed.**

## Honest limits

- **Three router refusals still start a timeline they cannot show.** Named above. Making them
  pre-`begin()` would require either a second router capability that can validate a route without a
  command, or splitting `route_presentation` into a check phase and a show phase. Neither is a
  cleanup, and neither is done here.
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
