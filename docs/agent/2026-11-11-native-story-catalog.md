# Native parsing for shipped story catalogues

Baseline: b69e3a56ed4edacccd5eb3f9206b654910cc275f (PR #274).
Outcome: reduce first-caption catalogue parsing while preserving all displayed text.

## Change and scope

StoryLocalization.catalog uses Godot JSON.parse_string instead of the scripted
StrictJson parser for shipped localization/story files. It keeps lazy caching,
missing-file and non-dictionary fallback, supported-locale selection, English
source matching, markup and translation behavior. StrictJson remains unchanged
for saves and other boundaries. The existing catalogue validator rejects duplicate
keys and verifies English DTL correspondence and all translated string catalogues.

Callers reviewed: DialogicBridge, SceneHost, DialogueLibraryCatalogue and witnessed
caption/history presentation. No caller uses the removed parser constant. No new
owner, dependency, migration, lint rule or source inventory is needed.

## Evidence

Six sequential fresh-process Linux headless runs alternate B,C,C,B,C,B. Each waits
two seconds after mandatory runtime readiness, clicks New Game, requires the exact
fully revealed opening caption plus native completion, acknowledgement and input
readiness, then opens Computer and checks the caption remains unchanged.

| Revision | New Game to usable caption (ms) | Median (ms) |
| --- | --- | --- |
| Baseline | 553.387, 418.487, 336.580 | 418.487 |
| Candidate | 326.196, 313.736, 296.597 | 313.736 |

All six journeys passed. One baseline and one candidate emitted an ObjectDB
shutdown leak warning; no engine errors occurred. Host variation is substantial;
the 104.751 ms median difference is not a guaranteed saving or Windows claim.
The prior parser-only comparison in PR #274 is stronger attribution evidence:
English strict 32–33 ms versus native 2.4–5.0 ms with identical values.

Focused acceptance: 7 tests / 300 assertions (catalogue and bilingual journey),
then 1 test / 40 assertions (fresh-process Load), all passing with clean final
logs. The new test compares every shipped catalogue against strict parsing,
requires nonempty dictionaries and unchanged cache identity, and checks unsupported
locale fallback. Existing tests cover source mismatches, missing translations,
paired text and current-profile presentation after Load. Catalogue validator passed.
Independent read-only caller and test review found no issue.

The initial unit-only invocation used an invalid test-root location and let normal
startup run; its assertions passed but resource errors occurred on shutdown. A
second runner attempt supplied an unsupported GUT argument and did not run tests.
Both logs are retained, excluded from clean acceptance. Final checks use a valid
.godot/phase2r_tests child directory and automatic test_manual mode.

## Reproduction and omissions

Evidence: tools/player_latency/evidence/2026-11-11-native-story-catalog, including
logs, XML, comparison scripts, probes and SHA-256 manifest. Copy scripts into
.godot/ci/native-catalog and rename observe.gd.txt to observe.gd. compare.py swaps
only StoryLocalization.gd against the baseline and restores candidate bytes in
finally. Run engines sequentially. checks.py runs the focused creator then loader
in separate processes with shared isolated storage; use fresh storage on reruns.
Run python tools/localization/validate_story_catalogs.py for shipped data validation.

Skipped the unrelated test matrix, new fault injection, rendering matrix and a new
Windows export: the change is catalogue parsing, not layout or platform code.
Headless tests do not establish physical paint time. Menu busy waits are unchanged;
review their rendered feedback separately before removing them.
