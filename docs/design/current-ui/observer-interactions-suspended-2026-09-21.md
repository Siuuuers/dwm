# Observer interactions suspended in the current build

Owner decision, 2026-09-21. Bead: `dwm-6gk`.

The owner suspends the provisional Day 2 Capture/Compare and timed-restraint
interactions. They are future work, not required player actions in this build.
This bounded current-build decision supersedes the interaction-evidence
conjunction in the August 7 flow specification for the two solo Observer gates.
It does not promote future plot candidates or claim that the interactions occurred.

## Preserved implementation

The entire original implementation, scene, tests, and design context are retained
on [archive/observer-interactions-2026-09-21](https://github.com/Siuuuers/dwm/tree/archive/observer-interactions-2026-09-21),
at `845d987d52adfe57f27511c39a02a18c7834e84d`.

Relevant recovery paths are `scripts/ui/DatingScene.gd`,
`scripts/application/run/DatingPhysicalOwner.gd`,
`scripts/profile/ObserverEvidence.gd`,
`tests/unit/test_dating_attempt_runtime.gd`, and
`tests/scene/test_minesweeper_challenge_controls.gd`.
Restoration requires a new owner-approved design and its behavioral tests; do not
merge that entire historical branch over later fixes.

## Current eligibility

| Observer scope | Current requirements |
| --- | --- |
| Angela–Priscilla | Four exact current-canonical Perfect boards on Days 1, 2, 4, 6; eligible selected Day 7 destination; Sweet tone; actual ordered ending completion |
| Angela–Lavinia | Four exact current-canonical Perfect boards on Days 2, 3, 5, 6; eligible selected Day 7 destination; Sweet tone; actual ordered ending completion |
| Priscilla–Lavinia | Existing pair rules unchanged: both counted windows and current canonical Perfect boards, Sweet form, four actually witnessed pair forms, and durable preceding ending completion |
| Sylvia | No Observer route |

Solo eligibility does not require Capture, Compare, or restraint receipts.
Full versus residue still uses actual prior Gallery ending completion.
Missing, foreign-run, sibling-branch, unfinished, Solved, or Exploded board heads
cannot manufacture mastery. No narrative knowledge or interaction evidence is
created by relaxing the gate.

## Runtime and save boundary

The live DatingScene does not mount the provisional interaction UI.
The physical owner admits no Observer source; retired actions are refused.
An older saved `dating_observer_source.checkpoint_pending` cannot hold current
board input. Existing profile/schema evidence remains readable and unchanged.
Future story descriptions remain design material; this implementation does not
rewrite them as events that happened in the current playthrough.

The accepted removal of dating confirmation cards and the special-mine choice
is separately tracked as `dwm-cb1`, including actual semantic DTL playback.
That separate work is not established by this Observer change.

## Verification

Focused Windows coverage includes current canonical mastery, retired interaction
dispatch, stale-save board entry, UI absence, Profile evidence compatibility, and
ordered ending playback. Passing evidence must name the tested commit/run.
