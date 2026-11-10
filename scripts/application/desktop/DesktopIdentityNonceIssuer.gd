class_name DesktopIdentityNonceIssuer
extends RefCounted


const _CANONICAL_WRITER := preload("res://scripts/validation/CanonicalJsonWriter.gd")

const GENERATION_PURPOSE := &"desktop_timeline_generation"
const CAUSAL_DAY_PURPOSE := &"causal_day_instance"

const CHILD_PARENT_PURPOSE := &"transaction_id"

const CHILD_KINDS: Array[String] = [
	"schedule_entry",
	"schedule_commit",
	"day7_schedule_provenance",
	"empty_schedule_done",
	"contact_source",
	"hospital_resolution",
	"condition_hospital_stage",
	"condition_hospital_retirement",
	"hospital_miss",
	"sylvia_hospital_witness",
	"day_resolution_stage",
	"board_command",
	"board_start",
	"shop_quote",
	"desktop_action",
	"causal_sequence",
	"condition",
	"board_fate",
	"destination_intent",
	"notification_intent",
	"continuation_operation",
	"warning",
	"navigation",
	"terminal_intent",
	"action_consequence",
	"scene_day_completion",
]

const CHILD_REQUEST_KEYS: Array[String] = [
	"child_kind",
	"ordinal",
	"parent_receipt_id",
	"source_ids",
]

const PROVENANCE_KEYS: Array[String] = [
	"child_id",
	"child_kind",
	"ordinal",
	"parent_receipt_id",
	"schema_version",
	"source_ids",
]

const CHILD_SCHEMA_VERSION := 1

var _root: Object = null



func configure(root_store: Object) -> Dictionary:
	if root_store == null:
		return _failed(&"issuer_configure_invalid", "configure requires a root store")
	if _root != null and _root != root_store:
		return _failed(&"issuer_already_configured", "configure may not replace a retained root")
	_root = root_store
	return {"ok": true}


func issue(purpose: StringName) -> Dictionary:
	var ready := _require_configured("issue")
	if not ready.get("ok", false):
		return ready
	if purpose == GENERATION_PURPOSE:
		return _failed(&"generation_allocation_required",
			"a desktop timeline generation is allocated, never issued directly")
	if purpose == CAUSAL_DAY_PURPOSE:
		return _failed(&"causal_day_advance_allocation_required",
			"a causal day instance is allocated, never issued directly")
	var issued: Dictionary = _root.call(&"issue", purpose)
	return issued


func issue_deferred(purpose: StringName) -> Dictionary:
	var ready := _require_configured("issue_deferred")
	if not ready.get("ok", false):
		return ready
	if purpose == GENERATION_PURPOSE:
		return _failed(&"generation_allocation_required",
			"a desktop timeline generation is allocated, never issued directly")
	if purpose == CAUSAL_DAY_PURPOSE:
		return _failed(&"causal_day_advance_allocation_required",
			"a causal day instance is allocated, never issued directly")
	var issued: Dictionary = _root.call(&"issue_deferred", purpose)
	return issued


func flush() -> Dictionary:
	var ready := _require_configured("flush")
	if not ready.get("ok", false):
		return ready
	var flushed: Dictionary = _root.call(&"flush")
	return flushed


func verify_issued(receipt: Dictionary, expected_purpose: StringName) -> Dictionary:
	var ready := _require_configured("verify_issued")
	if not ready.get("ok", false):
		return ready
	var proven: Dictionary = _root.call(&"verify_receipt", receipt, expected_purpose)
	return proven


func derive_child(request: Dictionary) -> Dictionary:
	var ready := _require_configured("derive_child")
	if not ready.get("ok", false):
		return ready
	var shaped := _exact_keys(request, CHILD_REQUEST_KEYS)
	if not shaped.get("ok", false):
		return shaped
	var child_kind := str(request["child_kind"])
	var ordinal_check := _validate_child_shape(child_kind, request["ordinal"], request["source_ids"])
	if not ordinal_check.get("ok", false):
		return ordinal_check
	var parent := _resolve_parent(str(request["parent_receipt_id"]))
	if not parent.get("ok", false):
		return parent
	var derived := _child_id(parent["value"], child_kind, int(request["ordinal"]),
		request["source_ids"])
	if not derived.get("ok", false):
		return derived
	var provenance := {
		"schema_version": CHILD_SCHEMA_VERSION,
		"parent_receipt_id": str(request["parent_receipt_id"]),
		"child_kind": child_kind,
		"ordinal": int(request["ordinal"]),
		"source_ids": (request["source_ids"] as Array).duplicate(true),
		"child_id": str(derived["value"]),
	}
	return {
		"ok": true,
		"value": {"child_id": str(derived["value"]), "provenance": provenance.duplicate(true)},
		"receipt": provenance.duplicate(true),
	}


