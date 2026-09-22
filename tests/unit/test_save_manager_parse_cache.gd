extends "res://addons/gut/test.gd"

const SAVE := preload("res://autoload/SaveManager.gd")
const STORAGE := preload("res://scripts/infrastructure/storage/JsonFileStorage.gd")
const STRICT := preload("res://scripts/validation/StrictJson.gd")
const SCHEMA := preload("res://scripts/infrastructure/save/SaveDocumentSchema.gd")
const CANONICAL := preload("res://scripts/validation/CanonicalJsonWriter.gd")

var _previous_control := ""

class ReadFaultOps extends "res://tests/support/FakeFileOps.gd":
	var refuse_reads := false
	func read_bytes(path: String) -> Dictionary:
		if refuse_reads: return {"ok": false, "code": &"fixture_read_refused"}
		return super.read_bytes(path)

class Participant extends RefCounted:
	var plan_key := ""
	var unavailable := false
	var preparations := 0
	func _init(key: String) -> void: plan_key = key
	func prepare(_input: Dictionary) -> Dictionary:
		preparations += 1
		if unavailable: return {"ok": false, "code": &"NARRATIVE_CONTENT_UNAVAILABLE"}
		return {"ok": true, "value": {plan_key: {}, "locale_id": "en"}}
	func capture() -> Dictionary: return {"ok": true, "value": {}}
	func apply_silent(_plan: Dictionary) -> Dictionary: return {"ok": true}
	func rollback_silent(_backup: Dictionary) -> Dictionary: return {"ok": true}
	func finalize() -> Dictionary: return {"ok": true}

func before_each() -> void:
	_previous_control = OS.get_environment("DWM_SAVE_PARSE_CACHE_DISABLED")
	OS.set_environment("DWM_SAVE_PARSE_CACHE_DISABLED", "")

func after_each() -> void:
	OS.set_environment("DWM_SAVE_PARSE_CACHE_DISABLED", _previous_control)

func _manager() -> Node:
	return autofree(SAVE.new())

func _fixture() -> Dictionary:
	var snapshot := STRICT.parse_object(FileAccess.get_file_as_string(
		"res://tests/fixtures/saves/v7_desktop_prepared.json"))
	assert_true(snapshot.get("ok", false), str(snapshot))
	if not snapshot.get("ok", false): return {}
	var built := SCHEMA.build(&"slot", 1, &"manual",
		{"checkpoint_kind": "manual_save", "snapshot": snapshot.value}, [])
	assert_true(built.get("ok", false), str(built))
	if not built.get("ok", false): return {}
	var emitted := CANONICAL.stringify(built.value)
	assert_true(emitted.get("ok", false), str(emitted))
	if not emitted.get("ok", false): return {}
	var text: String = emitted.value + "\n"
	var ops := ReadFaultOps.new({"parse-cache/slot_1.json": text})
	var storage := STORAGE.new("parse-cache", ops)
	var manager := _manager()
	assert_true(manager.initialize(storage).get("ok", false))
	return {"manager": manager, "ops": ops, "storage": storage, "text": text}

func _replace(fixture: Dictionary, path: String, text: String) -> void:
	assert_true(fixture.ops.write_bytes(path, text.to_utf8_buffer()).get("ok", false))
	assert_true(fixture.ops.flush_path(path).get("ok", false))

func test_cold_and_warm_results_preserve_types_and_are_detached() -> void:
	var manager := _manager()
	var text := '{"integer":1,"decimal":1.0,"nested":{"items":["中文",null]}}'
	var expected := STRICT.parse_object(text)
	var first: Dictionary = manager._parse_document_text(text)
	assert_true(CANONICAL._deep_same(first, expected))
	first.value.nested.items[0] = "first caller edit"
	var second: Dictionary = manager._parse_document_text(text)
	assert_true(CANONICAL._deep_same(second, expected))
	assert_eq(typeof(second.value.integer), TYPE_INT)
	assert_eq(typeof(second.value.decimal), TYPE_FLOAT)
	second.value.nested.items.append("second caller edit")
	assert_true(CANONICAL._deep_same(manager._parse_document_text(text), expected))

func test_exact_text_changes_and_malformed_inputs_keep_strict_results() -> void:
	var manager := _manager()
	for text: String in ['{"value":1}', '{ "value":1}', '{"value":2}']:
		assert_true(CANONICAL._deep_same(manager._parse_document_text(text), STRICT.parse_object(text)))
	assert_eq(manager._document_parse_cache.size(), 2)
	for text: String in ['{"value":1,"value":2}', '{"value":', '[1,2]', '{"value":NaN}']:
		var expected := STRICT.parse_object(text)
		assert_false(expected.get("ok", true))
		assert_eq(manager._parse_document_text(text), expected)
		assert_eq(manager._parse_document_text(text), expected)
		for entry: Dictionary in manager._document_parse_cache:
			assert_ne(entry.text, text, "malformed input is never admitted")

