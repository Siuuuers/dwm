class_name FatalDiagnosticProjector
extends RefCounted

## The one general, pure projector of raw recovery diagnostics into
## gate-latchable primitive fatal failures
## (docs/superpowers/plans/2026-07-17-phase-2r-03-lifecycle-save.md Task 3).

const DEPTH_BUDGET := 24
const NODE_BUDGET := 4096
const DIAGNOSTIC_KEYS: Array[String] = ["operation", "owner_id", "result"]
const FAILURE_KEYS: Array[String] = ["code", "details", "phase", "source"]

const INVARIANT_FALLBACK := {
	"source": "fatal_diagnostic_projector",
	"phase": "project_failure",
	"code": "FATAL_PROJECTOR_INVARIANT",
	"details": {"reason": "invalid_projector_output", "path": "$"},
}

static func project_failure(
		source: Variant,
		phase: Variant,
		code: Variant,
		context: Dictionary,
		raw_diagnostics: Array
) -> Dictionary:
	var header: Array[String] = []
	for value: Variant in [source, phase, code]:
		if typeof(value) != TYPE_STRING and typeof(value) != TYPE_STRING_NAME:
			return {"ok": false, "code": &"invalid_projection_input", "message": "header must be String/StringName"}
		var text := str(value)
		if text.is_empty():
			return {"ok": false, "code": &"invalid_projection_input", "message": "header must be nonempty"}
		header.append(text)
	var budget := {"nodes": NODE_BUDGET}
	var projected_context: Variant = _project_value(context, "$.context", DEPTH_BUDGET, budget)
	var projected_diagnostics: Array = []
	for index: int in range(raw_diagnostics.size()):
		projected_diagnostics.append(_project_diagnostic(raw_diagnostics[index], index, budget))
	return {
		"ok": true, "code": &"ok",
		"value": {"failure": {
			"source": header[0],
			"phase": header[1],
			"code": header[2],
			"details": {"context": projected_context, "diagnostics": projected_diagnostics},
		}},
		"receipt": {},
	}

static func validate_failure(failure: Dictionary) -> Dictionary:
	var keys := failure.keys()
	var string_keys: Array[String] = []
	for key: Variant in keys:
		if typeof(key) != TYPE_STRING:
			return {"ok": false, "code": &"invalid_fatal_failure", "message": "non-string failure key"}
		string_keys.append(str(key))
	string_keys.sort()
	if string_keys != FAILURE_KEYS:
		return {"ok": false, "code": &"invalid_fatal_failure", "message": "unexpected failure keys"}
	for field: String in ["source", "phase", "code"]:
		if typeof(failure[field]) != TYPE_STRING or str(failure[field]).is_empty():
			return {"ok": false, "code": &"invalid_fatal_failure", "message": field + " must be a nonempty String"}
	if typeof(failure["details"]) != TYPE_DICTIONARY:
		return {"ok": false, "code": &"invalid_fatal_failure", "message": "details must be a Dictionary"}
	if not _primitive_valid(failure["details"], DEPTH_BUDGET):
		return {"ok": false, "code": &"invalid_fatal_failure", "message": "details must be primitive JSON"}
	return {"ok": true, "code": &"ok"}

static func get_invariant_fallback() -> Dictionary:
	return INVARIANT_FALLBACK.duplicate(true)

static func _project_value(value: Variant, path: String, depth: int, budget: Dictionary) -> Variant:
	budget["nodes"] = int(budget["nodes"]) - 1
	if depth <= 0 or int(budget["nodes"]) <= 0:
		return {"reason": "unsupported_type", "path": path}
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_INT:
			return value
		TYPE_FLOAT:
			if is_finite(value):
				return value
			return {"reason": "nonfinite_number", "path": path}
		TYPE_STRING:
			return value
		TYPE_STRING_NAME:
			return str(value)
		TYPE_ARRAY:
			var projected_array: Array = []
			for index: int in range((value as Array).size()):
				projected_array.append(_project_value(value[index], "%s[%d]" % [path, index], depth - 1, budget))
			return projected_array
		TYPE_DICTIONARY:
			var seen := {}
			for key: Variant in (value as Dictionary):
				if typeof(key) != TYPE_STRING and typeof(key) != TYPE_STRING_NAME:
					return {"reason": "non_string_key", "path": path}
				var normalized_key := str(key)
				if seen.has(normalized_key):
					return {"reason": "normalized_key_collision", "path": path}
				seen[normalized_key] = true
			var projected_dictionary := {}
			for key: Variant in (value as Dictionary):
				var normalized_key := str(key)
				projected_dictionary[normalized_key] = _project_value(
					value[key], path + "." + normalized_key, depth - 1, budget)
			return projected_dictionary
	return {"reason": "unsupported_type", "path": path}

static func _project_diagnostic(raw: Variant, index: int, budget: Dictionary) -> Dictionary:
	var path := "$.diagnostics[%d]" % index
	var malformed := {
		"owner_id": "fatal_diagnostic_projector",
		"operation": "project_diagnostic",
		"ok": false,
		"code": "invalid_fatal_diagnostic",
		"message": "",
		"details": {"reason": "malformed_diagnostic", "path": path},
	}
	if typeof(raw) != TYPE_DICTIONARY:
		return malformed
	var diagnostic := raw as Dictionary
	var keys: Array[String] = []
	for key: Variant in diagnostic:
		if typeof(key) != TYPE_STRING and typeof(key) != TYPE_STRING_NAME:
			return malformed
		keys.append(str(key))
	keys.sort()
	if keys != DIAGNOSTIC_KEYS:
		return malformed
	var owner_value: Variant = diagnostic.get("owner_id", diagnostic.get(&"owner_id"))
	var operation_value: Variant = diagnostic.get("operation", diagnostic.get(&"operation"))
	var result_value: Variant = diagnostic.get("result", diagnostic.get(&"result"))
	for header: Variant in [owner_value, operation_value]:
		if typeof(header) != TYPE_STRING and typeof(header) != TYPE_STRING_NAME:
			return malformed
		if str(header).is_empty():
			return malformed
	if typeof(result_value) != TYPE_DICTIONARY:
		return malformed
	var result := result_value as Dictionary
	if typeof(result.get("ok")) != TYPE_BOOL:
		return malformed
	var code_value: Variant = result.get("code")
	if typeof(code_value) != TYPE_STRING and typeof(code_value) != TYPE_STRING_NAME:
		return malformed
	if str(code_value).is_empty():
		return malformed
	var projected := {
		"owner_id": str(owner_value),
		"operation": str(operation_value),
		"ok": bool(result["ok"]),
		"code": str(code_value),
		"message": "",
		"details": {},
	}
	if not bool(result["ok"]):
		var message_value: Variant = result.get("message")
		if typeof(message_value) != TYPE_STRING and typeof(message_value) != TYPE_STRING_NAME:
			return malformed
		if typeof(result.get("details")) != TYPE_DICTIONARY:
			return malformed
		projected["message"] = str(message_value)
		projected["details"] = _project_value(result["details"], path + ".details", DEPTH_BUDGET, budget)
	return projected

static func _primitive_valid(value: Variant, depth: int) -> bool:
	if depth <= 0:
		return false
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_STRING:
			return true
		TYPE_FLOAT:
			return is_finite(value)
		TYPE_ARRAY:
			for element: Variant in value:
				if not _primitive_valid(element, depth - 1):
					return false
			return true
		TYPE_DICTIONARY:
			for key: Variant in (value as Dictionary):
				if typeof(key) != TYPE_STRING:
					return false
				if not _primitive_valid(value[key], depth - 1):
					return false
			return true
	return false
