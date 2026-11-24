extends RefCounted


const _STATE_SCHEMA := preload("res://scripts/domain/schedule/ScheduleStateSchema.gd")

const CHILD_KIND := &"day_resolution_stage"


static func validate(request: Dictionary, issuer: Object) -> Dictionary:
	if typeof(request["resolution_issuer_receipt"]) != TYPE_DICTIONARY \
			or typeof(request["completion_transaction_provenance"]) != TYPE_DICTIONARY:
		return _fail(&"invalid_presentation_intent",
			"the root receipt and child provenance must be dictionaries", {})

	var root: Dictionary = request["resolution_issuer_receipt"]
	var verified: Variant = issuer.call(&"verify_issued", root.duplicate(true),
		&"transaction_id")
	if typeof(verified) != TYPE_DICTIONARY or not (verified as Dictionary).get("ok", false):
		return _fail(&"presentation_root_unverified",
			"the resolution issuer receipt did not verify", {})

	var provenance: Dictionary = request["completion_transaction_provenance"]
	var revalidated: Variant = issuer.call(&"validate_child", provenance.duplicate(true),
		CHILD_KIND)
	if typeof(revalidated) != TYPE_DICTIONARY or not (revalidated as Dictionary).get("ok", false):
		return _fail(&"presentation_completion_unverified",
			"the completion provenance did not revalidate through the issuer", {})
	if str(provenance.get("child_id", "")) != str(request["completion_transaction_id"]):
		return _fail(&"presentation_completion_unverified",
			"the completion id disagrees with its own provenance", {})
	if str(provenance.get("parent_receipt_id", "")) != str(root.get("receipt_id", "")):
		return _fail(&"presentation_completion_unverified",
			"the completion child is not parented to this resolution root", {})

	var expected := source_ids(request)
	if expected.is_empty():
		return _fail(&"invalid_presentation_intent",
			"the completion projection is not canonically representable", {})
	var actual: Variant = provenance.get("source_ids")
	if typeof(actual) != TYPE_ARRAY or (actual as Array) != expected:
		return _fail(&"presentation_completion_unverified",
			"the completion provenance does not project these exact bytes",
			{"expected": expected, "actual": actual})
	return {"ok": true, "code": &"ok", "value": {"validated": true}, "receipt": {}}


static func source_ids(request: Dictionary) -> Array:
	var context_hash: Dictionary = _STATE_SCHEMA.canonical_sha256(request["context"])
	if not context_hash.get("ok", false):
		return []
	var tokens: Array = [
		_project("role", "presentation.completion"),
		_project("resolution_id", str(request["resolution_id"])),
		_project("stage_id", str(request["stage_id"])),
		_project("substage_id", str(request["substage_id"])),
		_project("route_id", str(request["route_id"])),
		_project("timeline_id", str(request["timeline_id"])),
		_project("context_sha256", str((context_hash["value"] as Dictionary)["sha256"])),
	]
	for token: String in tokens:
		if token.is_empty():
			return []
	tokens.sort()
	return tokens


static func _project(path: String, value: Variant) -> String:
	var canonical: Dictionary = _STATE_SCHEMA.canonical_json(value)
	if not canonical.get("ok", false):
		return ""
	return path + "=" + str((canonical["value"] as Dictionary)["text"])


static func _fail(code: StringName, message: String, details: Dictionary) -> Dictionary:
	return {"ok": false, "code": code, "message": message, "details": details}
