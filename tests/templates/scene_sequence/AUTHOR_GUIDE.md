# Author guide: reusable Challenge, echo and option pointers

## Current authored-week text editing

Edit `dialogic/timelines/authored_week/Day1.dtl` through `Day7.dtl` directly.
Keep a caption's existing `#id:` when changing its wording or moving its position.
Give each inserted caption a new unique ID. Never renumber following captions or
reuse a deleted ID for a different story moment. The old generated-file headers
describe the initial import; `build_playable_week.py` now refuses to overwrite
existing authored DTL because its ordinal IDs are not safe for later edits.

`data/manifests/authored_week_source.json` still owns entry, day, marker, choice,
and Challenge bindings. Its `lines` lists are historical import provenance,
not a second editable copy of current dialogue. Update a marker's `after_line_id`
when changing the caption that directly precedes that control.

Update `localization/story/en.json` to match the current DTL and choice text.
Keep the same caption and choice IDs in all four translated catalogs; add or
remove their entries together with the English source. Run
`python tools/localization/validate_story_catalogs.py` to check source equality,
matching IDs, character names and plain-text formatting.

On the cloud Godot runner, regenerate the committed registration with
`tools/authoring/ExportSevenDayRegistration.gd`, then run the authored-week tests
and the relevant connected journeys. Native DTL compilation owns current text,
IDs and executable positions. Do not hand-edit generated hashes. Keep the prior
committed registration present during regeneration: identical line ID/text pairs
retain their revision, including legacy revision `1`; changed or new text uses
its content hash. Repeating an export preserves these revisions. Read status
remains shared across languages through the canonical English caption revision.
Translation-only edits do not create a separate language-specific read mark.

This authoring rule does not itself implement cross-version save restoration.

