class_name ScheduleActionRegistry
extends RefCounted


const MANIFEST_PATH := "res://data/manifests/schedule_actions.v1.json"
const SCHEMA_PATH := "res://schemas/manifests/schedule-actions.schema.json"

const _STRICT_JSON := preload("res://scripts/validation/StrictJson.gd")
const _CANONICAL_JSON := preload("res://scripts/validation/CanonicalJsonWriter.gd")
const _SCHEMA_VALIDATOR := preload("res://scripts/validation/JsonSchemaValidator.gd")

const GROUP_PAIR := ["priscilla", "lavinia"]
const MINIMUM_DAY := 1
const MAXIMUM_DAY := 7

const _SCHEMA := {
	"$schema": "https://json-schema.org/draft/2020-12/schema",
	"type": "object",
	"additionalProperties": false,
	"required": ["schema_version", "kind", "registry_version", "records"],
	"properties": {
		"schema_version": {"const": 1},
		"kind": {"const": "schedule_actions"},
		"registry_version": {"const": 1},
		"records": {
			"type": "array",
			"items": {
				"type": "object",
				"additionalProperties": false,
				"required": [
					"action_id", "action_kind", "allowed_days", "effect_ids", "motivation_cost",
					"participants", "repeatable", "route_id", "source_receipt_kind",
				],
				"properties": {
					"action_id": {"type": "string", "minLength": 1},
					"action_kind": {"enum": ["ordinary", "solo", "group"]},
					"allowed_days": {
						"type": "array",
						"uniqueItems": true,
						"items": {"type": "integer"},
					},
					"effect_ids": {
						"type": "array",
						"uniqueItems": true,
						"items": {"type": "string", "minLength": 1},
					},
					"motivation_cost": {"const": 1},
					"participants": {
						"type": "array",
						"uniqueItems": true,
						"items": {"type": "string", "minLength": 1},
					},
					"repeatable": {"type": "boolean"},
					"route_id": {"enum": ["dating", null]},
					"source_receipt_kind": {
						"enum": ["solo_read_acceptance", "group_reply_acceptance", null],
					},
				},
			},
		},
	},
}

static var _current: RefCounted = null

var _records: Dictionary = {}
var _fingerprint: String = ""


func _init(records: Dictionary = {}, fingerprint: String = "") -> void:
	_records = records
	_fingerprint = fingerprint



static func load_current() -> Dictionary:
	if _current != null:
		return _loaded(_current)
	if not FileAccess.file_exists(MANIFEST_PATH):
		return _fail(&"missing_registry_manifest", "the Schedule action manifest is absent",
			{"path": MANIFEST_PATH})
	var parsed: Dictionary = _STRICT_JSON.parse_object(FileAccess.get_file_as_string(MANIFEST_PATH))
	if not parsed.get("ok", false):
		return _fail(&"malformed_registry_manifest",
			"the Schedule action manifest is not strict JSON",
			{"path": MANIFEST_PATH, "cause": parsed.get("code", &"")})
	var built := from_manifest(parsed["value"])
	if not built.get("ok", false):
		return built
	_current = (built["value"] as Dictionary)["registry"]
	return built


static func from_manifest(manifest: Dictionary) -> Dictionary:
	var shape: Dictionary = _SCHEMA_VALIDATOR.validate(manifest, _SCHEMA)
	if not shape.get("ok", false):
		return _fail(&"invalid_registry_manifest", str(shape.get("message", "schema rejected")),
			{"errors": shape.get("errors", [])})
	var semantics := _validate_semantics(manifest["records"])
	if not semantics.is_empty():
		return semantics
	var canonical: Dictionary = _CANONICAL_JSON.stringify(manifest)
	if not canonical.get("ok", false):
		return _fail(&"noncanonical_registry_manifest",
			"the Schedule action manifest is not canonicalizable",
			{"cause": canonical.get("code", &"")})
	var records: Dictionary = {}
	for record: Dictionary in manifest["records"]:
		records[str(record["action_id"])] = record.duplicate(true)
	var registry := ScheduleActionRegistry.new(records, _digest(str(canonical["value"])))
	return _loaded(registry)



func fingerprint() -> String:
	return _fingerprint


func find_record(action_id: String) -> Dictionary:
	if not _records.has(action_id):
		return _fail(&"unregistered_action", "the action is not in the registry",
			{"action_id": action_id})
	return {
		"ok": true,
		"code": &"ok",
		"value": {"record": (_records[action_id] as Dictionary).duplicate(true)},
		"receipt": {},
	}




