extends "res://addons/gut/test.gd"

const ADMISSION := preload("res://scripts/infrastructure/save/SaveMigrations.gd")
const DOCUMENT := preload("res://scripts/infrastructure/save/SaveDocumentSchema.gd")
const FIXTURES := "res://tests/fixtures/saves/"

func _fixture(name: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(FIXTURES + name))

# These are authored v6 test documents, not upgrades of player records.
func _document(kind: StringName = &"slot", slot_id: Variant = 1, dark_mode: bool = false) -> Dictionary:
	var snapshot := _fixture("v5_desktop_none.json")
	snapshot["schema_version"] = 6
	snapshot["lifecycle"]["dark_mode"] = dark_mode
	snapshot["lifecycle"]["active_condition_hospital_plan"] = null
	snapshot["lifecycle"]["condition_hospital_history"] = {}
	snapshot["lifecycle"]["terminal_intent_handoff"] = null
	snapshot["gameplay"].erase("opening_seen")
	snapshot["gameplay"].erase("tutorial_seen")
	snapshot["schedule_view"] = {
		"day": snapshot["lifecycle"]["day"],
		"causal_day_instance": snapshot["lifecycle"]["causal_day_instance"],
		"entries": [], "date_entry_seen": false, "pending_warning": null,
		"consumed_warning_receipts": {}, "condition_departure_receipts": {},
	}
	var reason: StringName = &"manual" if kind == &"slot" else (&"quick" if kind == &"quick" else &"day_start")
	var built: Dictionary = DOCUMENT.build(kind, slot_id, reason,
		{"checkpoint_kind": "day_start", "snapshot": snapshot}, [])
	assert_true(built.get("ok", false), str(built))
	return built.value if built.get("ok", false) else {}

func _assert_refused_unchanged(raw: Dictionary, locator: Dictionary, code: StringName = &"") -> void:
	var before := raw.duplicate(true)
	var locator_before := locator.duplicate(true)
	var result: Dictionary = ADMISSION.migrate_document(raw, locator)
	assert_false(result.get("ok", true), str(result))
	if not code.is_empty(): assert_eq(result.get("code"), code)
	assert_false(result.has("value"), "A refused record yields no repaired document or Profile patch")
	assert_eq(raw, before, "Admission never changes source data")
	assert_eq(locator, locator_before, "Admission never changes the supplied locator")

func test_current_documents_are_admitted_for_their_exact_locator_and_dark_value() -> void:
	for dark: bool in [false, true]:
		for locator: Dictionary in [{"kind": "slot", "slot_id": 1}, {"kind": "slot", "slot_id": 7},
				{"kind": "quick", "slot_id": null}, {"kind": "autosave", "slot_id": null}]:
			var raw := _document(StringName(locator.kind), locator.slot_id, dark)
			var before := raw.duplicate(true)
			var admitted: Dictionary = ADMISSION.migrate_document(raw, locator)
			assert_true(admitted.get("ok", false), str(admitted))
			if not admitted.get("ok", false): continue
			assert_eq(admitted.value.document, raw)
			assert_eq(admitted.value.document.current_snapshot.snapshot.lifecycle.dark_mode, dark)
			assert_eq(admitted.value.legacy_profile_patch_input, {})
			assert_eq(admitted.value.migration_receipts, [])
			assert_eq(raw, before)

func test_current_result_is_detached_from_source_and_preserves_checkpoint_history() -> void:
	var raw := _document()
	var earlier: Dictionary = raw.current_snapshot.duplicate(true)
	raw.recovery_journal = [earlier]
	var before := raw.duplicate(true)
	var admitted: Dictionary = ADMISSION.migrate_document(raw, {"kind": "slot", "slot_id": 1})
	assert_true(admitted.get("ok", false), str(admitted))
	if not admitted.get("ok", false): return
	assert_eq(admitted.value.document.recovery_journal, before.recovery_journal)
	admitted.value.document.current_snapshot.snapshot.lifecycle.dark_mode = true
	admitted.value.document.recovery_journal[0].snapshot.lifecycle.day = 6
	assert_eq(raw, before, "Changing the detached result cannot change either source bundle")

func test_saved_time_is_retained_exactly_and_absence_is_not_synthesized() -> void:
	var raw := _document(&"autosave", null)
	var absent: Dictionary = ADMISSION.migrate_document(raw, {"kind": "autosave", "slot_id": null})
	assert_true(absent.ok)
	assert_false(absent.value.document.has("saved_time"))
	var saved_time := {"unix_seconds": 0, "utc_offset_minutes": 480, "hhmm": "08:00"}
	raw["saved_time"] = saved_time.duplicate(true)
	var admitted: Dictionary = ADMISSION.migrate_document(raw, {"kind": "autosave", "slot_id": null})
	assert_true(admitted.get("ok", false), str(admitted))
	if admitted.get("ok", false): assert_eq(admitted.value.document.saved_time, saved_time)
	var invalid := raw.duplicate(true)
	invalid["saved_time"]["hhmm"] = "09:00"
	_assert_refused_unchanged(invalid, {"kind": "autosave", "slot_id": null}, &"invalid_saved_time")

