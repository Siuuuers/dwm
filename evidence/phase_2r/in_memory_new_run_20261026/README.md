# In-memory New Acc: accepted results, 2026-10-26

PR [#111](https://github.com/Siuuuers/dwm/pull/111) is merged.

- Baseline: `ff5b327a5433867f33c85644e3173d15cdef01d0`.
- Tested candidate: `e286838c106c1dd716ceacb89a5e4554f4b1b4d2`.
- Merged master: `0a15de6724ab6256953d0643eab74c6b8cb23807`.
- Candidate and merge have identical tree `15c7fa52fb9a80d54ea982f886a9062bb1ce85cb`.
- [Windows acceptance](https://github.com/Siuuuers/dwm/actions/runs/40307319429): 61 jobs passed, one intentionally skipped, zero failed.
- [Matched exported comparison](https://github.com/Siuuuers/dwm/actions/runs/40307319301): passed 24 processes and 64 screenshot hashes, with ObjectDB warnings and script/resource errors rejected.

## Behavior

New Acc starts at the canonical authored entry with fresh mutable defaults, without an initial Autosave, Sweet/Dark assignment, preference consumption, or durable creation operation. Previous saves and Profile/global progress remain intact. Ordinary later Save and Load continue to work; old Run9 assignment is ignored and omitted by later saves. Identity allocation remains because live board/day/restore consumers use it. Scene Logout remains unsaved, explicitly confirmed by the owner; this supersedes the earlier handoff's save-on-logout statement.

Title's approved confirmation sentence is applied in five locales without changing buttons/layout. Existing route and narrative signals finish activation. No polling coroutine holds Title across its destruction. Historical creation recovery code remains for compatibility paths; this is not a claim that every legacy subsystem was deleted.

## Matched medians

| Complete action | Baseline | Candidate | Change |
|---|---:|---:|---:|
| Fresh New Acc to complete first caption | 4.400001 s | 1.6408945 s | 62.71% less time |
| Retained New Acc, excluding confirmation dwell | 4.461479 s | 1.6911495 s | 62.09% less time |
| Log in through Load to complete saved caption, excluding drawer dwell | 2.3285135 s | 2.3726565 s | +44.143 ms (+1.90%) |

Four samples per variant/case, AB/BA/AB/BA on one Windows runner. The Load ranges overlap (baseline 2.280–2.477 s; candidate 2.268–2.423 s); no Load improvement is claimed. These descriptive samples do not establish statistical certainty or performance on every PC. Compare within this batch: absolute timings from earlier runners differ. Fresh means empty user data, not cold OS cache. Verbose engine logging and the observer are identical on both builds.

The action timer ends at the complete drawn caption, before the subsequent real Save or teardown. Retained New Acc and Load receive byte-identical copies of the first baseline profile after its real manual Save. Load proves old-format source bytes, run identity, gameplay, scene and reading position preserved; the candidate's later Save omits assignment.

Median largest action-frame gap remains 1.535 s fresh and 1.586 s retained, down from 2.813 s and 2.886 s. The action is faster but still contains a noticeable synchronous pause. Nested validation/phase counters are inclusive and must not be added together.

## Diagnostic corrections and limits

Three incomplete batches stopped on Ogg resources at shutdown, including unchanged baseline fresh and Load. Verbose logging named `story_theme.ogg`, AudioStreamPlaybackOggVorbis and related Ogg resources. The diagnostic now calls existing audio-owner cleanup only after measurements and saving, checks stopped/null players, and allows 100 ms plus a frame before exit. This is harness teardown, not proof of a production audio-shutdown fix. Strict errors were never suppressed.

Batch 40305621045 was green under the former error-only gate but manually rejected: all eight candidate New Acc samples leaked one GDScriptFunctionState. The added polling loop kept MenuScene awaiting SaveManager across scene replacement. Removing that five-line loop lets the existing signal owners complete activation without retaining the disappearing Title coroutine. The final batch has no ObjectDB warnings, leaked-instance lines, resource errors or script errors. The strengthened checker also rejects the retained earlier failing evidence. RGB8-to-RGBA8 hardware conversion warnings remain and are retained in journey-checks.json.

No local Godot execution occurred. Local work comprised source/static/Python checks, artifact analysis and visual review. All 24 caption screenshots were reviewed together; final candidate confirmation and loaded caption were also inspected at full size. Art, text and retained UI matched the expected scene.

## Retained evidence

- `summary.json`: raw sample metrics, hashes, inclusive phases, paired differences and aggregates; reverified with the final comparison script.
- `journey-checks.json`: observed state, full caption text, actual inputs, preferences, engine/renderer, process status, screenshot hashes and stderr for all samples.
- `source.json`, `harness.json`, package and startup-variant receipts: exact provenance.
- `shutdown-diagnostics.json`, `coroutine-diagnostics.json`: failures and manually rejected batch, not omitted from the record.
- `caption-review.jpg`, `confirmation.png`, `loaded-caption.png`: reviewed visual evidence.
- Full CI evidence artifact: 12643333786, zip SHA256 `87ac710708fe20336e17784d154af8c77f6b1a6b3442051fa139582ddafb1ea2`.
- Exact exported packages artifact: 12642463947, zip SHA256 `db3521524f7393d16e95bc32ab49bb8679b047044d3db5e087eec601cf454b49`.

CI artifacts expire; this evidence branch preserves the listed compact records. Do not merge raw evidence as a product change.
