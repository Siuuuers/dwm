# Scene event registry reuse — 4 November 2026

## Changes

SceneEventCommandPort returns the installed manifest's recursively frozen bundle
instead of a deep copy. Both dispatch forms retain per-event checks. Exact
canonical identity avoids whole-registry comparison; other owner registrations
still use the existing typed canonical comparison. There is no new cache,
manager, dependency, save format, or authored-content change.

A separate one-line cleanup removes duplicate gameplay application inside the
day-renewal branch. The existing unconditional application still runs before
scene/audio/native adoption. No latency claim is attached to that deletion.

## Reproduction and attribution

Base: `90bc2fa202c607fc942b221779504ef8419bbc5d`.
[Authentic seed and attribution run](https://github.com/Siuuuers/dwm/actions/runs/41839936778)
uses source `7f4eb6654a2f6e7e464c132b7c1961c92aed7815`, including only the
one-line day-renewal cleanup plus temporary diagnostics.

It starts from Title, naturally walks 800 captions through
`line.Day7.untouched.impulse.004`, physically saves slot 3, and copies the whole
private user directory before visiting the result. The seed has 806 globally
witnessed line IDs. The source slot SHA256 is
`6633123adc318e7e83815243dd5ea07e81aa05a91ba0fce667c5e2e052f959e9`.

The uninstrumented aged process took 4320 ms to reach `line.Day7.A.001`.
A fresh process loading that exact state took 1206 ms. These observations expose
an age-dependent cost; they are not interchangeable benchmark populations.
Three fresh-load attribution samples took 1127–1156 ms. In the first sample,
two event dispatches totalled 678 ms (inclusive), whole-registry comparisons
accounted for approximately 166 ms, Profile persistence for 241 ms, and 151
reading captures for 2.4 ms. Nested spans must not be summed.

A separate five-sample local probe found median copied-bundle validation of
119.139 ms versus 0.033 ms for the prepared canonical bundle; comparison of the
canonical bundle with a copy took 163.065 ms. Copies were built outside timers,
and every validation produced the same fingerprint. This is supporting
synchronous attribution, not a game-wide performance claim.

## Matched acceptance

[Rendered acceptance run](https://github.com/Siuuuers/dwm/actions/runs/41841087754),
source `452b0ef7298041f666c56121d7c5ef41efff415e`, artifact `13330080815`.
Ubuntu 24.04, Godot 4.6.3 standard, Xvfb, Mesa software renderer, native speech.
Six fresh processes restore separate byte-identical copies of the authentic
seed. Only SceneEventCommandPort changes, in B/C/C/B/B/C order. The day-renewal
cleanup is present in both variants. There is no timing instrumentation.

The existing authored journey timer covers native Accept through full visible
caption, acknowledgement, unblocked input, and a rendered frame.

| Variant | Result-entry times (ms) | Median (ms) |
| --- | --- | --- |
| Baseline | 2132, 2081, 2135 | 2132 |
| Candidate | 1357, 1361, 1339 | 1357 |

Median reduction: 775 ms (36.4%). The following ordinary caption remained
799–813 ms across variants. All six runs preserved the source slot and produced
identical final Profile SHA256:
`9a5fae72e97c1d0887071468f7a445004110045e745cd3f7c91d2575e06804c3`.
Do not compare absolute times across separate cloud runners.

## Focused checks and limits

- Six loaded-transition cases: 133 assertions each.
- Native caption Challenge Finish/create and fresh Load: 69 + 42 assertions.
- Real Computer board/create and fresh Load: 127 + 45 assertions.
- Canonical port identity, ordered dispatch, duplicate dispatch, and mutable
  registration detachment: 46 assertions. Identity regression fails on baseline.
- Day-renewal state preservation and next-day first-board/payment: 74 assertions.
  Selected methods: `test_daily_renewal_preserves_cumulative_rewards_purchases_pressure_and_task_claims`
  and `test_next_day_debug_round_one_does_not_inherit_yesterdays_payment`.
- Comment lint, workflow lint, and diff whitespace checks pass.

The comparison measures a freshly restored, naturally reached late-game state.
It does not establish an aged-session percentage, a cold-start gain, or Windows
hardware performance. Broad matrices and fault injection were not run. No new
lint rule or formal model was warranted.

## Long-session follow-up

[Two natural-playthrough diagnostic jobs](https://github.com/Siuuuers/dwm/actions/runs/41841761089),
source `58ec4138c7a202ae78b8b59ddf3b63491fd4ec65`, passed 7373 assertions each.
Artifacts: baseline `13328559584`, candidate `13329753065`. Collection is enabled
only at the final result transition and following caption. These instrumented,
single samples on different workers are attribution, not an aged speedup claim:
baseline 6107 ms; candidate 5398 ms. Both following captions took 798 ms.

Both sessions retained 800 native ledger captions and 31 live command receipts
(80365 serialized UTF-8 bytes; complete Run input 84341 bytes). In the candidate:

- Playable event acceptance: 2716 ms; subsequent Finish acceptance: 1433 ms.
- Target admission within Finish: 1055 ms, including Bridge preparation 529 ms.
- Full Run input capture: 17 calls, 5 ms combined.
- Staging-source validation: 9 calls, 209 ms combined.
- Reading capture: 152 calls, 373 ms combined.
- Typed canonical equality: 66 calls, 963 ms combined.
- Profile persistence: one call, 411 ms.

These are nested inclusive spans, not additive costs. They rule out raw Run
snapshot copying as the main explanation and narrow the remaining work to
playable preparation and accumulated reading-state validation. They do not yet
attribute every millisecond to one leaf operation. Live receipts still serve
duplicate detection, ordering, and retry/rollback custody; the ledger still
serves reading-state validation. Neither was trimmed in this change. A next
bounded investigation should split playable preparation's retained source,
ledger validation, and commit phases before changing their ownership.

## Draft caption compatibility

Route selection uses registered markers, choices, outcomes, and target IDs,
not caption wording. SoloReadingSession restores stable position IDs against
current content. Existing content-recovery tests cover wording edits and
insertions. Removing the currently saved position ID deliberately reports a
content error; disposable development saves do not require a migration layer.
