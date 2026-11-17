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
