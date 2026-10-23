class_name NarrativeCheckpointSchema
extends RefCounted
## Pure semantic narrative-checkpoint shape (dwm-p2r.8, Plan-05 Task 2).
##
## build() composes the exact checkpoint from a boundary plus the completed/revealed manifest
## event and its branch-validated successor. validate() re-resolves event and post_event from the
## timeline record rather than trusting saved indices, and requires an exact match. No raw paths,
## no arbitrary event objects, no Dialogic full-state.
##
## NOTE (timeline_start): the plan pins line/choice/effect/variable/marker/scene_transition/
## completion shapes explicitly and leaves timeline_start's post_event implicit; it is treated
## here as `before_event` staging the first registered event (event_index 0).

const SCHEMA_VERSION := 1

const TOP_KEYS := ["boundary", "content_fingerprint", "event", "last_committed_line_id", "post_event", "schema_version", "timeline_completed", "timeline_id"]
const BOUNDARY_KEYS := ["kind", "semantic_id", "transaction_id"]
const EVENT_KEYS := ["event_id", "event_index", "event_kind", "semantic_id"]
const POST_EVENT_KEYS := ["event_id", "event_index", "event_kind", "position", "semantic_id"]

const BOUNDARY_KINDS := ["timeline_start", "line", "choice", "effect_transaction", "variable_transaction", "safe_marker", "scene_transition", "timeline_complete"]
const POSITIONS := ["revealed_event", "before_event", "external_route", "timeline_complete"]
const NULL_SEMANTIC_KINDS := ["timeline_start", "timeline_complete"]
const TRANSACTIONAL_KINDS := ["choice", "effect_transaction", "variable_transaction", "safe_marker", "scene_transition"]
const EVENT_BEARING_KINDS := ["line", "choice", "effect_transaction", "variable_transaction", "safe_marker"]


static func build(timeline_record: Dictionary, boundary: Dictionary, event: Dictionary, post_event: Dictionary, last_committed_line_id: Variant, timeline_completed: bool) -> Dictionary:
	var checkpoint := {
		"schema_version": SCHEMA_VERSION,
		"timeline_id": str(timeline_record.get("id", "")),
		"content_fingerprint": str(timeline_record.get("content_fingerprint", "")),
		"last_committed_line_id": _copy(last_committed_line_id),
		"boundary": _copy(boundary),
		"event": _copy(event),
		"post_event": _copy(post_event),
		"timeline_completed": timeline_completed,
	}
	var validated := validate(checkpoint, timeline_record)
	if not validated.get("ok", false):
		return validated
	return {"ok": true, "code": &"ok", "value": checkpoint}


static func validate(checkpoint: Dictionary, timeline_record: Dictionary) -> Dictionary:
	if not _exact_keys(checkpoint, TOP_KEYS):
		return _fail(&"invalid_checkpoint", "top keys must be exactly " + str(TOP_KEYS))
	if checkpoint["schema_version"] != SCHEMA_VERSION:
		return _fail(&"invalid_checkpoint", "schema_version must be 1")
	if str(checkpoint["timeline_id"]) != str(timeline_record.get("id", "")):
		return _fail(&"timeline_mismatch", str(checkpoint["timeline_id"]))
	if str(checkpoint["content_fingerprint"]) != str(timeline_record.get("content_fingerprint", "")):
		return _fail(&"fingerprint_mismatch", str(checkpoint["content_fingerprint"]))
	if typeof(checkpoint["timeline_completed"]) != TYPE_BOOL:
		return _fail(&"invalid_checkpoint", "timeline_completed must be bool")
	var last_line: Variant = checkpoint["last_committed_line_id"]
	if last_line != null and (typeof(last_line) != TYPE_STRING or str(last_line).is_empty()):
		return _fail(&"invalid_checkpoint", "last_committed_line_id must be null or a nonempty string")

	var boundary: Variant = checkpoint["boundary"]
	if typeof(boundary) != TYPE_DICTIONARY or not _exact_keys(boundary, BOUNDARY_KEYS):
		return _fail(&"invalid_boundary", "boundary keys must be exactly " + str(BOUNDARY_KEYS))
	var kind := str(boundary["kind"])
	if kind not in BOUNDARY_KINDS:
		return _fail(&"invalid_boundary", "unknown kind " + kind)
	var semantic: Variant = boundary["semantic_id"]
	if kind in NULL_SEMANTIC_KINDS:
		if semantic != null:
			return _fail(&"invalid_boundary", kind + " requires a null semantic_id")
	elif typeof(semantic) != TYPE_STRING or str(semantic).is_empty():
		return _fail(&"invalid_boundary", kind + " requires a nonempty semantic_id")
	var transaction_id: Variant = boundary["transaction_id"]
	if typeof(transaction_id) != TYPE_STRING:
		return _fail(&"invalid_boundary", "transaction_id must be a string")
	if kind in TRANSACTIONAL_KINDS:
		if str(transaction_id).is_empty():
			return _fail(&"invalid_boundary", kind + " requires a nonempty transaction_id")
	elif not str(transaction_id).is_empty():
		return _fail(&"invalid_boundary", kind + " requires an empty transaction_id")

	if bool(checkpoint["timeline_completed"]) != (kind == "timeline_complete"):
		return _fail(&"invalid_checkpoint", "timeline_completed must match a timeline_complete boundary")

	var event: Variant = checkpoint["event"]
	if typeof(event) != TYPE_DICTIONARY or not _exact_keys(event, EVENT_KEYS):
		return _fail(&"invalid_event", "event keys must be exactly " + str(EVENT_KEYS))
	if kind in EVENT_BEARING_KINDS:
		var resolved := _resolve_event(event, timeline_record)
		if not resolved.get("ok", false):
			return resolved
	elif not _all_null_event(event):
		return _fail(&"invalid_event", kind + " requires a null event")

	var post_event: Variant = checkpoint["post_event"]
	if typeof(post_event) != TYPE_DICTIONARY or not _exact_keys(post_event, POST_EVENT_KEYS):
		return _fail(&"invalid_post_event", "post_event keys must be exactly " + str(POST_EVENT_KEYS))
	var position := str(post_event["position"])
	if position not in POSITIONS:
		return _fail(&"invalid_post_event", "unknown position " + position)
	if position != _expected_position(kind):
		return _fail(&"invalid_post_event", "%s requires position %s" % [kind, _expected_position(kind)])

	var post_subset := _event_subset(post_event)
	match position:
		"revealed_event":
			var pe := _resolve_event(post_subset, timeline_record)
			if not pe.get("ok", false):
				return pe
			if not _same_event(post_subset, event):
				return _fail(&"invalid_post_event", "revealed_event must equal the completed event")
		"before_event":
			var pe := _resolve_event(post_subset, timeline_record)
			if not pe.get("ok", false):
				return pe
			var successor := _check_successor(kind, event, post_subset, timeline_record)
			if not successor.get("ok", false):
				return successor
		"external_route", "timeline_complete":
			if not _all_null_event(post_subset):
				return _fail(&"invalid_post_event", position + " requires null event fields")

	return {"ok": true, "code": &"ok", "value": checkpoint.duplicate(true)}