func test_entry_eviction_utf8_budget_and_oversize_bypass() -> void:
	var manager := _manager()
	for text: String in ['{"value":1}', '{"value":2}', '{"value":1}', '{"value":3}']:
		assert_true(manager._parse_document_text(text).get("ok", false))
	assert_eq(manager._document_parse_cache.size(), 2)
	assert_eq(manager._document_parse_cache[0].text, '{"value":1}')
	assert_eq(manager._document_parse_cache[1].text, '{"value":3}')
	# Each source is just over half the UTF-8 budget but under half in characters.
	# Keep the large span ASCII so this bound test does not benchmark Unicode parsing.
	var padding := "x".repeat(4 * 1024 * 1024 - 32)
	var medium := '{"value":"' + padding + "中".repeat(8) + '"}'
	var large := '{"value":"' + padding + "文".repeat(8) + '"}'
	assert_true(manager._parse_document_text(medium).get("ok", false))
	assert_true(manager._parse_document_text(large).get("ok", false))
	assert_eq(manager._document_parse_cache.size(), 1, "UTF-8 bytes, not character count, bound admission")
	assert_eq(manager._document_parse_cache_text_bytes, large.to_utf8_buffer().size())
	var oversized := '{"value":"' + "x".repeat(SAVE._PARSE_CACHE_MAX_TEXT_BYTES) + '"}'
	var parsed: Dictionary = manager._parse_document_text(oversized)
	assert_true(parsed.get("ok", false), "budget does not introduce a parser refusal")
	assert_eq(parsed.value.value.length(), SAVE._PARSE_CACHE_MAX_TEXT_BYTES)
	assert_eq(manager._document_parse_cache.size(), 1)
	assert_eq(manager._document_parse_cache[0].text, large)

func test_initialize_resets_cache_and_disabled_control_preserves_results() -> void:
	var manager := _manager()
	var text := '{"value":[1,2,3]}'
	assert_true(manager._parse_document_text(text).get("ok", false))
	assert_eq(manager._document_parse_cache.size(), 1)
	assert_true(manager.initialize(STORAGE.new("parse-cache", ReadFaultOps.new())).get("ok", false))
	assert_true(manager._document_parse_cache.is_empty())
	assert_eq(manager._document_parse_cache_text_bytes, 0)
	OS.set_environment("DWM_SAVE_PARSE_CACHE_DISABLED", "1")
	assert_eq(manager._parse_document_text(text), STRICT.parse_object(text))
	assert_true(manager._document_parse_cache.is_empty())

func test_warm_inspection_does_not_accept_a_changed_external_target() -> void:
	var f := _fixture()
	if f.is_empty(): return
	var prepared: Dictionary = f.manager.prepare_backup_action("delete", "slot:1")
	assert_true(prepared.get("ok", false), str(prepared))
	if not prepared.get("ok", false): return
	var changed: String = " " + f.text
	_replace(f, "parse-cache/slot_1.json", changed)
	var committed: Dictionary = f.manager.commit_backup_action(prepared.value.token)
	assert_false(committed.get("ok", true))
	assert_eq(committed.get("code"), &"stale_backup_target")
	var inspected: Dictionary = f.manager.inspect_backup("slot:1")
	assert_true(inspected.get("ok", false))
	assert_eq(inspected.value.revision, changed.sha256_text())
	assert_eq(f.ops.read_bytes("parse-cache/slot_1.json").value.get_string_from_utf8(), changed)

func test_warm_cache_keeps_storage_refusals_absence_and_schema_validation() -> void:
	var f := _fixture()
	if f.is_empty(): return
	assert_eq(f.manager.inspect_backup("slot:1").value.state, "occupied")
	var validated: Dictionary = f.manager._document_text_validator(f.text)
	assert_true(validated.get("ok", false))
	validated.value.schema_version = -1
	assert_true(f.manager._document_text_validator(f.text).get("ok", false))
	f.ops.refuse_reads = true
	assert_eq(f.manager.inspect_backup("slot:1").get("code"), &"fixture_read_refused")
	f.ops.refuse_reads = false
	var marker: String = f.storage._marker_path("slot_1.json")
	_replace(f, marker, "{}")
	assert_eq(f.manager.inspect_backup("slot:1").get("code"), &"reconcile_required")
	assert_true(f.ops.remove_path(marker).get("ok", false))
	assert_true(f.ops.remove_path("parse-cache/slot_1.json").get("ok", false))
	assert_eq(f.manager.inspect_backup("slot:1").value.state, "empty")
	var invalid := '{"schema_version":999}'
	assert_true(f.manager._parse_document_text(invalid).get("ok", false))
	assert_false(f.manager._document_text_validator(invalid).get("ok", true))
	_replace(f, "parse-cache/slot_1.json", invalid)
	assert_eq(f.manager.inspect_backup("slot:1").value.reason, "newer_version")

func test_warm_inspection_reprepares_participants_and_current_guard() -> void:
	var f := _fixture()
	if f.is_empty(): return
	var participants := {}
	for pair: Array in [["run", "run_plan"], ["desktop_consequence", "consequence_plan"],
		["desktop_board", "board_plan"], ["schedule_view", "schedule_view_plan"],
		["profile", "profile_plan"], ["localization", "localization_plan"],
		["audio", "audio_plan"], ["route", "route_plan"], ["narrative", "narrative_plan"]]:
		participants[pair[0]] = Participant.new(pair[1])
	assert_true(f.manager.configure_restore_participants(participants).get("ok", false))
	var initial: Dictionary = f.manager.inspect_backup("slot:1")
	assert_true(initial.value.loadable, str(initial))
	participants.narrative.unavailable = true
	var changed: Dictionary = f.manager.inspect_backup("slot:1")
	assert_false(changed.value.loadable)
	assert_eq(changed.value.reason, "no_compatible_checkpoint")
	assert_eq(participants.narrative.preparations, 2)
	assert_true(f.manager.acquire_save_lock(&"restore").get("ok", false))
	assert_false(f.manager.inspect_backup("slot:1").value.operation_allowed)
	assert_true(f.manager.release_save_lock(&"restore").get("ok", false))
