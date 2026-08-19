# The day-resolution walk now launches the Hospital and Dating adapters

**What this closes.** The last unclosed bullet of the `dwm-p2r.18` SCOPE list: *"`SceneRouter.route_presentation()`
already exists and is tested; wire the walk to it."* Six of the seven bullets landed across
`2f08fe1f`..`e66411a9`. This one did not, and every comment on the bead since `2f08fe1f` has repeated
the same sentence — "`SceneRouter.route_presentation()` has no caller in the walk" — while deferring
it to Plan 03.

**What was actually missing.** Two seams, not one. Repo-wide grep before this change found zero
production callers of `SceneRouter.route_presentation()` **and** zero production callers of
`HospitalPresentationPort.begin()` / `DatingPresentationPort.begin()`. `HospitalScene` deliberately
does not call `begin()` — a scene may not decide that a presentation started — and the only callers
anywhere were test bodies driving the port by hand
(`tests/integration/test_committed_schedule_effect_order.gd:498`). So the producer derived an exact
`P01.presentation.intent`, the walk paused on `await_registered_command` carrying its `route_id` and
`presentation_request`, and then the command was handed to nothing at all. No adapter was ever
launched.

**What did not change.** The producer, the identity derivation, the matrix rows, the resume
behaviour, the completion path, and every port contract are untouched. This is the dispatch and
nothing else.

## The two decisions, both taken by the maintainer rather than assumed

**Where the dispatch lives: inside `DayResolutionCoordinator.resume()`.** The coordinator is the
object that PAUSES the walk on a presentation, so it is the object that must be able to launch one.
The rejected alternative was a separate `dispatch_presentation()` the caller invokes after `resume()`
returns — which would have left "the adapters are actually launched" resting on a production caller
that does not exist, i.e. the same gap the bead exists to close.

**What a failed launch does: fail closed, stage ACTIVE and unreceipted.** `resume()` returns the
refusal verbatim. Nothing is rolled back and nothing needs to be: the stage carries no receipt, no
domain state was touched, and `_awaiting` keeps this exact command. Because `begin()` is idempotent
per completion transaction, the next `resume()` re-derives byte-identical bytes and re-offers them
without restarting a presentation that may already be running. The rejected alternative was to skip
dispatch silently when no router is configured, which would let a mis-composed graph reach a
presentation stage and show nothing.

## The order is forced, not chosen

`route_presentation` hands the off-tree scene the CANONICAL command — the request plus
`command_sha256` and the owner-derived `physical_token` — and only `begin()` produces those bytes. So
the physical presentation necessarily starts before the scene opens. That makes the ordering of the
*checks* load-bearing rather than cosmetic: route id, then router, then port are all validated before
`begin()` is called, so a route that cannot be shown is refused before a timeline starts behind it.
`test_an_unconfigured_router_never_starts_a_physical_presentation` is exactly that claim, and
mutation 2 below proves it is enforced rather than merely written down.

Note that no redundant `is_ready()` pre-check was added: `is_ready()` is false exactly when the port
has no configured physical owner, and `begin()` already refuses on that same condition — so Phase
2R's deliberately unconfigured Dating route fails at `begin()` with
`dating_physical_owner_unconfigured` before anything physical happens, and never reaches the router.

## What landed

`scripts/application/run/DayResolutionCoordinator.gd`

- `PRESENTATION_ROUTER_METHODS` — the exact route capability, consumed unwidened.
- `configure_presentation_router(router)` — accepts the one production route surface once; identical
  replay is idempotent, replacement returns `presentation_router_conflict`. Mirrors the existing
  `configure_presentation_ports` seam exactly.
- `_launch_presentation(command)` — returns `{}` for a bare route command (so `complete_route_stage`'s
  path is untouched), otherwise validates, starts the port, and routes the canonical command.
- The call site in `resume()`, placed AFTER `_awaiting` and `_registered_history` are set, so a port
  whose owner completes synchronously publishes into a coordinator already awaiting this exact
  transaction.

`autoload/ApplicationBootstrap.gd`

- The SAME `SceneRouter` the two ports were just injected into is handed to the coordinator. One
  object serves both roles deliberately: a second router would open a scene holding ports this
  coordinator never adopted, so its completion would arrive from an object the coordinator refuses —
  a presentation that plays and can never be checkpointed.

## Fail-closed codes, and why two of them are distinct

| Condition | Code |
|---|---|
| command names a route that is neither Hospital nor Dating | `invalid_presentation_route` |
| no route surface composed | `presentation_router_unconfigured` |
| no presentation ports composed | `presentation_ports_unconfigured` |
| the port refuses to start | the port's own code, verbatim |
| the router refuses to show | the router's own code, verbatim |

`presentation_ports_unconfigured` is deliberately NOT the existing `presentation_ports_conflict`:
that code means the configure seam REFUSED a port, and nothing was refused here — the graph never
composed one. A mis-composed graph has to say which half is missing, or it is debugged by guesswork.

## Tests

`tests/support/FakePresentationRouter.gd` (new) records `(route_id, command)` pairs into a shared
ordering log rather than instantiating a `PackedScene` and mutating `tree.current_scene`.
`tests/support/FakePresentationPort.gd` gains a real `begin()` body returning the same envelope the
real ports return, plus a forced-failure seam.

