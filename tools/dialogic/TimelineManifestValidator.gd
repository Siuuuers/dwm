extends RefCounted
## Validates the generated manifests against their schemas and the live runtime constants
## (dwm-p2r.8, Plan-05 Task 1). Fails closed on any drift.

const SCHEMA_VALIDATOR := preload("res://scripts/validation/JsonSchemaValidator.gd")
const STRICT_JSON := preload("res://scripts/validation/StrictJson.gd")
const DATING_ENDING_RULES := preload("res://scripts/domain/ending/DatingEndingRules.gd")
const EFFECT_RESOLVER := preload("res://autoload/EffectResolver.gd")
const SCENE_ROUTER := preload("res://autoload/SceneRouter.gd")

const TIMELINES_SCHEMA_PATH := "res://schemas/manifests/timelines.schema.json"
const ID_REGISTRY_SCHEMA_PATH := "res://schemas/manifests/id-registry.schema.json"
const EXPECTED_TIMELINE_COUNT := 61
const EXPECTED_PLACEHOLDER := 24
const EXPECTED_DRAFT := 37
const RETIRED_ENDING_IDS := ["ending.priscilla.true", "ending.lavinia.true", "ending.sylvia.true"]


static func validate_timelines(manifest: Dictionary) -> Dictionary:
	var schema := _load_schema(TIMELINES_SCHEMA_PATH)
	if not schema.get("ok", false):
		return schema
	var schema_result := SCHEMA_VALIDATOR.validate(manifest, schema["value"])
	if not schema_result.get("ok", false):
		return schema_result
	var records: Array = manifest["records"]
	if records.size() != EXPECTED_TIMELINE_COUNT:
		return _fail("timeline_count", "%d != %d" % [records.size(), EXPECTED_TIMELINE_COUNT])
	var seen := {}
	var placeholder := 0
	var draft := 0
	for record in records:
		var id := str(record["id"])
		if seen.has(id):
			return _fail("duplicate_timeline_id", id)
		seen[id] = true
		var res_path := "res://" + str(record["path"])
		if not FileAccess.file_exists(res_path):
			return _fail("missing_timeline_file", res_path)
		if "sha256:" + FileAccess.get_sha256(res_path) != str(record["content_fingerprint"]):
			return _fail("fingerprint_drift", res_path)
		match str(record["content_status"]):
			"placeholder": placeholder += 1
			"draft": draft += 1
			_: return _fail("unexpected_status", str(record["content_status"]))
	if placeholder != EXPECTED_PLACEHOLDER:
		return _fail("placeholder_count", str(placeholder))
	if draft != EXPECTED_DRAFT:
		return _fail("draft_count", str(draft))
	return {"ok": true, "value": {"count": records.size(), "placeholder": placeholder, "draft": draft}}


static func validate_endings(endings: Dictionary, timelines: Dictionary) -> Dictionary:
	var by_id := {}
	for record in timelines.get("records", []):
		by_id[str(record["id"])] = record
	var records: Variant = endings.get("records")
	if typeof(records) != TYPE_ARRAY:
		return _fail("endings_invalid", "records must be an array")
	if int(endings.get("schema_version", 0)) != 1:
		return _fail("endings_invalid", "schema_version must be 1")
	var primary: Array = []
	var postscript: Array = []
	var epilogue: Array = []
	var seen := {}
	for record in records:
		if typeof(record) != TYPE_DICTIONARY:
			return _fail("endings_invalid", "record not object")
		for key in ["ending_id", "role", "timeline_id", "label"]:
			if not (record as Dictionary).has(key):
				return _fail("endings_invalid", "missing " + key)
		var ending_id := str(record["ending_id"])
		var role := str(record["role"])
		var timeline_id := str(record["timeline_id"])
		var label := str(record["label"])
		if ending_id in RETIRED_ENDING_IDS:
			return _fail("retired_ending_id", ending_id)
		if seen.has(ending_id):
			return _fail("duplicate_ending_id", ending_id)
		seen[ending_id] = true
		match role:
			"primary": primary.append(ending_id)
			"postscript": postscript.append(ending_id)
			"epilogue": epilogue.append(ending_id)
			_: return _fail("unknown_role", role)
		if not by_id.has(timeline_id):
			return _fail("unknown_ending_timeline", timeline_id)
		if label not in (by_id[timeline_id] as Dictionary).get("labels", []):
			return _fail("unresolved_ending_label", ending_id + " -> " + label)
	if not _same_set(primary, DATING_ENDING_RULES.VALID_PRIMARY_IDS):
		return _fail("primary_set_mismatch", str(primary))
	if not _same_set(postscript, DATING_ENDING_RULES.POSTSCRIPT_IDS):
		return _fail("postscript_set_mismatch", str(postscript))
	if not _same_set(epilogue, ["ending.priscilla_lavinia"]):
		return _fail("epilogue_set_mismatch", str(epilogue))
	var union: Array = []
	union.append_array(primary)
	union.append_array(postscript)
	union.append_array(epilogue)
	if not _same_set(union, DATING_ENDING_RULES.CANONICAL_ENDING_IDS):
		return _fail("canonical_set_mismatch", str(union))
	return {"ok": true, "value": {"count": records.size()}}


static func validate_effects(effects: Dictionary) -> Dictionary:
	var schema := _load_schema(ID_REGISTRY_SCHEMA_PATH)
	if not schema.get("ok", false):
		return schema
	var schema_result := SCHEMA_VALIDATOR.validate(effects, schema["value"])
	if not schema_result.get("ok", false):
		return schema_result
	if str(effects.get("kind", "")) != "effects":
		return _fail("effects_kind", str(effects.get("kind", "")))
	var resolver: Node = EFFECT_RESOLVER.new()
	resolver._build_fixed_effects()
	var unknown := ""
	for id in effects["ids"]:
		if not resolver.is_effect_known(str(id)):
			unknown = str(id)
			break
	resolver.free()
	if unknown != "":
		return _fail("unknown_effect_id", unknown)
	return {"ok": true, "value": {"count": (effects["ids"] as Array).size()}}


static func validate_routes(routes: Dictionary) -> Dictionary:
	var schema := _load_schema(ID_REGISTRY_SCHEMA_PATH)
	if not schema.get("ok", false):
		return schema
	var schema_result := SCHEMA_VALIDATOR.validate(routes, schema["value"])
	if not schema_result.get("ok", false):
		return schema_result
	if str(routes.get("kind", "")) != "routes":
		return _fail("routes_kind", str(routes.get("kind", "")))
	var expected: Array = []
	for key in SCENE_ROUTER._SCENE_PATHS.keys():
		expected.append(str(key))
	if not _same_set(routes["ids"], expected):
		return _fail("routes_set_mismatch", str(routes["ids"]))
	return {"ok": true, "value": {"count": (routes["ids"] as Array).size()}}


static func _load_schema(path: String) -> Dictionary:
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		return {"ok": false, "code": &"schema_missing", "message": path}
	return STRICT_JSON.parse_object(text)


static func _same_set(a: Array, b: Array) -> bool:
	var set_a := {}
	for x in a:
		set_a[str(x)] = true
	var set_b := {}
	for y in b:
		set_b[str(y)] = true
	if set_a.size() != set_b.size():
		return false
	for key in set_a:
		if not set_b.has(key):
			return false
	return true


static func _fail(code: String, message: String) -> Dictionary:
	return {"ok": false, "code": StringName(code), "message": message}
