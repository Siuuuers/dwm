# Settings first-open investigation: reject dialog-theme reuse candidate

Base: master `caf1c8c640ec64a3db6245a3fb83a78c2ed0669c` (PR287). No runtime change accepted. Runtime and test source were restored exactly to this base after measurement.

Goal: reduce first Settings opening without moving required first-ready setup later or changing controls/focus. Profile before choosing surgery.

## Attribution

Two headless Godot 4.6.3 fresh-process probes on authored Day1 measured `SettingsContent.apply_text_size` sections. First Settings also constructs Computer; these spans do not account for the whole opening.

- First theme/context section: 163–171 ms. It includes font/theme preparation and category/scroll presentation; it does not isolate individual font loads.
- Controls sheet presentation: first 12.5–13.4 ms, later 10.2–13.6 ms.
- Font overrides: roughly 5–6 ms.
- Dynamic values/status presentation: roughly 7–11 ms.
- Rail text measurement: below 0.3 ms.
- Reset dialog presentation: roughly 5.6–7.4 ms.

The main theme already survives unchanged refreshes. Initial theme construction includes the five-language font fallback setup. Removing those fonts is not justified: native language names and localized UI still need correct glyph coverage.

## Trial and rejection

The candidate retained ControlsSheet dialog themes when theme/font size/large-target inputs were unchanged, kept live binding refresh, and shared one confirmation theme across four dialogs. Independent source review found no correctness blocker. A focused regression was drafted for theme identity, live copy refresh and independent input invalidation; it was not run because the performance gate rejected the candidate first.

Initial uninstrumented first openings: baseline 486/490 ms, candidate 624/642 ms. Later instrumented candidate openings were 510/544 ms and showed a local Controls section reduction to about 7.6–9.6 ms on refresh. Instrumented timings cannot substitute for complete-operation comparison.

A second uninstrumented comparison ran base → candidate → candidate → base with identical fresh-profile probes:

| Revision | First opening | Later openings |
| --- | ---: | ---: |
| Base, first process | 538.384 ms | 56.151 / 58.232 ms |
| Candidate, first process | 539.550 ms | 52.277 / 57.870 ms |
| Candidate, second process | 596.108 ms | 61.023 / 63.776 ms |
| Base, final process | 486.919 ms | 54.930 / 52.553 ms |

No complete-operation improvement established. First opening remained worse in the candidate sample; later openings were inconsistent. The measurements do not prove why: scheduling, resource initialization and changed theme sharing were not independently isolated. Rejecting the candidate avoids shipping an unsupported optimization.

All 12 diagnostic/comparison processes completed 52 assertions each (624 total): actual Settings/Computer viewport open-close cycles, current preference, restored caption admission and unchanged reading history. These headless checks are not visual Windows proof. New candidate-specific suites and broad matrices were not run after rejection. No lint rule added.

## Evidence and next boundary

Evidence: `tools/player_latency/evidence/2026-11-12-settings-layout-investigation/`, including the rejected patch, raw compressed logs/XML, probes, ordered comparison runner and SHA256 checksums. Run from repository root after copying scripts to `.godot/ci/settings-open/` and probe to `probe.gd`; use fresh labels. Apply the rejected patch only in an isolated experiment. The comparison script restores the candidate in `finally`; restore base after experimentation.

Next useful measurement: split the first theme/context span into typography/font fallback construction, style/icon creation, and the initial scroll/category applications. Do not add more memoization until an end-to-end first-open improvement survives a matched comparison. Existing PR287 close-time improvement remains intact.
