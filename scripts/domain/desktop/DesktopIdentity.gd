class_name DesktopIdentity
extends RefCounted

## Frozen desktop attempt identity contract (Plan 02 Task 2, dwm-p2r.32.1).
## {run_id, branch_id, desktop_timeline_generation, causal_day_instance, app_round_ordinal}
## is the closed tuple every candidate/board command, receipt, checkpoint, journal entry, and
## warning fingerprint carries. Difficulty, seed, day number, and board revision are never
## identity substitutes.

const _CANONICAL_JSON := preload("res://scripts/validation/CanonicalJsonWriter.gd")

const _KEYS := [
	"run_id", "branch_id", "desktop_timeline_generation", "causal_day_instance", "app_round_ordinal",
]

const _MIN_ORDINAL := 1
const _MAX_ORDINAL := 5


static func validate(identity: Dictionary) -> Dictionary:
	var shape := _exact_keys(identity)
	if not shape.get("ok", false):
		return shape
	var run_id_check := _nonblank_string(identity["run_id"], "run_id")
	if not run_id_check.get("ok", false):
		return run_id_check
	var branch_id_check := _nonblank_string(identity["branch_id"], "branch_id")
	if not branch_id_check.get("ok", false):
		return branch_id_check
	var causal_day_check := _nonblank_string(identity["causal_day_instance"], "causal_day_instance")
	if not causal_day_check.get("ok", false):
		return causal_day_check
	var generation: Variant = identity["desktop_timeline_generation"]
	if typeof(generation) != TYPE_INT or int(generation) < 0:
		return _fail(&"identity_field_invalid",
			"desktop_timeline_generation must be a nonnegative integer",
			{"field": "desktop_timeline_generation", "value": generation})
	var ordinal: Variant = identity["app_round_ordinal"]
	if typeof(ordinal) != TYPE_INT or int(ordinal) < _MIN_ORDINAL or int(ordinal) > _MAX_ORDINAL:
		return _fail(&"identity_field_invalid", "app_round_ordinal must be an integer in 1..5",
			{"field": "app_round_ordinal", "value": ordinal})
	return {"ok": true, "code": &"ok", "value": {"identity": identity.duplicate(true)}, "receipt": {}}


static func fingerprint(identity: Dictionary) -> Dictionary:
	var validated := validate(identity)
	if not validated.get("ok", false):
		return validated
	var canonical: Dictionary = _CANONICAL_JSON.stringify(identity)
	if not canonical.get("ok", false):
		return _fail(&"identity_not_canonicalizable", "identity is not canonically representable",
			{"cause": canonical.get("code", &"")})
	var hex: String = String(canonical["value"]).sha256_text()
	return {"ok": true, "code": &"ok", "value": {"fingerprint": hex}, "receipt": {}}


static func remap(identity: Dictionary, branch_id: String, timeline_generation: int,
		causal_day_instance: String) -> Dictionary:
	var validated := validate(identity)
	if not validated.get("ok", false):
		return validated
	if branch_id.strip_edges().is_empty():
		return _fail(&"identity_field_invalid", "branch_id must be nonblank", {"field": "branch_id"})
	if causal_day_instance.strip_edges().is_empty():
		return _fail(&"identity_field_invalid", "causal_day_instance must be nonblank",
			{"field": "causal_day_instance"})
	if timeline_generation < 0:
		return _fail(&"identity_field_invalid",
			"desktop_timeline_generation must be a nonnegative integer",
			{"field": "desktop_timeline_generation"})
	var remapped: Dictionary = identity.duplicate(true)
	remapped["branch_id"] = branch_id
	remapped["desktop_timeline_generation"] = timeline_generation
	remapped["causal_day_instance"] = causal_day_instance
	var revalidated := validate(remapped)
	if not revalidated.get("ok", false):
		return revalidated
	return {"ok": true, "code": &"ok", "value": {"identity": remapped}, "receipt": {}}


static func _exact_keys(identity: Dictionary) -> Dictionary:
	if identity.size() != _KEYS.size():
		return _fail(&"identity_member_set_invalid",
			"identity must have exactly %d members" % _KEYS.size(), {"size": identity.size()})
	for key: String in _KEYS:
		if not identity.has(key):
			return _fail(&"identity_member_set_invalid", "missing member: %s" % key, {"missing": key})
	return {"ok": true}


static func _nonblank_string(value: Variant, field: String) -> Dictionary:
	if typeof(value) != TYPE_STRING:
		return _fail(&"identity_field_invalid", "%s must be a string" % field, {"field": field, "value": value})
	if str(value).strip_edges().is_empty():
		return _fail(&"identity_field_invalid", "%s must be nonblank" % field, {"field": field})
	return {"ok": true}


static func _fail(code: StringName, message: String, details: Dictionary) -> Dictionary:
	return {"ok": false, "code": code, "message": message, "details": details}
