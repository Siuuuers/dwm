# Seven-day TEST story registration

`SevenDayTemplates.prepare()` compiles B's replaceable two-caption day templates
in seven files: `tests/fixtures/dialogic/Day1.dtl` through `Day7.dtl`. The explicit order and
bindings come from `tests/templates/scene_sequence/seven_day_order.json`.
`SceneSequenceAuthoring` owns ordinary-next relinking; registry sorting does not
choose story order. The historical single-caption fixture remains untouched.

The schema-3 registration has Day1 through Day7 and `ending.alone.normal`.
Day7's `Day7.end` marker follows `line.Day7.two` and selects the registered ending
target. Its role, presentation signature and frozen context come from the
existing neutral ending definition; its one TEST caption lives in
`Day7.dtl`, after the Day7 section. There are eight registered entries in exactly
seven active DTL files; the ending keeps its own role and completion behavior. Empty Contacts definitions and explicit null audio
bindings introduce no mandatory challenge or media. No production story is claimed.

Replace DTL text while retaining stable IDs and labels, then rebuild through the
native compiler. Add caption IDs and marker anchors together when adding beats.
Do not hand-edit generated hashes.

This split is a new registration revision. All entries retain the existing narrative
content version 1 required by the Run9 save contract. Locators and whole-file hashes change.
Old monolithic fixtures remain as historical fixtures, but old saved runs are not
migrated by this change. Keep existing save files intact; incompatible registration
must be refused through the existing checks, never silently loaded or overwritten.
Use a fresh isolated profile when qualifying this revision.

On the cloud Godot runner, run `tools/authoring/ExportSevenDayRegistration.gd`
before focused tests/export. During the first export use the existing debug
scene fixture override so startup has its registration before the new file exists.
The exporter writes:

- `data/manifests/scene_story_registration.json`
- `data/manifests/scene_ending_reading_catalogue.json`

Normal startup loads the first file once and exposes the configured
`DialogicEntryManifest.first_target_id()`. The explicit engineering fixture keeps
its existing debug-only selection. Runtime terminal admission, persistence and
ending playback remain the owning runtime components' responsibility; registration
acceptance alone is not proof of a connected Title → week → ending → Title journey.

Cloud GUT target: `tests/unit/test_seven_day_templates.gd` checks native
compiler/manifest/contract admission, fourteen day captions, six ordinary links,
the terminal target, strict ending context/role, and detached preparation.

## Connected evidence and authoring entry point

Normal startup composition is implemented. The
[run141 handoff](../../../handoff/a-seven-day-connected-20261016.md) records
25 tests / 623 assertions, including 3 rendered cases / 328 assertions:
Title → fourteen Day1–Day7 captions → registered ending → Gallery completion →
Title → fresh Day1, with separate Day4 and ending Save/Load processes.
This historical source-run milestone does not qualify current official exported
completion/normal Load exit, broad CI, ordinary latency or the whole game.

Use the [single author guide and existing template inventory](../scene_sequence/AUTHOR_GUIDE.md)
for five-result mappings, recall, optional option_a/b/c holders and explicit
scene ordering. The [seven-day handoff](../scene_sequence/SEVEN_DAY_HANDOFF.md)
records the concrete day/marker map. This documentation update adds no tests or
runtime behavior; final build acceptance remains pending.

Artwork and music replacement paths: [five-picture guide](../../../art/pictures/README.md). Title and story music use separate OGG files. Regenerate registration after replacing story music so its hash and duration match.
