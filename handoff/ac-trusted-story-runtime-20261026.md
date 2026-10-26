# Trusted story runtime and startup performance — 26 October 2026

## Start here

This is the latest user-approved direction for story validation and performance.
It supersedes conflicting runtime prevalidation and recovery recommendations in
[the original handoff](aa-reading-startup-simplification-20261026.md).
It does not replace accepted player-save, History, Replay or gameplay behavior.

This session measured current master and agreed a policy. The optimization and
soft-error behavior below are NOT implemented yet. This handoff is documentation only.
Start the next session from current master, not the diagnostic branch.

## User-approved principle

Prioritize getting the player reading promptly. Trust the exact shipped story
after thorough cloud build checks. Do not repeatedly prove that unchanged authored
content is valid during normal play.

The user intentionally accepts only best-effort behavior for audience-edited DTL.
Do not add compatibility, reconstruction or recovery systems for manual edits.
The user explicitly prefers a nonblocking error and skipping the failing line/event.
Do not restore the earlier recommendation to halt every failed Challenge, Contact
or transition merely to protect unsupported edited content.

- Validate authored story, IDs and references in cloud CI before release.
- Reuse prepared story tables. Remove redundant whole-bundle validation and
  comparisons whose only purpose is detecting manual content changes.
- Resolve only the IDs or resources the executing event actually needs.
- On a missing ID or unsupported command, show a soft error, skip the failing
  event and continue when a next event exists. Other UI remains usable.
- Release any pending wait owned by the skipped event. A skip must not hang.
- If no continuation exists, end that dialogue cleanly. Do not invent a destination.
- Do not precheck an entire story graph each time a line or command runs.
- Keep this implementation small. No new global registry, manager, generic
  recovery framework or speculative mod support.

The user's claim that manual editing is the only possible mismatch is a scope
decision, not a proven technical fact. Packaging mistakes are also possible;
catch them in build checks rather than charging every player repeated runtime cost.
Skipping arbitrary edited commands does not promise a coherent edited story.

External player-save validation is a separate responsibility. This decision does
not authorize blindly accepting malformed saves or removing persistence consistency.
Preserve accepted current-format story-update behavior; it is not the same as
supporting arbitrary audience edits.

## What immutable story tables mean

Immutable means read-only for the selected content during one process. It does
not make the current draft canon or prevent author edits in a later build.
The story can change; a new process prepares tables from the installed content.

DialogicEntryManifest loads registration JSON and owns derived entry, target,
board-profile, Challenge, Contact and marker indexes plus a fingerprint.
These tables describe authored content, not mutable money, choices, board progress
or reading history. They already have one owner. Do not add another.

Its _configure_scene_registration validates, builds and recursively freezes tables.
scene_contract_tables returns that shared immutable data.
scene_registration returns a deep copy.
RunSnapshotSchema.validate_current_scene currently calls
SceneEventContract.validate_bundle_structure again. That work rebuilds indexes,
checks links, encodes registries and the bundle, hashes content and copies tables.
Other callers also invoke it. Trace all relevant callers before changing signatures.
Prefer the existing trusted owner over a caller-supplied trust boolean.
Data-driven authoring is already present; moving duplicated facts into another
file is not simplification. Keep one source for each authored fact.

## Current implementation status

Measured product master: 51763f0af4d71909411ff208b3f3584516f09d37.
PR #107 implemented current-content save migration. PR #108 removed obsolete
player-reading conversion; current player reading format is 7, internal live
reading format is 5. Verify current code and PR metadata before further work.
Do not reimplement those batches from older handoff wording.

