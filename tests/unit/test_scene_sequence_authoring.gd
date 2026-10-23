extends "res://addons/gut/test.gd"
const HELPER := preload("res://tools/authoring/SceneSequenceAuthoring.gd")
const MANIFEST := preload("res://scripts/narrative/DialogicEntryManifest.gd")
const ADAPTER := preload("res://scripts/narrative/DialogicRuntimeAdapter.gd")
const CONTRACT := preload("res://scripts/domain/narrative/SceneEventContract.gd")
const PATH := "res://tests/fixtures/dialogic/scene_sequence_authoring.dtl"
const IDS := ["Day1", "Day1.1", "Day2"]

func _bindings() -> Dictionary:
	return {"Day1": {"target_id": "target.Day1", "next_marker_id": "Day1.next"},
		"Day1.1": {"target_id": "target.Day1.1", "next_marker_id": "Day1.1.next"},
		"Day2": {"target_id": "target.Day2", "next_marker_id": ""}}

func _marker(id: String, suffix: String, line: String, target: String) -> Dictionary:
	return {"marker_id": id + suffix, "label": id + suffix,
		"after_line_id": "line." + id + line, "kind": "scene.transition",
		"payload": {"target_id": target}}

func _source() -> Dictionary:
	var bundle := {"kind": "scene_reading_registration", "schema_version": 1,
		"entry_manifest": {"kind": "dialogic_entries", "schema_version": 2,
			"default_locale": "en", "locales": ["en"], "entry_count": 3, "entries": []},
		"context_registry": {"kind": "dialogic_frozen_context_registry", "schema_version": 1, "schemas": []},
		"ids_registry": {"kind": "scene_ids_registry", "schema_version": 1, "lines": [],
			"signals": [{"signal_id": "history.line.witness",
				"payload_fields": ["entry_id", "line_id", "playback_token", "receipt_id"]},
				{"signal_id": "scene.transition", "payload_fields": ["target_id"]}]},
		"caption_registry": {"kind": "scene_caption_registry", "schema_version": 1, "entries": []},
		"scene_programme": {"kind": "scene_programme", "schema_version": 1, "entries": []},
		"targets": [], "board_profiles": [], "challenges": [], "contacts": []}
	var texts := {"Day1": ["TEST Day1.", "TEST Day1 ordinary exit."],
		"Day1.1": ["TEST intermediate."], "Day2": ["TEST Day2 final placeholder."]}
	for id: String in IDS:
		var markers: Array = []
		if id == "Day1":
			markers = [_marker(id, ".branch", ".one", "target.Day2"),
				_marker(id, ".next", ".two", "target.Day1.1")]
		elif id == "Day1.1":
			markers = [_marker(id, ".next", ".one", "target.Day2")]
		var compiled: Dictionary = ADAPTER.compile_scene_programme(PATH, id, IDS, markers)
		assert_true(compiled.get("ok", false), "fixture compile: " + str(compiled))
		if not compiled.get("ok", false): return {}
		var grants := ["history.line.witness"]
		if not markers.is_empty(): grants.append("scene.transition")
		bundle.entry_manifest.entries.append({"entry_id": id, "role": "scene",
			"allowed_signals": grants, "atom_namespace": "atom." + id,
			"line_namespace": "line." + id, "content_version": 1,
			"context_schema_id": "context.scene." + id + ".v1",
			"locators": {"en": {"path": PATH, "label": id}},
			"visual_ids": {"required": [], "optional": []},
			"presentation_signature_schema": {"schema_version": 1, "fields": {}}})
		bundle.context_registry.schemas.append({"entry_id": id,
			"schema_id": "context.scene." + id + ".v1", "schema_version": 1,
			"fields": {"entry_id": {"const": id}, "entry_role": {"const": "scene"},
				"occurrence_id": "id", "admission_receipt_id": "id"}})
		var lines: Array = []
		for index in range(texts[id].size()):
			var suffix: String = [".one", ".two"][index]
			lines.append({"beat_id": "beat." + id + suffix, "line_id": "line." + id + suffix,
				"text": texts[id][index], "revision": "1"})
			bundle.ids_registry.lines.append({"line_id": "line." + id + suffix, "owning_entry_id": id})
		bundle.caption_registry.entries.append({"entry_id": id, "lines": lines})
		bundle.scene_programme.entries.append({"entry_id": id, "content_version": 1,
			"content_sha256": compiled.value.content_sha256,
			"program_sha256": compiled.value.program_sha256, "markers": markers})
		bundle.targets.append({"target_id": "target." + id, "target": {"kind": "scene",
			"entry_id": id, "label": id, "content_version": 1,
			"program_sha256": compiled.value.program_sha256}})
	# Registry storage ordering is canonical; it never determines narrative order.
	bundle.ids_registry.lines.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.line_id < b.line_id)
	var valid: Dictionary = MANIFEST.validate_scene_registration(bundle)
	assert_true(valid.get("ok", false), "source registration: " + str(valid))
	return bundle