static func _resolve_event(event: Dictionary, timeline_record: Dictionary) -> Dictionary:
	if typeof(event.get("event_id")) != TYPE_STRING or str(event["event_id"]).is_empty():
		return _fail(&"invalid_event", "event_id must be a nonempty string")
	if typeof(event.get("event_index")) != TYPE_INT:
		return _fail(&"invalid_event", "event_index must be an integer")
	if typeof(event.get("event_kind")) != TYPE_STRING:
		return _fail(&"invalid_event", "event_kind must be a string")
	if typeof(event.get("semantic_id")) != TYPE_STRING:
		return _fail(&"invalid_event", "semantic_id must be a string")
	for registered in timeline_record.get("events", []):
		if typeof(registered) != TYPE_DICTIONARY:
			continue
		if str(registered.get("event_id", "")) != str(event["event_id"]):
			continue
		if int(registered.get("event_index", -1)) != int(event["event_index"]):
			return _fail(&"event_index_mismatch", str(event["event_id"]))
		if str(registered.get("event_kind", "")) != str(event["event_kind"]):
			return _fail(&"event_kind_mismatch", str(event["event_id"]))
		if str(registered.get("semantic_id", "")) != str(event["semantic_id"]):
			return _fail(&"semantic_id_mismatch", str(event["event_id"]))
		return {"ok": true, "value": registered}
	return _fail(&"unregistered_event", str(event["event_id"]))


static func _check_successor(kind: String, event: Dictionary, post_event: Dictionary, timeline_record: Dictionary) -> Dictionary:
	if kind == "timeline_start":
		if int(post_event.get("event_index", -1)) != 0:
			return _fail(&"illegal_successor", "timeline_start must stage the first event")
		return {"ok": true}
	var registered := {}
	for candidate in timeline_record.get("events", []):
		if typeof(candidate) == TYPE_DICTIONARY and str(candidate.get("event_id", "")) == str(event.get("event_id", "")):
			registered = candidate
			break
	if registered.is_empty():
		return _fail(&"unregistered_event", str(event.get("event_id", "")))
	var legal: Array = []
	if typeof(registered.get("choice_successors")) == TYPE_DICTIONARY:
		for value in (registered["choice_successors"] as Dictionary).values():
			legal.append(str(value))
	elif registered.get("post_event_id") != null:
		legal.append(str(registered["post_event_id"]))
	if str(post_event.get("event_id", "")) not in legal:
		return _fail(&"illegal_successor", "%s -> %s" % [str(event.get("event_id", "")), str(post_event.get("event_id", ""))])
	return {"ok": true}


static func _expected_position(kind: String) -> String:
	match kind:
		"line":
			return "revealed_event"
		"timeline_start", "choice", "effect_transaction", "variable_transaction", "safe_marker":
			return "before_event"
		"scene_transition":
			return "external_route"
		"timeline_complete":
			return "timeline_complete"
	return ""


static func _event_subset(post_event: Dictionary) -> Dictionary:
	return {
		"event_id": post_event.get("event_id"),
		"event_index": post_event.get("event_index"),
		"event_kind": post_event.get("event_kind"),
		"semantic_id": post_event.get("semantic_id"),
	}


static func _same_event(left: Dictionary, right: Dictionary) -> bool:
	return str(left.get("event_id")) == str(right.get("event_id")) \
		and left.get("event_index") == right.get("event_index") \
		and str(left.get("event_kind")) == str(right.get("event_kind")) \
		and str(left.get("semantic_id")) == str(right.get("semantic_id"))


static func _all_null_event(event: Dictionary) -> bool:
	for key in EVENT_KEYS:
		if event.get(key) != null:
			return false
	return true


static func _exact_keys(target: Dictionary, keys: Array) -> bool:
	if target.size() != keys.size():
		return false
	for key in keys:
		if not target.has(key):
			return false
	return true


static func _copy(value: Variant) -> Variant:
	if typeof(value) == TYPE_DICTIONARY or typeof(value) == TYPE_ARRAY:
		return value.duplicate(true)
	return value


static func _fail(code: StringName, message: String) -> Dictionary:
	return {"ok": false, "code": code, "message": message, "details": {}}
