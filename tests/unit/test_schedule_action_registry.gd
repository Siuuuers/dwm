extends "res://addons/gut/test.gd"
## Immutable Schedule action registry (Plan 01 Task 2, dwm-wks).
##
## The surface asserted here is the one dwm-p2r.12 ratified at b09bd05 and that ScheduleRules
## duck-types against, NOT the superseded block at plan lines 203-212:
##
##     static func load_current() -> Dictionary        # value = {registry, registry_fingerprint}
##     static func from_manifest(m: Dictionary) -> Dictionary
##     func fingerprint() -> String                    # bare lowercase hex
##     func find_record(action_id: String) -> Dictionary   # value = {record}, empty receipt
##
## The registry is loaded through DynamicScriptProbe rather than preload: GDScript resolves a typed
## preload at PARSE time, so preloading a not-yet-existing script turns "the surface is missing"
## into a load failure instead of the failing assertion Step 2.4 requires.

const REGISTRY_PATH := "res://scripts/domain/schedule/ScheduleActionRegistry.gd"
const RULES_PATH := "res://scripts/domain/schedule/ScheduleRules.gd"
const SCHEMA_PATH := "res://schemas/manifests/schedule-actions.schema.json"

const PROBE := preload("res://tests/support/DynamicScriptProbe.gd")
const REGISTRY_FIXTURES := preload("res://tests/support/ScheduleRegistryFixtures.gd")
const STRICT_JSON := preload("res://scripts/validation/StrictJson.gd")

const RECORD_KEYS := [
	"action_id", "action_kind", "allowed_days", "effect_ids", "motivation_cost",
	"participants", "repeatable", "route_id", "source_receipt_kind",
]

var _script = null


func before_each() -> void:
	var loaded: Dictionary = PROBE.load_script(REGISTRY_PATH)
	_script = loaded["value"] if loaded.get("ok", false) else null


func _missing() -> bool:
	assert_not_null(_script, "expected RED: missing " + REGISTRY_PATH)
	return _script == null


func _registry() -> Object:
	var loaded: Dictionary = _script.load_current()
	if not loaded.get("ok", false):
		return null
	return (loaded["value"] as Dictionary)["registry"]


func test_load_current_returns_a_registry_and_its_fingerprint() -> void:
	if _missing():
		return
	var loaded: Dictionary = _script.load_current()
	assert_true(loaded.get("ok", false),
		"the frozen manifest loads clean: " + str(loaded.get("message", "")))
	if not loaded.get("ok", false):
		return
	var value: Dictionary = loaded["value"]
	var keys: Array = value.keys()
	keys.sort()
	assert_eq(keys, ["registry", "registry_fingerprint"], "load_current value is exact-key")
	assert_eq(loaded.get("code"), &"ok", "success carries the ok code")
	assert_not_null(value["registry"], "a registry object is returned")


func test_fingerprint_is_a_bare_lowercase_sha256_string() -> void:
	if _missing():
		return
	var registry := _registry()
	assert_not_null(registry, "a registry loads")
	if registry == null:
		return
	var fingerprint: Variant = registry.fingerprint()
	# ScheduleRules compares str(registry.fingerprint()) to a stored hex digest, so a CommandResult
	# dictionary here would fail every schedule validation closed.
	assert_eq(typeof(fingerprint), TYPE_STRING, "fingerprint() returns a bare String")
	assert_eq(str(fingerprint).length(), 64, "a SHA-256 digest is 64 hex characters")
	assert_eq(str(fingerprint), str(fingerprint).to_lower(), "the digest is lowercase")
	assert_true(str(fingerprint).is_valid_hex_number(), "the digest is hexadecimal")


func test_the_production_fingerprint_matches_the_task_one_fixture() -> void:
	# The parity gate. The manifest JSON, the frozen table asserted in the tooling suite, and the
	# code-built fixture are three independent statements of the same 20 records; this ties them.
	if _missing():
		return
	var registry := _registry()
	assert_not_null(registry, "a registry loads")
	if registry == null:
		return
	var fixture: RefCounted = REGISTRY_FIXTURES.new()
	assert_eq(str(registry.fingerprint()), str(fixture.fingerprint()),
		"the shipped manifest encodes exactly the frozen v1 table the fixture builds")


func test_find_record_returns_the_exact_record_with_no_receipt() -> void:
	if _missing():
		return
	var registry := _registry()
	if registry == null:
		assert_not_null(registry, "a registry loads")
		return
	var found: Dictionary = registry.find_record("working")
	assert_true(found.get("ok", false), "a registered action resolves")
	if not found.get("ok", false):
		return
	var value: Dictionary = found["value"]
	assert_eq(value.keys(), ["record"], "find_record value is exactly {record}")
	assert_eq(found.get("receipt", null), {}, "a pure lookup issues no receipt")
	var record: Dictionary = value["record"]
	var keys: Array = record.keys()
	keys.sort()
	assert_eq(keys, RECORD_KEYS, "the record is exact-key")
	assert_eq(record["effect_ids"], ["pressure:+2", "health:-2", "money:+30"],
		"effects come from the registry, in canonical order")
	assert_eq(record["motivation_cost"], 1, "cost is exactly one")


func test_find_record_rejects_an_unregistered_action() -> void:
	if _missing():
		return
	var registry := _registry()
	if registry == null:
		assert_not_null(registry, "a registry loads")
		return
	var found: Dictionary = registry.find_record("mystery_action")
	assert_false(found.get("ok", true), "an unknown action fails closed")
	assert_eq(found.get("code"), &"unregistered_action", "typed rejection")
	assert_false(found.has("value"), "a failure carries no candidate")
	assert_false(found.has("receipt"), "a failure carries no receipt")


