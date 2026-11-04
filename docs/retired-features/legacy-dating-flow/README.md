# DTL-only production progression

The user retired separate Dating scheduling/progression, Gallery Practice, and the
whole automatic Schedule/Hospital/day-resolution flow on 2026-11-04. DTL controls
challenge entry, outcome continuation, day transitions, and story endings.

The existing authored-week implementation already owns these behaviors. This
change removes the parallel production composition; it does not replace the DTL
compiler, create another flow manager, or change authored story text.

## Removed

- Bootstrap composition and resumption of automatic Schedule/day resolution,
  Hospital/condition progression, and Dating pre/post-challenge playback.
- Hospital/Dating scene routes and their presentation-port injection/startup holds.
- Uncalled Dating queue routing methods and the old previous-dialogue list.
- Unconstructed Dating narrative phase adapter; mixed caption tests use Bridge directly.
- Gallery Practice, its rehearsal owner/admission/UI, and exclusive runner entries.
- Tests that required the retired production composition. Current startup,
  shared board identity, restore, Gallery reading, and DTL checks remain.

## Retained deliberately

`DatingPhysicalOwner` and `DatingPresentationPort` still execute DTL scene
challenges. Their scene-challenge branch, generation owner, checkpoint flushing,
restore reconciler, and shared saved-data envelope are live dependencies.

The ScheduleView data restore participant remains part of the current snapshot
contract; it does not schedule or advance the story. This change does not migrate
that schema. Other legacy domain/scene source remains where retained tests,
read-only presentation copies, or shared domain APIs still reference it. It is not
routed or composed as the old production flow. Do not infer deletion safety from
filenames alone. Historical evidence is retained as history, not current acceptance.

Artwork, read-only dialogue library/replay, DTL challenges, ordinary desktop
Minesweeper, and current save/load remain supported. No runtime speedup is claimed
from the source deletion count.

## Verification scope

Focused checks cover startup/scene composition, shared board and restore owners,
DTL challenge/panel behavior, Gallery layout/navigation, and startup/return routing.
The authored-week rendered create/load journey exercises real DTL progression and
physical saves. The PR records final results and limitations for its candidate.

Three failures in the full profile-stage suite also reproduce on unchanged master:
`test_profile_stage_validates_and_binds_shipped_visited_registry_before_initialize`,
`test_final_contact_stage_reuses_profile_storage_and_retains_one_identity_graph`,
and `test_ready_callbacks_are_side_effect_free_or_deferred_only`. They are outside
this retirement; their assertions are not weakened here.