func _assert_valid(result: Dictionary) -> void:
	assert_true(result.get("ok", false), str(result))
	if not result.get("ok", false): return
	assert_true(MANIFEST.validate_scene_registration(result.value.registration).get("ok", false))
	assert_true(CONTRACT.validate_bundle_structure(result.value.registration).get("ok", false))

func test_three_scene_order_and_two_scene_removal_use_real_registration() -> void:
	var source := _source()
	var before := source.duplicate(true)
	var bindings := _bindings()
	var three: Dictionary = HELPER.build(["Day1", "Day1.1", "Day2"], source, bindings)
	var two: Dictionary = HELPER.build(["Day1", "Day2"], source, bindings)
	_assert_valid(three)
	_assert_valid(two)
	if not three.get("ok", false) or not two.get("ok", false): return
	assert_eq(three.value.first_target_id, "target.Day1")
	assert_eq(two.value.first_target_id, "target.Day1")
	assert_eq(three.value.registration.scene_programme.entries[0].markers[1].payload,
		{"target_id": "target.Day1.1"})
	assert_eq(two.value.registration.scene_programme.entries[0].markers[1].payload,
		{"target_id": "target.Day2"})
	assert_eq(two.value.registration.scene_programme.entries[0].markers[0],
		source.scene_programme.entries[0].markers[0], "explicit branch untouched")
	assert_eq(two.value.registration.scene_programme.entries[2],
		source.scene_programme.entries[2], "final scene unchanged")
	assert_eq(source, before, "input registration immutable")
	assert_eq(bindings, _bindings())
	two.value.registration.caption_registry.entries[0].lines[0].text = "detached"
	assert_eq(source, before, "nested output does not alias input")

func test_explicit_order_is_not_sorted_or_incremented() -> void:
	var result: Dictionary = HELPER.build(["Day1.1", "Day1", "Day2"], _source(), _bindings())
	_assert_valid(result)
	if not result.get("ok", false): return
	assert_eq(result.value.first_target_id, "target.Day1.1")
	assert_eq(result.value.registration.scene_programme.entries[1].markers[0].payload,
		{"target_id": "target.Day1"})

func test_invalid_sequences_and_bindings_refuse_without_partial_output() -> void:
	var source := _source()
	var before := source.duplicate(true)
	for order: Array in [[], ["Day1", "Day1"], ["Missing"], [1]]:
		var result: Dictionary = HELPER.build(order, source, _bindings())
		assert_false(result.ok)
		assert_false(result.has("value"))
	assert_eq(HELPER.build(["Day1"], source, _bindings()).code, "sequence_terminal_required")
	var bindings := _bindings()
	bindings.Day1.next_marker_id = "missing.marker"
	assert_eq(HELPER.build(["Day1", "Day2"], source, bindings).code, "sequence_marker_missing")
	bindings = _bindings()
	bindings.Day1.target_id = "target.Day2"
	assert_eq(HELPER.build(["Day1", "Day2"], source, bindings).code, "sequence_target_invalid")
	assert_eq(source, before)

func test_missing_referenced_content_is_clear_and_not_repaired() -> void:
	var source := _source()
	source.entry_manifest.entries[0].locators.en.path = "res://tests/fixtures/dialogic/missing_sequence_content.dtl"
	var before := source.duplicate(true)
	var result: Dictionary = HELPER.build(["Day1", "Day2"], source, _bindings())
	assert_false(result.ok)
	assert_eq(result.code, "sequence_source_invalid")
	assert_true(result.message.contains("Referenced content"))
	assert_false(result.has("value"))
	assert_eq(source, before)

func test_source_hash_tampering_is_not_authenticated_by_recompilation() -> void:
	var source := _source()
	source.scene_programme.entries[0].program_sha256 = "0".repeat(64)
	var result: Dictionary = HELPER.build(["Day1", "Day2"], source, _bindings())
	assert_false(result.ok)
	assert_eq(result.code, "sequence_source_invalid")

func test_single_scene_retains_terminal_policy() -> void:
	var source := _source()
	var result: Dictionary = HELPER.build(["Day2"], source, _bindings())
	_assert_valid(result)
	if not result.get("ok", false): return
	assert_eq(result.value.first_target_id, "target.Day2")
	assert_eq(result.value.registration, source)