func test_returned_records_are_deeply_detached() -> void:
	if _missing():
		return
	var registry := _registry()
	if registry == null:
		assert_not_null(registry, "a registry loads")
		return
	var first: Dictionary = (registry.find_record("training")["value"] as Dictionary)["record"]
	(first["effect_ids"] as Array).append("tamper:+1")
	first["motivation_cost"] = 99
	var second: Dictionary = (registry.find_record("training")["value"] as Dictionary)["record"]
	assert_eq(second["effect_ids"], ["pressure:+1", "health:+2"],
		"mutating a returned record cannot reach the retained snapshot")
	assert_eq(second["motivation_cost"], 1, "the retained cost is untouched")


func test_the_registry_exposes_no_mutator() -> void:
	if _missing():
		return
	var registry := _registry()
	if registry == null:
		assert_not_null(registry, "a registry loads")
		return
	for forbidden: String in ["set_record", "add_record", "remove_record", "clear", "set_records"]:
		assert_false(registry.has_method(forbidden),
			"an immutable registry exposes no %s" % forbidden)


func test_load_current_retains_one_instance_per_process() -> void:
	if _missing():
		return
	var first := _registry()
	var second := _registry()
	assert_not_null(first, "a registry loads")
	if first == null:
		return
	assert_eq(first.get_instance_id(), second.get_instance_id(),
		"load_current retains its validated registry rather than re-reading")


func test_from_manifest_runs_the_same_validation_and_fingerprint_path() -> void:
	if _missing():
		return
	var manifest := {
		"schema_version": 1,
		"kind": "schedule_actions",
		"registry_version": 1,
		"records": REGISTRY_FIXTURES.default_records(),
	}
	var built: Dictionary = _script.from_manifest(manifest)
	assert_true(built.get("ok", false),
		"an in-memory frozen manifest validates: " + str(built.get("message", "")))
	if not built.get("ok", false):
		return
	var registry: Object = (built["value"] as Dictionary)["registry"]
	assert_eq(str(registry.fingerprint()), str(REGISTRY_FIXTURES.new().fingerprint()),
		"from_manifest reproduces the same canonical digest")


func test_from_manifest_rejects_drift_rather_than_trusting_the_caller() -> void:
	if _missing():
		return
	for mutation: String in [
		"unsorted", "duplicate_id", "bad_cost", "unknown_kind", "reversed_pair", "extra_key",
		"descending_days", "missing_key",
	]:
		var result: Dictionary = _script.from_manifest(_mutated(mutation))
		assert_false(result.get("ok", true), "a %s manifest is rejected" % mutation)
		assert_false(result.has("value"), "a rejected manifest yields no registry (%s)" % mutation)


func test_the_embedded_schema_matches_the_published_contract() -> void:
	if _missing():
		return
	assert_true(FileAccess.file_exists(SCHEMA_PATH), "expected RED: missing " + SCHEMA_PATH)
	if not FileAccess.file_exists(SCHEMA_PATH):
		return
	var parsed: Dictionary = STRICT_JSON.parse_object(FileAccess.get_file_as_string(SCHEMA_PATH))
	assert_true(parsed.get("ok", false), "the published schema parses")
	if not parsed.get("ok", false):
		return
	var constants: Dictionary = _script.get_script_constant_map()
	assert_true(constants.has("_SCHEMA"), "the registry embeds its schema so it reads one file")
	if not constants.has("_SCHEMA"):
		return
	assert_eq(constants["_SCHEMA"], parsed["value"],
		"the embedded schema and the published file cannot drift apart")


func test_schedule_rules_accepts_the_production_registry() -> void:
	# The reason the ratified fixture surface won: ScheduleRules duck-types on fingerprint() and
	# find_record(). This proves the real registry satisfies that seam end to end.
	if _missing():
		return
	var registry := _registry()
	var rules: Dictionary = PROBE.load_script(RULES_PATH)
	assert_true(rules.get("ok", false), "ScheduleRules loads")
	if registry == null or not rules.get("ok", false):
		assert_not_null(registry, "a registry loads")
		return
	var entries: Array = [{
		"draft_entry_id": "d1",
		"day": 3,
		"slot_index": 0,
		"action_id": "rest",
		"action_kind": "ordinary",
		"participants": [],
		"source_receipt_id": null,
	}]
	var result: Dictionary = rules["value"].validate_draft(3, entries, registry,
		str(registry.fingerprint()), {})
	assert_true(result.get("ok", false),
		"a legal ordinary draft validates against the production registry: "
			+ str(result.get("code", "")) + " " + str(result.get("message", "")))


func _mutated(kind: String) -> Dictionary:
	var records: Array = REGISTRY_FIXTURES.default_records()
	match kind:
		"unsorted":
			records.reverse()
		"duplicate_id":
			records[1] = (records[0] as Dictionary).duplicate(true)
		"bad_cost":
			(records[0] as Dictionary)["motivation_cost"] = 0
		"unknown_kind":
			(records[0] as Dictionary)["action_kind"] = "chore"
		"reversed_pair":
			for record: Dictionary in records:
				if str(record["action_kind"]) == "group":
					record["participants"] = ["lavinia", "priscilla"]
		"extra_key":
			(records[0] as Dictionary)["unexpected"] = true
		"descending_days":
			for record: Dictionary in records:
				if str(record["action_id"]) == "training":
					record["allowed_days"] = [6, 5, 4, 3, 2, 1]
		"missing_key":
			(records[0] as Dictionary).erase("route_id")
	return {
		"schema_version": 1,
		"kind": "schedule_actions",
		"registry_version": 1,
		"records": records,
	}
