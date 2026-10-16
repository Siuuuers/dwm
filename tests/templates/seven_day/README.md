# Seven-day TEST story registration

`SevenDayTemplates.prepare()` compiles B's replaceable two-caption day templates
in `tests/fixtures/dialogic/scene_seven_day_linear.dtl`. The explicit order and
bindings come from `tests/templates/scene_sequence/seven_day_order.json`.
`SceneSequenceAuthoring` owns ordinary-next relinking; registry sorting does not
choose story order. The historical single-caption fixture remains untouched.

The schema-3 registration has Day1 through Day7 and `ending.alone.normal`.
Day7's `Day7.end` marker follows `line.Day7.two` and selects the registered ending
target. Its role, presentation signature and frozen context come from the
existing neutral ending definition; its one TEST caption lives in
`scene_seven_day_ending.dtl`. Empty Contacts definitions and explicit null audio
bindings introduce no mandatory challenge or media. No production story is claimed.

Replace DTL text while retaining stable IDs and labels, then rebuild through the
native compiler. Add caption IDs and marker anchors together when adding beats.
Do not hand-edit generated hashes.

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
