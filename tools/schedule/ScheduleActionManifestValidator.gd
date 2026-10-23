class_name ScheduleActionManifestValidator
extends RefCounted

## Build-time gate over the frozen v1 Schedule action manifest (Plan 01 Task 2, dwm-wks).
##
## Layering, decided during the dwm-wks grilling session and recorded in that issue:
##
##   ScheduleActionRegistry  -- shape, enums, ordering and cross-record laws. Runs at RUNTIME for
##                              both the production manifest and any in-memory manifest.
##   this validator          -- everything above, PLUS completeness (the exact v1 record count) and
##                              cross-manifest effect-vocabulary parity against effects.json.
##                              Runs in tests and CI only.
##
## The split is load-bearing. tests/support/ScheduleRegistryFixtures.stale_records() deliberately
## uses an effect id outside the effects vocabulary so it can produce a different digest for the
## stale-fingerprint rejection test; cross-validating effects inside the registry would stop that
## fixture from constructing and break test_schedule_strict_validation.gd, which Task 2 may not edit.

const EXPECTED_RECORD_COUNT := 20
const MANIFEST_PATH := "res://data/manifests/schedule_actions.v1.json"
const SCHEMA_PATH := "res://schemas/manifests/schedule-actions.schema.json"
const EFFECTS_PATH := "res://data/manifests/effects.json"

const _REGISTRY := preload("res://scripts/domain/schedule/ScheduleActionRegistry.gd")
const _STRICT_JSON := preload("res://scripts/validation/StrictJson.gd")
const _SCHEMA_VALIDATOR := preload("res://scripts/validation/JsonSchemaValidator.gd")


## Full gate over an in-memory manifest. Returns the registry fingerprint on success.
static func validate_manifest(manifest: Dictionary) -> Dictionary:
	var built: Dictionary = _REGISTRY.from_manifest(manifest)
	if not built.get("ok", false):
		return built

	var records: Array = manifest["records"]
	if records.size() != EXPECTED_RECORD_COUNT:
		return _fail(&"incomplete_registry",
			"the frozen v1 registry declares exactly %d actions" % EXPECTED_RECORD_COUNT,
			{"expected": EXPECTED_RECORD_COUNT, "actual": records.size()})

	var vocabulary := _effect_vocabulary()
	if not vocabulary.get("ok", false):
		return vocabulary
	var known: Array = (vocabulary["value"] as Dictionary)["ids"]
	for record: Dictionary in records:
		for effect_id: Variant in record["effect_ids"]:
			if not known.has(effect_id):
				return _fail(&"unknown_effect_id",
					"an action declares an effect outside the effects vocabulary",
					{"action_id": str(record["action_id"]), "effect_id": str(effect_id)})

	var fingerprint: String = (built["value"] as Dictionary)["registry_fingerprint"]
	return {
		"ok": true,
		"code": &"ok",
		"value": {"registry_fingerprint": fingerprint, "record_count": records.size()},
		"receipt": {},
	}


## CLI entry point: reads both files, checks the manifest against the PUBLISHED schema, then runs
## the full gate. Proving the published schema accepts the manifest is what keeps the registry's
## embedded copy honest outside the test suite.
static func validate_file(manifest_path: String, schema_path: String) -> Dictionary:
	var manifest := _read_json(manifest_path)
	if not manifest.get("ok", false):
		return manifest
	var schema := _read_json(schema_path)
	if not schema.get("ok", false):
		return schema
	var shape: Dictionary = _SCHEMA_VALIDATOR.validate(manifest["value"], schema["value"])
	if not shape.get("ok", false):
		return _fail(&"published_schema_rejected", str(shape.get("message", "schema rejected")),
			{"schema": schema_path, "errors": shape.get("errors", [])})
	return validate_manifest(manifest["value"])


static func _effect_vocabulary() -> Dictionary:
	var effects := _read_json(EFFECTS_PATH)
	if not effects.get("ok", false):
		return effects
	var document: Dictionary = effects["value"]
	var ids: Variant = document.get("ids", null)
	if not (ids is Array) or (ids as Array).is_empty():
		return _fail(&"missing_effect_vocabulary", "the effects manifest declares no ids",
			{"path": EFFECTS_PATH})
	return {"ok": true, "code": &"ok", "value": {"ids": ids}, "receipt": {}}


static func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return _fail(&"missing_manifest", "the file is absent", {"path": path})
	var parsed: Dictionary = _STRICT_JSON.parse_object(FileAccess.get_file_as_string(path))
	if not parsed.get("ok", false):
		return _fail(&"malformed_manifest", "the file is not strict JSON",
			{"path": path, "cause": parsed.get("code", &"")})
	return {"ok": true, "code": &"ok", "value": parsed["value"], "receipt": {}}


static func _fail(code: StringName, message: String, details: Dictionary) -> Dictionary:
	return {"ok": false, "code": code, "message": message, "details": details}
