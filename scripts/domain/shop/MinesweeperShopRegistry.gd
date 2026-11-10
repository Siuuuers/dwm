class_name MinesweeperShopRegistry
extends RefCounted


const MANIFEST_PATH := "res://data/manifests/minesweeper_shop.v1.json"
const SCHEMA_PATH := "res://data/schemas/minesweeper-shop.schema.json"

const _STRICT_JSON := preload("res://scripts/validation/StrictJson.gd")
const _SCHEMA_VALIDATOR := preload("res://scripts/validation/JsonSchemaValidator.gd")

const REGISTRY_VERSION := "minesweeper_shop_v1"

const CAPABILITY_UNION := ["first_cell_safe", "first_cell_zero", "forced_no_guess"]

const _SCHEMA := {
	"$schema": "https://json-schema.org/draft/2020-12/schema",
	"type": "object",
	"additionalProperties": false,
	"required": ["schema_version", "kind", "registry_version", "records"],
	"properties": {
		"schema_version": {"const": 1},
		"kind": {"const": "minesweeper_shop"},
		"registry_version": {"const": REGISTRY_VERSION},
		"records": {
			"type": "array",
			"items": {
				"type": "object",
				"additionalProperties": false,
				"required": [
					"item_id", "currency", "price", "effect_ids", "capability_ids", "cap",
				],
				"properties": {
					"item_id": {"type": "string", "minLength": 1},
					"currency": {"enum": ["money", "minesweeper_coin"]},
					"price": {"type": "integer"},
					"effect_ids": {
						"type": "array",
						"uniqueItems": true,
						"items": {"type": "string", "minLength": 1},
					},
					"capability_ids": {
						"type": "array",
						"uniqueItems": true,
						"items": {"enum": CAPABILITY_UNION},
					},
					"cap": {
						"type": "object",
						"additionalProperties": false,
						"required": ["per_causal_day", "per_branch"],
						"properties": {
							"per_causal_day": {},
							"per_branch": {},
						},
					},
				},
			},
		},
	},
}

static var _records: Dictionary = {}
static var _ids: Array[String] = []
static var _loaded: bool = false



static func initialize(path: String = MANIFEST_PATH) -> Dictionary:
	if _loaded:
		return _ok({"registry_version": REGISTRY_VERSION, "record_count": _ids.size()})
	if not FileAccess.file_exists(path):
		return _fail(&"missing_shop_manifest", "the Minesweeper shop manifest is absent",
			{"path": path})
	var parsed: Dictionary = _STRICT_JSON.parse_object(FileAccess.get_file_as_string(path))
	if not parsed.get("ok", false):
		return _fail(&"malformed_shop_manifest",
			"the Minesweeper shop manifest is not strict JSON",
			{"path": path, "cause": parsed.get("code", &"")})
	var manifest: Dictionary = parsed["value"]
	var shape: Dictionary = _SCHEMA_VALIDATOR.validate(manifest, _SCHEMA)
	if not shape.get("ok", false):
		return _fail(&"invalid_shop_manifest", str(shape.get("message", "schema rejected")),
			{"path": path, "errors": shape.get("errors", [])})
	var records: Array = manifest["records"]
	var semantics := _validate_semantics(records)
	if not semantics.is_empty():
		return semantics
	var by_id: Dictionary = {}
	var ids: Array[String] = []
	for record: Dictionary in records:
		var item_id := str(record["item_id"])
		by_id[item_id] = record.duplicate(true)
		ids.append(item_id)
	_records = by_id
	_ids = ids
	_loaded = true
	return _ok({"registry_version": REGISTRY_VERSION, "record_count": _ids.size()})



static func get_record(item_id: String) -> Dictionary:
	var ready := initialize()
	if not ready.get("ok", false):
		return ready
	if not _records.has(item_id):
		return _fail(&"unregistered_shop_item", "the item is not in the registry",
			{"item_id": item_id})
	return _ok({"record": (_records[item_id] as Dictionary).duplicate(true)})


static func get_ids() -> Array[String]:
	if not initialize().get("ok", false):
		return []
	var out: Array[String] = []
	out.assign(_ids)
	return out


static func validate_all() -> Dictionary:
	var ready := initialize()
	if not ready.get("ok", false):
		return ready
	var records: Array = []
	for item_id: String in _ids:
		records.append(_records[item_id])
	var semantics := _validate_semantics(records)
	if not semantics.is_empty():
		return semantics
	return _ok({"record_count": _ids.size()})



static func _validate_semantics(records: Array) -> Dictionary:
	if records.is_empty():
		return _fail(&"empty_registry", "the registry declares no items", {})
	var seen: Dictionary = {}
	for record: Dictionary in records:
		var item_id := str(record["item_id"])
		if seen.has(item_id):
			return _fail(&"duplicate_item_id", "an item id is declared twice",
				{"item_id": item_id})
		seen[item_id] = true
		if int(record["price"]) < 0:
			return _fail(&"invalid_price", "a price is never negative",
				{"item_id": item_id, "price": record["price"]})

		var cap: Dictionary = record["cap"]
		var per_branch: Variant = cap["per_branch"]
		if typeof(per_branch) != TYPE_INT or int(per_branch) < 1:
			return _fail(&"invalid_cap", "per_branch is a positive integer",
				{"item_id": item_id, "per_branch": per_branch})
		var per_causal_day: Variant = cap["per_causal_day"]
		if per_causal_day != null:
			if typeof(per_causal_day) != TYPE_INT or int(per_causal_day) < 1:
				return _fail(&"invalid_cap", "per_causal_day is null or a positive integer",
					{"item_id": item_id, "per_causal_day": per_causal_day})
			if int(per_causal_day) > int(per_branch):
				return _fail(&"invalid_cap", "a per-causal-day cap never exceeds its branch cap",
					{"item_id": item_id, "cap": cap.duplicate()})
	return {}



static func _ok(value: Dictionary) -> Dictionary:
	return {"ok": true, "code": &"ok", "value": value, "receipt": {}}


static func _fail(code: StringName, message: String, details: Dictionary) -> Dictionary:
	return {"ok": false, "code": code, "message": message, "details": details}