func test_v0_through_v4_are_unsupported_without_creating_captured_dark() -> void:
	for version: int in range(5):
		var raw := _document()
		raw.schema_version = version
		raw.current_snapshot.snapshot.schema_version = version
		raw.current_snapshot.snapshot.lifecycle.erase("dark_mode")
		_assert_refused_unchanged(raw, {"kind": "slot", "slot_id": 1}, &"unsupported_run_configuration_schema")
		assert_false(raw.current_snapshot.snapshot.lifecycle.has("dark_mode"))
	# The retained v4 fixture itself stays untouched; the outer document is only
	# a test wrapper, and no current schema builder is used to repair its content.
	var old_snapshot := _fixture("v4_desktop_none.json")
	var historical := {"schema_version": 4, "kind": "slot", "slot_id": 1, "save_reason": "manual",
		"current_snapshot": {"checkpoint_kind": "day_start", "snapshot": old_snapshot}, "recovery_journal": []}
	_assert_refused_unchanged(historical, {"kind": "slot", "slot_id": 1}, &"unsupported_run_configuration_schema")

func test_both_incompatible_v5_variants_are_refused_without_repair() -> void:
	var ui_v5 := _document()
	ui_v5.schema_version = 5
	ui_v5.current_snapshot.snapshot.schema_version = 5
	ui_v5.current_snapshot.snapshot.erase("schedule_view")
	ui_v5.current_snapshot.snapshot.lifecycle.erase("active_condition_hospital_plan")
	ui_v5.current_snapshot.snapshot.lifecycle.erase("condition_hospital_history")
	ui_v5.current_snapshot.snapshot.lifecycle.erase("terminal_intent_handoff")
	_assert_refused_unchanged(ui_v5, {"kind": "slot", "slot_id": 1},
		&"unsupported_run_configuration_schema")

	var gameplay_v5 := _document()
	gameplay_v5.schema_version = 5
	gameplay_v5.current_snapshot.snapshot.schema_version = 5
	gameplay_v5.current_snapshot.snapshot.lifecycle.erase("dark_mode")
	gameplay_v5["current_snapshot"]["snapshot"]["gameplay"]["opening_seen"] = false
	gameplay_v5["current_snapshot"]["snapshot"]["gameplay"]["tutorial_seen"] = false
	_assert_refused_unchanged(gameplay_v5, {"kind": "slot", "slot_id": 1},
		&"unsupported_run_configuration_schema")

func test_future_fractional_missing_and_wrong_type_versions_are_refused() -> void:
	var future := _document()
	future.schema_version = 7
	_assert_refused_unchanged(future, {"kind": "slot", "slot_id": 1}, &"unsupported_future_schema")
	for version: Variant in [6.5, "6", null, true, {}, [], INF]:
		var raw := _document()
		raw.schema_version = version
		_assert_refused_unchanged(raw, {"kind": "slot", "slot_id": 1}, &"invalid_schema_version")
	var missing := _document()
	missing.erase("schema_version")
	_assert_refused_unchanged(missing, {"kind": "slot", "slot_id": 1}, &"invalid_schema_version")

func test_json_integral_numbers_are_accepted_without_coercing_dark() -> void:
	var raw := _document(&"slot", 1, true)
	var decoded: Dictionary = JSON.parse_string(JSON.stringify(raw))
	var admitted: Dictionary = ADMISSION.migrate_document(decoded, {"kind": "slot", "slot_id": 1})
	assert_true(admitted.get("ok", false), str(admitted))
	if not admitted.get("ok", false): return
	assert_eq(admitted.value.document, raw)
	assert_eq(typeof(admitted.value.document.current_snapshot.snapshot.lifecycle.dark_mode), TYPE_BOOL)
	for invalid: Variant in [null, 0, 1, "true"]:
		var bad := raw.duplicate(true)
		bad.current_snapshot.snapshot.lifecycle.dark_mode = invalid
		_assert_refused_unchanged(bad, {"kind": "slot", "slot_id": 1})

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

func test_current_document_does_not_repair_missing_dark_or_old_embedded_snapshot() -> void:
	var missing := _document()
	missing.current_snapshot.snapshot.lifecycle.erase("dark_mode")
	_assert_refused_unchanged(missing, {"kind": "slot", "slot_id": 1})
	var old := _document()
	old.current_snapshot.snapshot.schema_version = 4
	_assert_refused_unchanged(old, {"kind": "slot", "slot_id": 1})
	var malformed := _document()
	malformed.current_snapshot.snapshot.lifecycle.day = 8
	_assert_refused_unchanged(malformed, {"kind": "slot", "slot_id": 1})
	var bad_reason := _document()
	bad_reason.save_reason = "quick"
	_assert_refused_unchanged(bad_reason, {"kind": "slot", "slot_id": 1})
