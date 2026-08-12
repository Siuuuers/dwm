class_name ScheduleActionRegistry
extends RefCounted

## The immutable, versioned v1 Schedule action registry (Plan 01 Task 2, dwm-wks).
##
## Route, effects, motivation cost, allowed days, kind, participants, repeatability and
## source-receipt class come ONLY from this registry. Drafts, saves, scenes and action-ID spelling
## can neither supply nor override them; nothing here parses an action ID for facts.
##
## The consumed surface is the one dwm-p2r.12 ratified at b09bd05, NOT the superseded block at
## plan lines 203-212. ScheduleRules duck-types on exactly two methods:
##
##     func fingerprint() -> String                        # bare lowercase hex
##     func find_record(action_id: String) -> Dictionary   # CommandResult, value={record}
##
## ScheduleRules._guard_registry compares str(registry.fingerprint()) against a stored digest, so
## fingerprint() MUST stay a bare String; a CommandResult here fails every validation closed.
##
## Schema note: the shape contract is embedded as `_SCHEMA` so a load reads exactly one file, and
## schemas/manifests/schedule-actions.schema.json publishes the same contract for tooling and CI.
## test_schedule_action_registry.gd asserts the two cannot drift apart.
##
## Cross-manifest effect-vocabulary parity deliberately lives in the tooling validator, never here:
## tests/support/ScheduleRegistryFixtures.stale_records() uses an effect id outside effects.json and
## must keep constructing so the stale-fingerprint rejection test stays honest.

const MANIFEST_PATH := "res://data/manifests/schedule_actions.v1.json"
const SCHEMA_PATH := "res://schemas/manifests/schedule-actions.schema.json"

const _STRICT_JSON := preload("res://scripts/validation/StrictJson.gd")
const _CANONICAL_JSON := preload("res://scripts/validation/CanonicalJsonWriter.gd")
const _SCHEMA_VALIDATOR := preload("res://scripts/validation/JsonSchemaValidator.gd")

## Canonical ordered participants for the only legal group action.
const GROUP_PAIR := ["priscilla", "lavinia"]
const MINIMUM_DAY := 1
const MAXIMUM_DAY := 7

## Mirrors schemas/manifests/schedule-actions.schema.json byte-for-byte in meaning. The mini
## validator supports only const/enum/type/required/properties/additionalProperties/uniqueItems/
## items/minLength, so nullable fields are expressed as enums rather than type unions, and every
## ordering or cross-record law is hand-written in _validate_semantics below.
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

## Retained after the first successful load. A later edit to the manifest file never takes effect
## in this process; a genuinely changed registry is caught downstream, where ScheduleRules compares
## this fingerprint against the one persisted beside a committed Schedule.
static var _current: RefCounted = null

var _records: Dictionary = {}
var _fingerprint: String = ""


func _init(records: Dictionary = {}, fingerprint: String = "") -> void:
	_records = records
	_fingerprint = fingerprint


# ---- construction ----

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


## Validates, canonicalizes and fingerprints an in-memory manifest through the exact path
## load_current uses. Tests and the CLI validator both enter here, so neither can claim a record is
## trusted without earning it.
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


# ---- the surface ScheduleRules consumes ----

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


# ---- validation ----

## Cross-record and ordering laws the schema dialect cannot express.
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
				# Canonical order is Priscilla then Lavinia; a reversed pair is a tamper, not a
				# synonym, because participant order is semantic.
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


# ---- helpers ----

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