Diagnostic [PR #109](https://github.com/Siuuuers/dwm/pull/109) is closed, unmerged.
DO NOT merge its branch: it disables the normal PR test trigger for diagnosis.
Its observer overlay is not a product optimization.

[Successful cloud measurement run](https://github.com/Siuuuers/dwm/actions/runs/40263114679).
[Retained report and evidence](https://github.com/Siuuuers/dwm/blob/902b14259b147c544b0cfd24fcfdcc36be89e7b9/evidence/phase_2r/current_startup_measurement_20261026/README.md).
That exact commit retains raw timing summaries, logs, hashes, representative
screenshots and contact sheets. Do not depend on scratch files surviving.

## Measured baseline

Four samples per case. Values are seconds: median [minimum–maximum].

| Interval | Time |
|---|---:|
| Launch to usable Title, empty user data | 8.395 [8.119–8.853] |
| Launch to Title, retained New Acc profile | 6.955 [6.881–7.421] |
| Launch to Title, Load seed | 6.987 [6.936–7.122] |
| Fresh New Acc click to complete caption | 14.826 [14.756–14.885] |
| Retained New Acc confirmation to caption | 14.768 [14.702–15.073] |
| Log in click to usable Backup | 0.055 [0.054–0.059] |
| Load click to ready signal | 7.360 [7.337–7.781] |
| Load click to complete saved caption | 7.546 [7.525–7.981] |

Median longest frame gaps: fresh New Acc 9.485 s; retained after confirmation
9.347 s; Load 7.466 s.

Fresh New Acc: decision preparation 5.229 s; resume transaction 7.783 s.
Bundle validation: 36 calls / 3.906 s fresh, 36 / 3.844 s retained,
23 / 2.494 s Load.
Reading configuration: 0.198 s fresh, 0.195 s retained, 0.109 s Load.
Compilation is included in configuration: 0.055 s fresh, 0.054 s retained,
0.042 s Load.
Load records seven snapshot validations, total median 5.342 s; before semantic
validation 4.167 s; semantic validation 1.138 s.

These costs overlap. Never add bundle validation to snapshot or phase totals.
The internal Load profiling scope starts before Log in and is wider than
Load-click timing. New Acc uses a separate creation-validation path; its empty
snapshot-detail list does not mean no validation occurred.
The bundle totals cover all callers and do not predict savings from one change.

Launch to observer entry is about 6.831 s fresh and 4.947 s retained.
The cause is not isolated. Do not attribute it to disk, GPU or compilation without
another measurement. Bundle validation does not explain all startup delay.

Conditions: one instrumented exported Windows release on one Windows Server 2022
cloud runner with Hyper-V Video. Twelve new processes in fixed fresh/retained/Load
order. Retained means retained user data, not a warm process. Cold OS caches were
not controlled. All Load inputs matched the same 74-file seed. All 12 processes
exited cleanly; Load preserved saved gameplay, scene, reading and source Autosave
bytes. All 32 screenshots were hash-checked and visually reviewed.
Four samples are descriptive. Do not compare unmatched older runs as speedup
evidence or promise these timings on player hardware.

## Next-session work order

Observable outcome: New Acc and Load reach the same visible state and preserve
accepted save behavior with less waiting; an unsupported missing event shows a
nonblocking error and advances without leaving a pending wait.

1. Read AGENTS.md, CLAUDE.md and relevant owner records. Fetch master and inspect
   work merged since this handoff. Use a clean product branch.
2. Trace repeated structural validation and copying of the selected immutable
   bundle. Separate unknown-input boundaries from trusted internal use.
3. Remove redundant work using the existing owner. Do not require repeated full
   validation solely to tolerate manually edited content. Audit whether startup
   work can be guaranteed by the exact-artifact cloud build checks.
4. Trace the native dialogue/event completion path. Implement the smallest
   nonblocking error-and-skip path; cover missing IDs, wait release and no-next-event.
5. Preserve changing save/gameplay checks where needed. Review each by its actual
   owner and purpose, not blanket defensive rules. Avoid unrelated save rewrites.
6. Complete focused independent reviews before final acceptance. Parallel agents
   may investigate disjoint owners; one coordinator owns integration/publication.
7. Run Godot and Windows execution only in cloud CI. Local static checks are OK.
   Use focused unit checks for event decisions, integration checks for waits/state,
   and rendered E2E checks for connected New Acc, Load and error-and-skip journeys.
8. Compare baseline and candidate complete journeys under matched conditions and
   order. Include Title time, click-to-caption time and longest frame gap. Count
   remaining validations. Do not claim gains from shorter code alone.
9. Merge verified product changes; direct PR merges are authorized. Report real
   improvements, remaining delays and any changed behavior.

Ask only when a concrete unresolved design changes the solution. Do not reopen
the agreed manual-edit support policy or add theoretical robustness without buy-in.
The user requested this handoff so work can continue in a new session.
