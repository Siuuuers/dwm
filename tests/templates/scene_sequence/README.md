# Editable scene sequence — composed TEST authoring

Original preparation by B; starting PR36 source head `5e4da996bdb896fb0db96641232595d78dd08cd9`.
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

## Focused cloud qualification

`tests/unit/test_scene_sequence_authoring.gd` was qualified in A's cloud-only
Godot 4.6.3 standard / Windows PowerShell campaign. Six test cases cover:

1. Three-entry and two-entry complete registration admission, branch/final preservation and nested detachment.
2. Explicit reordered IDs (Day1.1 before Day1), independent of canonical registry storage sorting.
3. Invalid sequences, target ownership, missing ordinary marker and non-terminal final binding.
4. Missing referenced DTL with no repair or partial result.
5. Tampered input program hash refused before recompilation.
6. Single explicit terminal scene leaves registration unchanged.

Both the full manifest validator and scene event contract validate successful outputs.
No local Godot/PowerShell or independent cloud dispatch by B.
The original B preparation was not engine-tested by B. A subsequently qualified
these six cases / 68 assertions, including in
[connected run141](../../../handoff/a-seven-day-connected-20261016.md).
Reuse that bounded evidence; this documentation update does not rerun it.

## Composed startup and remaining limits

The [seven-day builder](../seven_day/README.md) already composes the registration
and normal New Game selects `target.Day1` through the existing immutable
registration/NewRun owners without a debug switch. The helper itself remains
detached; isolated fixture selection is separate from normal startup.
Compose replacements before consumer caches are frozen, never in a live save session.

Owner correction [6207882951](https://github.com/Siuuuers/dwm/pull/30#issuecomment-6207882951)
supersedes the earlier three-scene connected assignment. Day1.1 is only the generic
insertion/removal example, not required game content. A's run141 qualified normal
Title → Day1 through Day7 → registered ending → Title → fresh Day1, plus separate
Day4 and ending Save/Load processes. See the [existing handoff](SEVEN_DAY_HANDOFF.md).
This does not qualify current official exported completion/normal exit or broad CI.

Use the [single author guide and template inventory](AUTHOR_GUIDE.md) for five
result mappings, optional content holders and registered target replacement.
Preserve optional boards, exact saved state, full-caption Load, history and
recovery. Production prose and final build acceptance remain pending.
