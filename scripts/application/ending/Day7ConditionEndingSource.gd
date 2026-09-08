class_name Day7ConditionEndingSource
extends RefCounted

## Read-only admission of the existing terminal destination outbox. The policy receipt freezes
## pre-action invitation reads; later Contacts reads cannot choose a different ending on retry.
const CONSEQUENCE := preload("res://scripts/domain/desktop/DesktopConsequenceState.gd")
const ACTION := preload("res://scripts/domain/desktop/DesktopActionReceipt.gd")
const CONTACTS := preload("res://scripts/domain/contact/ContactInvitationState.gd")
const JSON_WRITER := preload("res://scripts/validation/CanonicalJsonWriter.gd")
const CONDITION_KEYS := ["action_commit_receipt_id", "action_commit_receipt_provenance",
	"causal_day_instance", "causal_sequence", "causal_sequence_receipt_id",
	"causal_sequence_receipt_provenance", "condition_after", "danger", "day", "decision",
	"receipt_id", "receipt_provenance", "source_receipt_ids", "sylvia_read_receipt_id", "trigger"]
const DESTINATION_KEYS := ["accepted_unfulfilled_sources", "causal_day_instance", "day",
	"intent_id", "intent_id_provenance", "kind", "prerequisite_receipt_ids",
	"source_condition_receipt_id", "source_condition_receipt_provenance", "terminal_cause",
	"terminal_provenance"]
const CAUSES := {"day7_dark_alone": "dark_mode_alone",
	"day7_sylvia_special": "sylvia_special", "day7_hospital_alone": "hospital_alone"}


static func validate(state: Dictionary, lifecycle: Dictionary, schedule: Dictionary,
		contacts: Dictionary, issuer: Object) -> Dictionary:
	if issuer == null or not issuer.has_method("verify_issued") or not issuer.has_method("validate_child"):
		return _fail("identity issuer is unavailable")
	if lifecycle.get("state") != "PLAYING" or lifecycle.get("day") != 7 \
			or lifecycle.get("ending_plan") != null or lifecycle.get("active_condition_hospital_plan") != null:
		return _fail("a condition ending requires pre-Done Day 7")
	if schedule.get("commit_receipt") != null:
		return _fail("Schedule Done already committed")
	var prior: Variant = lifecycle.get("active_resolution_plan")
	if prior is Dictionary:
		if int(prior.get("source_day", 7)) >= 7: return _fail("Day 7 resolution already started")
		for stage: Dictionary in prior.get("stages", []):
			if stage.get("state") != "completed": return _fail("the preceding day is incomplete")
	var valid: Dictionary = CONSEQUENCE.validate(state)
	if not valid.get("ok", false): return valid
	if state.pending != null: return _fail("the source action has not completed cleanup")
	var raw: Variant = state.outbox.get("hospital")
	if not raw is Dictionary or raw.size() != 9: return _fail("a complete durable destination record is required")
	var record: Dictionary = raw
	if record.consumer != "day7_terminal" or record.status != "pending":
		return _fail("the destination is not an unconsumed Day 7 terminal result")
	var action: Dictionary = record.action_receipt
	valid = ACTION.validate(action)
	if not valid.get("ok", false): return valid
	for key: String in ["run_id", "branch_id", "desktop_timeline_generation", "causal_day_instance", "day"]:
		if action[key] != lifecycle.get(key): return _fail("the action belongs to another " + key)
	if state.causal_day_instance != action.causal_day_instance \
			or state.causal_day_instance_issuer_receipt != lifecycle.get("causal_day_instance_issuer_receipt") \
			or record.causal_sequence != state.causal_sequence or int(record.causal_sequence) < 1:
		return _fail("the outbox is not the current completed causal action")
	valid = issuer.verify_issued(action.transaction_issuer_receipt, &"transaction_id")
	if not valid.get("ok", false): return valid
	if action.transaction_id != action.transaction_issuer_receipt.get("token"):
		return _fail("the action transaction differs from its issued root")
	var parent_id: String = str(action.transaction_issuer_receipt.receipt_id)
	if action.action_id != action.commit_receipt_id or action.action_id_provenance != action.commit_receipt_provenance:
		return _fail("the desktop commit identity differs from its action")
	valid = _child(issuer, action.action_id_provenance, action.action_id, "desktop_action", parent_id)
	if not valid.get("ok", false): return valid
	var sources: Array = action.action_id_provenance.source_ids
	if sources.size() != 3 or not sources.has(action.action_kind) or not sources.has(action.source_commit_receipt_id):
		return _fail("the action has different source ancestry")
	var source_kind := "shop_quote" if action.action_kind == "shop_purchase" else "board_start"
	valid = _child(issuer, action.source_commit_receipt_provenance, action.source_commit_receipt_id, source_kind)
	if not valid.get("ok", false): return valid

	var condition: Dictionary = record.condition_receipt
	var destination: Dictionary = record.payload
	if not _exact(condition, CONDITION_KEYS) or not _exact(destination, DESTINATION_KEYS):
		return _fail("the frozen condition or destination member set is invalid")
	if condition.day != 7 or condition.causal_day_instance != action.causal_day_instance \
			or condition.causal_sequence != record.causal_sequence or condition.condition_after != action.condition_after \
			or condition.action_commit_receipt_id != action.commit_receipt_id \
			or condition.action_commit_receipt_provenance != action.commit_receipt_provenance:
		return _fail("the condition describes another action")
	if condition.danger != true or condition.trigger != true \
			or not bool(action.condition_after.carried_sequela) \
			or (int(action.condition_after.pressure) < 10 and int(action.condition_after.health) > 0):
		return _fail("the receipted condition did not trigger a departure")
	# The production causal sequence is a content identity, not an issuer child. Reconstruct
	# its exact preimage from the retained action and the current consequence counters.
	var sequence := {"transaction_id": action.transaction_id,
		"transaction_issuer_receipt": action.transaction_issuer_receipt, "run_id": action.run_id,
		"branch_id": action.branch_id, "desktop_timeline_generation": action.desktop_timeline_generation,
		"causal_day_instance": action.causal_day_instance, "source_kind": action.action_kind,
		"source_commit_receipt_id": action.commit_receipt_id,
		"source_commit_receipt_provenance": action.commit_receipt_provenance,
		"causal_sequence": state.causal_sequence, "run_revision": state.run_revision}
	if condition.causal_sequence_receipt_id != "causal_sequence_receipt." + _hash(sequence) \
			or condition.causal_sequence_receipt_provenance != {"kind": "causal_sequence",
				"transaction_id": action.transaction_id, "causal_sequence": state.causal_sequence,
				"run_revision": state.run_revision}:
		return _fail("the sequence receipt is not the completed action's content identity")
	valid = _child(issuer, condition.receipt_provenance, condition.receipt_id, "condition", parent_id,
		[_projection("action_commit_receipt_id", action.commit_receipt_id),
		_projection("causal_sequence_receipt_id", condition.causal_sequence_receipt_id)])
	if not valid.get("ok", false): return valid
	valid = _validate_read_sources(condition, action, contacts, issuer)
	if not valid.get("ok", false): return valid
	var decision := "day7_dark_alone" if bool(lifecycle.get("dark_mode", false)) else (
		"day7_sylvia_special" if condition.sylvia_read_receipt_id != null else "day7_hospital_alone")
	if condition.decision != decision or destination.terminal_cause != CAUSES[decision]:
		return _fail("the destination contradicts the frozen read receipt or captured Dark Mode")
	var prerequisites: Array = [action.commit_receipt_id, condition.receipt_id]
	prerequisites.sort()
	if destination.kind != "day7_terminal" or destination.day != 7 \
			or destination.causal_day_instance != action.causal_day_instance \
			or destination.source_condition_receipt_id != condition.receipt_id \
			or destination.source_condition_receipt_provenance != condition.receipt_provenance \
			or destination.accepted_unfulfilled_sources != [] or destination.terminal_provenance != null \
			or destination.prerequisite_receipt_ids != prerequisites \
			or record.key != destination.intent_id or record.provenance != destination.intent_id_provenance:
		return _fail("the terminal destination has different prerequisites or identity")
	valid = _child(issuer, destination.intent_id_provenance, destination.intent_id, "destination_intent", parent_id,
		[_projection("condition_receipt_id", condition.receipt_id),
		_projection("action_commit_receipt_id", action.commit_receipt_id)])
	if not valid.get("ok", false): return valid
	return {"ok": true, "code": &"ok", "value": {
		"terminal_cause": str(destination.terminal_cause),
		"sylvia_read_receipt_id": condition.sylvia_read_receipt_id,
		"transaction_issuer_receipt": action.transaction_issuer_receipt.duplicate(true),
		"publication_request": {"kind": "hospital", "key": record.key, "payload_hash": record.payload_hash,
			"provenance": record.provenance.duplicate(true), "consumer": "day7_terminal"}}}


