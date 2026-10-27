# Trusted live Save comparison

Date: 2026-10-27, Hong Kong time.

[Cloud run](https://github.com/Siuuuers/dwm/actions/runs/40492720812) passed all 24 exported journeys.
[PR 135](https://github.com/Siuuuers/dwm/pull/135) tracks final regression acceptance and merge status.
Baseline: `93c3198639a54c9b392754d462d62fc7a9a3db70`.
Measured candidate: `348bdf2f9cca187d4c59f92f9bff3490d0e5d68c`.

Four pairs used AB, BA, AB, BA order on one Windows runner. Both exports used the same observation overlay.

| Median | Baseline | Candidate |
| --- | ---: | ---: |
| Manual Save, fresh journey | 2064.08 ms | 922.19 ms |
| Manual Save, retained journey | 2070.46 ms | 919.97 ms |
| Manual Save, longer reading journey | 2092.73 ms | 931.97 ms |
| Passage first correct drawing | 552.16 ms | 549.10 ms |
| Passage usable | 571.71 ms | 568.08 ms |
| Load first drawing | 625.89 ms | 632.33 ms |

Manual Save improved in all pairs and all three cases. The longer-reading median fell 55.5%.
Load was 1.0% slower by median. Passage drawing changed little. Do not claim a Load speedup.
The median of the 28 ordinary-caption medians was 107.19 ms before and 106.02 ms after.
This aggregate is descriptive; the retained JSON has each caption's four samples.

The longer-reading Save recorded 40 scene validations before and 12 after in each pair.
The candidate has zero validation calls under availability or capture. The remaining calls are in
snapshot composition, document composition, storage validation and journal commit. Each Run validation
restores reading twice in the schema and once through semantic validation. Caller labels identify selected
synchronous owner frames, not every helper. Their elapsed spans overlap; do not add them.

Manual Save timing begins before Backup opening and live capture, and ends after commit.
It is not physical-button-to-painted-confirmation latency. OS caches were not cleared.
These are instrumented exports. Do not compare absolute timings with another runner.
Ordinary reading and passage transition made no game-storage calls and left Autosave bytes unchanged.
Named checkpoint arrival remains covered by separate regression journeys.

`measurement.json` preserves source identity, selected exact samples and Save caller profiles.
Original artifact: 12730505905. Verified ZIP SHA-256:
`bf6407ff86ec3336dcbe34771ffd176ca584d2ed3e25a86eb6a9cf2a997d4f74`.
