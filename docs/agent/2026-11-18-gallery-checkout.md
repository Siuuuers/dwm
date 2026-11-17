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
second changes the checkout. The existing PR selector compares HEAD^ to HEAD,
so hosted acceptance selects the Gallery job on the final candidate. The complete
PR includes shared selection logic; whole-PR classification must remain broad.
This commit structure does not claim broad shared-selector runtime acceptance.

## Verification

- `python tools/testing/test_windows_coverage.py`: 50 tests pass.
- actionlint 1.7.12, same pinned checksum as source-lint: pass.
- git diff --check: pass.
- Source audit: both existing rendered probes retain all identified inputs.

Hosted rendering result is recorded in the PR once available. No game performance
or Windows player-experience improvement is claimed. Only the affected Linux
Gallery job and source lint are requested for hosted acceptance; unrelated game,
Windows export, desktop rendering and inventory jobs should remain skipped.
