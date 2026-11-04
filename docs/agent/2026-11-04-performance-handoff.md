# DWM continuation handoff

Updated 4 November 2026. Verified runtime baseline: `b6ed7b7ccbe722405eca4652351ea031382e64b8` on `Siuuuers/dwm` master.

## Start here

The next task is to reduce the long-session Challenge handoff pause without changing the visible caption, selected outcome, board, history, or persistence behavior. Do not restart the completed Dating retirement or registry optimizations.

The remaining pause is real, but its complete leaf-level cause is not yet established. The strongest next target is preparation and validation of the playable state before an adjacent Challenge Finish. A freshly loaded checkpoint does not reproduce the full long-session cost.

This handoff covers the work investigated in this thread. It is not a claim that every subsystem, release requirement, or open issue in the repository has been audited.

Before editing, fetch current master, inspect local changes, read `AGENTS.md`, `CLAUDE.md`, and `docs/design/2026-10-25-current-scene-state.md`, and check whether another session has already completed the proposed work. The baseline above is a verified revision, not a permanent pin.

## Established decisions and constraints

- Development and qualification use cloud Linux. These runs use Godot **4.6.3 standard with GDScript**, not the .NET build. Windows remains the player target; Linux timing is not Windows hardware evidence.
- The game is unshipped. Earlier development saves are disposable; do not add legacy migrations without a concrete requirement.
- DTL owns the story flow. The old Dating scene and Schedule paths were retired. `DatingPhysicalOwner` and `DatingPresentationPort` still serve live DTL boards: their names do not make them dead code.
- Caption wording is draft. Stable IDs, registered markers, choices, outcomes, and targets determine progression. Do not use displayed text to identify behavior.
- Prefer one existing owner, deletion over replacement machinery, and the smallest complete diff. Keep internal typed values; validate at the boundary that owns unknown inputs.
- Preserve error handling that prevents data loss, actual trust-boundary validation, accessibility, exact board restoration, and required behavior. Do not remove these merely because they add lines.
- Use focused positive checks. No new injection/fault tests or speculative external-threat protections. Review existing test bodies before selecting them: several apparently relevant suites include deliberate failures.
- Measure performance before and after on equivalent workloads. Smaller code is not proof of lower latency.
- Parallel agents may investigate independently or edit disjoint files. One coordinator owns shared files, integration, publication, and final acceptance.
- Direct merge/publication is authorized. Do not weaken checks or overwrite concurrent work. Use a guarded branch update and verify the resulting head.
- Issues/PRs #183, #185, and #187 were closed; do not reopen their experiments as part of this continuation.

## Completed work — preserve, do not redo

| Change | Published commit | Evidence and scope |
| --- | --- | --- |
| Legacy Dating/Schedule retirement | `0c6e02f9` | Retired scenes and legacy persistence paths removed; current Scene Save9 remains. Live DTL board owners retained. |
| Restore-participant expectation corrected | `a8e37fdf` | Expected participant count changed from nine to eight after retirement; focused rendered journeys passed. |
| Profile validation reused within one atomic write | `5b1b564b` | Matched first-visit ending captions: median of run medians 911 → 749.5 ms. Later reads/writes still validate; physical readback and recovery retained. |
| Canonical registry retained through physical challenge authorization | `90bc2fa2` | Fresh direct-entry Day7 probe: median 2053 → 1589 ms. Mutable registrations remain detached. |
| Duplicate day-renewal gameplay application removed | `db37e6d2` | One-line deletion; 74 focused assertions plus authentic day transitions. No speed claim. |
| Canonical registry reused during event dispatch | `b6ed7b7c` | Authentic late-game checkpoint, fresh Load: median 2132 → 1357 ms, 36.4% lower. Arbitrary owner registrations retain comparison fallback. |

These percentages describe different workloads and cannot be added or multiplied into a whole-game improvement.

Detailed records:

- [Profile validation](2026-11-04-profile-write-validation.md)
- [Physical challenge registry](2026-11-04-challenge-registry-reuse.md)
- [Event dispatch, day cleanup, and long-session diagnostics](2026-11-04-scene-event-registry-reuse.md)