This guide is for neutral replaceable templates, not story writing. It follows
[Director scope](https://github.com/Siuuuers/dwm/pull/30#issuecomment-6236752089),
[five-result names](https://github.com/Siuuuers/dwm/pull/30#issuecomment-6236942172)
and [optional slot clarification](https://github.com/Siuuuers/dwm/pull/30#issuecomment-6236980632).

Current composition checked at PR36 `775a7d51a37fe2ff3de64ec3fe5353a5d11973a2`.
The guide and two-slot builder are already composed there. The pinned examples
below retain their original evidence identities; old PR39 alone does not supply
five-result/recall support. A owns registration integration and cloud-only
Godot 4.6.3 standard GDScript / Windows PowerShell execution.

## Start with the working example

Reuse these existing PR36 files; do not build another result dispatcher:

- [Neutral DTL: Start, End, five passages, common continuation and later recall](https://github.com/Siuuuers/dwm/blob/77df47a73c5c2b69978cf2df74ecf8ac4e9294a9/tests/fixtures/dialogic/scene_challenge_recall.dtl).
- [Complete registration builder](https://github.com/Siuuuers/dwm/blob/77df47a73c5c2b69978cf2df74ecf8ac4e9294a9/tests/support/SceneChallengeRecallFixture.gd).
- [A's binding/evidence handoff](https://github.com/Siuuuers/dwm/blob/77df47a73c5c2b69978cf2df74ecf8ac4e9294a9/handoff/a-challenge-recall-20261017.md).

On the composed tree, this is the actual offline builder call:

```gdscript
const EXAMPLE = preload("res://tests/support/SceneChallengeRecallFixture.gd")
var built: Dictionary = EXAMPLE.bundle()
if not built.get("ok", false):
    push_error(str(built))
    return
var checked: Dictionary = EXAMPLE.MANIFEST.validate_scene_registration(built.value)
if not checked.get("ok", false):
    push_error(str(checked))
    return
# built.value is the complete registration. Preparation does not install it.
```

The fixture's `install()` calls the existing TEST registration selector. Use it
only in isolated fixture setup before consumers freeze registration. It does not
replace normal Title/New Game. Product registration/export stays A-owned.

A label marks a DTL location. **Its spelling does not execute a Challenge,
select a result or remember anything.** The registration binds that location to a
control kind, exact preceding caption, payload and registered destinations.

## Five meanings, one represented Challenge

The documented mapping is below. The order of JSON keys does not select results.

| Pointer target ID | Meaning at End | Runtime destination key | DTL entry/label in the example |
| --- | --- | --- | --- |
| `echo_a_day1` | Not started: no first Reveal | `never_started` | `scene.test.echo_a_day1` |
| `echo_b_day1` | Started, no terminal win/loss | `unfinished` | `scene.test.echo_b_day1` |
| `echo_c_day1` | Win, excluding Perfect | `won` | `scene.test.echo_c_day1` |
| `echo_d_day1` | Lose/exploded | `lost` | `scene.test.echo_d_day1` |
| `echo_e_day1` | Perfect | `perfect` | `scene.test.echo_e_day1` |

These are five outcomes, not five Challenges. Day suffixes identify author-used
content; they do not read a clock or select the current board. Use `echo_a_dayN` through `echo_e_dayN` for day1–day6 as needed;
these are naming conventions, not six preinstalled sets of result passages.
The existing Day7 remains in the skeleton.
Distinct represented Challenges need distinct challenge IDs.

Opening Computer freezes caption/Auto progression. Viewing the panel is not
starting an attempt; first Reveal is the boundary. Pre-Reveal flag actions are
currently refused, so they cannot turn Not started into Unfinished. Closing
Computer alone neither advances the story nor resolves the result. An unfinished
board can be resumed while its opportunity remains open.

Resolve once at the authored End. The five result destinations are exclusive:
Perfect does not additionally dispatch Win. Physical board state for a win remains
`won`; the existing owner projects `perfect` from canonical Perfect reasons.
Do not rename board enums, invent scoring or award awareness in the author guide.
Historical four-target registrations retain their older won behavior; new
five-result content must provide all five keys.

## Copyable Start and End binding

This is the existing DTL segment; replace its TEST sentences with dialogue:

```text
label scene.test.recall.start
TEST challenge before Playable. #id:line.scene.test.recall.start.one
label scene.test.recall.start.playable
TEST challenge can be left unstarted. #id:line.scene.test.recall.start.two
label scene.test.recall.start.end
return
```

These are actual marker rows within that entry's
`scene_programme.entries[].markers` array:

```json
[
  {
    "marker_id": "scene.test.recall.start.playable",
    "label": "scene.test.recall.start.playable",
    "after_line_id": "line.scene.test.recall.start.one",
    "kind": "challenge.playable",
    "payload": {"challenge_id": "TEST.recall.challenge"}
  },
  {
    "marker_id": "scene.test.recall.start.end",
    "label": "scene.test.recall.start.end",
    "after_line_id": "line.scene.test.recall.start.two",
    "kind": "challenge.end",
    "payload": {"challenge_id": "TEST.recall.challenge"}
  }
]
```

The corresponding `challenges[]` row is:

```json
{
  "challenge_id": "TEST.recall.challenge",
  "entry_id": "scene.test.recall.start",
  "playable_marker_id": "scene.test.recall.start.playable",
  "end_marker_id": "scene.test.recall.start.end",
  "board_profile_id": "TEST.profile",
  "targets": {
    "never_started": "echo_a_day1",
    "unfinished": "echo_b_day1",
    "won": "echo_c_day1",
    "lost": "echo_d_day1",
    "perfect": "echo_e_day1"
  }
}
```

`TEST.profile` is the existing fixture's registered board profile, not a magic
built-in name. The complete builder supplies it. It also supplies the target
table, entry locators, contexts, caption/ID registries and allowed signals.
These JSON fragments are not a standalone registration.

Start admission retains its caption; the next physical reading advance leaves
that held control. Do not assume one Enter both opens an opportunity and skips
to the following caption. End then selects the result target through existing
receipt and target-admission owners. DTL `return` only terminates the compiler
segment; it is not durable ending completion.

## Common continuation and later recall

The existing example already rejoins all five End passages. Each
`scene.test.echo_X_day1` has a `.next` label after its `.one` caption.
Its marker has kind `scene.transition` and payload:

```json
{"target_id": "recall.later"}
```

All five therefore reach the single common entry `scene.test.recall.later`.
This is an example of convergence, not a requirement to write five different
stories. Several result keys may instead point to one registered scene target
when the passage is shared. Keep all five keys even then.

In the example the common passage goes on to recall the represented result:

```json
{
  "marker_id": "scene.test.recall.later.recall",
  "label": "scene.test.recall.later.recall",
  "after_line_id": "line.scene.test.recall.later.one",
  "kind": "challenge.recall",
  "payload": {
    "challenge_id": "TEST.recall.challenge",
    "never_started_target_id": "recall_a_day1",
    "unfinished_target_id": "recall_b_day1",
    "won_target_id": "recall_c_day1",
    "lost_target_id": "recall_d_day1",
    "perfect_target_id": "recall_e_day1"
  }
}
```

The entry allows `challenge.recall`; the IDs registry declares its payload fields
in this order: `challenge_id`, `never_started_target_id`,
`unfinished_target_id`, `won_target_id`, `lost_target_id`,
`perfect_target_id`. All destinations are registered scene targets.
The `recall_*` names merely distinguish the later passages from the immediate
`echo_*` passages; authors can use other stable names with explicit bindings.

Recall reads the uniquely prior `challenge_closed` receipt for that challenge ID
in the selected saved Run. It does not inspect whichever board is active now,
close the Challenge again, or reapply rewards/effects. Missing or ambiguous saved
results are errors, not Not started. Keep a represented challenge ID stable when
several later passages refer to that same result.

For a common continuation without recall, author an ordinary following passage
and bind its next transition normally instead of registering `challenge.recall`.
Do not delete a still-referenced label. That adaptation needs recompilation and
focused validation; it is not an already-executed variant of A's example.

## Two used option slots, no quota or extra menu

[scene_author_option_slots.dtl](../../fixtures/dialogic/scene_author_option_slots.dtl)
contains only `scene.test.option_a_day1` and `scene.test.option_b_day1`.
There is no required option_c, no simultaneous three-button choice and no daily
quota. Its role is assigned by registration. The composed
[OptionSlotTemplates.gd](OptionSlotTemplates.gd) now supplies the complete offline
A→B registration. Preload that script as the builder constant and call its
`bundle()` method, then validate the returned `value` as in the example above.
It does not select normal startup.

For an ordinary A→B sequence, use this marker in A's programme:

```json
{
  "marker_id": "scene.test.option_a_day1.next",
  "label": "scene.test.option_a_day1.next",
  "after_line_id": "line.scene.test.option_a_day1.one",
  "kind": "scene.transition",
  "payload": {"target_id": "option_b_day1"}
}
```

Register the targets `option_a_day1` and `option_b_day1` against their matching
`scene.test.*` entry/label. A target row's exact existing shape is:

```gdscript
# id = "scene.test.option_b_day1"; compiled is the successful adapter result.
var target = {
    "target_id": "option_b_day1",
    "target": {
        "kind": "scene", "entry_id": id, "label": id,
        "content_version": 1,
        "program_sha256": compiled.value.program_sha256
    }
}
```

Compile each entry using `DialogicRuntimeAdapter.compile_scene_programme(path,
entry_id, entry_ids, markers)` and follow the existing complete builder for all
registries. In this two-slot adaptation use the new DTL path, the two-entry list,
A's marker above, no marker for B, and ordinary scene targets. Update entry_count;
declare/allow `scene.transition` and `history.line.witness`. Do not copy the
Challenge row or its recall signals into an ordinary two-slot example.

If a slot is used as the destination of an optional thought instead, use the
existing [partner-fork template](https://github.com/Siuuuers/dwm/blob/77df47a73c5c2b69978cf2df74ecf8ac4e9294a9/tests/templates/partner_fork/README.md) and
[actual thought registration example](https://github.com/Siuuuers/dwm/blob/77df47a73c5c2b69978cf2df74ecf8ac4e9294a9/tests/support/ScenePartnerForkFixture.gd).
That control has one Yes; passage across its authored boundary follows the default,
including normal Auto. The names option_a/b alone never create such a control.
The currently qualified partner example offers Yes at the complete caption
immediately before its expiry marker, not an arbitrary multi-caption interval.

Replace a paragraph behind a stable slot by editing its text while retaining the
required entry and caption identities. A stable target ID can also point to a
replacement DTL locator with its required entry/contract preserved. Recompile and
validate all affected registration hashes; callers keep the same target ID.
Unused/unreferenced slots may be omitted. To remove a used slot, update its callers
and order/bindings first, then remove its registration/content; a referenced missing
destination is an authoring error, never a silent skip.

## Insert, remove or reorder ordinary scenes

Use the existing [sequence helper guide](README.md), not filename sorting.
This supported example requires a complete valid source containing these entries:

```gdscript
const SEQUENCE = preload("res://tools/authoring/SceneSequenceAuthoring.gd")
var bindings = {
    "Day1": {"target_id": "target.Day1", "next_marker_id": "Day1.next"},
    "Day1.1": {"target_id": "target.Day1.1", "next_marker_id": "Day1.1.next"},
    "Day2": {"target_id": "target.Day2", "next_marker_id": ""}
}
var inserted = SEQUENCE.build(["Day1", "Day1.1", "Day2"], registered_source, bindings)
var removed = SEQUENCE.build(["Day1", "Day2"], registered_source, bindings)
var reordered = SEQUENCE.build(["Day1.1", "Day1", "Day2"], registered_source, bindings)
```

The helper changes only designated ordinary-next markers and returns
`value.registration` plus `value.first_target_id`. Explicit result branches
stay authored. The last binding has an empty ordinary-next marker so its existing
terminal policy is retained. Day1.1 is only an insertion example.

Bypassing an entry in the list does not delete it or redirect incoming explicit
branches. First build a valid source, including the inserted entry and matching
IDs/locators/contexts/captions/targets; the helper refuses stale input hashes before
relinking. It is not a repair tool for malformed registration.

## Replacement checklist and existing templates

1. Change TEST text at the caption lines. Preserve stable IDs when the same beat
   remains; add/change caption IDs and exact marker anchors together for structural edits.
2. When renaming, update entry ID/label, locator, context schema and its entry
   constant, ID/caption registries, programme row, marker references, target entry
   and any caller target IDs. Changing a represented Challenge ID also changes
   which saved fact later recall requests.
3. Rebuild with the existing compiler/builder, update content versions/caption
   revisions as required by the owners, and validate the full bundle. Never invent hashes.
4. Have A integrate/export and run affected Windows cloud Godot4.6.3 standard
   checks. Editing a registered programme changes save compatibility; stable pointer
   names do not promise arbitrary old-save migration or authorize overwriting saves.

Existing template inventory (one author guide; use the linked owners):

| Content | Builder / ordering owner | Current scope |
| --- | --- | --- |
| [Seven-day TEST story](../seven_day/README.md) | [SevenDayTemplates.gd](../seven_day/SevenDayTemplates.gd), [explicit order](seven_day_order.json) | Normal startup composition; bounded connected run141 |
| [Ordinary scene insertion/removal](README.md) | [SceneSequenceAuthoring.gd](../../../tools/authoring/SceneSequenceAuthoring.gd) | Detached authoring; Day1.1 is a generic example |
| Five-result Challenge and recall | [SceneChallengeRecallFixture.gd](../../support/SceneChallengeRecallFixture.gd) | Isolated example; outcome coverage remains bounded below |
| [Optional option_a/b holders](../../fixtures/dialogic/scene_author_option_slots.dtl) | [OptionSlotTemplates.gd](OptionSlotTemplates.gd) | Offline A→B registration; option_c is optional, no quota |
| [Partner TEST fork](../partner_fork/README.md) | [ScenePartnerForkFixture.gd](../../support/ScenePartnerForkFixture.gd) | Connected test fixture, outside normal seven-day startup |
| [Title-opening template](../scene_startup/README.md) | [Registration.gd](../scene_startup/Registration.gd) | Earlier isolated opening milestone |
| [Ending DTL section](../../fixtures/dialogic/Day7.dtl) | Seven-day builder plus existing terminal owner | Registered TEST ending; exported final acceptance pending |

The active week uses exactly `Day1.dtl` through `Day7.dtl` under
`tests/fixtures/dialogic/`; edit each day's file independently. The ending label
is in `Day7.dtl`. The older monolithic fixtures are historical, not active startup
content. Moving the content creates a new registration revision, not an old-save
migration; retain existing saves and use a fresh profile for the new layout.

The seven-day builder registers Day7.end→ending.alone.normal through the existing
terminal owner. A bare return is not a replacement for that contract.

## Evidence and remaining qualification

A's linked handoff reports physical-owner five-outcome dispatch, synthetic
five-outcome recall selection, and native Not-started recall after fresh Load.
It does not establish native fresh Load for every outcome. C owns the finite
coverage/example review. B inspected the actual DTL/builder and statically checked
this guide and the two-slot DTL; B ran no Godot/PowerShell and claims no new
runtime acceptance. A subsequently composed the complete two-slot builder and
qualified it through the existing compiler and full-registration validators:
[run162](https://github.com/Siuuuers/dwm/actions/runs/39088365076), two tests /
22 assertions / one clean process exit. The missing-referenced-target case is
rejected without mutating its input. See [integration evidence](../../../handoff/a-author-slots-20261018.md).
This is offline authoring validation; the example remains outside normal startup,
and it adds no rendered or Save/Load claim. Normal seven-day composition is also already installed and boundedly qualified:
[run141 handoff](../../../handoff/a-seven-day-connected-20261016.md), 25 tests /
623 assertions, including 3 rendered cases / 328 assertions. That historical
source-run result is separate from current official exported ending/Gallery/Title/
normal Load-exit qualification, which remains pending. Ordinary Save/transition
latency and relevant broader integration failures remain open under
[Director6264816510](https://github.com/Siuuuers/dwm/pull/30#issuecomment-6264816510).
No production story, placement, awareness thresholds or ending catalogue is
selected here. This documentation reconciliation adds no engine execution or
new acceptance; PR36 stays draft/unmerged.
