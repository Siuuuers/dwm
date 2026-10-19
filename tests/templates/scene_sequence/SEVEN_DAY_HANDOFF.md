# Seven-day linear TEST content — composed connected milestone

Supersedes the concrete Day1.1 journey example per
[owner correction6207882951](https://github.com/Siuuuers/dwm/pull/30#issuecomment-6207882951).
Prepared on B PR39 parent `4ea170dc86e72964a85bb84dd96fcd43c89e748c`.
That preparation is historical. A subsequently composed and qualified the
connected journey in [run141](../../../handoff/a-seven-day-connected-20261016.md).
Current documentation reconciliation uses PR36
`775a7d51a37fe2ff3de64ec3fe5353a5d11973a2`; do not reset it to B's older parent.

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
| Day7 | TEST Day7 opening. → TEST Day7 closing. | Day7.end | target.ending.alone.normal |

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
Day7 also grants `scene.transition`; its `Day7.end` marker follows `line.Day7.two`
and selects the registered ending target through the existing terminal contract.

The delivered DTL is linear: no branch-preservation probe, loop, jump, Contact detour,
choice or required Minesweeper challenge. Each return is a native segment delimiter.
Day7's return is NOT the durable ending transition: the registered `Day7.end`
marker and existing terminal owner supply that behavior.

## Implemented terminal and startup composition

The helper's empty final `next_marker_id` preserves authored terminal policy;
[SevenDayTemplates.gd](../seven_day/SevenDayTemplates.gd) supplies that policy.
It binds `Day7.end` to `target.ending.alone.normal`, whose role is `ending`,
using the existing neutral ending definition/context and replaceable
`scene_seven_day_ending.dtl`. No numeric-day routing is introduced.

Normal New Game already selects `target.Day1` through the exported schema-3
registration and existing NewRun owners. The preparation helper itself remains
detached. See the [builder README](../seven_day/README.md) and
[single author guide](AUTHOR_GUIDE.md) for replacement and compatibility rules.

## Accepted connected journey

Run141 qualified the normal path: Title → Day1 → Day2 → Day3 → Day4 → Day5 → Day6 → Day7 →
registered TEST ending → Title → new Day1 run.
The ordinary dialogue is the fourteen captions in the table, in that exact order.
The separate-process Save/Load coverage includes `line.Day4.two`:
the same saved caption is fully visible, without advancing or replaying consequences.
Reuse existing board-layout persistence and optional board coverage; seven mandatory boards are not requested.
The ending loader also restored the exact saved ending after prior completion,
without a duplicate Gallery transaction. See the source-pinned run141 report.

The existing Day1.1 helper tests remain useful generic insertion/removal checks. They are not game content,
a seven-day requirement, or a separate connected campaign. No duplicate three-scene linear fixture was created.

## Verification and limits

A's [run141 handoff](../../../handoff/a-seven-day-connected-20261016.md) records
25 tests / 623 assertions, including 3 rendered cases / 328 assertions. This is
bounded historical source-run acceptance, not a new result from this docs update.
B ran no Godot/PowerShell; all engine validation remains cloud-only.

Current official exported ending/durable Gallery/Title/normal Load exit,
ordinary Save/transition latency and relevant broader integration failures remain
open. No whole-game, arbitrary interruption, performance, production-story or
old-save-migration claim. PR36 remains draft/unmerged; no release.
