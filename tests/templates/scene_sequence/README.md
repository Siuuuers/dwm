# Editable scene sequence — uninstalled TEST preparation

Owner B; starting PR36 source head `5e4da996bdb896fb0db96641232595d78dd08cd9`.
Assignment: [Director6206547454](https://github.com/Siuuuers/dwm/pull/30#issuecomment-6206547454).
PR1 is the product umbrella. A owns shared runtime, normal startup selection, cloud execution and integration.

## Observable outcome

Given an existing valid registration, an explicit ordered array and ordinary-exit bindings,
produce a detached registration whose ordinary successors follow that array.
The first target is returned for the existing NewRun owner to consume.
No filename ordering or arithmetic on day names is used.

```gdscript
const SEQUENCE = preload("res://tools/authoring/SceneSequenceAuthoring.gd")
var bindings = {
    "Day1": {"target_id": "target.Day1", "next_marker_id": "Day1.next"},
    "Day1.1": {"target_id": "target.Day1.1", "next_marker_id": "Day1.1.next"},
    "Day2": {"target_id": "target.Day2", "next_marker_id": ""},
}
var result = SEQUENCE.build(["Day1", "Day1.1", "Day2"], registered_source, bindings)
# To bypass the intermediate entry, change only the order:
result = SEQUENCE.build(["Day1", "Day2"], registered_source, bindings)
# On success:
# result.value.registration = complete validated bundle
# result.value.first_target_id = "target.Day1"
```

Expected ordinary links:

| Order | Day1 ordinary target | Intermediate ordinary target | First target |
| --- | --- | --- | --- |
| Day1, Day1.1, Day2 | target.Day1.1 | target.Day2 | target.Day1 |
| Day1, Day2 | target.Day2 | unused by this sequence | target.Day1 |

These are authoring results, not rendered journey acceptance. The test source is built
in `test_scene_sequence_authoring.gd::_source` using the real compiler and replaceable
`scene_sequence_authoring.dtl`. No production narrative is introduced.

## Ownership and refusal behavior

- Input is a complete existing registration plus explicit bindings; this is not a second registration schema or runtime router.
- The existing full registration validator checks input BEFORE any hash refresh. Stale source hashes/content are refused, not blessed by recompilation.
- Only designated non-final ordinary `scene.transition` marker payloads change.
  Explicit branch marker destinations remain authored. All target program hashes are refreshed
  from the existing compiler, including targets referenced by branches, using exactly the compiler's identity. Payload-only relinking may leave native program hashes unchanged; the full bundle fingerprint still covers transition payloads.
- The last entry must explicitly bind an empty ordinary-next marker. Its content and terminal policy are retained;
  this helper does not invent an ending handoff or treat a bare DTL return as durable game completion.
- Missing entries, duplicate/non-string IDs, incorrect target ownership, missing ordinary markers,
  missing referenced content and invalid compiled registration return a failure with no partial value.
- Removing an entry from the order bypasses it; it does not delete its registered content or incoming explicit branches.
  To remove a file, first remove/reconcile its registration and references through the existing authoring owners.
  A still-referenced missing file is a clear content failure.
- Output is detached; no registration is installed, cache selected, file written, Run changed,
  save migrated, board regenerated or engine process launched.
- Sequence changes alter registration identity. No migration of old saves across changed/removed content is promised.

## Focused cloud checks for A

Run `tests/unit/test_scene_sequence_authoring.gd` in A's existing pinned Godot 4.6.3
standard/Windows PowerShell campaign. Six test cases cover:

1. Three-entry and two-entry complete registration admission, branch/final preservation and nested detachment.
2. Explicit reordered IDs (Day1.1 before Day1), independent of canonical registry storage sorting.
3. Invalid sequences, target ownership, missing ordinary marker and non-terminal final binding.
4. Missing referenced DTL with no repair or partial result.
5. Tampered input program hash refused before recompilation.
6. Single explicit terminal scene leaves registration unchanged.

Both the full manifest validator and scene event contract validate successful outputs.
No local Godot/PowerShell or independent cloud dispatch by B.
Test status at delivery: **NOT RUN**. No assertion totals or playable acceptance claimed.
A may generate UID/import metadata under existing integration ownership.

## Minimal shared interface request to A

After the later-caption correction, use the returned first_target_id with the existing
authenticated NewRun selection. Existing registration is currently TEST-only and selected
through debug flag/environment seams. Final Title → Day1 must use the approved normal
startup selection without a debug/test-only switch; B does not alter that shared owner here.

Compose the returned registration before immutable consumer caches are selected; never hot-replace
registration in a live save session. Reuse the existing compiler/registration validation and
scene-transition transaction. C's retained-ending handoff supplies terminal integration.

Owner correction [6207882951](https://github.com/Siuuuers/dwm/pull/30#issuecomment-6207882951)
supersedes the earlier three-scene connected assignment. The synthetic IDs above test generic
insertion/removal only; Day1.1 is not required game content or a connected acceptance milestone.
Connected acceptance remains A's work: normal Title → Day1 through Day7 →
authored ending → Title → fresh Day1. See `tests/templates/seven_day/README.md` for preparation.
Preserve optional board,
exact board restore, full-caption Load (without advancing/replaying consequences), history and recovery.
Do not merge this preparation as evidence of that complete journey. PR37 partner-fork files remain untouched.