The earlier challenge-registry record says day-renewal cleanup was left outside that change. It was subsequently completed in `db37e6d2`; it is no longer outstanding.

## Priority queue

| Priority | Work | Owner and scope | Completion evidence |
| --- | --- | --- | --- |
| P1 | Split long-session playable handoff cost into actual operations | GameState, DialogicBridge, SoloReadingSession, narrative checkpoint port; measure before editing | Identify dominant exclusive work and repeatable calls using the naturally reached Day7 boundary; preserve actual native input and rendering |
| P1, after attribution | Remove only demonstrated redundant work | The existing owner of the measured operation | Focused behavioral checks and matched uninstrumented long-session comparison; no regression in fresh Load, board continuity, or visible captions |
| P2, conditional | Further first-visit caption/Profile cost | ProfileManager and its schema/storage owners, only if still a priority after handoff work | Equivalent unwitnessed captions and identical starting Profile; compare full Accept-to-ready operation |
| Later qualification | Windows/device behavior and visual coverage | Actual target build; relevant layout/input/accessibility checks | Target-specific evidence before claiming player-hardware latency or release readiness |
| Only when recurring evidence exists | CI setup, coverage, lint, or TLA+ work | Existing workflow/rule owner | A measured setup bottleneck or repeatable defect; narrow rule with a clear fix, not new infrastructure by default |

No user decision is required to begin P1 measurement. Ask only if a proposed fix would change observable behavior or policy—for example history retention, when discoveries become durable, Challenge Start/Finish semantics, or how missing saved IDs should resolve.

## What the remaining measurements actually show

The authentic source is `line.Day7.untouched.impulse.004`, reached by walking 800 shipped captions from Title. Advancing enters `line.Day7.A.001`, then `.002` is the neighboring ordinary-caption control. The seed Profile contains 806 witnessed line IDs before those result captions are visited.

In one job without attribution wrappers:

- The naturally aged process took **4320 ms** to enter the result.
- A fresh process loading its exact saved state took **1206 ms**.

This establishes different runtime populations. Do not use the faster Load population as a substitute for a long-session benchmark.

Later, instrumented natural-playthrough jobs observed 6107 ms baseline and 5398 ms candidate on separate workers. Each is a single diagnostic sample, so neither their difference nor their ratio is an established long-session speedup.

Both retained 800 native ledger captions and 31 live command receipts. Serialized receipts occupied 80365 UTF-8 bytes; complete Run input occupied 84341 bytes. Candidate observations:

| Span | Calls | Inclusive time |
| --- | ---: | ---: |
| Playable event acceptance | 1 | 2716 ms |
| Subsequent Finish acceptance | 1 | 1433 ms |
| Target admission within Finish | 1 | 1055 ms |
| Bridge target preparation | 1 | 529 ms |
| Full Run input capture | 17 | 5 ms total |
| Staging-source validation | 9 | 209 ms total |
| Reading capture | 152 | 373 ms total |
| Typed canonical equality | 66 | 963 ms total |
| Profile persistence | 1 | 411 ms |

The spans overlap. Never sum them. Raw snapshot copying is not the principal explanation; neither the capture count nor receipt-map size alone proves the remaining root cause.

## Next bounded implementation assignment

**Observable outcome:** after a long natural session, one ordinary Accept from the Day7 cue reaches the same full result caption and outcome with less pause, without repeating effects or changing Save/Load behavior.

**Start with these functions, not source line numbers:**

- `GameState._prepare_scene_playable_event`, `_validate_scene_playable_source`, `_accept_scene_playable_event`, and `accept_scene_event`.
- `DialogicBridge.commit_scene_playable`, `_commit_scene_playable_owned`, and `_scene_playable_current`.
- `SoloReadingSession.prepare_scene_next`, control continuation, capture, and saved-state validation used by that path.
- `SaveManagerNarrativeCheckpointPort` control retention, commit, and acknowledgement consumption.
- For the later phase: GameState target admission/staging validation and Bridge source/candidate checks.

**Investigation sequence:**