func lookup(action_id: String, expected_fingerprint: Variant) -> Dictionary:
	var guard := _expected_fingerprint_error(expected_fingerprint)
	if not guard.is_empty():
		return guard
	return find_record(action_id)


func snapshot(expected_fingerprint: Variant) -> Dictionary:
	var guard := _expected_fingerprint_error(expected_fingerprint)
	if not guard.is_empty():
		return guard
	var records: Dictionary = {}
	for action_id: String in _records:
		records[action_id] = (_records[action_id] as Dictionary).duplicate(true)
	return {
		"ok": true,
		"code": &"ok",
		"value": {"records": records, "registry_fingerprint": _fingerprint},
		"receipt": {},
	}


func _expected_fingerprint_error(expected_fingerprint: Variant) -> Dictionary:
	if typeof(expected_fingerprint) != TYPE_STRING or str(expected_fingerprint).is_empty():
		return _fail(&"invalid_expected_fingerprint",
			"an expected registry fingerprint must be a nonempty String",
			{"expected": expected_fingerprint})
	if str(expected_fingerprint) != _fingerprint:
		return _fail(&"stale_registry_fingerprint",
			"the registry no longer matches the expected fingerprint",
			{"expected": str(expected_fingerprint), "actual": _fingerprint})
	return {}



static func _validate_semantics(records: Array) -> Dictionary:
	if records.is_empty():
		return _fail(&"empty_registry", "the registry declares no actions", {})
	var seen: Dictionary = {}
	var previous_id := ""
	for record: Dictionary in records:
		var action_id := str(record["action_id"])
		if seen.has(action_id):
			return _fail(&"duplicate_action_id", "an action id is declared twice",
				{"action_id": action_id})
		seen[action_id] = true
		if not previous_id.is_empty() and action_id < previous_id:
			return _fail(&"unsorted_registry",
				"records are stored in lexicographic action_id order",
				{"action_id": action_id, "previous": previous_id})
		previous_id = action_id

		var days: Array = record["allowed_days"]
		if days.is_empty():
			return _fail(&"empty_allowed_days", "an action must allow at least one day",
				{"action_id": action_id})
		var previous_day := 0
		for day: Variant in days:
			var value := int(day)
			if value < MINIMUM_DAY or value > MAXIMUM_DAY:
				return _fail(&"day_out_of_range", "an allowed day is outside 1..7",
					{"action_id": action_id, "day": value})
			if value <= previous_day:
				return _fail(&"unsorted_allowed_days", "allowed days ascend",
					{"action_id": action_id, "day": value})
			previous_day = value

		var kind := str(record["action_kind"])
		var participants: Array = record["participants"]
		var repeatable := bool(record["repeatable"])
		var source: Variant = record["source_receipt_kind"]
		match kind:
			"ordinary":
				if not participants.is_empty():
					return _fail(&"invalid_participants",
						"an ordinary action carries no participants", {"action_id": action_id})
				if not repeatable:
					return _fail(&"invalid_repeatability", "ordinary actions repeat",
						{"action_id": action_id})
				if source != null:
					return _fail(&"invalid_source_class",
						"an ordinary action needs no source receipt", {"action_id": action_id})
			"solo":
				if participants.size() != 1:
					return _fail(&"invalid_participants", "a solo action names one participant",
						{"action_id": action_id})
				if repeatable:
					return _fail(&"invalid_repeatability", "date actions never repeat",
						{"action_id": action_id})
				if source != "solo_read_acceptance":
					return _fail(&"invalid_source_class", "a solo action reads a solo receipt",
						{"action_id": action_id})
			"group":
				if participants != GROUP_PAIR:
					return _fail(&"invalid_participants",
						"the group pair is exactly Priscilla then Lavinia",
						{"action_id": action_id, "participants": participants.duplicate()})
				if repeatable:
					return _fail(&"invalid_repeatability", "date actions never repeat",
						{"action_id": action_id})
				if source != "group_reply_acceptance":
					return _fail(&"invalid_source_class", "a group action reads a reply receipt",
						{"action_id": action_id})
	return {}



static func _digest(canonical: String) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(canonical.to_utf8_buffer())
	return context.finish().hex_encode()


static func _loaded(registry: RefCounted) -> Dictionary:
	return {
		"ok": true,
		"code": &"ok",
		"value": {"registry": registry, "registry_fingerprint": registry.fingerprint()},
		"receipt": {},
	}


static func _fail(code: StringName, message: String, details: Dictionary) -> Dictionary:
	return {"ok": false, "code": code, "message": message, "details": details}
