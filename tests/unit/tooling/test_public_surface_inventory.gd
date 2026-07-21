extends "res://addons/gut/test.gd"

const TOOL_PATH := "res://tools/runtime/PublicSurfaceInventory.gd"
const REQUIRED_PATH := "res://evidence/phase_2r/runtime/game_state_required_surface.json"

const RESERVED_SIGNATURES := {
	"open_contact": "func open_contact(friend_id: String, command_id: String) -> Dictionary",
	"reply_invitation": "func reply_invitation(friend_id: String, command_id: String) -> Dictionary",
	"resolve_invitations_for_day": "func resolve_invitations_for_day(attendance: Dictionary, command_id: String) -> Dictionary",
	"request_next_ending_command": "func request_next_ending_command() -> Dictionary",
}
const RESERVED_TASKS := {
	"open_contact": "Task 3",
	"reply_invitation": "Task 3",
	"resolve_invitations_for_day": "Task 3",
	"request_next_ending_command": "Task 6",
}

var _counter := 0

const FIXTURE_SCRIPT := """extends Node

signal sample_changed(value: int)

const SAMPLE_MAX := 3

var sample_value: int = 0

func retained_query() -> int:
	return sample_value

func replaced_mutation(value: int) -> void:
	sample_value = value

func removable_helper() -> void:
	pass

func _private_only() -> void:
	pass

static func static_helper() -> int:
	return SAMPLE_MAX
"""

const FIXTURE_CALLER := """extends Node

func _ready() -> void:
	var target := get_node("/root/Sample")
	print(target.retained_query())
	target.call("replaced_mutation", 1)
	target.sample_changed.connect(_on_sample_changed)

func _on_sample_changed(_value: int) -> void:
	pass
"""

const FIXTURE_TEST_CALLER := """extends Node

func exercise(target: Node) -> void:
	target.removable_helper()
"""

func _scratch_root() -> String:
	_counter += 1
	return OS.get_environment("DWM_TEST_ROOT").path_join("surface-fixture-%d" % _counter)

func _write_file(path: String, text: String) -> void:
	assert_eq(DirAccess.make_dir_recursive_absolute(path.get_base_dir()), OK)
	var file := FileAccess.open(path, FileAccess.WRITE)
	assert_not_null(file)
	file.store_string(text)
	file.close()

func _classification(disposition: String, replacement: String, contract_test: String) -> Dictionary:
	return {"disposition": disposition, "replacement": replacement, "contract_test": contract_test}

func _good_required() -> Dictionary:
	return {"symbols": [
		{"symbol": "sample_changed", "kind": "signal", "availability": "current", "disposition": "retain", "replacement": "", "contract_test": "test_sample_signal_contract"},
		{"symbol": "SAMPLE_MAX", "kind": "constant", "availability": "current", "disposition": "retain", "replacement": "", "contract_test": "test_sample_max_contract"},
		{"symbol": "sample_value", "kind": "property", "availability": "current", "disposition": "replace", "replacement": "func set_sample_value(value: int) -> Dictionary", "contract_test": "test_sample_value_migration"},
		{"symbol": "retained_query", "kind": "function", "availability": "current", "disposition": "retain", "replacement": "", "contract_test": "test_retained_query_contract"},
		{"symbol": "replaced_mutation", "kind": "function", "availability": "current", "disposition": "replace", "replacement": "func request_mutation(command_id: String) -> Dictionary", "contract_test": "test_replaced_mutation_migration"},
		{"symbol": "removable_helper", "kind": "function", "availability": "current", "disposition": "remove", "replacement": "", "contract_test": ""},
		{"symbol": "static_helper", "kind": "function", "availability": "current", "disposition": "retain", "replacement": "", "contract_test": "test_static_helper_contract"},
		{"symbol": "future_seam", "kind": "function", "availability": "planned_future", "disposition": "retain", "replacement": "", "contract_test": "", "signature": "func future_seam() -> Dictionary", "owner_plan": "phase2r-04", "owner_task": "Task 3"},
	]}

