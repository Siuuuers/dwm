# Trusted checkpoint conversion and edited DTL

> Later plan: [named presentation checkpoints and checkpoint-only Autosave](ar-named-checkpoint-autosave-plan-20261027.md) changes future Autosave scheduling and presentation-feature priority. It is approved but not implemented. Accepted runtime, edited-DTL behavior and historical measurements remain below.

Date: 2026-10-27, Hong Kong time.
Status: PRs 127, 128 and 129 merged after cloud acceptance. No runtime work is pending from these three changes.

## Scope

Continue [ap](ap-trusted-checkpoints-edited-dtl-20261027.md).
Use cloud execution for Godot and exported-game tests.
Do not implement general nonblocking error-and-skip.

## Additional owner decision

If a save is inside a branch and its dialogue ID still exists, keep that saved line.
Do not jump away only because an earlier selected choice was removed.
Use the authored default when execution needs to resolve an invalid choice.
Do not rewrite historical choices or repeat their consequences.

## Accepted compact checkpoint simplification

[PR 127](https://github.com/Siuuuers/dwm/pull/127) merged as `b3934ce7ffa0a8872c7b647d02f6ae2d40c90eea`.
Candidate: `eb2464d158b651d8425b41e1d838bafd6477770a`.
Candidate tree: `b6bf38ffa476f4b473836363f785f3c4b76dcfff`.
Baseline: `f3231bc90c645288d4106e11693a4a805a4a23da`.

After schema-7 admission, `project_player_checkpoint()` returns a detached copy.
It no longer captures expanded state, projects it again, and restores the result again.
Schema-5 conversion and actual Load restoration remain separate.

[Regression 40450801857](https://github.com/Siuuuers/dwm/actions/runs/40450801857) passed all 63 executed jobs.
One obsolete benchmark was skipped.
The player-position suite passed all 17 selected tests.
[Matched comparison 40450801886](https://github.com/Siuuuers/dwm/actions/runs/40450801886) passed all 24 exported journeys.
All eight destination screenshots were reviewed.

| Measurement | Baseline | Candidate |
| --- | ---: | ---: |
| First correct drawing, median ms | 1931.945 | 1929.381 |
| Complete reveal and readiness, median ms | 1953.899 | 1951.641 |
| Maximum transition frame gap, median ms | 1927.312 | 1924.664 |
| Restores per transition observation | 40 | 37 |
| Saved-reading validations per transition observation | 41 | 38 |

The complete-transition result does not establish a meaningful speed increase.
The four drawing differences are -71.140, -2.954, -2.173 and +7.892 ms.
Accept this change as a verified simplification.
Do not compare these absolute timings with another runner session.
Nested phase times overlap. Do not add them.

Artifact: `12710548346`, `checkpoint-projection-evidence-40450801886-1`.
ZIP SHA256: `a89d92d099f6ee2cb15625fa9236e7625f51d1ce7e243e214027f5a40899e5c5`.

## Accepted edited-DTL behavior

[PR 128](https://github.com/Siuuuers/dwm/pull/128) merged as `d0417b1846c404edb2b074d69da7c9c5f8f18369`.
Latest candidate: `d706fc3fe55484d8c8791c0781f7d258643c6449`.
Latest tree: `43da1a2c1aec2618da6b6f22c1770e494d499c6c`.

The candidate preserves valid saved IDs and removes recovery-anchor/day-start rewinds.
It reports required missing references at Load or continuation.
The existing application mutation gate blocks further Save and Autosave.
The existing confirmation surface shows the error until Quit closes the game.
Current requested passage text supplies wording for captions and History.
The runtime does not scan all DTL files to find edits.

An unchanged registration can accompany a manually edited file.
Tests must edit DTL bytes without rebuilding registration for that case.
An appended passage can retain a saved completed caption.
Adapt that boundary only after actual restoration finds a changed path.
A deleted saved ID must still fail.

If updated content replaces a held Challenge control with a normal control, resume the same saved caption.
The next input resolves the new control.
Do not leave the player on an unusable held Challenge surface.

The old History route scanner has no runtime caller after rewind removal.
Its helpers and route-only tests are removed.
Encounter-only History projection and real runtime route tests remain.

The first candidate exposed a real blocked-continuation failure in the transfer-terminal journey.
Do not cite that superseded run as acceptance.
The accepted candidate passed the unchanged board-transfer assertions.

Visual review found that late reading-input cleanup could take keyboard focus from Quit.
The fatal dialog now retains Quit focus through the viewport focus signal.
It disconnects that signal when it exits.
The accepted missing-default journey exits through a real Enter press and release without resetting focus in the test.
Do not use the earlier mouse-only evidence as proof of keyboard behavior.

[Regression 40455484923](https://github.com/Siuuuers/dwm/actions/runs/40455484923) passed all 65 executed jobs, with one historical benchmark skipped.
Eight selected suites passed 88 cases and 2,056 assertions.
All twelve edited-content lanes passed, including unchanged-registry edits and the original board-transfer assertions.
Four negative connected lanes verify stable Quit focus, production exit code 0, unchanged source/autosave bytes, and no failed slot 3.
The missing-default lane exits through real Enter input.
Final error and destination screenshots were reviewed.

[Matched comparison 40455484954](https://github.com/Siuuuers/dwm/actions/runs/40455484954) passed all 24 exported journeys.
Its baseline is the accepted PR 127 tree. All eight destination screenshots were reviewed.

| Measurement | Baseline | Candidate |
| --- | ---: | ---: |
| First correct drawing, median ms | 1836.264 | 1770.479 |
| Complete reveal and readiness, median ms | 1858.078 | 1791.772 |
| Maximum transition frame gap, median ms | 1831.819 | 1765.315 |
| Ordinary Load, median ms | 692.320 | 664.876 |
| Restores per transition observation | 37 | 35 |
| Saved-reading validations per transition observation | 38 | 36 |

The first-drawing median is 3.58% lower. Three of four pairs improved; one slowed by 122.713 ms.
This is a modest, variable improvement, not evidence of a universal speedup.
The roughly 1.77-second transition hitch in this instrumented run remains substantial.
Artifact `12712209992` ZIP SHA256: `9537051db5bc945160a2ac0fee221540c21e0f79b4441647695e2d14262abc10`.
Only final d706fc3 evidence is acceptance. Earlier runs exposed real continuation and keyboard-focus bugs and are superseded.

## Accepted direct live-checkpoint conversion

Before PR 129, the schema-5 projection branch restored the full captured reading state before building its compact representation.
The compact builder already read the supplied capture directly; it needed the prepared scene programme, not a rebuilt historical ledger or transient traversal proof.
The accepted implementation prepares the requested programme directly, then keeps compact construction and compact restoration.
[PR 129](https://github.com/Siuuuers/dwm/pull/129) merged as `b7b90afed3d2e743d90921e0627f5bb32cfbcf5d`.
Candidate: `cede98fc01c139b3a22a2dd47c0a6f7adc6f644f`.
Tree: `799773fc506cd1bdf267b8198fe6b1d267379c67`.
[Regression 40456763394](https://github.com/Siuuuers/dwm/actions/runs/40456763394) passed all 65 executed jobs, with one historical benchmark skipped. Rendered desktop/dialogue, Gallery, exported startup and the Settings uncertain-write journey passed.
Player-position coverage passed 24 tests and 495 assertions, including the differential conversion cases.
Content contracts passed 48 tests and 511 assertions, including modal focus and failed-state save preservation.
Public API coverage passed all 11 tests and reproduced both complete-tree inventories exactly.
[Matched comparison 40456763408](https://github.com/Siuuuers/dwm/actions/runs/40456763408) passed all 24 exported journeys.
All eight destination screenshots were reviewed.
The baseline `d706fc3` has exactly the merged PR 128 tree.

| Measurement | Baseline | Candidate |
| --- | ---: | ---: |
| First correct drawing, median ms | 1809.711 | 1747.178 |
| Ordinary Load, median ms | 664.987 | 686.914 |
| Fresh startup, median ms | 1129.339 | 1089.561 |
| Retained startup, median ms | 1156.388 | 1108.131 |
| Restores per transition observation | 35 | 28 |
| Saved-reading validations per transition observation | 36 | 29 |

The passage median is 3.46% lower, but paired changes are +177.547, -3.965, -21.390 and -229.382 ms.
Load is 21.927 ms slower at the median, with paired changes +50.328, -2.319, +42.261 and -18.295 ms.
Accept this as a verified simplification with mixed timing results, not a universal speedup.
Do not add gains across the three runner sessions.
The complete transition remains roughly 1.75 seconds in this instrumented run.
Artifact `12712578991` ZIP SHA256: `a7c6ac0d69a4b3b3e40901a88ad38c413e0493a1249aa1dd6e4e3bb04e1de9fb`.

Do not add a public trusted flag or another manager.
Internal schema-5 captures come from the reading owner, target staging, initial publication, or compact-save expansion.
Decoded player saves use schema 7.
Conversion intentionally no longer re-admits discarded historical-ledger details, a non-control internal cursor or transient `next_operation` traversal proof.
This does not change schema-7 file admission or actual Load/rollback restoration. Required compact ID, publication, held-control and wrapper checks remain.

The accepted tests compare complete compact outputs for captions, held controls, completion, loops, multiple occurrences and populated History.
They restore results and verify the same next caption/control and publication numbering.
Future changes must keep callback-mutation, retry, uncertain-acknowledgment and Save/Autosave coverage.
Future comparisons should measure the complete passage transition against accepted current master with the same observer.
Do not claim a speed increase from fewer calls alone.

## Durable evidence

- [Compact checkpoint conversion](../evidence/reading_performance_20261027/compact-checkpoint.json)
- [Edited DTL](../evidence/reading_performance_20261027/edited-dtl.json)
- [Live checkpoint conversion](../evidence/reading_performance_20261027/live-checkpoint-conversion.json)

These files retain source identities, matched samples, paired differences, selected checks and artifact hashes.
GitHub Actions artifact links may expire; the JSON summaries remain in the repository.
All Godot and exported-game execution was cloud-only. Local work was source inspection, static validation and evidence processing.

## Next investigation, not an accepted optimization

The source review found a repeated configuration cost worth measuring separately:
`NarrativeCaptionLedger._restore_scene_snapshot()` creates a candidate ledger and calls `initialize()`.
Initialization validates and duplicates the full caption registry, freezes each beat and rebuilds three lookup maps.
The current shipped registry contains 1,666 caption beats across 92 entries.
These are configuration facts; restored caption rows and occurrence contexts are separate mutable state.
No leaf timing currently proves how much of the remaining pause this costs.

The final candidate still spends approximately 518 ms in saved-state validation and 498 ms in restoration as inclusive median phase spans. These overlap and must not be added.
Add observation-only timing for registry admission and ledger initialization before choosing a change.
Use the same complete-operation observer and matched baseline/candidate protocol.
Prefer reuse of the canonical admitted immutable configuration within its owner if the evidence supports it.
Do not introduce a public trusted flag, cross-callback cache or new manager by default.

Do not remove callback/source custody checks merely because their phase includes repeated projection.
Exact-hash reuse would need to prove that candidate, supplied checkpoint and privately retained checkpoint remain unchanged across the relevant callbacks.
Keep the owner, retry, uncertain-acknowledgment, rollback and real-save obligations visible in that review.

## Continuation boundary

No blocking product question remains. The user authorized cloud-only execution, parallel focused investigations and direct PR merges.
This is a useful fresh-session boundary: three independently tested changes are accepted, their final evidence is durable, and the next step is a new timing attribution experiment.
Start from current master and this handoff; do not repeat the superseded edited-DTL or compact-conversion work.
Keep the still-valid saved-ID decision above. Do not restore the unwanted nonblocking error-and-skip proposal.
