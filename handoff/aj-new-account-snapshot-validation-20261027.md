# Scene snapshot admission: New Account and Load

Date: 2026-10-27, Hong Kong time.

## Accepted work

PR 116 is merged at `292be5200d8ac25b5e3f5bafcc40725feca891d2`.
Its tested head was `1b6b492fa7247e78432b3bf09081ef6752eeea86`.
The merge has the same tree as that tested head.

- Current scene Load restores the saved Run and its identities in memory.
- Current settings and global unlocks stay current.
- Challenge boards and attempts belong to the Run, not Global Profile.
- Load writes no recovery progress. Both real process-kill tests passed.
- Settings Back works after changing language in all five supported languages.
- New Account reuses the existing dialogue compiler cache.

Final acceptance: 61 successful jobs and one intentionally skipped comparison job.
The separate comparison succeeded. All 298 persistence tests passed.
See https://github.com/Siuuuers/dwm/actions/runs/40354573498.

The final Load comparison changed median click-to-caption time from 2623.2975 ms
to 2149.4495 ms. All four pairs improved. This is about 18% in that cloud sample.
See https://github.com/Siuuuers/dwm/actions/runs/40354573437.
Evidence artifact: `12666116081`; package artifact: `12666380419`.
Evidence ZIP SHA-256:
`2e243f02ea5b267fbc8ee237791087d4179adc0a770c07609cb1fdfca09ca4ba`.
New Account timing changes in PR 116 varied between runs. Do not claim a reliable
overall New Account speedup from that PR.

## New Account investigation

PR 117: https://github.com/Siuuuers/dwm/pull/117.
Use its exact head checks and merge status as the final acceptance record.

Observable outcomes: New Account reaches the same first caption sooner with a fresh
Run; Load reaches the exact selected saved caption sooner. Prior saves, current
preferences and global unlocks remain unchanged by either admission optimization.

The measured path was:

1. `SaveManager._start_scene_new_run_in_memory` builds the initial snapshot.
2. `RunSnapshotSchema.build_scene` validates that snapshot.
3. SaveManager constructs a private journal reset from the validated result.
4. After applying detached participant plans, `CheckpointJournal.commit_prepared`
   validates that same snapshot again.

The diagnostic run used the same runtime and observer on both sources. It is an
attribution measurement, not an optimization result.
See https://github.com/Siuuuers/dwm/actions/runs/40356717090.
Evidence artifact: `12665624087`; package artifact: `12665609186`.
Evidence ZIP SHA-256:
`b3bff7be1de5707c2875418704df91facba77b71e3fcb9f5a5ee191ebf21f725`.

Each fresh New Account full validation took about 178–182 ms. Retained-account
validations took about 172–178 ms. Normalization and primitive traversal took less
than 1 ms. Owner-state and reading checks used most of the time.
Live input validation took about 78–89 ms and sees a different representation.
Keep that check. Do not add inclusive measurements to their nested child spans.

## Candidate ownership change

Both in-memory scene operations use the existing private journal
`_install_prepared` method for their already admitted reset or seed.

SaveManager is the sole producer of the creation reset. Load retains a detached
private preparation when its source is admitted. At commit, it compares the public
preparation with that retained copy, then selects the private copy **before**
acquiring the save lock. The lock emits a synchronous capability callback: using
the public dictionary after comparison would let a listener change the seed
between admission and installation. No additional copy or manager is needed.

Participants receive detached plans. The journal installer keeps its existing
deep copies, sequence state, and proof clearing. Transaction rollback stays in
the existing owner. Public `commit_prepared` still validates caller dictionaries;
legacy recovery is unchanged. Live-input validation remains necessary.

The cloud-selected `test_scene_direct_load.gd` rejects precommit seed tampering,
then exercises malformed and schema-valid progress replacement during the actual
save-lock callback. Both must restore exactly the selected journal, gameplay and
lifecycle while preserving Profile, identity and every persistent file byte.
The diagnostic fixture controls activation; existing rendered E2E and killed-process
tests cover the connected journey and interrupted process separately.

The phase timers are test-only source overlays in the exported comparison harness.
They are applied equally to both variants and do not become shipped runtime code.
The observer records the source hashes before and after its changes.

## Earlier New Account-only measurements (not merged)