static func _validate_read_sources(condition: Dictionary, action: Dictionary,
		contacts: Dictionary, issuer: Object) -> Dictionary:
	var valid: Dictionary = CONTACTS.validate_state(contacts)
	if not valid.get("ok", false): return valid
	if not condition.source_receipt_ids is Array: return _fail("the read source list is malformed")
	var previous := ""
	var sylvia: Variant = null
	for raw: Variant in condition.source_receipt_ids:
		if not raw is String or str(raw) <= previous: return _fail("read sources must be sorted and unique")
		previous = str(raw)
		valid = CONTACTS.get_schedule_source_receipt(contacts, previous)
		if not valid.get("ok", false): return valid
		var source: Dictionary = valid.value.receipt
		if source.day != 7 or action.unlock_receipt_ids.has(previous) \
				or action.unlock_receipt_ids.has(source.previous_receipt_id):
			return _fail("the claimed read was not available before this Day 7 action")
		valid = _child(issuer, source.receipt_provenance, previous, "contact_source")
		if not valid.get("ok", false): return valid
		if source.participants == ["sylvia"]:
			if sylvia != null: return _fail("multiple Sylvia read identities are ambiguous")
			sylvia = previous
	if condition.sylvia_read_receipt_id != sylvia:
		return _fail("Sylvia eligibility differs from the frozen read source list")
	return {"ok": true}


static func _child(issuer: Object, raw: Variant, child_id: Variant, kind: String,
		parent_id: String = "", projections: Array = []) -> Dictionary:
	if not raw is Dictionary or raw.get("child_id") != child_id or raw.get("ordinal") != 0:
		return _fail("the " + kind + " identity is malformed")
	if not parent_id.is_empty() and raw.get("parent_receipt_id") != parent_id:
		return _fail("the " + kind + " belongs to another transaction root")
	if not projections.is_empty():
		projections.sort()
		if raw.get("source_ids") != projections: return _fail("the " + kind + " projects different sources")
	return issuer.validate_child(raw, StringName(kind))


static func _exact(value: Dictionary, expected: Array) -> bool:
	var keys: Array = value.keys()
	keys.sort()
	return keys == expected


static func _projection(key: String, value: Variant) -> String:
	return key + "=" + str(JSON_WRITER.stringify(value).value)


static func _hash(value: Dictionary) -> String:
	var encoded: Dictionary = JSON_WRITER.stringify(value)
	return str(encoded.value).sha256_text() if encoded.get("ok", false) else ""


static func _fail(message: String) -> Dictionary:
	return {"ok": false, "code": &"day7_condition_source_invalid", "message": message}
