extends "res://addons/gut/test.gd"
## Frozen v1 Schedule action manifest (Plan 01 Task 2, dwm-wks).
##
## This suite is the human-readable statement of the frozen 20-record table. It asserts the JSON
## field by field so a drift reports WHICH record and WHICH field moved, rather than only a changed
## digest. The digest tie-break lives in test_schedule_action_registry.gd.
##
## Cross-manifest effect parity against data/manifests/effects.json lives HERE and in the CLI
## validator, never in the registry load path: tests/support/ScheduleRegistryFixtures.stale_records()
## deliberately uses an effect id outside that vocabulary, and it must keep constructing.

const MANIFEST_PATH := "res://data/manifests/schedule_actions.v1.json"
const SCHEMA_PATH := "res://schemas/manifests/schedule-actions.schema.json"
const EFFECTS_PATH := "res://data/manifests/effects.json"
const VALIDATOR_PATH := "res://tools/schedule/ScheduleActionManifestValidator.gd"

const PROBE := preload("res://tests/support/DynamicScriptProbe.gd")
const STRICT_JSON := preload("res://scripts/validation/StrictJson.gd")

const RECORD_KEYS := [
	"action_id", "action_kind", "allowed_days", "effect_ids", "motivation_cost",
	"participants", "repeatable", "route_id", "source_receipt_kind",
]

const ORDINARY_DAYS := [1, 2, 3, 4, 5, 6]

## The frozen v1 table, written out literally. Ordered lexicographically by action_id exactly as the
## manifest must be. Columns: action_id, allowed_days, action_kind, participants, repeatable,
## route_id, effect_ids, source_receipt_kind. motivation_cost is 1 for every record.
const FROZEN_TABLE := [
	["group:priscilla_lavinia:day2", [2], "group", ["priscilla", "lavinia"], false, "dating", [], "group_reply_acceptance"],
	["group:priscilla_lavinia:day6", [6], "group", ["priscilla", "lavinia"], false, "dating", [], "group_reply_acceptance"],
	["rest", ORDINARY_DAYS, "ordinary", [], true, null, ["pressure:-2", "health:+1"], null],
	["solo:lavinia:day2", [2], "solo", ["lavinia"], false, "dating", [], "solo_read_acceptance"],
	["solo:lavinia:day3", [3], "solo", ["lavinia"], false, "dating", [], "solo_read_acceptance"],
	["solo:lavinia:day5", [5], "solo", ["lavinia"], false, "dating", [], "solo_read_acceptance"],
	["solo:lavinia:day6", [6], "solo", ["lavinia"], false, "dating", [], "solo_read_acceptance"],
	["solo:lavinia:day7", [7], "solo", ["lavinia"], false, null, [], "solo_read_acceptance"],
	["solo:priscilla:day1", [1], "solo", ["priscilla"], false, "dating", [], "solo_read_acceptance"],
	["solo:priscilla:day2", [2], "solo", ["priscilla"], false, "dating", [], "solo_read_acceptance"],
	["solo:priscilla:day4", [4], "solo", ["priscilla"], false, "dating", [], "solo_read_acceptance"],
	["solo:priscilla:day6", [6], "solo", ["priscilla"], false, "dating", [], "solo_read_acceptance"],
	["solo:priscilla:day7", [7], "solo", ["priscilla"], false, null, [], "solo_read_acceptance"],
	["solo:sylvia:day1", [1], "solo", ["sylvia"], false, "dating", [], "solo_read_acceptance"],
	["solo:sylvia:day3", [3], "solo", ["sylvia"], false, "dating", [], "solo_read_acceptance"],
	["solo:sylvia:day4", [4], "solo", ["sylvia"], false, "dating", [], "solo_read_acceptance"],
	["solo:sylvia:day5", [5], "solo", ["sylvia"], false, "dating", [], "solo_read_acceptance"],
	["solo:sylvia:day7", [7], "solo", ["sylvia"], false, null, [], "solo_read_acceptance"],
	["training", ORDINARY_DAYS, "ordinary", [], true, null, ["pressure:+1", "health:+2"], null],
	["working", ORDINARY_DAYS, "ordinary", [], true, null, ["pressure:+2", "health:-2", "money:+30"], null],
]


