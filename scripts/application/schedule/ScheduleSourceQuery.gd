class_name ScheduleSourceQuery
extends RefCounted

## Pure read projection of a trusted Contacts-owner snapshot. Receipt linkage is
## validated here; issuer authentication and restore admission remain with its
## existing owners. These action/receipt IDs are command data, never display copy.

const _CONTACTS := preload("res://scripts/domain/contact/ContactInvitationState.gd")
const _ORDINARY := ["training", "working", "rest"]
const _DAY7_PARTICIPANTS := ["priscilla", "lavinia", "sylvia"]


static func project(contacts: Dictionary, day: int, registry: Object,
		fingerprint: String) -> Dictionary:
	if day < 1 or day > 7:
		return _fail(&"invalid_day")
	var state_check: Dictionary = _CONTACTS.validate_state(contacts)
	if not state_check.get("ok", false):
		return state_check
	if registry == null or not registry.has_method("snapshot") \
			or not registry.has_method("lookup") or fingerprint.is_empty():
		return _fail(&"invalid_registry")
	var snapshot: Dictionary = registry.snapshot(fingerprint)
	if not snapshot.get("ok", false):
		return snapshot

	var sources: Array = []
	if day < 7:
		for action_id: String in _ORDINARY:
			var found: Dictionary = registry.lookup(action_id, fingerprint)
			if not found.get("ok", false):
				return found
			var record: Dictionary = found["value"]["record"]
			if day not in record["allowed_days"]:
				return _fail(&"ordinary_source_not_day_eligible")
			sources.append({"action_id": action_id, "source_receipt_id": null})

	var invitations: Array = []
	for receipt_id: Variant in contacts["schedule_source_receipts"]:
		if typeof(receipt_id) != TYPE_STRING:
			return _fail(&"invalid_schedule_source_index")
		var receipt: Dictionary = contacts["schedule_source_receipts"][receipt_id]
		var action_id := str(receipt["action_id"])
		if not _CONTACTS.is_date_addable(contacts, action_id):
			continue
		var found: Dictionary = registry.lookup(action_id, fingerprint)
		if not found.get("ok", false):
			return found
		var record: Dictionary = found["value"]["record"]
		if day not in record["allowed_days"]:
			continue
		var validated: Dictionary = _CONTACTS.validate_schedule_source_receipt(
			contacts, receipt_id, record, day)
		if not validated.get("ok", false):
			return validated
		var order := _generation_order(contacts, action_id, record)
		if order < 1:
			return _fail(&"invitation_generation_order_unavailable")
		var participant_order := _participant_order(record)
		if day == 7 and participant_order < 0:
			return _fail(&"invalid_day7_participant")
		invitations.append({
			"action_id": action_id,
			"source_receipt_id": receipt_id,
			"generation_order": order,
			"participant_order": participant_order,
		})

	if day == 7:
		invitations.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
			return int(left["participant_order"]) < int(right["participant_order"]))
	else:
		invitations.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
			return int(left["generation_order"]) < int(right["generation_order"]))
		for index: int in range(1, invitations.size()):
			if invitations[index - 1]["generation_order"] == invitations[index]["generation_order"]:
				return _fail(&"ambiguous_invitation_generation_order")
	for invitation: Dictionary in invitations:
		sources.append({
			"action_id": invitation["action_id"],
			"source_receipt_id": invitation["source_receipt_id"],
		})
	return _ok(sources)


static func _generation_order(contacts: Dictionary, action_id: String,
		record: Dictionary) -> int:
	if record["action_kind"] == "solo":
		var action: Dictionary = contacts["solo_actions"].get(action_id, {})
		var message_id := str(action.get("offer_message_id", ""))
		var participant := str(record["participants"][0])
		for message: Dictionary in contacts["messages"][participant]:
			if message["message_id"] == message_id:
				return int(message["sequence"])
		return 0
	var sequences: Array = []
	for participant: String in record["participants"]:
		for message: Dictionary in contacts["messages"][participant]:
			if message["type"] == "group_offer" \
					and message["parameters"].get("action_id") == action_id:
				sequences.append(int(message["sequence"]))
	if sequences.size() != record["participants"].size():
		return 0
	sequences.sort()
	for index: int in range(1, sequences.size()):
		if sequences[index] == sequences[index - 1]:
			return 0
	return int(sequences[0])


static func _participant_order(record: Dictionary) -> int:
	if record["action_kind"] != "solo" or record["participants"].size() != 1:
		return -1
	return _DAY7_PARTICIPANTS.find(record["participants"][0])


static func _ok(sources: Array) -> Dictionary:
	return {"ok": true, "code": &"ok", "value": {"sources": sources}, "receipt": {}}


static func _fail(code: StringName) -> Dictionary:
	return {"ok": false, "code": code, "details": {}}