func validate_child(provenance: Dictionary, expected_kind: StringName) -> Dictionary:
	var ready := _require_configured("validate_child")
	if not ready.get("ok", false):
		return ready
	var shaped := _exact_keys(provenance, PROVENANCE_KEYS)
	if not shaped.get("ok", false):
		return shaped
	if int(provenance["schema_version"]) != CHILD_SCHEMA_VERSION:
		return _failed(&"child_provenance_malformed", "unexpected provenance schema_version")
	var child_kind := str(provenance["child_kind"])
	if child_kind != String(expected_kind):
		return _failed(&"child_kind_mismatch", child_kind)
	var shape := _validate_child_shape(child_kind, provenance["ordinal"], provenance["source_ids"])
	if not shape.get("ok", false):
		return shape
	var parent := _resolve_parent(str(provenance["parent_receipt_id"]))
	if not parent.get("ok", false):
		return parent
	var derived := _child_id(parent["value"], child_kind, int(provenance["ordinal"]),
		provenance["source_ids"])
	if not derived.get("ok", false):
		return derived
	if str(provenance["child_id"]) != str(derived["value"]):
		return _failed(&"child_id_not_reproducible", str(provenance["child_id"]))
	return {"ok": true, "value": {"provenance": provenance.duplicate(true)}}


func prepare_continuation_allocation(request: Dictionary) -> Dictionary:
	var ready := _require_configured("prepare_continuation_allocation")
	if not ready.get("ok", false):
		return ready
	var prepared: Dictionary = _root.call(&"prepare_allocation", request)
	if not prepared.get("ok", false):
		return prepared
	return {"ok": true, "value": (prepared.get("value", {}) as Dictionary).duplicate(true)}


func commit_continuation_allocation(candidate: Dictionary) -> Dictionary:
	var ready := _require_configured("commit_continuation_allocation")
	if not ready.get("ok", false):
		return ready
	var committed: Dictionary = _root.call(&"commit_allocation", candidate)
	if not committed.get("ok", false):
		return committed
	return {"ok": true, "value": committed.get("value", {})}


func prepare_causal_day_advance(request: Dictionary) -> Dictionary:
	var ready := _require_configured("prepare_causal_day_advance")
	if not ready.get("ok", false):
		return ready
	var prepared: Dictionary = _root.call(&"prepare_causal_day_advance", request)
	return prepared


func commit_causal_day_advance(candidate: Dictionary) -> Dictionary:
	var ready := _require_configured("commit_causal_day_advance")
	if not ready.get("ok", false):
		return ready
	var committed: Dictionary = _root.call(&"commit_causal_day_advance", candidate)
	return committed


func capture_root() -> Dictionary:
	var ready := _require_configured("capture_root")
	if not ready.get("ok", false):
		return ready
	var captured: Dictionary = _root.call(&"capture")
	return captured



func _resolve_parent(parent_receipt_id: String) -> Dictionary:
	var captured: Dictionary = _root.call(&"capture")
	if not captured.get("ok", false):
		return captured
	var receipts: Dictionary = (captured.get("value", {}) as Dictionary).get("receipts", {})
	if not receipts.has(parent_receipt_id):
		return _failed(&"child_parent_absent", parent_receipt_id)
	var parent: Dictionary = receipts[parent_receipt_id]
	var proven: Dictionary = _root.call(&"verify_receipt", parent, CHILD_PARENT_PURPOSE)
	if not proven.get("ok", false):
		return proven
	return {"ok": true, "value": parent}


func _child_id(parent: Dictionary, child_kind: String, ordinal: int, source_ids: Variant) -> Dictionary:
	var canonical: Dictionary = _CANONICAL_WRITER.stringify(source_ids)
	if not canonical.get("ok", false):
		return _failed(&"child_source_ids_malformed",
			str(canonical.get("message", "source IDs are not canonically representable")))
	return {"ok": true, "value": "%s.%s" % [
		child_kind,
		_sha256_hex("desktop_child_v1\n%s\n%d\n%s\n%s\n%d\n%s" % [
			str(parent.get("namespace", "")),
			int(parent.get("counter", 0)),
			str(parent.get("receipt_id", "")),
			child_kind,
			ordinal,
			str(canonical.get("value", "")),
		]),
	]}


func _validate_child_shape(child_kind: String, ordinal: Variant, source_ids: Variant) -> Dictionary:
	if not CHILD_KINDS.has(child_kind):
		return _failed(&"child_kind_unregistered", child_kind)
	if typeof(ordinal) != TYPE_INT or int(ordinal) < 0:
		return _failed(&"child_ordinal_invalid", str(ordinal))
	if typeof(source_ids) != TYPE_ARRAY:
		return _failed(&"child_source_ids_malformed", "source IDs must be an array")
	var values: Array = source_ids
	var previous := ""
	for index in range(values.size()):
		if typeof(values[index]) != TYPE_STRING:
			return _failed(&"child_source_ids_malformed", "source IDs must be strings")
		var current := str(values[index])
		if current.strip_edges().is_empty():
			return _failed(&"child_source_ids_blank", "source IDs must be nonblank")
		if index > 0 and current <= previous:
			return _failed(&"child_source_ids_unsorted", current)
		previous = current
	return {"ok": true}



func _require_configured(method: String) -> Dictionary:
	if _root == null:
		return _failed(&"issuer_not_configured", "DesktopIdentityNonceIssuer.%s before configure" % method)
	return {"ok": true}


func _exact_keys(value: Dictionary, expected: Array) -> Dictionary:
	if value.size() != expected.size():
		return _failed(&"request_member_set_invalid",
			"expected %d members, saw %d" % [expected.size(), value.size()])
	for key in expected:
		if not value.has(key):
			return _failed(&"request_member_set_invalid", "missing " + str(key))
	return {"ok": true}


static func _sha256_hex(text: String) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(text.to_utf8_buffer())
	return context.finish().hex_encode()


func _failed(code: StringName, message: String) -> Dictionary:
	return {"ok": false, "code": code, "message": "DesktopIdentityNonceIssuer: " + message}
