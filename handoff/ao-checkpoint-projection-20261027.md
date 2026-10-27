# Invocation-local checkpoint projection comparison

Date: 2026-10-27, Hong Kong time.
Status: PR 124 merged and accepted.

Next-work amendment: [ap](ap-trusted-checkpoints-edited-dtl-20261027.md) records the later user-approved checkpoint and edited-DTL policy. It supersedes the refusal-preservation and edited-DTL scope instructions below. The measurements and accepted implementation in this file remain historical evidence.

## Scope

Continue [an](an-checkpoint-reference-20261027.md). Measure the same native Enter transition from line.Day1.031 to line.Day1.photo.default.001, preserving the pass choice, Run identity, encountered History and subsequent Save/Autosave.

Baseline: `c9aeee8fe12b5f0dd88bfca5d2bf3cf778150efd`.
Candidate: `9c76266daeba6fe44e3071a1660bbee0860d503b`.
Candidate tree: `87a857eee766d24c5f5f1da1ad24bc2826e6d7ba`.
[PR 124](https://github.com/Siuuuers/dwm/pull/124) merged as `c050fc4f626d810e71a7a4858306d1382c28a680`.
The merge tree exactly matches the tested candidate tree above.

## Change

`SaveManagerNarrativeCheckpointPort._scene_candidate_reference()` projects its persisted checkpoint once and compares that projection separately with the retained target and supplied checkpoint. Reuse ends when the function returns. No cache, manager or helper is introduced. Other callers retain `_player_checkpoint_same()`.

Persisted and retained type refusal, all projection refusal, both equality checks, private retained fingerprint, checkpoint ID and journal/autosave snapshot identity remain. No callback, await or signal occurs between the projection and reuse. Later invocations project current values again, preserving callback-mutation detection. One invalid-input ordering changes: without a retained entry, projection can occur before invalid reference/ID refusal. The result remains refusal.

Two appended unit tests exercise compact persisted schema-7 checkpoints against full schema-5 targets, with and without retained entry. They verify exact reference and unchanged inputs. Independent retained, supplied and persisted mismatches refuse, including a retained target whose fingerprint was recomputed. Null, scalar and incomplete persisted values also refuse cleanly. The existing callback, retry, rollback and uncertain-acknowledgment tests remain selected.

The public surface inventory changes one source line reference after the function grew by ten lines. No API was added or removed.

## Measurement contract

Reuse the same observer and all 24 exported journeys. Four matched pairs use AB/BA/AB/BA on one software-rendered Windows runner. Each process is fresh; OS caches are not cleared. Snapshot, History, PNG and hash checks occur outside the passage timing interval. Polling and observer bookkeeping remain inside.

Counter scope runs from input through readiness and the additional one-second observation window. Inclusive spans overlap and must not be added. The helper-call count can fall to zero because the comparisons are now inline; that does not mean equality checks disappeared. Judge actual projection/validation counts, reference costs and complete action timings.

The expected projection reduction is 13 to 10, and validation reduction 47 to 41. These are predictions, not acceptance assertions. Use the measured result. Do not compare absolute timings across separate runner sessions or claim a device-wide guarantee.

No Godot process runs locally. Local checks cover Python/YAML syntax, source-overlay preparation, whitespace and source inventory references. Cloud execution owns runtime acceptance.

## Cloud acceptance

[Regression 40410443495](https://github.com/Siuuuers/dwm/actions/runs/40410443495): all 63 executed jobs passed; one older benchmark skipped. The checkpoint suite ran all 26 tests with 914 assertions. The rendered owner suite ran all 12 tests with 462 assertions. Exact method checks reject skipped coverage.

[Matched comparison 40410443738](https://github.com/Siuuuers/dwm/actions/runs/40410443738): all 24 exported journeys passed. All eight destination screenshots were reviewed. Correct caption, art, History layout and controls remain. Pass choice, same Run, no unselected-route encounters, source bytes and subsequent Save/Autosave checks pass. Measured processes exit without script errors or ObjectDB leak reports.

Artifact `12694175597`, `checkpoint-projection-evidence-40410443738-1`.
ZIP SHA256: `bb501762b67e360bd07b5001669043807b2110f9751a097fc3940792d8dd3a38`.
Raw samples, paired differences, artifact identity and all boundary-case results are retained in [checkpoint-projection.json](../evidence/reading_performance_20261027/checkpoint-projection.json).

Milliseconds; medians across four matched samples per variant:

| Measurement | Baseline | Candidate |
| --- | ---: | ---: |
| Input to first correct destination drawing | 1506.977 | 1377.122 |
| Input to complete reveal and readiness | 1525.156 | 1395.326 |
| Maximum transition frame gap | 1503.702 | 1373.882 |
| Candidate-reference work, inclusive | 343.116 | 252.584 |
| Player projection work, inclusive | 366.226 | 274.919 |
| Saved-reading validation, inclusive | 614.539 | 523.312 |
| Ordinary Load to complete caption | 529.844 | 532.614 |

All four first-drawing, readiness and maximum-gap pairs improve. First-drawing savings are 139.545, 162.307, 145.333 and 97.140 ms. Median first-drawing latency falls about 8.6%. Projection calls fall from 13 to 10, validations from 47 to 41, and restores from 46 to 40 in every sample. Reference checks remain three. Both equality comparisons remain despite the comparison-helper count falling to zero.

The approximately 1.38-second passage hitch remains. This change is not a Load or startup optimization. Fresh New Account median is 880.534 versus 886.390 ms; retained-profile New Account is 911.084 versus 843.647 ms. These small sample results do not establish a general startup change.

## Next attribution lead and important limit

`SoloReadingSession.project_player_checkpoint()` restores its input, then `_project_player_reading()` constructs a compact save and restores that result again. Separate these two purposes before choosing another deletion.

Static caller review found only two calls to `_project_player_reading()`, both in `project_player_checkpoint()`:

- Schema 7 input has already passed `restore_player()`, followed by capture. Its compact-specific admission has already occurred.
- Schema 5 input passed live `restore()`. This does not prove every compact-save invariant. The output reconstruction currently supplies additional admission.

Do not remove output reconstruction indiscriminately. Static inspection identifies extra compact requirements: canonical positive/unexhausted publication counter, authored predecessor for held controls, completion reachability and unique authored locator resolution. A malformed live publication ID such as `invented` is a proposed negative test: live admission may accept it while compact projection must refuse its invalid computed serial. This particular example has not been executed in cloud yet.

The next smallest investigation is to attribute the second reconstruction separately by input format. Preserve public schema-5 refusal obligations and compact output that can actually load. Add meaningful negative conversion tests before changing that boundary. Existing roundtrip tests cover ordinary captions, compact idempotence, held controls and malformed compact inputs; they do not by themselves prove these full-to-compact refusal cases.

No cross-callback cache is proposed. Keep the same native passage journey and compare complete action latency. Manually edited DTL error-and-skip remains out of scope; cloud-only execution and minimal owned changes remain the working policy.