1. Keep runtime changes out of the observation overlay. Time retained-source capture, ledger validation, source/destination projection, control retention, commit, acknowledgement, and adoption separately.
2. Record collection sizes outside the timed window. Enable expensive observation only at the selected result and its ordinary-caption control.
3. Trace every caller and callback of the dominant operation. Identify what each copy/comparison proves and which owner can mutate its inputs.
4. Prefer reusing an existing immutable or already-prepared value. A repeated check across a real mutable callback boundary is not automatically redundant.
5. Describe relevant ordinary failures before editing: stale source, repeated Accept, changed retained choice, failed persistence, or interruption between commit and presentation. Preserve existing handling; do not add an injection campaign.
6. Make one bounded candidate. Finish compatible caller/test reviews before final acceptance.
7. Compare complete native Accept → fully visible, acknowledged, input-ready caption → rendered frame, with instrumentation removed. Match initial Profile, content, session age, and source state. Alternate baseline/candidate order.
8. Publish only after selected checks pass on the actual candidate. Record revision, reproduction, run, result, and limits.

## State and behavior that must survive

| Area | Preserve |
| --- | --- |
| Reading | Exact visible beat, stable position, encountered history, and correct native frontier; no backfilling unseen history |
| Draft edits | Wording and insertion remain distinct from deleting the currently saved ID; deletion currently reports a content error instead of silently rewinding |
| Challenge | Never-started, unfinished, won/lost/perfect outcomes; exact board/spec/flags and selected attempt prefix; one closure |
| Save/Load | Exact selected caption, board, choices, and outcomes; no replay of prior gameplay consequences |
| Global Profile | Discoveries/Gallery do not rewind with an older Run; retain publication after required persistence |
| Transactions | Command identity, ordering, mutation lease, retry candidate, rollback/custody, and acknowledgement ownership |
| Registry | Exact canonical frozen identity may be reused; mutable or merely equivalent inputs keep their existing boundary handling |
| Presentation | Authored transition effects and their input holds, audio selection, focus, accessibility, and caption readiness |

Live receipts are deliberately absent from player Save9 and restored empty, but still serve duplicate detection, ordering, triggers, and retry/rollback in a running session. Native history also differs between a long-lived session and compact restored state. Do not trim either collection solely to make a benchmark smaller.

Do not skip an adjacent playable marker or collapse Start/Finish into a different semantic action without proving all required behavior, including Computer entry, authored audio, and continuation, remains intact.

## Reproduction and evidence map

