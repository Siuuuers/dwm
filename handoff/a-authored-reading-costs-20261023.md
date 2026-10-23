# Authored reading costs — 23 October 2026

Continue cloud-only Windows / Godot 4.6.3 standard. Read AGENTS.md and CLAUDE.md. User requests smooth flow, minimal meaningful verification, autonomous progress and focused parallel review. No design question currently blocks the scoped changes. No master/PR51 changes, merge or Steam upload.

## Ownership and current source

Product branch: `codex/authored-week-followup-20261023`. PR30 is historical; draft PR50 is the separate diagnostic controller (`codex/story-day-qualification-20261023`). Never merge its workflow overrides into product.

Latest qualified runtime: `fceef00d715e67e68c7c806092359f012513300c`, tree `a5493c81b40398d06e824f3ff2cf630be15e2bdc`. Master remains `d2062f8d9807f7f06935f86065640ff14a5400d6`; it has no newer fix for this path.

Previous handoff: [validation owner reuse](a-authored-owner-reuse-20261023.md). The later baseline omitted by that handoff is native-projection runtime `27321f29754e7201cf1f445941e5ca687ecd4b64`, cloud run 39909557197.

## Observable outcome and changes

Restore the authentic interrupted Day2 save through real Load, preserve its visible beat and all prior consequences, then cross its saved control boundary without a long pause.

1. `86668705820ca91676f14455d71df4fe5b36c138`: ledger entry lookup derives a set from admitted beats instead of scanning every beat per publication. Both restore paths transfer it; save bytes unchanged.
2. `4785ef958e947fb60b72c936783b5cd087e32fd5`: one fresh operation/path proof supplies the opposite endpoint. The selected endpoint is already checked; public project/path APIs retain full validation. No cross-call proof reuse.
3. `fceef00d715e67e68c7c806092359f012513300c`: each pure validation checks each distinct occurrence/entry frame once, carrying the fresh source publication set into its suffix. Ledger-owned frozen frames are returned as detached results without revalidating their immutable payloads. Public arbitrary-frame validation remains fresh.

Independent implementation and test-body reviews completed before each candidate's cloud run. Tests cover both phases, changed plan hashes, opposite ledger refusal, invalid paths, duplicate source/suffix/destination publications, changed frames on later calls, detached results, empty restore, manifest-only rejection and failed-restore isolation.

## Cloud comparisons

| Run | Runtime | Cases | Load | Control departure | Ordinary captions |
| --- | --- | --- | --- | --- | --- |
| [39909557197](https://github.com/Siuuuers/dwm/actions/runs/39909557197) | 27321f29 | 18 | 79.193 s | 141.578 s | 1.021 / 0.956 s |
| [39914912447](https://github.com/Siuuuers/dwm/actions/runs/39914912447) | 86668705 | 19 | 85.139 s | 148.042 s | 0.921 / 0.845 s |
| [39915753102](https://github.com/Siuuuers/dwm/actions/runs/39915753102) | 4785ef95 | 16 | 43.007 s | 69.409 s | 0.548 / 0.530 s |
| [39916362418](https://github.com/Siuuuers/dwm/actions/runs/39916362418) | fceef00d | 35 | 60.168 s | 84.397 s | 0.710 / 0.731 s |

All cases passed with clean requested child exits. The fast middle runner also had much faster unchanged boot, so do not attribute its whole timing difference to the code. The first lookup alone established no elapsed-time improvement. Deterministic repeated work was removed, but these pauses remain unacceptable for smooth flow.

Latest Load still performs 28 snapshot validations (45.628 s inclusive total); departure performs 24 (38.323 s). Receipt authentication and physical Profile proofs remain fresh. Inclusive timing scopes overlap; do not add them.

Compact original logs, JUnit reports, process records, source pins and comparison metadata are retained under `evidence/phase_2r/authored_followup_20261023/run<id>_comparison/`. Each inspection records the downloaded original artifact's SHA256. Outer/inner ZIP CRCs were checked. Full archives remain in the corresponding GitHub Actions artifacts; the authentic seed root remains committed in `run39888749357_journey/original-artifact.zip`. This session did not duplicate those large archives into the repository. Baseline screenshot was inspected with both paintings and “I could tell her I wanted her to stay.”

## Remaining work and active experiment

The genuine probe covers 290 retained captions and 17 receipts, not the whole week. The original 1,800-second authored journey remains failed. Do not claim full-week or export acceptance.

The pure reading memo experiment `6d91719f63077aa7ca917ae30c70c55998e54022` passed all 39 cases in [39918248332](https://github.com/Siuuuers/dwm/actions/runs/39918248332), but was rejected and removed. Load/control measured 46.113/64.118 seconds, while unchanged bundle/physical work ran at about 70% of the previous runner and ordinary captions worsened to 0.839/0.847 seconds. Cache-key checks alone consumed 6.570/17.268 seconds. This does not establish a useful cache speedup. Compact proof/profile data is retained in its comparison directory; original logs remain in the Actions artifact.

Current candidate `66e035ba77765cdf50b7246e9b57d06fc5d3809a`, tree `bde973298e4455fc474f93766a97f7cde5b82227`, removes that memo completely. Manifest owns one recursively frozen structural projection for its already admitted selected registration. An explicit selected-receipt API reuses it, while arbitrary-bundle validation stays fresh. FrozenRunContext and seven selected GameState callers use the selected API. SaveManager reuses its existing exact-text parser for the retained initial creation document, after fresh durable creation/allocation/Profile checks. No receipt/issuer/Profile/disk proof is cached.

Independent source/test review passed; `git diff --check` passed. Cloud qualification [39919536732](https://github.com/Siuuuers/dwm/actions/runs/39919536732), controller `78079273b3f10cad6cb7fbe6ec8945890e6ebd71`, is pending at this checkpoint: 6 registration cases, 12 saved-event-anchor cases, 5 joint-new-run cases and the same genuine recovery. It is not yet the qualified runtime above.

Then complete the existing authored Day4 Save, fresh-process Load to ending, ending replay and fresh New Game; export/launch the exact final source only after the journey passes. The existing 836-caption route and 1,800-second per-process deadline remain. No repeated artwork or Settings suite is needed. Diagnostic recovery workflow currently still has its PR path trigger: retire it when switching to the authored-week workflow, because PR paths are cumulative.
