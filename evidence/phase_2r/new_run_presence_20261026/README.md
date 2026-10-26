# New Acc presence check: results, 2026-10-26

[PR #112](https://github.com/Siuuuers/dwm/pull/112) is merged.

- Baseline: `0a15de6724ab6256953d0643eab74c6b8cb23807`.
- Tested candidate: `60e1d47484fc33073935d6e5e1ba05cceb2a48d5`.
- Merged master: `a5ecd04ecb2724aaaf8c7462aa2b41e9f895ccc5`.
- Candidate and merge have identical tree `09fe449dd8d218274654659b79455f9068620572`.
- [Windows acceptance](https://github.com/Siuuuers/dwm/actions/runs/40313255691): 61 passed, one intentional skip, no failures.
- [Final comparison](https://github.com/Siuuuers/dwm/actions/runs/40313255772): 24 processes and 64 screenshot hashes passed.

## Change

GameState supplies a typed boolean for installed, unfinished progress. Scene New Acc asks for that fact through RunRestoreParticipant. It no longer captures, serializes and hashes the full restore backup, or retains its unused revision. The legacy hashed baseline remains and uses the same predicate.

Presence includes installed PLAYING and ENDING runs, even when a raw route has retained inactive progress. Completed and retired Logout runs do not require consent. The change removes incidental dependence on serializing unrelated gameplay values; it does not add another state owner or change saved data.

## Measurements

Four samples per variant/case, AB/BA/AB/BA, on one Windows runner per batch. Both builds use the same observer. The preparation wrapper is synchronous and preserves the method result. Its measured spans include observer overhead, which was not measured independently.

| Final-batch median | Baseline | Candidate |
|---|---:|---:|
| Fresh confirmation preparation | 1.3145 ms | 0.3250 ms |
| Retained confirmation preparation | 1.1770 ms | 0.1505 ms |
| Fresh New Acc to complete caption | 2.102481 s | 2.093959 s |
| Retained New Acc, excluding consent dwell | 2.075339 s | 2.028619 s |
| Log in through Load, excluding drawer dwell | 2.966238 s | 2.821501 s |

The first independent batch used the same product code before a test-only correction. Its preparation medians were 1.0725→0.3020 ms fresh and 0.9485→0.2280 ms retained. Its whole-action medians were 1.827718→1.785350 s fresh, 1.755747→1.762413 s retained, and 2.536215→2.559916 s Load. [First comparison](https://github.com/Siuuuers/dwm/actions/runs/40312173100).

The preparation saving is consistently about 0.7–1.0 ms. Whole-action changes vary between batches. Load is outside this optimization's changed preparation path; its timing movement is not a demonstrated benefit. No reliable player-facing speedup or Load improvement is claimed. The remaining long frame needs attribution before another product edit.

Fresh means empty user data, not cold OS cache. The retained and Load cases use identical copies of the first baseline profile. The seed includes real manual Save and Autosave operations after the timed caption. The later save checks and audio teardown remain outside action timing. Both variants use matched verbose logging and the existing post-measurement audio cleanup. Nested phase spans overlap and must not be added.

## Verification and limits

The focused presence contract covers fresh/detached state, PLAYING, ENDING, completion/reset, read purity, and independence from unrelated serialization. The rendered title test covers real New Acc, manual Save, unsaved Logout, a second fresh run, and fresh-process Load.

An added native-click assertion after raw goto_menu failed to show a confirmation sheet in the first Windows run. Its cause remains unproven. The intended retained-state contract is now tested at the real SaveManager prepare/cancel boundary, explicitly labeled as an integration test. Normal rendered UI journeys remain intact, and the comparison exercises real retained-save confirmation through actual button input. This is not proof of native UI behavior after a raw route.

The final logs have no ObjectDB leak warning, leaked-instance line, resource error or script error. Hardware RGB8 conversion warnings are retained in journey-checks.json. All 24 caption screenshots were reviewed together; the retained candidate confirmation was also reviewed at full size. Opening art, text and UI remained consistent.

No local Godot execution occurred. Local work was source review, static/Python checks, evidence analysis and visual inspection. The inventories passed the cloud read-only check.

## Evidence

- `summary.json`: all raw sample metrics, hashes, inclusive phases, paired differences and aggregates.
- `journey-checks.json`: state observations, inputs, preferences, renderer, process status, screenshot hashes and stderr.
- `first-batch-selected-metrics.json`: raw and aggregate preparation/full-action metrics from the first batch.
- Source, observer, package and startup receipts identify the exact sources and exported packages.
- `caption-review.jpg` and `confirmation.png` retain reviewed visual evidence.
- Final full evidence artifact 12646511351: SHA256 `c2f414abc7f5d28835f6734d4c591e5d9e6e6d46adc0d3d4cb08ed367b95cb5a`.
- Final exported packages artifact 12645324542: SHA256 `21862e3ae21997e0099ebda62e95efc329bb391e555397ec491a1e2e8ce3cfd7`.
- First full evidence artifact 12645626087: SHA256 `8e0cb3656ce5475504cee7065c0d56a573a927f350d70149c4d25337489776ef`.

Keep this evidence on its separate branch. Do not merge raw evidence as a product change.
