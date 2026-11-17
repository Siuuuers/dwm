# Gallery replay isolation and CI checkout

Base: `65fa4d3e8647f8e15dfc74b67d2fa84a83778dd1` (PR #300).
Verified runtime candidate: `4e5ec694708f7a108c95b469239b8ee828d0a591`.
The final documentation-only commit does not change tested runtime or checks.

## Result

Gallery replay no longer records artwork discoveries into Profile. SceneArtView
uses the existing Bridge.is_rehearsal_playback query at its post-draw observation
boundary. Normal canonical artwork discovery remains active. The existing full
Profile/revision/persisted-bytes/Run equality assertion is unchanged.

The Gallery CI checkout now omits historical evidence while retaining every
non-evidence path and evidence/.gdignore. No repository archive or asset is deleted.
The existing owner selector recognizes rendered-journeys for future job-only edits.
No new manager, cache, dependency, profile format or gameplay timing change.

## Investigation and root cause

The original full-checkout Gallery job in PR #299 (130986894897) and initial sparse
job 134360666524 both passed the version register, then failed before startup was
ready. The probe allowed only 180 frames. Its 30-second elapsed deadline now waits
for staged startup without changing the readiness assertion or production startup.

That exposed the real read-only failure. Diagnostic job 134367959180 compared the
state before replay and after its first visible caption:

- Profile.displayed_artwork_ids: [] -> [picture5, picture4].
- Profile revision: 18 -> 19; persisted Profile bytes also changed.
- Canonical Run state: unchanged.

SceneArtView recorded visible textures without excluding replay. Its source matched
master before this fix. The sparse checkout and startup-wait edit did not modify
that owner. The diagnostic was rendered on the candidate with otherwise unchanged
runtime; no separate master-plus-wait rendered run is claimed. Temporary logging
was removed after identification. A headless diagnostic stalled before the state
comparison and was stopped; it supplies no acceptance evidence.

The one-line guard uses the existing authoritative replay status after drawing.
Independent review traced normal exit/cancel: entry retirement clears art textures
before replay state ends, so a queued observation does not discover retired replay
art after exit. Existing retained-failure behavior remains intact.

## Input audit and CI selection

Gallery probes use tests/fixtures/dialogic/gallery_collection_catalogue.json,
gallery_collection.dtl and data/manifests/art_placements.json plus current UI/assets.
user://evidence paths are generated output, not repository input. Independent audit
found no historical evidence dependency. Git sparse-pattern regression preserves
these inputs and excludes historical archives/images. The omitted directory was
previously measured at about 1.22 GB in PR #299; no new network/time gain is claimed.

The first branch-parent replay selected Gallery + test-scope, but that was not
GitHub's PR checkout semantics. Actions checks out a synthetic merge commit whose
HEAD^ is the PR base. Shared selector/runtime edits correctly caused broad fallback
for this PR. Splitting commits does not narrow an initial multi-commit PR. Future
changes confined to the recognized Gallery job can select its focused route.

## Acceptance

Hosted run 44176856724, job 134370673528 passes on the verified candidate:

- Sparse checkout, import and native Linux speech setup.
- Existing canonical artwork discovery test: 1 test, 28 assertions. Visible artwork
  persists; hidden/transition-covered artwork does not; Gallery reset stays correct.
- Version-register rendering: all 18 tuples.
- Caption-collection rendering: verified, 95 captures, including the unchanged full
  read-only assertion and existing exit/history/locale checks.

https://github.com/Siuuuers/dwm/actions/runs/44176856724/job/134370673528

All 50 selector tests pass locally. actionlint 1.7.12 and git diff --check pass.
Hosted source lint run 44176856523 passes. Independent review covered dependency
retention, selector gates, artwork-write ownership and replay-exit ordering.

No full-matrix, Windows player-experience, hardware input-to-photon or game speedup
claim. Broader jobs were automatically selected, but acceptance here relies on the
focused affected checks above. Existing failure cases were reused; no new injection
campaign was added. The earlier PR blocker is resolved by the passing rendered run.
