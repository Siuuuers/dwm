extends GutTest
const CATALOGUE := preload("res://scripts/narrative/DialogueLibraryCatalogue.gd")
const FIXTURE := preload("res://tests/support/DialogueLibraryFixture.gd")

func before_each() -> void:
	assert_true(FIXTURE.install().ok)

func after_each() -> void:
	assert_true(CATALOGUE.configure([], [], {}).ok)

func test_only_reached_checkpoint_and_exact_witness_are_projected() -> void:
	assert_eq(CATALOGUE.reached_passages({"checkpoints": [], "witnesses": {}}), [])
	var discovery := FIXTURE.discovery()
	var before := discovery.duplicate(true)
	var rows: Array = CATALOGUE.reached_passages(discovery)
	assert_eq(rows.size(), 1)
	if rows.size() != 1: return
	assert_eq(rows[0].id, FIXTURE.CHECKPOINT)
	assert_true(rows[0].entries[0].read)
	assert_eq(rows[0].entries[0].text, "TEST read caption.")
	for index: int in [1, 2, 3]:
		assert_false(rows[0].entries[index].read)
		assert_eq(rows[0].entries[index].text, "", "unread source never leaves catalogue projection")
	assert_eq(rows[0].entries[1].kind, "thought")
	assert_eq(discovery, before, "query never records reads or reaches")
	rows[0].entries[0].text = "caller edit"
	assert_eq(CATALOGUE.reached_passages(discovery)[0].entries[0].text, "TEST read caption.")

func test_requirements_keep_all_choices_and_alternatives_visible_when_unread() -> void:
	var rows: Array = CATALOGUE.reached_passages(FIXTURE.discovery())
	var requirements: String = rows[0].entries[2].requirements
	for wording: String in ["Choose to help", "Win the Challenge", "Finish without a mistake"]:
		assert_string_contains(requirements, wording)
	assert_string_contains(requirements.to_lower(), "and")
	assert_string_contains(requirements.to_lower(), "or")
	assert_string_contains(requirements, "(")
	assert_string_contains(requirements, ")")
	assert_eq(rows[0].entries[2].requirements, rows[0].entries[3].requirements)
	var localized: Array = CATALOGUE.reached_passages(FIXTURE.discovery(), "zh_HK")
	assert_eq(localized[0].title, "測試已讀段落")
	assert_string_contains(localized[0].entries[2].requirements, "選擇幫忙")

func test_discovery_requires_actual_checkpoint_and_exact_variant() -> void:
	assert_eq(CATALOGUE.discovery_for_beat(FIXTURE.beat(), ""), {})
	assert_eq(CATALOGUE.discovery_for_beat(FIXTURE.beat(), "TEST.absent"), {})
	var actual: Dictionary = CATALOGUE.discovery_for_beat(FIXTURE.beat(), FIXTURE.CHECKPOINT)
	assert_eq(actual.checkpoint_id, FIXTURE.CHECKPOINT)
	assert_eq(actual.witness_id, FIXTURE.key(FIXTURE.beat()))
	var other: Dictionary = CATALOGUE.discovery_for_beat(FIXTURE.beat("not-catalogued"), FIXTURE.CHECKPOINT)
	assert_eq(other.get("witness_id", ""), "")
	assert_true(CATALOGUE.configure([], [], {}).ok)
	assert_eq(CATALOGUE.reached_passages(FIXTURE.discovery()), [], "empty production catalogue never invents passages")

func test_authoring_reports_unregistered_exact_variant_without_replacing_catalogue() -> void:
	var passages := FIXTURE.passages()
	var admitted: Array = []
	for passage: Dictionary in passages:
		for entry: Dictionary in passage.entries: admitted.append(entry.beat.duplicate(true))
	# An ordinary edited descriptor must be re-registered before authors can bind it.
	passages[0].entries[0].beat.presentation_signature.revision = "TEST-r2"
	var before: Array = CATALOGUE.reached_passages(FIXTURE.discovery())
	var result: Dictionary = CATALOGUE.configure(passages, admitted,
		{FIXTURE.CHECKPOINT: {}, FIXTURE.UNREACHED: {}},
		{"choice": {"en": "Choose to help"}, "win": {"en": "Win the Challenge"}, "clean": {"en": "Finish without a mistake"}})
	assert_false(result.ok)
	assert_eq(result.code, &"library_beat_unregistered")
	assert_eq(CATALOGUE.reached_passages(FIXTURE.discovery()), before)
