# Profile write validation reuse

## Outcome and scope

A newly presented caption still records its Profile discovery before acknowledgement.
Within one synchronous atomic write, each distinct text receives full validation once.
Repeated identical text reuses that successful admission. Later writes and ordinary
reads validate again; migration retains its original validator. Physical byte/hash
readback, recovery, fatal latching and publication after persistence are unchanged.
The implementation follows SaveManager's existing write-scoped validation memo.
Two pre-validation copies were removed because ProfileSchema already detaches input.

## Attribution

Baseline: `a8e37fdfaba9efcd0914c59b1eeb827ab0535896`.
[Observation overlay and run](https://github.com/Siuuuers/dwm/actions/runs/41828236371)
at `4794e6546a13752447c87fd24519003c9c427117` measured the same 21 ending captions.
First visits had a 685 ms median complete interval and 409.05 ms median Profile
persistence span, with 21 commits. Already-witnessed replay had a 184 ms median
and zero commits. These are different workloads, not a session-age comparison.
Spans are nested inclusive observations and must not be summed.

## Matched experiment

[Candidate and reproducible diagnostic workflow](https://github.com/Siuuuers/dwm/tree/c197e3f66572084ea113eb8289c6e33ea5c7588d)
contains `profile-write-comparison.yml`, `prepare_profile_match.py`, and
`profile_first_visit.gd`. [Passing run](https://github.com/Siuuuers/dwm/actions/runs/41830620555).
The production ProfileManager SHA-256 is
`cd34582d2b6eeaa4c03146e1909280a23fc349473a81ca7d5c52fb5c055285c6`.

The baseline shipped route creates an actual ending Save and captures the Profile
before the next 21 captions are witnessed. Each fresh process restores identical
private test files. Only ProfileManager changes between variants. Order is
baseline/candidate/candidate/baseline/candidate/baseline/baseline/candidate.
The existing timer covers Accept through complete, acknowledged, input-ready text
and its rendered frame. No attribution wrappers run in this comparison.

| Variant | Four run medians, ms | Median of run medians, ms |
| --- | --- | --- |
| Baseline | 916, 916, 906, 901 | 911 |
| Candidate | 751, 748, 758, 742 | 749.5 |

Reduction: 161.5 ms, or 17.7%, in this bounded Linux software-rendering comparison.
The four runs per variant are the repetitions; individual captions are not
independent trials. No Windows, hardware, cold-start or whole-game claim is made.

All eight rendered comparisons passed 343 assertions each. Each Profile grew
from 815 to 836 exact witnesses, completed the passage and gained one Gallery
receipt. Every final Profile had SHA-256
`c123de1eb8d5c212693ab18e144de745434d6159c240de07e5d57e37310e4d35`.
Source Save hashes remained identical. Both baseline seed journeys also passed.

Seven focused local checks passed 93 assertions: write-local reuse and later
revalidation; detached typed reads; changed presentation registry admission;
durable detached marks and duplicate suppression; publication after adoption;
atomic caption union; and durable dialogue-library discovery. Comment lint and
whitespace checks passed. No broad suite or failure-injection run was added.

## Remaining measurement

Result-entry pauses are separate. Measure challenge closure, target/checkpoint
commit, native installation and acknowledgement/render waits before changing them.
The observed 151 capture calls do not prove which stage causes the wait.
