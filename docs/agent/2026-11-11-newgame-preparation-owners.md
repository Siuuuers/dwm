# Initial reading ownership cleanup

## Result and scope

Remove a throwaway whole-registration copy and a repeated walk over the canonical
frozen story bundle. Preserve exact opening text, presentation, context schemas,
session ownership and restoration behavior. This is a small ownership cleanup;
**the matched runs do not demonstrate faster New Game**.

Baseline: 1b96539b3664e39795e9eb43c4fde18f21845431 (PR #271).
Candidate runtime/tests/workflow: 174360c8658da657f0caec3d236ca11ef4102354.

## Investigation before editing

The prior trace identified snapshot input around 49 ms and initial reading around
52 ms. Follow their callers before changing them: initial reading also serves
saved-candidate reconstruction, so retain its frame and scene validation.

Nested baseline trace:
- Snapshot presentation arrival: 44.178 ms. Separate deeper trace: first runtime
  source parsing 44.489 ms, programme projection 1.391 ms. This is useful first-use
  parsing; it remains intact.
- Initial presentation context: 10.798 ms. FrozenPresentationContext requested a
  detached copy of the entire bundle, then copied only its schemas and IDs again.
- Initial configuration: 36.900 ms. Separate deeper trace: catalogue construction
  5.879 ms, registration preparation 16.008 ms, recursive freezing 13.666 ms.

FrozenPresentationContext now reads scene_contract_tables().bundle and retains
its existing detached schema/ID copies. Selection, registration-use marking,
errors and retained-schema fallback have the same owner and behavior.

SoloReadingSession freezes only the newly allocated catalogue, variants and
registry, then the outer prepared dictionary. The canonical manifest owner
already recursively freezes bundle and manifest before publishing them. The
registration factory freezes its indexes. No generic read-only shortcut is added.

Failure obligations: returned schema mutations must not alter the context owner
or canonical bundle; nested catalogue/beat data must stay immutable; replacement
registrations must not reuse prior configuration; New Game and initial-candidate
reconstruction must remain valid. Existing and added focused checks cover these.

## Measurements and limits

Godot 4.6.3 standard, Linux headless. Eight sequential, uninstrumented runs,
B/C/C/B then C/B/B/C, each with a fresh user. New Game is invoked two seconds after
mandatory runtime readiness. Require exact opening caption, completed reveal,
native completion, acknowledgment and unblocked input. Then open Computer and
verify the same caption remains visible.

| New Game to usable caption | Baseline ms | Candidate ms |
| --- | --- | --- |
| Samples | 432.020, 356.469, 370.674, 375.164 | 379.999, 403.490, 374.620, 378.384 |
| Median | 372.919 | 379.192 |

Candidate median is 6.273 ms higher, with overlapping sample ranges. The first
four runs were inconclusive, so a second balanced group was added. Do not claim
an overall speedup or a statistically established regression from this sample.
Startup observations are retained in matched JSON; no startup improvement claim.
Two baseline probes and one candidate probe emitted an ObjectDB shutdown warning.
All eight exited 0 without errors; warnings are retained rather than discarded.

Separate diagnostic runs observed context setup 10.798 -> 2.376 ms and freezing
13.666 -> 8.955 ms. Candidate complete configuration was 36.578 ms, close to the
baseline 36.900 ms. These are single instrumented observations, not matched
confidence estimates. Retain this tiny change because it removes identifiable
redundant copying/traversal under existing owners; do not present it as a visible
latency win. Candidate parsing remained 50.993 ms in its deeper diagnostic.

## Focused acceptance

Four separate suites: 31 tests / 2805 positive test-body assertions in JUnit.
- Scene compiler cache: 18 / 603, including nested immutability and detached
  context schemas/IDs/returned results.
- Frozen presentation context: 6 / 2101, including retained schema behavior.
- Initial candidate: 6 / 60.
- Joint New Game: 1 / 41.

All focused logs have no warnings/errors. Independent read-only review passed.
GameState/SaveManager public surfaces and callers are unchanged; no inventory
regeneration required. No new lint rule, unrelated matrix or injection tests.

Windows run [43011887474](https://github.com/Siuuuers/dwm/actions/runs/43011887474)
passed on candidate 174360c8658da657f0caec3d236ca11ef4102354: export, packaged data
audit, opening, Computer, Save and exact fresh-process Load. Three normal exits 0,
no forced cleanup, no player warnings/errors. Saved/restored screenshots reviewed:
exact caption and matching artwork visible, no clipping observed.

Create title observed at 6967.964 ms; early New Game to observed caption
3506.447 ms; selected Load to observed caption 843.752 ms. These UIA upper bounds
include polling/provider waits; no matched Windows speedup or regression claim.
Forward+/D3D12 Microsoft Basic Render Driver, Dummy audio, accessibility Always.
Physical-GPU/audio qualification was not run.
Artifact 13851336693 SHA256:
939610efee7eb12bc0e2e2930b19c68d9d38d7660841b1d8cc1677e3f0b6be7d.
Export ZIP SHA256:
418771a916b6da9142f6245dac0f2c1da86591e3dfe244e358413cabf5551722.

## Reproduce and continue

Evidence: tools/player_latency/evidence/2026-11-11-newgame-preparation-owners.
sha256.json identifies retained logs, JUnit, scripts and observations. In an
imported checkout with the baseline commit available and godot on PATH, copy the
scripts to .godot/ci/newgame-owners and rename observe.gd.txt to observe.gd. Use
fresh owned output/user paths. Run compare.py, then compare_extension.py, with no
other engines/editors. They switch only the two runtime files and restore the
candidate in finally. Run attribute.py and deep.py on the baseline checkout;
run candidate_attribute.py and candidate_deep.py on the candidate checkout. These
diagnostic scripts instrument current sources and restore them; they do not
select revisions. Run each separately with a fresh diagnostic user directory.

Next measured target is first-use dialogue parsing, roughly 44–53 ms in these
traces. Break down resource construction and text processing before changing it.
No parser replacement or title-idle warming is implemented in this pass.