Six tests in `tests/unit/test_day_resolution_coordinator.gd`: the configure seam (once / idempotent
replay / replacement / incomplete capability / null); the launch itself (exact request bytes, exact
canonical routed command, `begin` strictly before `route_presentation`, stage still ACTIVE); the
unconfigured router; the unconfigured ports; a refused route plus its byte-identical retry; and a
port that cannot start never reaching the router.

Two tests in `tests/integration/test_hospital_dating_adapter_negative_contract.gd`: the walk is the
sole production caller of `route_presentation`, and the REAL `SceneRouter` satisfies the capability
the coordinator declares — the fake is only as good as its agreement with the real object, so that
agreement is asserted rather than assumed.

One test in `tests/integration/test_schedule_presentation_bootstrap_wiring.gd`: the coordinator
dispatches through the exact router instance the ports were injected into, and refuses a second.

## Proven by mutation — five mutations, all reverted

Each was applied to production source alone and the affected suites re-run.

1. **Route the raw request instead of the port's canonical started command.** 19/20, EXACTLY ONE test
   red — the launch test, naming the two differing dictionaries.
2. **Check the router only AFTER `begin()` has already run.** 19/20, EXACTLY ONE test red —
   `test_an_unconfigured_router_never_starts_a_physical_presentation`, reporting the request the port
   should never have received. This is the direct proof that "nothing physical starts behind a scene
   that cannot open" is enforced by the check ORDER and not by accident.
3. **Swallow a launch failure and pause anyway.** 17/20, three tests red — all three fail-closed
   cases, each reporting `await_registered_command` where a refusal was required.
4. **Delete the router call from the walk entirely.** This one found a real defect *in the test*: the
   caller scan matched the seam name inside `PRESENTATION_ROUTER_METHODS` and stayed green. The scan
   now additionally requires the CALL form (`.call(&"route_presentation"`), and re-running under the
   same mutation goes red naming exactly that. Recorded rather than quietly fixed, because it means
   the first version of that test was vacuous.
5. **Bootstrap composes the ports onto the router but never hands the router to the coordinator.**
   The composition-identity test goes red.

## Observed gates, all at the final tree — exit 0, no `SUITE_NOT_EXECUTED`, orphans 24

| Gate | Baseline at `9b1b48c4a` | Observed | Delta |
|---|---|---|---|
| `hospital_dating_adapter_gate` (18 scripts) | 231 / 5086 | **240 / 5198** | +9 / +112 |
| Step 8.8 `presentation_day7_green` (12) | 163 / 1936 | **164 / 1947** | +1 / +11 |
| Step 7.7 `hospital_order_green` (11) | 141 / 1945 | **147 / 2017** | +6 / +72 |
| guarded-path regression (5) | 62 / 2903 | **68 / 2975** | +6 / +72 |

Scene-load smoke (`res://tests/smoke_load_scenes.gd`): exit 0, `SMOKE_LOAD_SCENES: PASS (28/28)`.

### Every delta accounted for

The three touched suites were run alone at the pristine tree and again at the final tree, rather than
having their deltas inferred:

| Suite | Before | After | Delta |
|---|---|---|---|
| `test_day_resolution_coordinator.gd` | 15 / 149 | 21 / 221 | +6 / +72 |
| `test_hospital_dating_adapter_negative_contract.gd` | 11 / 308 | 13 / 337 | +2 / +29 |
| `test_schedule_presentation_bootstrap_wiring.gd` | 15 / 115 | 16 / 126 | +1 / +11 |

Step 7.7 and the guarded-path regression list the coordinator suite and neither of the others, so
both move by exactly its `+6 / +72`. Step 8.8 lists the bootstrap-wiring suite and neither of the
others, so it moves by exactly its `+1 / +11`. The adapter gate lists all three, and `6+2+1 = 9`,
`72+29+11 = 112`. **No pre-existing test changed**; the assert counts above include each suite's fixed
per-test `before_each` cost (11 asserts per test in the negative-contract suite, 4 in the
bootstrap-wiring suite), which is why two tests can cost 29 asserts.

## Honest limits

- **Production still cannot reach a presentation site.** DEVIATION-5 stands unchanged: the Plan-02
  desktop-consequence source is deliberately never configured, so the producer fails closed before any
  presentation is derived, and `get_desktop_contract_state().presentation_producer_ready` still
  reports `false`. This change makes the launch REACHABLE the moment Plan 02 configures that seam; it
  does not make it reachable today, and no such claim is made.
- **No single test walks a real producer through a real port into a real routed scene.** The dispatch
  law is proved at the unit level over the REAL coordinator with a fake router and fake ports; the
  real router's capability agreement and the composition identity are proved separately against the
  real `SceneRouter`. A true end-to-end walk would need the real coordinator wired to the real
  producer, and no harness in the repo does that — every producer suite drives
  `GameStateDayResolutionPort` directly. Building that harness is real work, not a cleanup, and it is
  recorded here rather than skipped silently.
- **`complete_presentation_stage()` still has no production caller.** Plan 03 owns the Done dispatch
  surface, so nothing in production issues a Schedule-Done command at all. That is unchanged by this
  work and is a separate seam from the one closed here.
- **The identical-shape early return in `complete_route_stage`** remains deliberately untouched and
  flagged, exactly as `ed29271f` recorded.