Runtime candidate: `4f32ccd8b96f618df531c7c68590419fec684545`.
Baseline: accepted PR 116 head `1b6b492fa7247e78432b3bf09081ef6752eeea86`.
Run: https://github.com/Siuuuers/dwm/actions/runs/40358476161.
Evidence artifact: `12666463526`.
Evidence ZIP SHA-256:
`3d75a57bf8c8d810b29a40185c2e667b6c86272dc73dece0e04d4e8d81c2d37f`.

| Action median | Baseline | Candidate |
| --- | ---: | ---: |
| Fresh New Account to caption | 2128.8525 ms | 1938.5595 ms |
| Retained New Account, excluding confirmation dwell | 2091.835 ms | 1927.813 ms |
| Load to caption, unchanged control path | 2197.091 ms | 2212.0975 ms |

All four fresh pairs and all four retained pairs improved. Median reductions are
about 8.9% and 7.8%. Every New Account sample changed from two full snapshot
validations to one. The initial Load control median increased by 0.68%. Further comparisons at
`0a7e9051b5881909fb70afa01a1e37708378503f` increased by 4.84% and 1.33%
(run `40360383283`, attempts 1 and 2). Nine of twelve Load pairs were slower.
The New Account-only candidate was therefore held, despite all twelve fresh and
twelve retained creation pairs improving. These are diagnostic results, not final
acceptance for the expanded candidate. PR 116's separate Load result is above.

There are 24 exported journeys, four pairs per case in AB/BA/AB/BA order on one
Windows runner. Both variants use the same observer. Each action starts a new
process. Retained cases use identical seeded data. OS caches were not cleared.
These small samples describe these runs; they do not establish universal timings.
Use the PR's final head checks for acceptance after the generated inventory update.

## Expanded candidate acceptance

Runtime candidate: `95ba7fc73d5693fe39e37fadd63910e014c994f1`.
Tree: `dfbfb48401448b3b4471ce7dd0db94e3264ac446`.
Cloud Windows run: https://github.com/Siuuuers/dwm/actions/runs/40365873113.
Matched comparison: https://github.com/Siuuuers/dwm/actions/runs/40365873026.
The matched comparison succeeded. All four pairs improved for every action:

| Action median | Baseline | Candidate | Reduction |
| --- | ---: | ---: | ---: |
| Fresh New Account | 2179.914 ms | 1990.0955 ms | 8.71% |
| Retained New Account, excluding confirmation dwell | 2164.406 ms | 1977.2 ms | 8.65% |
| Load to caption | 2292.481 ms | 2113.3115 ms | 7.82% |

Every sample confirmed full snapshot validation counts: New Account 2 to 1,
Load 4 to 3. The exported-journey assertions and caption screenshot review passed.
Evidence artifact: `12670861903`; packages: `12670898082`.
Evidence ZIP SHA-256:
`3007064c90834a0f4deb9c57bde0b0a9243212c655916e7d660fce948fcd3a26`.

All 298 persistence tests and both interrupted-process Load checks passed.
The initial API check found stale generated inventories. Both inventories were
regenerated and verified in that cloud job, then copied exactly into the branch.
Inventory artifact: `12670786592`; ZIP SHA-256:
`e0cf97779974b1d1d9a25eeb3bb49e4df99cf96060ffa04287cfdb67dfa33292`.
GameState inventory SHA-256:
`a7376927eac0c5da8779f31d6bf972b54e61b9c833241097c442768781f600af`.
SaveManager inventory SHA-256:
`38a94d77093c52c42996f395d65a24f82ba0de7078d020d532a8a3e365f865b2`.

The next commit contains only these inventories and this handoff. Final exact-head
Windows acceptance, rendered/export jobs and its matched repeat remain pending at
this documentation snapshot. Use PR 117's current checks/body and merge status as
the final record. Do not infer acceptance merely from these candidate measurements.

## Further work

Read current master before another edit. Do not remove checks only because they
share names: live inputs and projected player snapshots can need different checks.
Measure a complete player action before accepting another performance change.
All Godot validation remains cloud-only.

Named presentation checkpoints and overlays remain a separate feature. Use the
existing art manifest as the owner. Save the checkpoint ID and ordered overlay
labels; restore them directly. Each art appears at most once. Showing an active
label or removing an absent label is a no-op. Entering a new named presentation
checkpoint **clears all active overlays**. This is the latest user decision.
