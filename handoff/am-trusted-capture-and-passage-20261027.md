# Trusted capture and passage compilation accepted

Date: 2026-10-27, Hong Kong time.

## Working policy

Use cloud-only Godot execution and automatic tests. The user permits focused parallel audits and direct merges after acceptance. Trust shipped content and internally admitted values. Keep validation at the boundary that owns unknown input. Do not add speculative guards or managers. Preserve encounter synchronization, saved-data obligations and native presentation/input ownership.

Nonblocking error-and-skip for manually edited DTL is out of scope. This supersedes the pending item in the older al handoff. Do not restore that task automatically.

Read current master and root AGENTS.md before editing. The previous record is [al](al-trusted-load-accepted-history-next-20261027.md).

## Accepted PR 119

[PR 119](https://github.com/Siuuuers/dwm/pull/119) merged as `211192562d7be919d0dfd65714153e5199762f29`.
Its tree is `1d547ae6a9180ac0f5715c853e3b20fe27993264`, exactly the tested tree.
Tested candidate: `d12778f427a6f4ac1a37b977f95dc1b3e0fc78d5`.
Baseline: `1592d62f9f68b02e1c0778ca083bfb8115272319`.

`SoloReadingSession._capture_scene()` now returns its detached checkpoint after encounter synchronization. It no longer reconstructs and validates a second temporary ledger. Native publication and restore own admission. Restore and explicit saved-state validation remain unchanged. Keep copies, progress synchronization and pending-checkpoint consumption.

The new focused test starts with uncaptured encounters. It checks encounter synchronization, pending-boundary consumption, detached nested data, repeated capture and History, subsequent native publication, and restore equality.

### Acceptance evidence

- [Regression 40393643880](https://github.com/Siuuuers/dwm/actions/runs/40393643880): all 61 executed jobs passed.
- [Matched export 40393644197](https://github.com/Siuuuers/dwm/actions/runs/40393644197): all 24 journeys passed.
- Four repetitions per variant/case, AB/BA/AB/BA, same Windows runner and observation overlay. Cases are fresh New Account, retained-profile New Account, and Load. Each uses a fresh process. OS caches are not cleared.
- Thirty actual encountered captions, with natural reveal followed by real Enter press/release. Same Run and saved gameplay/scene/reading/source bytes remain intact. Subsequent Save and Autosave succeed.
- Measured processes exit cleanly, with no script errors or ObjectDB leak reports.
- Visual review covered all eight Load next-caption images and representative title, backup, New Account and consent images. No observed layout regression. Next-caption captures remain mid-reveal by design.
- Artifact `12686453071`: `history-refresh-evidence-40393644197-1`. ZIP SHA256 `a0622f4eca52c7615045331c847726697ff7d9820294e0933e1811234e40367d`.
- Selected raw samples and aggregates are retained in [trusted-capture.json](../evidence/reading_performance_20261027/trusted-capture.json). GitHub artifact retention is seven days.

Milliseconds; medians of four samples per variant:

| Measurement | Baseline | Candidate |
| --- | ---: | ---: |
| Load to first correct drawing | 974.428 | 659.410 |
| Load to complete caption | 1030.872 | 688.424 |
| First Accept to next correct drawing | 71.902 | 62.997 |
| Caption 30 input to observed drawing | 155.598 | 128.143 |
| Caption 30 maximum frame gap | 112.515 | 84.796 |
| First Accept capture cost | 19.901 | 0.042 |
| Caption 30 capture cost | 34.049 | 0.186 |
| Total capture cost during Load | 368.496 | 0.532 |

These are instrumented, descriptive results on one software-rendered Windows runner. They are not a device or frame-rate guarantee. Synchronous spans overlap; do not sum nested costs. Later-caption drawing intervals can include an observation frame. Observer capture/hash occurs after the complete-caption timestamp. It contributes to first-input-ready and next-drawing latency, not Load-to-complete-caption latency. Its cost is measured separately. Do not compare this run numerically with older, differently instrumented Load runs.

### Rejected refresh experiment

The first PR 119 candidate coalesced deferred UI refresh requests. The matched journey executed one refresh during Load and none during ordinary caption advance. Complete Load did not improve. That candidate and its specific tests were removed before acceptance. No pending-refresh flag remains in the accepted tree.

The first comparison run had an incorrect summary assertion that expected an ordinary Accept to execute a UI projection. Zero calls are valid. The final accepted harness records absent counters as zero. Do not report the rejected candidate as an optimization.

## Accepted PR 120

[PR 120](https://github.com/Siuuuers/dwm/pull/120) merged as `adb7d03260765660ba308611db670cfe5e94e5d6`.
Its tree `a71a1aac0e1eb48f0493ab55c2f0f692b3cbd283` exactly matches the tested candidate.
Candidate: `47c377251f97de802c6bf7dad3f19c0a96cfb367`.
Baseline: accepted PR 119.

The one runtime change routes `DialogicBridge._prepare_scene_entry()` through the existing runtime compiler. The caller uses selected registered labels/markers and only reads the returned mapping. The runtime compiler shares the current-day parse and caches the prepared immutable mapping. Admission can reuse it. Registration replacement clears caches; translation-enabled mode still bypasses reuse. Public strict compilation remains available for physical-source validation.

The dedicated experiment reaches line.Day1.031 through real input. Its next ordinary Enter selects the existing pass route and reaches line.Day1.photo.default.001. Before timing, it checks that the destination is absent from runtime and strict semantic caches while the current day parse is available. After timing, it checks choice, destination, same Run, History, no unselected yes-route encounters, and subsequent Save/Autosave.

### Acceptance evidence

- [Regression 40396170770](https://github.com/Siuuuers/dwm/actions/runs/40396170770): all 61 executed jobs passed; one older benchmark skipped.
- [Matched export 40396170828](https://github.com/Siuuuers/dwm/actions/runs/40396170828): all 24 journeys passed. Four matched uncached-passage pairs used the same observer and Windows runner.
- All eight destination screenshots were reviewed. Caption, art, scrollback and controls agree. The pass choice, same Run, History and subsequent Save/Autosave checks pass. Measured processes exit cleanly.
- Artifact `12687043105`, `passage-compilation-evidence-40396170828-1`. ZIP SHA256 `218670edb5d97a51ef7453d8a812356d89cdcdc3e5f31ee218ebf9511ab811fe`.
- Raw samples, aggregate metrics and scope are retained in [passage-compilation.json](../evidence/reading_performance_20261027/passage-compilation.json).

| Measurement, median ms | Baseline | Candidate |
| --- | ---: | ---: |
| Entry preparation | 100.774 | 35.093 |
| Input to first correct destination drawing | 2368.298 | 2285.117 |
| Input to complete reveal and usability | 2390.203 | 2306.515 |
| Maximum frame gap during transition | 2363.611 | 2280.928 |
| Ordinary Load to complete caption | 680.080 | 693.255 |

Entry preparation improves by 62.8–67.8 ms in every pair. Day parses fall from one to zero; source reads fall from two to one. Whole-transition improvement is modest and noisy: one paired first-drawing sample worsens by 151.025 ms. Do not claim a universal transition or Load improvement. These measurements use additional compiler observers and must not be directly compared with PR 119 figures.

The remaining transition hitch is about 2.3 seconds. This change does not solve it.

## Next priority: attribute repeated checkpoint projection

The first new passage records 63 `_validate_scene_saved` calls in both variants. Candidate median aggregate cost is 1083.503 ms. The action also records about 132 captures. These costs overlap other spans; do not add them.

Independent review traced the probe's ready polling and frame-post-draw observation. Neither invokes saved-state validation. Full snapshot, History and PNG checks occur after the timing scope is cleared. The repeated validations are production work. Exact caller attribution still needs measurement.

Do not remove `restore()` validation globally. Start with the complete native pass transition already measured. Attribute checkpoint projection, equality comparisons, source retention and frozen-boundary checks. Compare complete input-to-drawing and frame-gap results with the same observer.

### Smallest next experiment

In `scripts/application/narrative/SaveManagerNarrativeCheckpointPort.gd`, `_scene_route_candidate_valid()` already calls `_scene_candidate_reference()`. The explicit reference check immediately after the route check repeats this work. The final precommit pair repeats it again. At the accepted revision these sites are lines 494/496 and 510/512; the nested call is at 626.

Each reference compares persisted versus retained checkpoint and persisted versus supplied checkpoint. `_player_checkpoint_same()` projects both sides. `SoloReadingSession.project_player_checkpoint()` and its nested player-reading projection restore twice. Static successful-path tracing therefore identifies 16 of the 63 validations in two duplicate reference checks. Actual time attribution is not yet measured.

First add identical caller-phase counters for `_scene_candidate_reference`, `_player_checkpoint_same`, `project_player_checkpoint` and `_validate_scene_saved`. The smallest candidate keeps explicit reference checks for non-scene-route entries and omits only those covered by the scene-route validator. Preserve candidate fingerprints, authority/source callbacks, post-callback checks, restore validation, equality semantics and persisted-target identity. Expect 16 fewer validations only if the instrumented path confirms the trace.

Required evidence:

- `tests/unit/test_scene_checkpoint_ack.gd`: final authority/source callbacks cannot mutate prepared narrative, payload or checkpoint ID before writing.
- The same file: changed candidate payload, uncertain readback, changed board facts and reintroduced retry ledgers still fail.
- `tests/integration/test_scene_owner_composition.gd`: a callback that changes the lower prepared object is refused before commit.
- Keep non-scene-route entry coverage, failed-write rollback and uncertain acknowledgments.
- Repeat the same complete real-input passage comparison and destination screenshots after independent review.

This is a new focused investigation. Neither PR 119 nor PR 120 implements the proposed duplicate-check deletion.

## Secondary measured lead: first History resource load

Accepted PR 119's Load History projection costs 21.044 ms median. Its nested `project_encountered()` costs 2.797 ms. All 19 Load captures together cost only 0.532 ms. About 18 ms remains unattributed in the projection wrapper.

The dynamic `load("res://scripts/narrative/SceneReadingHistory.gd")` is a hypothesis, not proven attribution. Measure that resource load separately and a second actual History projection in the same process. Do not immediately preload it: this can move a one-time cost into startup. Compare total launch/Load and later History before accepting a change.

Ordinary Accept currently performs no History projection. First- and 30th-caption capture medians are below 0.2 ms. The maximum total capture time per measured Accept action is 0.337 ms; the maximum individual capture call is 0.209 ms. Further capture/copy surgery is not justified by this evidence.

Keep named presentation checkpoints and overlays as a separate feature. No new architecture question currently blocks this measured performance work.
