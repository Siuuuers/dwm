extends "res://addons/gut/test.gd"

const DOCUMENT := preload("res://scripts/infrastructure/save/SaveDocumentSchema.gd")
const FIXTURE := preload("res://tests/support/SceneRunSaveFixture.gd")
var fixture := FIXTURE.new()
var scope := preload("res://tests/support/SceneValidationScope.gd").new()

func before_all() -> void:
	scope.install(true)
	assert_true(fixture.setup(get_tree()).ok)

func after_all() -> void:
	fixture.close()
	scope.restore()

func _document(kind: StringName = &"slot", slot_id: Variant = 1) -> Dictionary:
	var reason: StringName = &"manual" if kind == &"slot" else (&"quick" if kind == &"quick" else &"day_start")
	var built := DOCUMENT.build(kind, slot_id, reason,
		{"checkpoint_kind": "day_start", "snapshot": fixture.snapshot}, [])
	assert_true(built.ok, str(built))
	return built.value

func _assert_refused_unchanged(raw: Dictionary, locator: Dictionary, code: StringName = &"") -> void:
	var before := raw.duplicate(true)
	var locator_before := locator.duplicate(true)
	var result: Dictionary = DOCUMENT.admit_document(raw, locator)
	assert_false(result.get("ok", true), str(result))
	if not code.is_empty(): assert_eq(result.get("code"), code)
	assert_false(result.has("value"), "A refused record yields no repaired document or Profile patch")
	assert_eq(raw, before, "Admission never changes source data")
	assert_eq(locator, locator_before, "Admission never changes the supplied locator")

func test_current_documents_are_admitted_for_their_exact_locator() -> void:
	for locator: Dictionary in [{"kind": "slot", "slot_id": 1}, {"kind": "slot", "slot_id": 7},
			{"kind": "quick", "slot_id": null}, {"kind": "autosave", "slot_id": null}]:
		var raw := _document(StringName(locator.kind), locator.slot_id)
		var before := raw.duplicate(true)
		var admitted := DOCUMENT.admit_document(raw, locator)
		assert_true(admitted.ok, str(admitted))
		if not admitted.ok: continue
		assert_eq(admitted.value, raw)
		admitted.value.current_snapshot.snapshot.gameplay.coins += 1
		assert_eq(raw, before)

func test_previous_formats_and_future_versions_are_refused_unchanged() -> void:
	for version in range(DOCUMENT.SCENE_DOCUMENT_VERSION):
		_assert_refused_unchanged({"schema_version": version}, {"kind": "slot", "slot_id": 1},
			&"unsupported_run_configuration_schema")
	_assert_refused_unchanged({"schema_version": DOCUMENT.SCENE_DOCUMENT_VERSION + 1},
		{"kind": "slot", "slot_id": 1}, &"unsupported_future_schema")

func test_expected_locator_shape_is_strict_and_does_not_relabel_a_document() -> void:
	var raw := _document()
	for locator: Dictionary in [{}, {"kind": "slot"}, {"kind": "slot", "slot_id": 0},
			{"kind": "slot", "slot_id": 8}, {"kind": "slot", "slot_id": "1"},
			{"kind": "slot", "slot_id": null}, {"kind": "quick", "slot_id": 1},
			{"kind": "autosave", "slot_id": 0}, {"kind": "other", "slot_id": null},
			{"kind": "slot", "slot_id": 1, "extra": true}]:
		_assert_refused_unchanged(raw, locator, &"invalid_expected_locator")
	for locator: Dictionary in [{"kind": "slot", "slot_id": 2}, {"kind": "quick", "slot_id": null},
			{"kind": "autosave", "slot_id": null}]:
		_assert_refused_unchanged(raw, locator, &"save_locator_mismatch")

func test_current_legacy_members_are_rejected_instead_of_stripped() -> void:
	for member: String in ["settings", "audio_state", "seen_endings", "visited_lines", "input_mappings"]:
		var raw := _document()
		raw.current_snapshot.snapshot[member] = {}
		_assert_refused_unchanged(raw, {"kind": "slot", "slot_id": 1})
		assert_true(raw.current_snapshot.snapshot.has(member))
	for member: String in ["opening_seen", "tutorial_seen"]:
		var raw := _document()
		raw.current_snapshot.snapshot.gameplay[member] = false
		_assert_refused_unchanged(raw, {"kind": "slot", "slot_id": 1})
	var outer := _document()
	outer["preferences"] = {}
	_assert_refused_unchanged(outer, {"kind": "slot", "slot_id": 1})

func test_load_refuses_prior_fields_and_missing_outcome_without_touching_source() -> void:
	var raw := _document()
	var locator := {"kind": "slot", "slot_id": 1}
	var snapshot: Dictionary = raw.current_snapshot.snapshot
	for field: String in ["audio_context", "active_app_id"]:
		snapshot[field] = null
		_assert_refused_unchanged(raw, locator)
		assert_eq(DOCUMENT.load_current_document(raw).code, &"unsupported_save_format")
		snapshot.erase(field)
	snapshot.lifecycle["scene_assignment"] = {}
	_assert_refused_unchanged(raw, locator)
	assert_eq(DOCUMENT.load_current_document(raw).code, &"invalid_lifecycle")
	snapshot.lifecycle.erase("scene_assignment")
	var prior := {"challenge_id": "test.challenge", "outcome": "won"}
	snapshot.gameplay.scene_challenge_outcomes["a".repeat(64)] = prior
	_assert_refused_unchanged(raw, locator)
	assert_eq(DOCUMENT.load_current_document(raw).code, &"invalid_gameplay")
	assert_false(prior.has("physical_slot"))

func test_ordinary_load_refuses_unsupported_version_before_reading_runtime_state() -> void:
	# No registration, gameplay owners or snapshot body is needed to reject a
	# version that this build cannot interpret.
	for version: Variant in [8, DOCUMENT.SCENE_DOCUMENT_VERSION + 1, "9", 9.5, null]:
		var raw := {"schema_version": version}
		var before := raw.duplicate(true)
		var loaded: Dictionary = DOCUMENT.load_current_document(raw)
		assert_false(loaded.ok)
		assert_eq(loaded.code, &"unsupported_save_format")
		assert_false(loaded.has("value"))
		assert_eq(raw, before)
	assert_eq(DOCUMENT.load_current_document({}).code, &"unsupported_save_format")
