# Next-session handoff — 18 November 2026

## Start here

Repository: https://github.com/Siuuuers/dwm
Verified master: `31b62e01b1b268af0ed3ee4e3563d7bbb4501c9f` (merged PR #301).
Fetch current master and read AGENTS.md before choosing work. This handoff is a
completed-session record, not evidence that later master is unchanged.

A fresh conversation is useful now: the investigation is complete and its many
rejected trials/diagnostic branches need not occupy the next working context.
There is no known unresolved blocker from PR #301 and no reason to reopen it.

## What actually changed

- PR #299: public-surface CI omits historical evidence; measured tracked content
  fell from 1,391,134,742 to 169,594,909 bytes. Those are uncompressed content sizes,
  not measured network transfer or duration. Archives stay in the repository.
- PR #300: public-surface job edits plus reviewed companion prose can select their
  owners. Shared selector/runtime edits retain broader fallback.
- PR #301: Gallery render checkout also omits historical evidence; its owner can
  be selected for future job-only edits. The replay probe now waits up to 30 elapsed
  seconds for staged startup instead of 180 frames.
- PR #301's actual bug: SceneArtView recorded picture5/picture4 discoveries during
  Gallery replay. This changed Profile, revision and persisted bytes; canonical
  Run stayed unchanged. One existing-owner condition now skips discovery while
  Bridge.is_rehearsal_playback() is true. Ordinary gameplay discovery remains.

Do not repeat PR #298's rejected Settings preload trial: first opening worsened
from 200–220 ms to 246–257 ms with no reliable startup gain. Earlier threading
trial also supplied no reliable improvement. Shorter code is not latency evidence.

## Acceptance already completed

Runtime candidate: `4e5ec694708f7a108c95b469239b8ee828d0a591`; final docs did not
change its tested code. Merged tree matched the local final candidate.

https://github.com/Siuuuers/dwm/pull/301
https://github.com/Siuuuers/dwm/actions/runs/44176856724/job/134370673528

Hosted Linux rendered job passed:

- Canonical artwork discovery: 1 test, 28 assertions.
- Gallery version-register: 18 tuples.
- Gallery caption collection: 95 rendered captures, original Profile/revision/
  persisted-bytes/Run equality assertions intact.

50 local selector tests, actionlint 1.7.12 and whitespace checks passed; hosted
source lint also passed. Temporary state logging was removed. Independent review
covered ownership, replay exit ordering, dependency retention and job gates.
No full-matrix, Windows player-experience or input-to-photon acceptance is claimed.

## Next bounded investigation

Goal: establish which replay path the current authored Gallery uses and verify
that its existing checks protect the permitted persistence behavior.
Owner: DialogicBridge and GalleryReplayOwner; Profile owns persistent read marks.
Scope: inspect first, edit only for a concrete uncovered behavior or failure.
Dependencies: current Scene contract and existing connected passage tests.

1. Read docs/design/2026-10-25-current-scene-state.md, then the exact paths below.
2. Distinguish signature replay from current Scene passage-card replay. Do not
   generalize the signature probe's whole-Profile equality to every replay path.
3. Check the latest existing passage-replay CI result before scheduling another
   run. Existing tests may already fully cover the intended outcome.
4. If a check is needed, use the current create/load/replay runner with its required
   shared fixture storage. Do not improvise old-save seeds or run the full week
   merely to test a short replay boundary.
5. Stop if coverage is already adequate and passing. Report no additional fix
   needed and choose the user's next feature; do not invent cleanup work.

Relevant current sources:

- autoload/DialogicBridge.gd: replay_scene_passage, replay_reached_signature,
  _acknowledge_reached_date_card, _finish_reached_replay, is_rehearsal_playback.
- scripts/application/ending/GalleryReplayOwner.gd.
- scripts/ui/art/SceneArtView.gd: _queue_artwork_observation.
- tests/integration/test_scene_passage_connected_replay.gd and
  tests/integration/scene_passage_child.gd: replay_completed_passage_scene.
- tests/ui/render_gallery_caption_collection.gd.
- tests/integration/test_artwork_gallery.gd.

Expected distinction: canonical Run, rewards, completion receipts, Save files and
artwork discoveries are not replay consequences. A displayed passage card may
record its exact read revision; signature caption replay may merge its approved
caption history at exit. Existing passage tests explicitly permit only read-mark
Profile changes, reject unseen-caption marks and retain Run/Save equality. Preserve
these contracts; ask the user only if evidence reveals an unresolved design choice.

## Lint recommendation

No new lint added. A regex that merely requires is_rehearsal_playback in a function
cannot prove branch ordering, deferred callbacks or suppressed writes. A blanket
ban on Profile writes would break permitted read marks/history merging. Keep the
rendered replay equality check paired with positive canonical-artwork discovery;
those now run together in the Gallery job.

Existing tools/lint checks already enforce several narrow ownership/dependency
rules. Add another only for a concrete structural invariant with low false-positive
cost. Do not add host-sensitive timing thresholds, serialization/hash bans across
all code, or source-line-number API inventories.

## Workflow lessons and constraints

- GitHub PR checkout is a synthetic merge commit: HEAD^ is the PR base, not the
  preceding feature-branch commit. Splitting commits does not narrow full-PR
  coverage. Replay the actual checkout semantics when validating selectors.
- Linux/cloud-first. Windows packaged player experience remains a separate later
  task; do not restart it merely because this handoff exists.
- User authorizes focused fixes, PRs and direct merge after relevant evidence.
  Preserve data-loss handling, accessibility and approved game behavior. Record
  proven retirements before deletion; no speculative injection campaign.
- No universal promise of visible smoothness follows from headless timings.
- The temporary working checkout is /tmp/dwm-next, which may disappear. GitHub is
  authoritative. Git push lacks credentials here; publish through the GitHub
  connector and verify exact tree identity plus expected head before merge.
- Local Godot is 4.6.3. No local Xvfb was available. A headless version of the
  rendered probe stalled and was stopped; it was not acceptance evidence.
- No new session needs to recreate temporary diagnostic scripts or old user data.