| Purpose | Immutable source | Run |
| --- | --- | --- |
| Natural seed, fresh-load attribution | `7f4eb6654a2f6e7e464c132b7c1961c92aed7815` | [41839936778](https://github.com/Siuuuers/dwm/actions/runs/41839936778) |
| Six matched loaded-state comparisons and Save/Load pairs | `452b0ef7298041f666c56121d7c5ef41efff415e` | [41841087754](https://github.com/Siuuuers/dwm/actions/runs/41841087754) |
| Natural-session baseline/candidate attribution | `58ec4138c7a202ae78b8b59ddf3b63491fd4ec65` | [41841761089](https://github.com/Siuuuers/dwm/actions/runs/41841761089) |

The diagnostic branches retain workflows and wrappers; these are not production instrumentation:

- `codex/late-transition-profile`: `late-transition-profile.yml`, `late_transition_profile.py`, `late_transition_seed.gd`, `late_transition_measure.gd`.
- `codex/event-registry-reuse`: `event-registry-matched.yml` and the fresh-load measurement wrapper.
- `codex/aged-transition-profile`: `aged-transition-profile.yml`, `aged_transition_profile.py`, and the natural-session seed wrapper.

Workflow files are in `.github/workflows`, Python helpers in `tools/testing`, and GUT wrappers in `tests/integration`.

Artifacts have seven-day retention, nominally through 11 November 2026. Do not assume they remain downloadable. Source workflows can regenerate them:

- Authentic seed: artifact `13328114380`, folder `late-transition/seed`.
- Matched acceptance: `13330080815`.
- Aged baseline/candidate: `13328559584` / `13329753065`.

The source slot SHA256 is `6633123adc318e7e83815243dd5ea07e81aa05a91ba0fce667c5e2e052f959e9`. All six matched final Profiles had SHA256 `9a5fae72e97c1d0887071468f7a445004110045e745cd3f7c91d2575e06804c3`.

Fresh-load runs can clone the authentic seed. Long-session runs must naturally accumulate the relevant live state; restoring a compact save is not equivalent. Do not fabricate gameplay or checkpoint state to imitate age.

## Focused checks

Choose tests by changed behavior and read their bodies first.

- Owner/state rules: a focused unit check.
- Cross-owner commit, ordering, persistence, or recovery: the relevant integration check.
- Connected caption, input, transition, or board behavior: rendered native journey.

Relevant existing files include `test_scene_event_owner_contract.gd`, `test_scene_challenge.gd`, `test_scene_event_contract.gd`, `test_scene_day_renewal.gd`, `test_scene_day_commit_ordering.gd`, and `test_scene_content_recovery.gd`. Some are in `tests/integration`, others in `tests/unit`; resolve current paths with `rg --files`.

Rendered pairs used successfully:

- `test_scene_caption_challenge.gd` + `test_scene_caption_challenge_load.gd`.
- `test_scene_computer_create.gd` + `test_scene_computer_load.gd`.

The event-dispatch candidate passed six 133-assertion timing cases plus 283 assertions across those rendered pairs, and 46 focused local assertions. Day cleanup passed 74 local assertions. Both additional aged journeys passed 7373 assertions each. These successes do not imply a complete test matrix or release qualification.

## Runner details that prevent wasted runs

- Reuse the known passing Ubuntu 24.04/Godot 4.6.3 workflow setup, including Xvfb, Mesa, and `tools/testing/start_cloud_speech.sh`. Missing native speech services caused unrelated engine errors in earlier diagnostics.
- Put `DWM_TEST_ROOT` beneath the checkout's `.godot/phase2r_tests/`. An arbitrary temporary root can select the wrong Bootstrap mode.
- Do not pass `--phase2r-bootstrap-mode=test_manual` to GUT; GUT rejects that argument.
- Keep private storage shared only within intended create/load pairs. Give independent samples isolated directories and restore identical seed bytes.
- Run one import before tests; do not import concurrently with GUT. Restore import-only `project.godot` changes.
- `-gunit_test_name` selects a substring, not a regex or list. Inspect actual selected cases.
- Check JUnit case/assertion counts and failures; exit code zero alone is insufficient.
- Reset typed observation arrays with `.clear()` through dynamic references; assigning an untyped `[]` caused an earlier diagnostic failure.
- Do not wrap asynchronous functions as synchronous timers. Separate native-install, deferred restoration, draw, and acknowledgement times.
- Local Xvfb was blocked by socket permissions in this workspace. Headless checks work; use the cloud renderer for native visual qualification.
- Workflow dispatch was unavailable through the connector used here; a temporary branch push successfully triggered focused diagnostic workflows. A PR was not required to start a broad matrix.

## Workspace continuity

At verification, the main checkout had no tracked edits and no unfinished publication. Existing untracked evidence fragments and lint caches were left untouched. Do not use broad cleanup/reset commands on them.

If this workspace survives, diagnostics are under `.godot/ci/late-transition`, with earlier work under `.godot/ci/transition-profile` and `.godot/ci/caption-profile`. Extra profiling worktrees contain intentional observation edits and may be based on older commits. They are not clean baseline checkouts. Prefer a fresh isolated worktree from the chosen revision.

No new lint rule or TLA+ model was added. Introduce one only for an actual recurring structural mistake or a concrete transition invariant that current checks cannot express economically.

## Copy into a new session

> Continue Siuuuers/dwm using docs/agent/2026-11-04-performance-handoff.md. First verify current master and worktree state. The completed baseline was b6ed7b7c. Profile-write reuse, both registry-reuse changes, and duplicate day-renewal copy removal are finished. Next, split long-session playable-handoff cost into retained-source, ledger validation, control commit, and acknowledgement phases. Preserve DTL semantics, exact Save/Load, board state, encountered history, and global discoveries. Do not equate fresh Load with session age or trim retry/history state without tracing consumers. Use cloud Linux, focused checks, and matched complete-operation measurements; no broad matrix or fault injection. Parallel read-only investigation is welcome; coordinate shared-file edits. Proceed autonomously within this scope and ask only when observable behavior or an unresolved design choice must change.
