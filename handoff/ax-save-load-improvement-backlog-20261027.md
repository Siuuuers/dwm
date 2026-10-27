# Save and Load: deferred improvements

Date: 2026-10-27, Hong Kong time.
Status: Defer further performance work. Prioritize unfinished player-facing functions.
Previous handoff: [Quick Save completion](aw-quick-save-completion-20261027.md).
Measured evidence: [Save reading reuse report](../evidence/phase_2r/save_reading_reuse_20261027/README.md).

## Current decision

Keep the accepted Save and Load implementation.
Do not start another measurement run only because more optimization is possible.
Select the next unfinished player-facing function from the existing backlog.
No specific next feature was selected in this discussion.

This priority supersedes the immediate profiling instruction in the previous handoff.
The opportunities below are candidates, not approved implementation tasks or promised gains.

## Accepted behavior

When the game handles F5, capture the current saveable state and complete the Save.
Show "Saved" only after success. Keep the notice for two visible seconds.
The player can advance after Save completes while the notice remains visible.
Later gameplay does not update the saved snapshot or invalidate the completion fact.
A new successful F5 Save writes the newer state and starts a new notice.

Save still has synchronous work. Do not describe it as a background Save.
Do not promise that input and rendering continue during that work.
The physical F5-to-first-drawn-Saved delay has not been measured.

Preserve exact-current-state Save, named-checkpoint-only Autosave, Logout without
saving, and the accepted content compatibility and error behavior.

## Remaining opportunities

| Candidate | Evidence and limit | Action if work resumes |
| --- | --- | --- |
| Reuse semantic reading reconstruction | Schema validation already has an expanded checkpoint. GameState and FrozenRunContext reconstruct it again. Relevant semantic-side restore spans were about 65–69 ms per sampled longer-reading Save. These are not guaranteed removable costs. | Use existing owners. Preserve independent public validation, custom two-argument delegates, required frame checks, and raw reading5 projection. Review completed-passage validation too. |
| Reduce other Save costs | Existing SaveManager timers cover capture, document building, hashes, copies, source recheck, serialization, write, journal commit, signals, and metadata. Current evidence does not establish the dominant remaining phase. | Enable existing `DWM_SAVE_LOAD_PROFILE` timing in a cloud diagnostic before choosing a change. |
| Improve Quick Save responsiveness | Post-success capability capture and display-time save-condition polling are removed. Complete player-visible F5 latency is still unknown. | Measure handling native F5 through the first drawn Saved frame in the existing rendered journey. |
| Improve Load further | This session did not establish another worthwhile Load optimization. | Investigate a reproducible player-visible delay before proposing another change. |

Do not sum nested profile spans. Reading-validation and storage spans overlap.
Do not assume that removing all measured reconstruction time is possible.

## Measurements and acceptance

[PR 136](https://github.com/Siuuuers/dwm/pull/136) reduced repeated reading validations
from 12 to 8. The final matched Windows comparison used four counterbalanced pairs.

| Manual Save case | Baseline median | Candidate median |
| --- | ---: | ---: |
| Fresh | 946.52 ms | 879.06 ms |
| Retained | 933.09 ms | 887.76 ms |
| Longer reading | 964.77 ms | 903.75 ms |

Longer-reading Save improved 6.3%. Every pair improved in all three Save cases.
Passage first drawing measured 1.9% slower. Load first drawing measured 0.5% slower.
Do not claim a passage or Load improvement.

The approximately 0.9-second result measures the manual Save journey, including
Backup opening and Save work. It is not a measured F5 latency or a universal
player-device result. Revisit this delay before release.

PR 136 passed [67 cloud jobs](https://github.com/Siuuuers/dwm/actions/runs/40503361601)
and [24 comparison journeys](https://github.com/Siuuuers/dwm/actions/runs/40503361009).
[PR 137](https://github.com/Siuuuers/dwm/pull/137) passed
[67 cloud jobs](https://github.com/Siuuuers/dwm/actions/runs/40508226096).
Each regression run skipped one historical comparison.
Rendered coverage verifies native F5, durable Quick storage, actual notice drawing,
no display-time recapture, and notice expiry.

## Conditions for resuming performance work

Resume when a normal player journey shows a noticeable pause, growing content
makes the delay worse, a related feature requires work in the same path, or release
readiness requires a responsiveness check.

First profile the complete operation on the accepted current master.
Separate Backup opening, preparation, commit, and first drawing.
Then select one observed cost and compare one coherent candidate against that baseline.
Use matched cloud runs. Do not compare absolute times across different runners.

Do not add a prepared-save cache, background draft, new interaction gate,
injected-failure test, edited-file scenario, or speculative external protection
as part of this deferred work.