func _build_fixture(required: Dictionary) -> Dictionary:
	var probe := DynamicScriptProbe.load_script(TOOL_PATH)
	if not probe.get("ok", false):
		return {}
	var root := _scratch_root()
	var script_path := root.path_join("autoload/Sample.gd")
	_write_file(script_path, FIXTURE_SCRIPT)
	_write_file(root.path_join("scripts/Caller.gd"), FIXTURE_CALLER)
	_write_file(root.path_join("tests/TestCaller.gd"), FIXTURE_TEST_CALLER)
	var roots: Array[String] = [root.path_join("autoload"), root.path_join("scripts"), root.path_join("tests")]
	return probe["value"].build(script_path, roots, required)

func _record(inventory: Dictionary, symbol: String) -> Dictionary:
	for record: Dictionary in inventory.get("records", []):
		if str(record.get("symbol", "")) == symbol:
			return record
	return {}

func _has_code(result: Dictionary, code: String) -> bool:
	for error: String in result.get("errors", []):
		if str(error).begins_with(code):
			return true
	return false

func test_public_surface_inventory_exists() -> void:
	var probe := DynamicScriptProbe.load_script(TOOL_PATH)
	assert_true(probe.get("ok", false), "PublicSurfaceInventory must exist")

func test_build_produces_complete_sorted_records() -> void:
	var probe := DynamicScriptProbe.load_script(TOOL_PATH)
	assert_true(probe.get("ok", false), "PublicSurfaceInventory must exist")
	if not probe.get("ok", false):
		return
	var inventory := _build_fixture(_good_required())
	assert_true(inventory.get("ok", false), JSON.stringify(inventory.get("errors", [])))
	var records: Array = inventory.get("records", [])
	assert_eq(records.size(), 7, "seven public symbols expected, private excluded")
	var previous := ""
	for record: Dictionary in records:
		var keys := record.keys()
		keys.sort()
		assert_eq(keys, ["call_sites", "contract_test", "disposition", "kind", "replacement", "signature", "symbol"])
		assert_true(previous < str(record["symbol"]), "records must be sorted by symbol")
		previous = str(record["symbol"])
	assert_eq(str(_record(inventory, "sample_changed").get("kind", "")), "signal")
	assert_eq(str(_record(inventory, "SAMPLE_MAX").get("kind", "")), "constant")
	assert_eq(str(_record(inventory, "sample_value").get("kind", "")), "property")
	assert_eq(str(_record(inventory, "static_helper").get("signature", "")), "static func static_helper() -> int")
	assert_eq(str(_record(inventory, "retained_query").get("signature", "")), "func retained_query() -> int")
	var call_sites: Array = _record(inventory, "retained_query").get("call_sites", [])
	assert_true(call_sites.size() >= 1, "static caller reference must be recorded")
	assert_true(str(call_sites[0]).begins_with("scripts/Caller.gd:"), str(call_sites))

