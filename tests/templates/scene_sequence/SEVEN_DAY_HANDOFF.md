# Seven-day linear TEST content — pending connected integration

Supersedes the concrete Day1.1 journey example per
[owner correction6207882951](https://github.com/Siuuuers/dwm/pull/30#issuecomment-6207882951).
Prepared on B PR39 parent `4ea170dc86e72964a85bb84dd96fcd43c89e748c`.
A's reported current reading-qualified PR36 head is
`7adbff9a8b9a9a3ed2952e0a72b39979b9e4b032`; do not reset that ancestry to B's older parent.

## Content and mapping

- DTL: `res://tests/fixtures/dialogic/scene_seven_day_linear.dtl`
- Authoring arguments: `tests/templates/scene_sequence/seven_day_order.json`
- Existing helper: `tools/authoring/SceneSequenceAuthoring.gd`

The JSON contains only the helper's explicit `order` and `bindings` arguments.
It is NOT an alternative runtime registration, save schema, complete bundle or installed configuration.
Supply it alongside a valid bundle assembled by the existing registration/compiler owners.
No hashes are fabricated. The DTL uses the same stable entry IDs and per-entry target names as the helper examples.

| Entry | Visible captions, in order | Ordinary marker | Ordinary target |
| --- | --- | --- | --- |
| Day1 | TEST Day1 opening. → TEST Day1 closing. | Day1.next | target.Day2 |
| Day2 | TEST Day2 opening. → TEST Day2 closing. | Day2.next | target.Day3 |
| Day3 | TEST Day3 opening. → TEST Day3 closing. | Day3.next | target.Day4 |
| Day4 | TEST Day4 opening. → TEST Day4 closing. | Day4.next | target.Day5 |
| Day5 | TEST Day5 opening. → TEST Day5 closing. | Day5.next | target.Day6 |
| Day6 | TEST Day6 opening. → TEST Day6 closing. | Day6.next | target.Day7 |
| Day7 | TEST Day7 opening. → TEST Day7 closing. | none supplied | A's authenticated TEST ending contract |

Every opening uses `line.<entry>.one`; every closing uses `line.<entry>.two`.
Use matching caption-registry text, stable beat IDs and revision values through the existing authoring owner.
Each ordinary marker row uses the existing shape:
```json
{
  "marker_id": "Day1.next",
  "label": "Day1.next",
  "after_line_id": "line.Day1.two",
  "kind": "scene.transition",
  "payload": {"target_id": "target.Day2"}
}
```
Apply that shape explicitly to the six table rows, not via runtime numeric-day routing.
Each existing scene target binds its entry label, content_version and actual compiler-derived program_sha256.
Ordinary entries grant `history.line.witness` and `scene.transition` through the existing registry;
Day7's final grants/marker depend on the actual terminal contract.

The delivered DTL is linear: no branch-preservation probe, loop, jump, Contact detour,
choice or required Minesweeper challenge. Each return is a native segment delimiter.
In particular, Day7's bare return is NOT a durable ending transition and must not be
treated as completed playable integration.

## Terminal and startup dependencies for A

The helper's empty final `next_marker_id` preserves authored terminal policy; it does not create that policy.
A/C have published an interface proposal in PR40, but no concrete authenticated terminal payload or
callable fixture hook was published at B's inspection. Accordingly there is no invented Day7 ending marker,
target, ending prose or lifecycle mutation here. A must add the actual terminal boundary/registration
under its existing ownership when implementing that contract.

Normal New Game must select the returned first target `target.Day1` through the existing immutable
registration/NewRun owners without a debug switch. A owns schema3 selection and integration.
This packet neither installs registration nor modifies Bootstrap, SaveManager, SceneRouter or the compiler.

## Connected acceptance input

Expected normal path: Title → Day1 → Day2 → Day3 → Day4 → Day5 → Day6 → Day7 →
registered TEST ending → Title → new Day1 run.
Expected ordinary dialogue is the fourteen captions in the table, in that exact order.
Use one representative later-caption Save/fresh-process Load point, such as `line.Day4.two`:
the same saved caption is fully visible, without advancing or replaying consequences.
Reuse existing board-layout persistence and optional board coverage; seven mandatory boards are not requested.
Ending completion/Title return/new-run state assertions follow A's actual hooks and C's assigned verification.

The existing Day1.1 helper tests remain useful generic insertion/removal checks. They are not game content,
a seven-day requirement, or a separate connected campaign. No duplicate three-scene linear fixture was created.

## Verification and limits

B checks literal label/line uniqueness, six marker mappings, explicit ordered-list agreement and exact
published file bytes. These are static content checks, not engine compilation or registration admission.
Godot/PowerShell and connected tests: NOT RUN by B. A owns composed cloud execution.
No fabricated test totals, full-loop acceptance, production story, board format change or old-save migration.
Existing PR39 helper and branch-preservation tests, PR37 content, shared runtime and generated inventories remain unchanged.
