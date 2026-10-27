# Save reading reuse comparison

Date: 2026-10-27, Hong Kong time.
Implementation and final acceptance: [PR 136](https://github.com/Siuuuers/dwm/pull/136).

[Matched cloud run](https://github.com/Siuuuers/dwm/actions/runs/40501137509) passed all 24 exported journeys.
Baseline: `278fe58b674058aba2cfde143139380ef3c81d85`.
Measured candidate: `2525f9d912ecad3d81e8d9f5b281f1ca2772846b`.
Four AB/BA pairs used one Windows runner and identical observation overlays.

| Median | Baseline ms | Candidate ms |
| --- | ---: | ---: |
| Manual Save, fresh | 999.73 | 943.30 |
| Manual Save, retained | 1016.20 | 941.73 |
| Manual Save, longer reading | 1019.64 | 943.02 |
| Passage first correct drawing | 605.29 | 604.81 |
| Passage usable | 625.23 | 624.82 |
| Load first drawing | 669.09 | 674.47 |

Longer-reading Save improved 7.5%. All four pairs improved in all three Save cases.
Scene validation calls fell from 12 to 8 in each longer-reading Save.
The median of the 28 ordinary-caption medians was 112.44 ms before and 112.21 ms after.
Passage drawing changed little. Load was 0.8% slower. Do not claim a Load speedup.

The removed restoration was inside Run schema validation. Compact expansion had already
restored the same reading owner. Actual restoration and Challenge position checks remain.
Quick Save also omits a redundant presentation preflight. This harness does not measure
Quick Save; source predicts two fewer condition captures, not a measured latency gain.

Save timing starts before Backup opening/live capture and ends after commit. It is not
physical-button-to-painted-confirmation latency. Profile spans overlap. OS caches were not
cleared. Do not compare absolute times across runners. Ordinary reading and passage retain
the zero game-save-write assertions; separate Profile persistence remains.

`measurement.json` retains all 24 Save samples and their profiles, passage observations,
ordinary-caption samples and source identity. Original artifact: `12732763809`.
Verified ZIP SHA-256: `e0fbd64262da3b1f9994c4e4a0d72e328199ee40563b9ef9e7ec5597878b9ffa`.

Initial regression passed 63 jobs and found stale generated API inventories. The cloud
generated and verified both replacement inventories. PR 136 records final acceptance.

## Final acceptance

[Final regression](https://github.com/Siuuuers/dwm/actions/runs/40503361601) passed all
67 executed jobs; one historical comparison was skipped.
[Final comparison](https://github.com/Siuuuers/dwm/actions/runs/40503361009) passed all
24 journeys on candidate `4901df5a2213591ea6702550fd46024e02a6f7e0`.
PR 136 merged as `0dae7e22cccf8453679b82e63536e67973023175`.

| Median | Baseline ms | Candidate ms |
| --- | ---: | ---: |
| Manual Save, fresh | 946.52 | 879.06 |
| Manual Save, retained | 933.09 | 887.76 |
| Manual Save, longer reading | 964.77 | 903.75 |
| Passage first correct drawing | 594.61 | 605.76 |
| Passage usable | 616.00 | 626.70 |
| Load first drawing | 635.85 | 639.22 |

Longer-reading Save improved 6.3%. All four pairs improved in all three Save cases.
Scene validations fell from 12 to 8 in every pair. The ordinary-caption
median-of-medians was 116.85 ms before and 115.66 ms after. Passage drawing was
1.9% slower and Load was 0.5% slower. No passage or Load gain is claimed.

`final-measurement.json` retains the final samples. Artifact: `12734476648`.
Verified ZIP SHA-256: `39396fad3b800ead4baedc050db301b8e2e17681dfffa6b981145dcfa6a61c99`.