func test_validation_failure_matrix() -> void:
	var probe := DynamicScriptProbe.load_script(TOOL_PATH)
	assert_true(probe.get("ok", false), "PublicSurfaceInventory must exist")
	if not probe.get("ok", false):
		return
	var tool: Script = probe["value"]

	var unclassified_required := _good_required().duplicate(true)
	unclassified_required["symbols"] = unclassified_required["symbols"].filter(
		func(entry: Dictionary) -> bool: return str(entry.get("symbol", "")) != "removable_helper")
	assert_true(_has_code(_build_fixture(unclassified_required), "SURFACE_UNCLASSIFIED"), "missing classification must fail")

	var good := _build_fixture(_good_required())
	assert_true(good.get("ok", false), JSON.stringify(good.get("errors", [])))

	var duplicated := good.duplicate(true)
	duplicated["records"].append(duplicated["records"][0].duplicate(true))
	assert_true(_has_code(tool.validate(duplicated), "SURFACE_DUPLICATE"), "duplicate record must fail")

	var missing_scan := good.duplicate(true)
	missing_scan["records"][0].erase("call_sites")
	assert_true(_has_code(tool.validate(missing_scan), "SURFACE_CALL_SITES_MISSING"), "missing call-site scan must fail")

	var malformed := good.duplicate(true)
	malformed["records"][0]["signature"] = "garbage without a declaration"
	assert_true(_has_code(tool.validate(malformed), "SURFACE_SIGNATURE_MALFORMED"), "malformed signature must fail")

	var missing_required := _good_required().duplicate(true)
	missing_required["symbols"].append({"symbol": "missing_symbol", "kind": "function", "availability": "current", "disposition": "retain", "replacement": "", "contract_test": "test_missing"})
	assert_true(_has_code(_build_fixture(missing_required), "SURFACE_REQUIRED_MISSING"), "required current symbol absent must fail")

	var retain_untested := _good_required().duplicate(true)
	for entry: Dictionary in retain_untested["symbols"]:
		if str(entry.get("symbol", "")) == "retained_query":
			entry["contract_test"] = ""
	assert_true(_has_code(_build_fixture(retain_untested), "SURFACE_RETAIN_TEST_MISSING"), "retain requires a named contract test")

	var replace_unnamed := _good_required().duplicate(true)
	for entry: Dictionary in replace_unnamed["symbols"]:
		if str(entry.get("symbol", "")) == "replaced_mutation":
			entry["replacement"] = ""
	assert_true(_has_code(_build_fixture(replace_unnamed), "SURFACE_REPLACEMENT_MISSING"), "replace requires a literal replacement signature")

	var remove_consumed := _good_required().duplicate(true)
	for entry: Dictionary in remove_consumed["symbols"]:
		if str(entry.get("symbol", "")) == "retained_query":
			entry["disposition"] = "remove"
			entry["contract_test"] = ""
	assert_true(_has_code(_build_fixture(remove_consumed), "SURFACE_REMOVE_CONSUMERS"), "remove with non-test consumers must fail")

	var remove_dynamic := _good_required().duplicate(true)
	for entry: Dictionary in remove_dynamic["symbols"]:
		if str(entry.get("symbol", "")) == "replaced_mutation":
			entry["disposition"] = "remove"
			entry["replacement"] = ""
			entry["contract_test"] = ""
	assert_true(_has_code(_build_fixture(remove_dynamic), "SURFACE_DYNAMIC_UNRESOLVED"), "remove with dynamic references must fail")

func test_reserved_symbol_rules() -> void:
	var probe := DynamicScriptProbe.load_script(TOOL_PATH)
	assert_true(probe.get("ok", false), "PublicSurfaceInventory must exist")
	if not probe.get("ok", false):
		return
	var absent_ok := _build_fixture(_good_required())
	assert_true(absent_ok.get("ok", false), "absent planned_future symbol is valid")

	var reserved_present := _good_required().duplicate(true)
	for entry: Dictionary in reserved_present["symbols"]:
		if str(entry.get("availability", "")) == "planned_future":
			entry["symbol"] = "retained_query"
			entry["signature"] = "func retained_query() -> int"
		elif str(entry.get("symbol", "")) == "retained_query":
			entry["disposition"] = "deprecate"
			entry["replacement"] = "func retained_query_v2() -> Dictionary"
	assert_true(_has_code(_build_fixture(reserved_present), "SURFACE_RESERVED_DISPOSITION"), "present planned_future symbol permits only retain")

func test_write_canonical_json_round_trip() -> void:
	var probe := DynamicScriptProbe.load_script(TOOL_PATH)
	assert_true(probe.get("ok", false), "PublicSurfaceInventory must exist")
	if not probe.get("ok", false):
		return
	var inventory := _build_fixture(_good_required())
	assert_true(inventory.get("ok", false), JSON.stringify(inventory.get("errors", [])))
	var output_path := _scratch_root().path_join("game_state_surface.json")
	var written: Dictionary = probe["value"].write_canonical_json(inventory, output_path)
	assert_true(written.get("ok", false), JSON.stringify(written.get("errors", [])))
	var text := FileAccess.get_file_as_string(output_path)
	var parsed := StrictJson.parse_object(text)
	assert_true(parsed.get("ok", false), "canonical output must strict-parse")
	var canonical: Dictionary = CanonicalJsonWriter.stringify(parsed.get("value", {}))
	assert_true(canonical.get("ok", false))
	assert_eq(text, str(canonical.get("value", "")) + "\n", "output must be canonical with trailing newline")

