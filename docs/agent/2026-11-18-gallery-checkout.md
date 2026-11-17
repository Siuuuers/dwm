# Gallery CI checkout and focused selection

Base: `65fa4d3e8647f8e15dfc74b67d2fa84a83778dd1` (PR #300).
Goal: run the existing Linux Gallery render checks without checking out historical
evidence or launching unrelated jobs. Owners: rendered-journeys and test-scope.

## Investigation and implementation

The public-surface checkout and selector work already merged. Current Gallery CI
still used a full checkout. Its two render scripts consume current scenes/assets,
the GalleryCollectionFixture catalogue and DTL under tests/fixtures/dialogic,
and data/manifests/art_placements.json. user://evidence paths are generated outputs.
Independent dependency audit found no repository evidence input for this job.

Retain all files outside evidence plus evidence/.gdignore. No tracked archive,
fixture, game asset or runtime code is removed. This avoids the same historical
evidence directory measured at about 1.22 GB in PR #299; no new network/time
measurement is claimed. The actual Git pattern regression checks retained fixture,
manifest, source, tool and asset paths and omitted historical archive/image paths.

Add rendered-journeys to the existing explicit owner selection and job condition.
The first commit introduces the selection rule with focused local checks; the
second changes the checkout. A branch-parent replay selects Gallery + test-scope,
but this is not GitHub's checkout semantics: Actions checks out a synthetic merge
commit, whose HEAD^ is the PR base. Hosted run 44174052878 confirmed broad fallback
for this PR's shared-selector change. Future job-only changes can select Gallery.
Do not split commits expecting to narrow an initial multi-commit PR's coverage.

## Verification

- `python tools/testing/test_windows_coverage.py`: 50 tests pass.
- actionlint 1.7.12, same pinned checksum as source-lint: pass.
- git diff --check: pass.
- Source audit: both existing rendered probes retain all identified inputs.

Hosted rendering result is recorded in the PR once available. No game performance
or Windows player-experience improvement is claimed. The affected Linux
Gallery job and source lint are the acceptance checks for this checkout change.
The workflow also started broader jobs through its existing fallback; a full
matrix pass is not claimed.

## Existing probe timeout found during hosted acceptance

Both baseline job 130986894897 (PR #299, full checkout) and candidate job
134360666524 pass version-register rendering (18 tuples), then fail caption
collection before any capture with `production startup not ready`. The probe waits
only 180 frames despite staged startup. Replace this with a 30-second elapsed
budget, preserving readiness and all subsequent assertions. Production timing is
unchanged. This is an observed harness failure, not speculative runtime hardening.
The follow-up hosted run must establish whether the collection itself passes.

## Follow-up result and unresolved acceptance

Candidate `224980381d6773a044db235c71926c438a19b254`, run 44174546622,
Gallery job 134362624474: import and version-register rendering pass; startup now
reaches ready. Caption collection then fails its existing read-only assertion:
`Profile or canonical run changed at first visible acknowledgement`, captures=0.
This failure was previously hidden behind the startup allowance. Its changed field
and cause are not yet established. Preserve the assertion and leave PR #301 open,
unmerged; do not claim complete Gallery acceptance or attribute this to sparse
checkout without evidence. Import also reported an unrelated GUT online-version
API rate-limit error, not a script/load failure.

Next bounded task: capture the differing keys between `_baseline` and `_state()`
in the rendered probe, distinguish Profile/revision/persisted bytes/run state,
and compare against the same probe on master with only the startup-wait fix.
Then fix the confirmed owner or fixture while retaining the read-only contract.
No runtime changes or merge were performed in this session.

## Root cause identified in follow-up

Diagnostic job 134367959180 reproduced the same first-caption failure and isolated
the changes: Profile.displayed_artwork_ids [] -> [picture5, picture4], Profile
revision 18 -> 19, and persisted Profile bytes. Canonical Run state was identical.
SceneArtView recorded visible art during read-only Gallery replay. Its runtime
source was identical to master before this fix; neither sparse checkout nor the
startup-wait edit changed the artwork owner.

The candidate now uses the existing Bridge.is_rehearsal_playback query to suppress
artwork discovery writes during replay, beside its existing transition guard.
Normal canonical artwork discovery is unchanged. The complete read-only assertion
is preserved; temporary state logging is removed. Hosted acceptance also runs the
existing single rendered canonical-artwork test, ensuring visible gameplay art
still persists and hidden/transition-covered art stays undiscovered. No new
manager, profile format, cache, dependency or speculative protection is added.
The final hosted result is recorded in the PR; the earlier blocker remains
historical evidence, not a reason to weaken the assertion.
