# The deferred pair now completes through `DatingPresentationPort`

**What this closes, and what it does not.** The `dwm-p2r.14` gate note recorded the deferred pair as
"proved at the derivation level rather than end to end through a routed scene". This adds the
missing middle: a full `begin()` -> owner finish -> `completion_ready` round trip for the
`twofriends_if_deferred` context through the real port against `FakeDatingPresentationOwner`.

**The port is the ceiling, and that is stated rather than glossed.** Phase 2R routes the deferred
pair to `dating`, and the Dating route is deliberately fail-closed with
`dating_physical_owner_unconfigured` until `dwm-oyo.4` configures a real challenge owner through the
composition root. No routed scene can reach this path, so no end-to-end claim is available to make
and none is made here. The `.18` review brief's reachability item is unchanged.

## The gap this closed

In `tests/unit/test_dating_presentation_port.gd` before this change, `_pair_request()` was called at
exactly ONE site: line 175, `test_a_deferred_pair_intent_is_accepted_in_the_canonical_order`, and
that test stops at `begin()`. Every `complete()` test in the suite calls `_request()`, whose
`_context()` kind is `solo`. So the pair's completion child, its command bytes, its locator and its
settled receipt were never carried through settlement by anything.

The new test is `test_a_deferred_pair_completes_through_the_port_carrying_its_own_pair_bytes`. It
asserts the pair context reaches the owner unaltered and unsorted, that exactly one completion
publishes and no failure does, that the settled receipt's member set is exactly
`PORT.COMPLETION_RECEIPT_KEYS`, that `receipt_id` and `receipt_provenance` are the pair's own
completion child, that `timeline_id` is the PAIR locator rather than the solo one, that
`command_sha256` is `canonical_sha256` of the pair request's own bytes, that `physical_token` is the
token the owner derived over those bytes, and that the physical result reported is the owner's and
no more.

## RED proven by mutation

A first-run green proves nothing, so the test was proved load-bearing against three mutations of
PRODUCTION source (`scripts/application/run/DatingPresentationPort.gd`), each reverted. Baseline for
the suite alone is 20 tests / 213 asserts before the change and 21 / 233 after.

| Mutation | Result |
|---|---|
| `complete()` receipt `"timeline_id"` built from `command["route_id"]` | 20/21, 232/233 asserts, **exactly one test red — the new one**, `["dating"] expected to equal ["dating.twofriends.priscilla_lavinia.day2.pre_challenge"]` |
| `PAIR_PARTICIPANTS` reversed to `["lavinia", "priscilla"]` | 18/21, 217/222 asserts, three red: the new test (refused at `begin()` with `invalid_presentation_context`) plus the two existing pair tests |
| `complete()` receipt `"physical_token"` built from `command["command_sha256"]` | 20/21, 232/233 asserts, **exactly one test red — the new one**, on the `FAKE_OWNER.derive_token` binding |

Mutations 1 and 3 each went red in the new test and NOWHERE ELSE, which is the direct proof that the
settled receipt's locator and token binding had no other cover. All three reverted; `git status` on
`scripts/` and `autoload/` clean before the commit.

## Observed gates

All exit 0, no `SUITE_NOT_EXECUTED`, no `SCRIPT_LOAD_FAILED`.

| Gate | Scripts | Tests | Passing | Asserts | vs baseline |
|---|---|---|---|---|---|
| `hospital_dating_adapter_gate` | 18 | 231 | 231 | 5086 | 230/5066 -> **+1 test, +20 asserts** |
| Step 8.8 `presentation_day7_green` | 12 | 163 | 163 | 1936 | 162/1916 -> **+1 test, +20 asserts** |
| Step 7.7 `hospital_order_green` | 11 | 141 | 141 | 1945 | unchanged |
| guarded-path regression | 5 | 62 | 62 | 2903 | unchanged |
| `test_dating_presentation_port` alone | 1 | 21 | 21 | 233 | 20/213 -> +1 test, +20 asserts |

The two gates that moved are exactly the two that LIST `test_dating_presentation_port.gd`, and both
moved by exactly the suite-alone delta. Step 7.7 and the guarded-path regression do not list it and
did not move, which is what a test-only change confined to one suite must look like. The
guarded-path regression here is `test_day_resolution_coordinator`,
`test_committed_schedule_presentation_matrix`, `test_committed_schedule_presentation_resume`,
`test_committed_schedule_effect_order` and `test_committed_schedule_day_resolution`.

## Still open

`dwm-p2r.14`, `.18` and `.19` all remain open and none was closed here. The reachability items are
untouched: `SceneRouter.route_presentation()` still has no caller in the walk, the producer is
unreachable in production until Plan 02 configures the desktop-consequence source, and the pair's
end-to-end proof through a routed scene has to wait for `dwm-oyo.4` to configure the Dating port.
