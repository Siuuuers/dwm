class_name MinesweeperShopRegistry
extends RefCounted

## The immutable v1 Minesweeper shop capability registry (Plan 02 Task 1, dwm-p2r.16).
##
## DataCatalog delegates the three Shop item IDs here and keeps only derived presentation
## (localization_key, image_path, display name, and the secret/gift flags the registry does not
## carry). Currency, price, effect_ids and max_purchases are projected from these records, never
## stored beside them.
##
## Record shape per dwm-p2r.16 DECISION 4 / 9.16 / 11.7, derived from the frozen table at plan
## lines 627-631. `cap` is STRUCTURED rather than a flat max int so supportz encodes both of its
## limits losslessly -- "once per causal day; three per saved branch" -- because Task 2's
## supportz_eligible() needs the per-causal-day half that a flat int would drop. `effect_ids`
## carries the LEGACY strings DataCatalog uses today; `capability_ids` carries the board vocabulary
## frozen at plan lines 946/1194. first_cell_safe is baseline and granted by no item.
##
## RETENTION mirrors ScheduleActionRegistry.load_current(): the first successful load wins for the
## process, and a later edit to the manifest file never takes effect. Unlike that registry, every
## accessor here lazily self-initializes (dwm-p2r.16 DECISION 12.8) -- forced, not chosen, because
## GUT runs test_shop_projection_matches_the_frozen_literals, which reaches this registry through
## DataCatalog with no prior initialize(), BEFORE the test that calls initialize() explicitly.
## Requiring an explicit call would have meant inventing a registry_not_initialized code the plan
## never froze, which DECISION 5 and 9.9 both refuse.
##
## SCHEMA_PATH follows the plan literally (`data/schemas/`) rather than the dwm-wks convention
## `schemas/manifests/`, per dwm-p2r.16 DEVIATION 2. `_SCHEMA` mirrors that published file in
## meaning so a load reads exactly one file, matching the ScheduleActionRegistry precedent.

const MANIFEST_PATH := "res://data/manifests/minesweeper_shop.v1.json"
const SCHEMA_PATH := "res://data/schemas/minesweeper-shop.schema.json"

const _STRICT_JSON := preload("res://scripts/validation/StrictJson.gd")
const _SCHEMA_VALIDATOR := preload("res://scripts/validation/JsonSchemaValidator.gd")

const REGISTRY_VERSION := "minesweeper_shop_v1"

## The closed board-capability vocabulary, frozen at plan lines 946/1194.
const CAPABILITY_UNION := ["first_cell_safe", "first_cell_zero", "forced_no_guess"]

## Mirrors data/schemas/minesweeper-shop.schema.json. The mini validator supports only
## const/enum/type/required/properties/additionalProperties/uniqueItems/items/minLength, so it
## cannot express a nullable integer: `cap.per_causal_day` is null|int and an enum of [null, 1]
## would freeze v1 to today's exact values. Both cap members are therefore declared
## present-but-unconstrained -- `required` still forces presence and `additionalProperties: false`
## still rejects unknown keys -- and their value laws live in _validate_semantics below
## (dwm-p2r.16 DECISION 12.9).
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

## Retained after the first successful load, exactly as ScheduleActionRegistry retains _current.
static var _records: Dictionary = {}
static var _ids: Array[String] = []
static var _loaded: bool = false


# ---- construction ----

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


# ---- the surface DataCatalog consumes ----

static func get_record(item_id: String) -> Dictionary:
	var ready := initialize()
	if not ready.get("ok", false):
		return ready
	if not _records.has(item_id):
		return _fail(&"unregistered_shop_item", "the item is not in the registry",
			{"item_id": item_id})
	return _ok({"record": (_records[item_id] as Dictionary).duplicate(true)})


## Typed Array[String] cannot carry an envelope, so an unloadable registry answers with the empty
## array -- the StorageAdapter precedent for a non-Dictionary return.
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


# ---- validation ----

## Cross-record and value laws the schema dialect cannot express, including both `cap` members,
## which the mini validator has to leave unconstrained (see _SCHEMA above).
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


# ---- helpers ----

static func _ok(value: Dictionary) -> Dictionary:
	return {"ok": true, "code": &"ok", "value": value, "receipt": {}}


static func _fail(code: StringName, message: String, details: Dictionary) -> Dictionary:
	return {"ok": false, "code": code, "message": message, "details": details}
