extends GutTest
## Current Run9 documents use the existing semantic scene fixture.
const SCHEMA_PATH := "res://scripts/infrastructure/save/SaveDocumentSchema.gd"
const SCHEMA := preload("res://scripts/infrastructure/save/SaveDocumentSchema.gd")
const FIXTURE := preload("res://tests/support/SceneRunSaveFixture.gd")
const WRITER := preload("res://scripts/validation/CanonicalJsonWriter.gd")
var scope := preload("res://tests/support/SceneValidationScope.gd").new()
var fixture: RefCounted

func before_all() -> void:
	scope.install(true)
	fixture = FIXTURE.new()
	var setup: Dictionary = fixture.setup(get_tree())
	assert_true(setup.ok, str(setup))

func after_all() -> void:
	fixture.close()
	scope.restore()

func _schema_exists() -> bool:
	return ResourceLoader.exists(SCHEMA_PATH, "Script")

func _bundle(sequence: int = 2) -> Dictionary:
	var snapshot: Dictionary = fixture.snapshot.duplicate(true)
	snapshot.checkpoint_sequence = sequence
	snapshot.checkpoint_id = "%s:%d" % [snapshot.run_id, sequence]
	return {"checkpoint_kind": "safe_marker", "snapshot": snapshot}

func test_current_discriminators_round_trip_with_matching_scene_versions() -> void:
	for row: Array in [[&"slot", 1, &"manual"], [&"quick", null, &"quick"],
			[&"autosave", null, &"automatic"], [&"autosave", null, &"day_start"],
			[&"autosave", null, &"ending"], [&"autosave", null, &"pre_board"],
			[&"autosave", null, &"logout"]]:
		var built: Dictionary = SCHEMA.build(row[0], row[1], row[2], _bundle(), [])
		assert_true(built.ok, str(built))
		if not built.ok: return
		assert_eq(built.value.schema_version, 9)
		assert_eq(built.value.current_snapshot.snapshot.schema_version, 9)
		assert_eq(built.value.slot_id, row[1])
		assert_true(SCHEMA.validate(StrictJson.parse_object(JSON.stringify(built.value)).value).ok)

func test_build_normalizes_engine_text_and_detaches_current_bundle() -> void:
	var current := _bundle()
	current.snapshot.desktop.board.phase = &"NONE"
	var built: Dictionary = SCHEMA.build(&"quick", null, &"quick", current, [])
	assert_true(built.ok, str(built))
	if not built.ok: return
	assert_eq(typeof(built.value.current_snapshot.snapshot.schema_version), TYPE_INT)
	assert_eq(typeof(built.value.current_snapshot.snapshot.desktop.board.phase), TYPE_STRING)
	assert_eq(typeof(current.snapshot.desktop.board.phase), TYPE_STRING_NAME)
	current.snapshot.gameplay.story_flags["TEST.after_build"] = true
	assert_false(built.value.current_snapshot.snapshot.gameplay.story_flags.has("TEST.after_build"))

func test_proven_scene_journal_matches_full_builder_and_remains_detached() -> void:
	var first := _bundle(2)
	var current := _bundle(3)
	var proof: Dictionary = SCHEMA.build(&"autosave", null, &"automatic", first, []).value.current_snapshot
	var journal: Array = [first]
	var proofs: Array = [proof]
	var full: Dictionary = SCHEMA.build(&"autosave", null, &"automatic", current, journal)
	var proven: Dictionary = SCHEMA.build(&"autosave", null, &"automatic", current, journal, {}, proofs)
	assert_true(full.ok, str(full))
	assert_true(proven.ok, str(proven))
	if not full.ok or not proven.ok: return
	assert_eq(WRITER.stringify(proven.value).value, WRITER.stringify(full.value).value)
	assert_true(SCHEMA.validate(proven.value).ok)
	assert_true(SCHEMA.validate_outgoing(proven.value, proofs).ok)
	proof.snapshot.gameplay.story_flags["TEST.after_proof"] = true
	assert_false(proven.value.recovery_journal[0].snapshot.gameplay.story_flags.has("TEST.after_proof"))
	proven.value.recovery_journal[0].snapshot.gameplay.story_flags["TEST.after_document"] = true
	assert_false(proof.snapshot.gameplay.story_flags.has("TEST.after_document"))
func test_normalize_engine_text_returns_stringname_free_subtrees_by_identity() -> void:
	# A3: _normalize_engine_text rebuilds the whole current bundle AND the whole recovery journal on
	# every build, even though a StringName is rare and the rebuild is the identity in that case.
	# Making it identity-preserving is observable exactly where it pays: an unchanged subtree comes
	# back as the same container, and a tree that does contain a StringName rebuilds only the path
	# to it while its untouched siblings are returned by identity.
	assert_true(_schema_exists(), "SaveDocumentSchema must exist")
	if not _schema_exists():
		return
	var schema: Script = load(SCHEMA_PATH)

	var clean := {"outer": {"inner": [1, "two", 3.5, null, true]}, "empty": []}
	var clean_result: Variant = schema._normalize_engine_text(clean)
	assert_true(is_same(clean_result, clean), "a StringName-free tree is returned by identity")
	assert_true(is_same(clean_result["outer"], clean["outer"]), "...and so is every nested Dictionary")
	assert_true(is_same(clean_result["outer"]["inner"], clean["outer"]["inner"]),
		"...and every nested Array, at depth")

	var mixed := {"dirty": {"phase": &"NONE"}, "clean": {"kept": [1, 2]}}
	var mixed_result: Variant = schema._normalize_engine_text(mixed)
	assert_false(is_same(mixed_result, mixed), "a tree that contains a StringName is rebuilt")
	assert_false(is_same(mixed_result["dirty"], mixed["dirty"]), "the path to the StringName is rebuilt")
	assert_true(is_same(mixed_result["clean"], mixed["clean"]),
		"an untouched sibling container is returned by identity")
	assert_eq(typeof(mixed_result["dirty"]["phase"]), TYPE_STRING, "the StringName became a String")
	assert_eq(str(mixed_result["dirty"]["phase"]), "NONE", "with its text preserved")
	assert_eq(typeof(mixed["dirty"]["phase"]), TYPE_STRING_NAME, "the source is never mutated")

	# Conversion itself is unchanged: StringName keys, Array elements and bare values all convert.
	var keyed := {&"key": [&"element", {&"deep": &"value"}]}
	var keyed_result: Variant = schema._normalize_engine_text(keyed)
	var keyed_keys: Array = (keyed_result as Dictionary).keys()
	assert_eq(keyed_keys.size(), 1, "the key set is preserved")
	assert_eq(typeof(keyed_keys[0]), TYPE_STRING, "a StringName key becomes a String key")
	assert_eq(str(keyed_keys[0]), "key", "with its text preserved")
	assert_eq(typeof(keyed_result["key"][0]), TYPE_STRING, "an Array element converts")
	assert_eq(str(keyed_result["key"][0]), "element", "with its text preserved")
	assert_eq(typeof(keyed_result["key"][1]["deep"]), TYPE_STRING, "a nested value converts")
	var bare: Variant = schema._normalize_engine_text(&"bare")
	assert_eq(typeof(bare), TYPE_STRING, "a bare StringName converts")
	assert_eq(str(bare), "bare", "with its text preserved")
	var number: Variant = schema._normalize_engine_text(2.5)
	assert_eq(typeof(number), TYPE_FLOAT, "non-text leaves are untouched")
	assert_eq(number, 2.5, "and keep their value")
