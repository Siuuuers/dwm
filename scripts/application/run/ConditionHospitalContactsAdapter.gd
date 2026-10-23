class_name ConditionHospitalContactsAdapter
extends RefCounted

## Closes the frozen, already accepted sources. No draft Schedule is committed and no
## date outcome or Sylvia relationship change is fabricated by a Hospital visit.
const CONTACTS := preload("res://scripts/domain/contact/ContactInvitationState.gd")
const CANON := preload("res://scripts/validation/CanonicalJsonWriter.gd")

static func prepare(contacts: Dictionary, plan: Dictionary, issuer: Object) -> Dictionary:
	var valid: Dictionary = CONTACTS.validate_state(contacts)
	if not valid.get("ok", false): return valid
	var detached := contacts.duplicate(true)
	var source_ids: Array = []
	var misses: Array = []
	var witness: Variant = null
	var resolution: Dictionary = plan.resolution_receipt
	var resolution_id := str(resolution.receipt_id)
	var provenance: Dictionary = resolution.receipt_provenance
	var proven: Dictionary = issuer.validate_child(provenance, &"hospital_resolution")
	if not proven.get("ok", false): return proven
	if provenance.child_id != resolution_id:
		return _fail(&"condition_hospital_resolution_mismatch")
	# Derived IDs are not root-ledger entries. Every child uses the verified transaction
	# parent; the frozen resolution remains part of its explicit semantic source set.
	var root_id := str(provenance.parent_receipt_id)
	var sources: Array = plan.accepted_sources
	for index: int in range(sources.size()):
		var source: Dictionary = sources[index]
		var found: Dictionary = CONTACTS.get_schedule_source_receipt(contacts, str(source.receipt_id))
		if not found.get("ok", false): return found
		var receipt: Dictionary = found.value.receipt
		if receipt.action_id != source.action_id or int(receipt.day) != int(plan.source_day):
			return _fail(&"condition_hospital_source_mismatch")
		var action: Dictionary = contacts.solo_actions.get(source.action_id, contacts.group_action)
		if action.get("action_id") != source.action_id or action.get("state") != "ACCEPTED":
			return _fail(&"condition_hospital_source_already_closed")
		var miss_sources: Array = [resolution_id, str(source.receipt_id), str(source.action_id)]
		miss_sources.sort()
		var derived: Dictionary = issuer.derive_child({"child_kind": "hospital_miss",
			"parent_receipt_id": root_id, "ordinal": index, "source_ids": miss_sources})
		if not derived.get("ok", false): return derived
		var miss := {"receipt_id": str(derived.value.child_id),
			"receipt_provenance": derived.value.provenance.duplicate(true),
			"source_receipt_id": str(source.receipt_id), "action_id": str(source.action_id),
			"day": int(plan.source_day), "participants": receipt.participants.duplicate(true),
			"missed_reason": "hospital"}
		misses.append(miss)
		source_ids.append(str(source.receipt_id))
		if receipt.participants == ["sylvia"]:
			var witness_sources: Array = [resolution_id, str(source.receipt_id), str(miss.receipt_id)]
			witness_sources.sort()
			var derived_witness: Dictionary = issuer.derive_child({"child_kind": "sylvia_hospital_witness",
				"parent_receipt_id": root_id, "ordinal": index, "source_ids": witness_sources})
			if not derived_witness.get("ok", false): return derived_witness
			witness = {"kind": "sylvia_hospital_witness", "resolution_kind": "condition_hospital",
				"receipt_id": str(derived_witness.value.child_id),
				"receipt_provenance": derived_witness.value.provenance.duplicate(true),
				"resolution_receipt_id": resolution_id, "action_id": str(source.action_id),
				"source_receipt_id": str(source.receipt_id), "hospital_miss_receipt_id": str(miss.receipt_id),
				"care_followup_day": int(plan.source_day) + 1,
				"care_followup_entry_id": "care.sylvia.day%d" % (int(plan.source_day) + 1),
				"affection_delta": 2, "dark_delta": 1, "attitude": "fixated",
				"tier_transition": "advance_one_or_stay_love"}
			detached.sylvia_hospital_witness_receipts[witness.receipt_id] = witness
	# The canonical closure owner also expires unread invitations and classifies the
	# Day-2/6 pair window. Its receipt freezes that classification for later stages.
	var closed: Dictionary = CONTACTS.prepare_resolve_day_end(detached, int(plan.source_day),
		{"solo_attended_action_ids": [], "group_outcome": "prevented_by_fainting"}, resolution_id)
	if not closed.get("ok", false): return closed
	var validated: Dictionary = CONTACTS.validate_state(closed.value.candidate)
	if not validated.get("ok", false): return validated
	var miss_ids: Array = []
	for miss: Dictionary in misses: miss_ids.append(str(miss.receipt_id))
	source_ids.sort()
	miss_ids.sort()
	return {"ok": true, "value": {"contacts": closed.value.candidate, "misses": misses,
		"output": {"source_receipt_ids": source_ids, "miss_receipt_ids": miss_ids,
			"misses": misses, "sylvia_witness": witness, "closure_receipt": closed.receipt,
			"pl_window": closed.receipt.pl_window}}}

static func _fail(code: StringName) -> Dictionary:
	return {"ok": false, "code": code, "message": str(code), "details": {}}