func test_game_state_required_surface_reservations() -> void:
	assert_true(FileAccess.file_exists(REQUIRED_PATH), "game_state_required_surface.json must exist")
	if not FileAccess.file_exists(REQUIRED_PATH):
		return
	var parsed := StrictJson.parse_object(FileAccess.get_file_as_string(REQUIRED_PATH))
	assert_true(parsed.get("ok", false), "required surface must strict-parse")
	if not parsed.get("ok", false):
		return
	var manifest: Dictionary = parsed.get("value", {})
	var found := {}
	for entry: Variant in manifest.get("symbols", []):
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var record := entry as Dictionary
		if str(record.get("availability", "")) == "planned_future":
			found[str(record.get("symbol", ""))] = record
	assert_eq(found.size(), 4, "exactly four planned_future reservations")
	for symbol: String in RESERVED_SIGNATURES:
		assert_true(found.has(symbol), "reservation missing: " + symbol)
		if not found.has(symbol):
			continue
		var record: Dictionary = found[symbol]
		assert_eq(str(record.get("kind", "")), "function", symbol)
		assert_eq(str(record.get("signature", "")), str(RESERVED_SIGNATURES[symbol]), symbol)
		assert_eq(str(record.get("owner_plan", "")), "phase2r-04", symbol)
		assert_eq(str(record.get("owner_task", "")), str(RESERVED_TASKS[symbol]), symbol)

const SAVE_MANAGER_REQUIRED_PATH := "res://evidence/phase_2r/runtime/save_manager_required_surface.json"

const SAVE_MANAGER_IMPLEMENTED_SYMBOLS := [
	"run_restored", "save_capability_changed", "configure_mutation_gate",
	"record_stable_checkpoint", "commit_prepared_restore", "save_for_logout",
	"save_exists", "configure_restore_participants", "acquire_save_lock",
]

func test_save_manager_required_surface_freezes_realized_facade() -> void:
	assert_true(FileAccess.file_exists(SAVE_MANAGER_REQUIRED_PATH),
		"save_manager_required_surface.json must exist")
	if not FileAccess.file_exists(SAVE_MANAGER_REQUIRED_PATH):
		return
	var parsed := StrictJson.parse_object(FileAccess.get_file_as_string(SAVE_MANAGER_REQUIRED_PATH))
	assert_true(parsed.get("ok", false), "save-manager required surface must strict-parse")
	if not parsed.get("ok", false):
		return
	# Task 6 realized the frozen target: every seam is now an implemented `current`
	# symbol with a retain (or deprecate for legacy wrappers) disposition, and the
	# removed raw-path methods have left the surface entirely.
	var by_symbol := {}
	var deprecated_wrappers := 0
	for entry: Variant in parsed["value"].get("symbols", []):
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var record := entry as Dictionary
		by_symbol[str(record.get("symbol", ""))] = record
		assert_eq(str(record.get("availability", "")), "current",
			"Task 6 realizes every seam as a current symbol: " + str(record.get("symbol", "")))
		if str(record.get("disposition", "")) == "deprecate":
			deprecated_wrappers += 1
			assert_true(str(record.get("replacement", "")).length() > 0,
				"deprecated wrapper needs a replacement: " + str(record.get("symbol", "")))
	for symbol: String in SAVE_MANAGER_IMPLEMENTED_SYMBOLS:
		assert_true(by_symbol.has(symbol), "implemented seam missing: " + symbol)
		assert_eq(str((by_symbol.get(symbol, {}) as Dictionary).get("disposition", "")), "retain", symbol)
	for removed: String in ["get_slot_path", "SAVE_FOLDER", "write_json_file", "build_save_dict"]:
		assert_false(by_symbol.has(removed), "raw-path symbol must leave the surface: " + removed)
	assert_true(deprecated_wrappers >= 9, "legacy wrappers and signals carry deprecate dispositions")
