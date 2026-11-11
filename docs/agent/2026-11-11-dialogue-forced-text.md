# Skip matcher scans for explicitly escaped text

## Outcome and scope

A leading backslash is Dialogic's existing forced-text serialization. Select the
cached Text prototype directly for that prefix, then duplicate and parse it as
before. All other input retains the original ordered matcher loop. The runtime
change is three lines in DialogicTimeline.event_from_string.

Baseline: 76d7c1e59d6b7284ea938da27d01968874af69d3 (PR #272).
Candidate runtime/tests/workflow: 7de852a1b9341cbd0266329d218e8b4ce2b5e84a.

## Investigation before editing

The earlier trace measured first-use dialogue parsing around 44–53 ms. Split
Timeline.process into cache setup, event selection/construction and content
loading. On the two 455-line opening parses, baseline selection/construction was
31.995 / 27.501 ms; content loading was 15.703 / 13.372 ms; complete process was
49.552 / 42.394 ms. The initial 313-line setup parse also paid event-cache setup;
that is separate from the opening costs.

First tested sharing two fixed Text regexes. Its benefit was unclear, so revert
that experiment completely. A subsequent diagnostic split selection into matcher
scans (14.825 / 16.035 ms) and event duplication (9.893 / 11.445 ms). That trace
still had the experimental regex reuse and is not final-candidate evidence.

Audit both callers and the shipped event registry. Timeline.process and the
editor Enter handler both pass get_event_cache(), which always appends Text last.
No shipped non-text matcher accepts leading backslash. Text.to_text already adds
that escape to command-looking prose. Preserve prototype duplication, custom-default
application, translation-ID parsing and event-owned state. No new cache,
parser, manager, grammar or generic external-input protection is introduced.

Failure obligations: escaped command-like prose must stay Text; unescaped events
must retain classification/order; multiline text and IDs must match the old path;
event text/state must remain independent. Focused tests compare against the
original matcher loop rather than guessing a new grammar.

## Measurements

Final candidate only, Linux headless Godot 4.6.3 standard, B/C/C/B. Separate fresh
users and sequential engines; no source instrumentation in full-path comparisons.
Click New Game two seconds after mandatory runtime readiness. Require exact
opening caption, visible completed reveal, native completion, acknowledgment and
unblocked input. Immediately open Computer and verify the same caption.

| Operation | Baseline | Candidate |
| --- | --- | --- |
| New Game to usable caption, ms | 373.389 / 353.306 | 360.391 / 344.016 |
| Median, ms | 363.348 | 352.204 |
| Computer open, ms | 23.733 / 25.668 | 25.277 / 23.126 |
| Instrumented opening parse, ms | 49.552 / 42.394 | 26.810 / 26.893 |
| Selection/construction within those parses, ms | 31.995 / 27.501 | 12.347 / 12.315 |

The full-path median moved by 11.144 ms (3.1%), but ranges overlap and there are
only two observations per version. This is not a reliable whole-game or Windows
speedup estimate. The separate diagnostic shows a much clearer reduction in the
targeted scan. Its two parses occur within one process and are correlated; do not
present them as independent trials. No startup-speed claim. One candidate probe
had an ObjectDB shutdown warning; all four exited 0 without errors.

## Focused acceptance

27 tests / 1033 positive test-body assertions in JUnit:
- Forced-text classification, parsing and independence: 2 / 76.
- Scene compiler cache, including translation/source refresh: 18 / 603.
- Native activation runtime: 7 / 354.

Native fixture retains its missing self-talk localization warning; no test errors.
The first new test incorrectly expected Resource.duplicate to retain a non-exported
portrait runtime field. The unchanged original duplication also does not promise
that. Remove that test assumption, retain its failed log/XML, and rerun the final
suite. Do not count that failed attempt as passing acceptance. Independent caller,
editor, defaults and test review passed. No GameState/SaveManager inventory change.

Windows run [43014141188](https://github.com/Siuuuers/dwm/actions/runs/43014141188)
passed on candidate 7de852a1b9341cbd0266329d218e8b4ce2b5e84a: export, packaged data
audit, opening, Computer, Save and exact fresh-process Load. All three processes
exited 0 normally with no forced cleanup or player warnings/errors. Saved/restored
screenshots reviewed: exact caption, matching artwork, no clipping observed.

Create title observed at 7099.650 ms; early New Game to observed caption
3705.465 ms; selected Load to observed caption 673.714 ms. These UIA upper bounds
include polling/provider waits and are not matched Windows speedup estimates.
Forward+/D3D12 Microsoft Basic Render Driver, Dummy audio, accessibility Always;
no physical-GPU/audio qualification. Artifact 13851568383 SHA256:
d9d76b0bf189dc36e8f51b63d52eb6d0a2ac727e2b628f61bf75471edb7d1e97.
Export ZIP SHA256:
0f4dbbf4b4bbe9dd93d9958c77618d01d30a6767e5a9c784d5011bd471fbf75d.

## Reproduction and omissions

Evidence: tools/player_latency/evidence/2026-11-11-dialogue-forced-text, with a
sha256 manifest. `forced/` contains final comparisons, diagnostic and focused
checks; `investigation/` contains baseline attribution and rejected regex results.
In an imported checkout with the baseline commit available and godot on PATH,
copy final scripts to .godot/ci/dialogue-parse/forced and rename observe.gd.txt to
observe.gd. Run compare.py on the candidate from repository root with fresh owned
user/output paths and no concurrent engines/editors. It swaps only timeline.gd
and restores candidate bytes in finally. attribute.py instruments the CURRENT
revision, so choose baseline or candidate explicitly and use a fresh user path.
Investigation scripts use .godot/ci/dialogue-parse and require the rejected patch
for regex-candidate/selection reproduction (decompress rejected-regex.patch.gz).
The rejected patch is not shipped.

Skipped unrelated suites, broad rendering matrix, new injection tests and lint.
The focused behavior test protects the escape rule. A future custom event that
accepts the forced-text prefix would need to revisit that existing convention.
Keep content loading and separate native event ownership intact; no further
removal is justified by this scan result alone.