func _parse(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Dictionary = STRICT_JSON.parse_object(FileAccess.get_file_as_string(path))
	if not parsed.get("ok", false):
		return {}
	return parsed["value"]


func _manifest() -> Dictionary:
	return _parse(MANIFEST_PATH)


func _records() -> Array:
	var manifest := _manifest()
	var records: Variant = manifest.get("records", [])
	return records if records is Array else []


func test_the_manifest_file_exists_and_parses_as_strict_json() -> void:
	assert_true(FileAccess.file_exists(MANIFEST_PATH),
		"expected RED: missing " + MANIFEST_PATH)
	if not FileAccess.file_exists(MANIFEST_PATH):
		return
	var parsed: Dictionary = STRICT_JSON.parse_object(FileAccess.get_file_as_string(MANIFEST_PATH))
	assert_true(parsed.get("ok", false), "the manifest must parse under StrictJson")


func test_the_manifest_top_level_is_exactly_four_keys() -> void:
	var manifest := _manifest()
	assert_false(manifest.is_empty(), "expected RED: manifest absent or unparseable")
	if manifest.is_empty():
		return
	var keys: Array = manifest.keys()
	keys.sort()
	assert_eq(keys, ["kind", "records", "registry_version", "schema_version"],
		"the top level is exact-key")
	assert_eq(manifest.get("schema_version"), 1, "schema_version is exactly 1")
	assert_eq(manifest.get("kind"), "schedule_actions", "kind is schedule_actions")
	assert_eq(manifest.get("registry_version"), 1, "registry_version is exactly 1")
	assert_eq(typeof(manifest.get("schema_version")), TYPE_INT,
		"schema_version is an int, not an integral float")
	assert_eq(typeof(manifest.get("registry_version")), TYPE_INT,
		"registry_version is an int, not an integral float")


func test_the_manifest_holds_exactly_the_twenty_frozen_records() -> void:
	var records := _records()
	assert_eq(records.size(), FROZEN_TABLE.size(),
		"expected RED: the frozen v1 table has exactly %d records" % FROZEN_TABLE.size())
	if records.size() != FROZEN_TABLE.size():
		return
	for index in range(FROZEN_TABLE.size()):
		var expected: Array = FROZEN_TABLE[index]
		var record: Dictionary = records[index]
		var action_id: String = str(expected[0])
		var keys: Array = record.keys()
		keys.sort()
		assert_eq(keys, RECORD_KEYS, "%s: exact record keys" % action_id)
		assert_eq(record.get("action_id"), expected[0], "record %d: action_id" % index)
		assert_eq(record.get("allowed_days"), expected[1], "%s: allowed_days" % action_id)
		assert_eq(record.get("action_kind"), expected[2], "%s: action_kind" % action_id)
		assert_eq(record.get("participants"), expected[3], "%s: participants" % action_id)
		assert_eq(record.get("repeatable"), expected[4], "%s: repeatable" % action_id)
		assert_eq(record.get("route_id"), expected[5], "%s: route_id" % action_id)
		assert_eq(record.get("effect_ids"), expected[6], "%s: effect_ids" % action_id)
		assert_eq(record.get("source_receipt_kind"), expected[7],
			"%s: source_receipt_kind" % action_id)
		assert_eq(record.get("motivation_cost"), 1, "%s: motivation_cost is exactly 1" % action_id)
		assert_eq(typeof(record.get("motivation_cost")), TYPE_INT,
			"%s: motivation_cost is an int, not an integral float" % action_id)


func test_records_are_lexicographically_ordered_by_action_id() -> void:
	var records := _records()
	assert_false(records.is_empty(), "expected RED: no records to order")
	if records.is_empty():
		return
	var ids: Array = []
	for record: Dictionary in records:
		ids.append(str(record.get("action_id", "")))
	var sorted_ids: Array = ids.duplicate()
	sorted_ids.sort()
	assert_eq(ids, sorted_ids, "records are stored in lexicographic action_id order")
	assert_eq(ids.size(), _unique(ids).size(), "action_id values are unique")


func test_allowed_days_are_ascending_unique_and_in_range() -> void:
	var records := _records()
	assert_false(records.is_empty(), "expected RED: no records to inspect")
	if records.is_empty():
		return
	for record: Dictionary in records:
		var action_id: String = str(record.get("action_id", ""))
		var days: Array = record.get("allowed_days", [])
		assert_false(days.is_empty(), "%s: allowed_days is never empty" % action_id)
		var sorted_days: Array = days.duplicate()
		sorted_days.sort()
		assert_eq(days, sorted_days, "%s: allowed_days ascend" % action_id)
		assert_eq(days.size(), _unique(days).size(), "%s: allowed_days are unique" % action_id)
		for day: Variant in days:
			assert_eq(typeof(day), TYPE_INT, "%s: each day is an int" % action_id)
			assert_true(int(day) >= 1 and int(day) <= 7, "%s: each day is in 1..7" % action_id)


func test_enumerated_fields_only_use_legal_members() -> void:
	var records := _records()
	assert_false(records.is_empty(), "expected RED: no records to inspect")
	if records.is_empty():
		return
	for record: Dictionary in records:
		var action_id: String = str(record.get("action_id", ""))
		assert_true(record.get("action_kind") in ["ordinary", "solo", "group"],
			"%s: action_kind is a legal member" % action_id)
		assert_true(record.get("route_id") in ["dating", null],
			"%s: route_id is a legal member" % action_id)
		assert_true(record.get("source_receipt_kind") in
			["solo_read_acceptance", "group_reply_acceptance", null],
			"%s: source_receipt_kind is a legal member" % action_id)


func test_kind_determines_participants_repeatability_and_source_class() -> void:
	var records := _records()
	assert_false(records.is_empty(), "expected RED: no records to inspect")
	if records.is_empty():
		return
	for record: Dictionary in records:
		var action_id: String = str(record.get("action_id", ""))
		var kind: String = str(record.get("action_kind", ""))
		var participants: Array = record.get("participants", [])
		match kind:
			"ordinary":
				assert_eq(participants, [], "%s: ordinary actions carry no participants" % action_id)
				assert_true(bool(record.get("repeatable")), "%s: ordinary repeats" % action_id)
				assert_null(record.get("source_receipt_kind"),
					"%s: ordinary needs no source receipt" % action_id)
			"solo":
				assert_eq(participants.size(), 1, "%s: solo carries one participant" % action_id)
				assert_false(bool(record.get("repeatable")), "%s: dates never repeat" % action_id)
				assert_eq(record.get("source_receipt_kind"), "solo_read_acceptance",
					"%s: solo source class" % action_id)
			"group":
				# Canonical order is Priscilla then Lavinia; a reversed pair is a tamper.
				assert_eq(participants, ["priscilla", "lavinia"],
					"%s: the P-L pair is exactly ordered" % action_id)
				assert_false(bool(record.get("repeatable")), "%s: dates never repeat" % action_id)
				assert_eq(record.get("source_receipt_kind"), "group_reply_acceptance",
					"%s: group source class" % action_id)


func test_every_effect_id_exists_in_the_effects_vocabulary() -> void:
	var effects := _parse(EFFECTS_PATH)
	var known: Array = effects.get("ids", [])
	assert_false(known.is_empty(), "the effects vocabulary must load")
	var records := _records()
	assert_false(records.is_empty(), "expected RED: no records to inspect")
	if records.is_empty() or known.is_empty():
		return
	for record: Dictionary in records:
		var action_id: String = str(record.get("action_id", ""))
		for effect_id: Variant in record.get("effect_ids", []):
			assert_true(known.has(effect_id),
				"%s: effect %s must exist in effects.json" % [action_id, str(effect_id)])


func test_the_published_schema_accepts_the_manifest() -> void:
	assert_true(FileAccess.file_exists(SCHEMA_PATH), "expected RED: missing " + SCHEMA_PATH)
	var schema := _parse(SCHEMA_PATH)
	var manifest := _manifest()
	if schema.is_empty() or manifest.is_empty():
		assert_false(schema.is_empty(), "expected RED: schema absent or unparseable")
		return
	var result: Dictionary = JsonSchemaValidator.validate(manifest, schema)
	assert_true(result.get("ok", false),
		"the published schema accepts the frozen manifest: " + str(result.get("message", "")))


func test_the_validator_reports_the_registry_fingerprint_and_rejects_drift() -> void:
	var loaded: Dictionary = PROBE.load_script(VALIDATOR_PATH)
	assert_true(loaded.get("ok", false), "expected RED: missing " + VALIDATOR_PATH)
	if not loaded.get("ok", false):
		return
	var validator: Object = loaded["value"]
	var clean: Dictionary = validator.validate_manifest(_manifest())
	assert_true(clean.get("ok", false), "the frozen manifest validates clean")
	var fingerprint: String = str((clean.get("value", {}) as Dictionary).get("registry_fingerprint", ""))
	assert_eq(fingerprint.length(), 64, "the validator reports a SHA-256 digest")

	# Every mutation below must be rejected with a typed code, never silently accepted.
	for mutation: Array in [
		["drops a record", "records_size"],
		["reorders records", "records_order"],
		["adds an unknown key", "unknown_key"],
		["changes a motivation cost", "motivation_cost"],
		["reverses the P-L pair", "participants_order"],
		["uses an unknown effect id", "unknown_effect"],
	]:
		var mutated := _mutate(str(mutation[0]))
		var result: Dictionary = validator.validate_manifest(mutated)
		assert_false(result.get("ok", true),
			"a manifest that %s must be rejected" % str(mutation[0]))


func _mutate(kind: String) -> Dictionary:
	var manifest := _manifest()
	if manifest.is_empty():
		return manifest
	var records: Array = (manifest["records"] as Array).duplicate(true)
	match kind:
		"drops a record":
			records.remove_at(0)
		"reorders records":
			var moved: Variant = records.pop_back()
			records.insert(0, moved)
		"adds an unknown key":
			(records[0] as Dictionary)["unexpected"] = true
		"changes a motivation cost":
			(records[0] as Dictionary)["motivation_cost"] = 2
		"reverses the P-L pair":
			for record: Dictionary in records:
				if str(record["action_kind"]) == "group":
					record["participants"] = ["lavinia", "priscilla"]
		"uses an unknown effect id":
			for record: Dictionary in records:
				if str(record["action_id"]) == "training":
					record["effect_ids"] = ["pressure:+99"]
	manifest["records"] = records
	return manifest


func _unique(values: Array) -> Array:
	var seen: Array = []
	for value: Variant in values:
		if not seen.has(value):
			seen.append(value)
	return seen
