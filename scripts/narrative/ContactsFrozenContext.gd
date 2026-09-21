class_name ContactsFrozenContext
extends RefCounted

## Presentation facts accompany their causal Contacts generation. Existing snapshots
## are never rebuilt from later relationship values or the next day's group action.
const FROZEN := preload("res://scripts/narrative/FrozenPresentationContext.gd")
const CONTACTS := preload("res://scripts/domain/contact/ContactInvitationState.gd")
const RELATIONSHIP := preload("res://scripts/domain/relationship/ProvisionalProgressionRules.gd")
const ORDINARY := preload("res://scripts/domain/contact/OrdinaryReplyEchoState.gd")
const CACHE_KEY := "contacts_frozen_contexts_v1"
const ROLES := ["ordinary_message", "solo_invitation_offer", "ending_invitation_offer",
	"group_contact_offer", "consequence_followup", "echo_fallback"]

static func empty_cache() -> Dictionary:
	return {"schema_version": 1, "entries": {}}

static func key_for(presentation: Dictionary) -> String:
	var fields: Dictionary = presentation.get("fields", {})
	var entry_id: String = str(fields.get("entry_id", ""))
	if fields.get("entry_role") == "ordinary_message": return entry_id + "|" + str(fields.get("phase", ""))
	if fields.get("entry_role") == "echo_fallback":
		var echoes: Array = fields.get("due_echoes", [])
		return entry_id + "|" + str(echoes[0].get("echo_id", "")) if echoes.size() == 1 else ""
	return entry_id

static func immutable_snapshot(presentation: Dictionary) -> Dictionary:
	var detached := presentation.duplicate(true)
	FROZEN._freeze(detached)
	return detached

static func read(cache: Dictionary, entry_id: String, suffix: String = "") -> Dictionary:
	var key := entry_id + ("|" + suffix if not suffix.is_empty() else "")
	var presentation: Variant = cache.get("entries", {}).get(key)
	var checked := FROZEN.validate(entry_id, presentation)
	if not checked.ok: return _fail(&"contacts_frozen_snapshot_missing")
	return _ok(immutable_snapshot(checked.value))

static func offer(entry_id: String, relationship: Dictionary, attitude: String) -> Dictionary:
	var fields := _constants(entry_id)
	if fields.is_empty() or fields.entry_role not in ["solo_invitation_offer", "ending_invitation_offer"]:
		return _fail(&"contacts_frozen_entry_unavailable")
	var facts := _relationship(relationship, attitude)
	if not facts.ok: return facts
	fields.merge(facts.value)
	return FROZEN.build(entry_id, fields)

static func ordinary_awaiting(entry_id: String, relationship: Dictionary, attitude: String) -> Dictionary:
	var fields := _constants(entry_id)
	if fields.is_empty() or fields.entry_role != "ordinary_message": return _fail(&"contacts_frozen_entry_unavailable")
	var facts := _relationship(relationship, attitude)
	if not facts.ok: return facts
	fields.merge(facts.value)
	fields.merge({"phase": "awaiting_reply", "due_echoes": [], "selected_reply_id": null, "witnessed_line_id": null})
	return FROZEN.build(entry_id, fields)

static func ordinary_selected(awaiting: Dictionary, receipt: Dictionary) -> Dictionary:
	var entry_id := str(receipt.get("entry_id", ""))
	var checked := FROZEN.validate(entry_id, awaiting)
	if not checked.ok or awaiting.fields.get("phase") != "awaiting_reply": return _fail(&"contacts_frozen_awaiting_missing")
	var receipt_checked := ORDINARY.validate_receipt(receipt)
	if not receipt_checked.ok or receipt.get("kind") != "ordinary_reply": return _fail(&"contacts_frozen_reply_source_invalid")
	var fields: Dictionary = awaiting.fields.duplicate(true)
	fields.merge({"phase": "after_selection", "selected_reply_id": receipt.reply_id,
		"witnessed_line_id": receipt.witnessed_line_id}, true)
	return FROZEN.build(entry_id, fields)

static func echo_card(echo: Dictionary) -> Dictionary:
	return FROZEN.build("echo.fallback.day7", {"entry_id": "echo.fallback.day7",
		"entry_role": "echo_fallback", "day": 7, "due_echoes": [{"echo_id": echo.get("echo_id"),
		"presentation_atom_id": echo.get("presentation_atom_id")}]})

## Call within the authoritative mutation, before its existing checkpoint. Only new
## generation rows may sample live relationships; an old missing offer fails closed.
static func capture_generation(before: Dictionary, candidate: Dictionary, source_day: int,
		relationships: Dictionary, attitudes: Dictionary, cache: Dictionary, missed: Array = []) -> Dictionary:
	var checked := validate_cache(cache, before, false, missed, source_day)
	if not checked.ok: return checked
	var detached := cache.duplicate(true)
	for friend: String in CONTACTS.FRIEND_IDS:
		for message: Dictionary in candidate.get("messages", {}).get(friend, []):
			if _message_existed(before.get("messages", {}).get(friend, []), message): continue
			var built := for_message(candidate, friend, message, relationships, attitudes, detached, missed)
			if not built.ok: return built
			if built.value.fields.entry_role in ["solo_invitation_offer", "ending_invitation_offer"] \
					and int(message.target_day) != source_day: return _fail(&"contacts_frozen_historical_offer_missing")
			var retained := retain(detached, built.value)
			if not retained.ok: return retained
			detached = retained.value
	for transaction_id: String in candidate.get("transaction_receipts", {}):
		if before.get("transaction_receipts", {}).has(transaction_id): continue
		var receipt: Dictionary = candidate.transaction_receipts[transaction_id]
		if receipt.get("kind") not in ["activate_group", "open_group_first"]: continue
		var variation := "offer" if receipt.kind == "activate_group" else "need_reply_%s_first" % str(receipt.friend_id)
		var group := {"state": "AVAILABLE_UNOPENED" if variation == "offer" else "REPLY_REQUIRED",
			"inviter_id": null if variation == "offer" else receipt.friend_id,
			"opened_ids": [] if variation == "offer" else [receipt.friend_id], "replied_ids": []}
		var built := _group_context("contact.invitation.group.priscilla_lavinia.day%d.%s" % [int(receipt.day), variation], variation, null, group)
		if not built.ok: return built
		var retained := retain(detached, built.value)
		if not retained.ok: return retained
		detached = retained.value
	for witness_id: String in candidate.get("sylvia_hospital_witness_receipts", {}):
		if before.get("sylvia_hospital_witness_receipts", {}).has(witness_id): continue
		var message := _care_message(witness_id, candidate.sylvia_hospital_witness_receipts[witness_id])
		var built := _followup(candidate, "sylvia", message, entry_id_for_message(candidate, "sylvia", message), missed)
		if not built.ok: return built
		var retained := retain(detached, built.value)
		if not retained.ok: return retained
		detached = retained.value
	return _ok(detached)

## All detached producers call this before constructing their durable checkpoint.
static func capture_candidate(before: Dictionary, candidate: Dictionary, gameplay: Dictionary, source_day: int) -> Dictionary:
	var route: Dictionary = gameplay.get("route_context", {}).duplicate(true)
	var captured := capture_generation(before, candidate, source_day,
		gameplay.get("dating_route_state", {}), gameplay.get("friend_attitude", {}),
		route.get(CACHE_KEY, empty_cache()), gameplay.get("missed_invitations", []))
	if not captured.ok: return captured
	route[CACHE_KEY] = captured.value
	var detached := gameplay.duplicate(true)
	detached["route_context"] = route
	return _ok(detached)

## Only current, not-yet-shown ordinary cards and Day 7 echo cards may be admitted
## lazily. Historical offer facts are captured by generation, never by projection.
static func prepare_projection(contacts: Dictionary, gameplay: Dictionary, day: int, friend: String = "") -> Dictionary:
	var route: Dictionary = gameplay.get("route_context", {}).duplicate(true)
	var cache: Dictionary = route.get(CACHE_KEY, empty_cache()).duplicate(true)
	var checked := validate_cache(cache, contacts, false, gameplay.get("missed_invitations", []), day)
	if not checked.ok: return checked
	if day < 7 and not friend.is_empty():
		var available := ORDINARY.available(contacts, day, friend, "en")
		if not available.ok: return available
		if not available.value.is_empty():
			var key := str(available.value.entry_id) + "|awaiting_reply"
			if not cache.entries.has(key):
				var built := ordinary_awaiting(available.value.entry_id, gameplay.get("dating_route_state", {}).get(friend, {}),
					str(gameplay.get("friend_attitude", {}).get(friend, "")))
				if not built.ok: return built
				var retained := retain(cache, built.value)
				if not retained.ok: return retained
				cache = retained.value
	if day == 7:
		for echo: Dictionary in ORDINARY.pending_echoes_oldest_first(contacts):
			var built := echo_card(echo)
			if not built.ok: return built
			var retained := retain(cache, built.value)
			if not retained.ok: return retained
			cache = retained.value
	route[CACHE_KEY] = cache
	var detached := gameplay.duplicate(true)
	detached["route_context"] = route
	return _ok(detached)

static func retain(cache: Dictionary, presentation: Dictionary) -> Dictionary:
	var entry_id := str(presentation.get("fields", {}).get("entry_id", ""))
	var checked := FROZEN.validate(entry_id, presentation)
	if not checked.ok: return checked
	var key := key_for(presentation)
	if key.is_empty() or presentation.fields.entry_role not in ROLES: return _fail(&"contacts_frozen_entry_unavailable")
	var candidate := cache.duplicate(true)
	if candidate.entries.has(key):
		return _ok(candidate) if candidate.entries[key] == presentation else _fail(&"contacts_frozen_context_changed")
	candidate.entries[key] = presentation.duplicate(true)
	return _ok(candidate)

static func for_message(state: Dictionary, friend: String, message: Dictionary, relationships: Dictionary,
		attitudes: Dictionary, cache: Dictionary, missed: Array = []) -> Dictionary:
	var entry_id := entry_id_for_message(state, friend, message)
	if entry_id.is_empty(): return _fail(&"contacts_frozen_message_source_invalid")
	var role := str(_constants(entry_id).get("entry_role", ""))
	match role:
		"solo_invitation_offer", "ending_invitation_offer":
			if cache.entries.has(entry_id): return _ok(cache.entries[entry_id].duplicate(true))
			return offer(entry_id, relationships.get(friend, {}), str(attitudes.get(friend, "")))
		"ordinary_message":
			var receipt: Dictionary = state.transaction_receipts.get(message.parameters.get("reply_transaction_id"), {})
			return ordinary_selected(cache.entries.get(entry_id + "|awaiting_reply", {}), receipt)
		"group_contact_offer":
			var source: Dictionary = _message_operation(state, message)
			if source.get("kind") != "open_group_first": return _fail(&"contacts_frozen_message_source_invalid")
			var group := {"state": "REPLY_REQUIRED", "inviter_id": source.friend_id,
				"opened_ids": [source.friend_id], "replied_ids": []}
			return _group_context(entry_id, str(message.variant) + "_" + friend, friend, group)
		"consequence_followup": return _followup(state, friend, message, entry_id, missed)
	return _fail(&"contacts_frozen_entry_unavailable")

static func entry_id_for_message(state: Dictionary, friend: String, message: Dictionary) -> String:
	var target_day := int(message.get("target_day", 0))
	var kind := str(message.get("type", ""))
	if kind == "solo_offer":
		return "contact.invitation.%s.%s.day%d.offer" % ["ending" if target_day == 7 else "solo", friend, target_day]
	if kind == "group_offer":
		return "contact.invitation.group.priscilla_lavinia.day%d.%s_%s" % [target_day, str(message.get("variant", "")), friend]
	if kind in ORDINARY.MESSAGE_KINDS:
		var receipt: Dictionary = state.get("transaction_receipts", {}).get(message.get("parameters", {}).get("reply_transaction_id"), {})
		return str(receipt.get("entry_id", "")) if receipt.get("friend_id") == friend else ""
	if kind == "hospital_care": return "contact.hospital_care.sylvia.day%d" % target_day if friend == "sylvia" else ""
	if kind not in ["nevermind", "missed_question", "busy", "judge"]: return ""
	var source := _message_operation(state, message)
	if source.get("kind") != "resolve_day_end" or int(source.get("day", 0)) + 1 != target_day: return ""
	var solo: Dictionary = state.get("solo_actions", {}).get("solo:%s:day%d" % [friend, target_day - 1], {})
	var group_source := solo.get("state") == "SUPERSEDED"
	return "contact.invitation.group.priscilla_lavinia.day%d.%s_%s" % [target_day - 1, kind, friend] if group_source \
		else "contact.invitation.solo.%s.day%d.%s" % [friend, target_day - 1, kind]

static func validate_cache(cache: Variant, contacts: Dictionary, require_complete: bool = false, missed: Array = [], saved_day: int = 7) -> Dictionary:
	if not cache is Dictionary or not _exact(cache, ["schema_version", "entries"]) \
			or typeof(cache.schema_version) != TYPE_INT or cache.schema_version != 1 or not cache.entries is Dictionary:
		return _fail(&"contacts_frozen_cache_invalid")
	for key: Variant in cache.entries:
		var presentation: Variant = cache.entries[key]
		if not key is String or not presentation is Dictionary: return _fail(&"contacts_frozen_cache_invalid")
		var fields: Variant = presentation.get("fields")
		if not fields is Dictionary or fields.get("entry_role") not in ROLES: return _fail(&"contacts_frozen_cache_invalid")
		var checked := FROZEN.validate(str(fields.get("entry_id", "")), presentation)
		if not checked.ok or key != key_for(presentation): return _fail(&"contacts_frozen_cache_invalid")
		if not _source_matches(contacts, cache, presentation, missed, saved_day): return _fail(&"contacts_frozen_source_mismatch")
	if require_complete:
		for friend: String in CONTACTS.FRIEND_IDS:
			for message: Dictionary in contacts.get("messages", {}).get(friend, []):
				var entry_id := entry_id_for_message(contacts, friend, message)
				var key := entry_id + "|after_selection" if message.type in ORDINARY.MESSAGE_KINDS else entry_id
				if entry_id.is_empty() or not cache.entries.has(key): return _fail(&"contacts_frozen_history_missing")
		for receipt: Dictionary in contacts.get("transaction_receipts", {}).values():
			if receipt.get("kind") not in ["activate_group", "open_group_first"]: continue
			var variation := "offer" if receipt.kind == "activate_group" else "need_reply_%s_first" % str(receipt.friend_id)
			if not cache.entries.has("contact.invitation.group.priscilla_lavinia.day%d.%s" % [int(receipt.day), variation]):
				return _fail(&"contacts_frozen_history_missing")
		for witness: Dictionary in contacts.get("sylvia_hospital_witness_receipts", {}).values():
			if not cache.entries.has("contact.hospital_care.sylvia.day%d" % int(witness.care_followup_day)): return _fail(&"contacts_frozen_history_missing")
	return _ok(cache.duplicate(true))

static func _source_matches(state: Dictionary, cache: Dictionary, presentation: Dictionary, missed: Array, saved_day: int) -> bool:
	var fields: Dictionary = presentation.fields
	var entry_id: String = fields.entry_id
	if fields.entry_role in ["ordinary_message", "solo_invitation_offer", "ending_invitation_offer", "group_contact_offer"] \
			and int(fields.day) > saved_day: return false
	if fields.entry_role == "ordinary_message":
		if entry_id != ORDINARY.entry_id_for_day(int(fields.day)): return false
		if fields.phase == "awaiting_reply": return int(fields.day) <= saved_day
		for receipt: Dictionary in state.get("transaction_receipts", {}).values():
			if receipt.get("kind") != "ordinary_reply" or receipt.get("entry_id") != entry_id: continue
			var expected := ordinary_selected(cache.entries.get(entry_id + "|awaiting_reply", {}), receipt)
			return expected.ok and expected.value == presentation
		return false
	if fields.entry_role == "echo_fallback":
		if saved_day != 7: return false
		if fields.due_echoes.size() != 1: return false
		for receipt: Dictionary in state.get("transaction_receipts", {}).values():
			if receipt.get("kind") != "ordinary_reply": continue
			if not ORDINARY.validate_receipt(receipt).ok: continue
			var expected := echo_card(receipt)
			if expected.ok and expected.value == presentation: return true
		return false
	if fields.entry_role == "group_contact_offer" and fields.contact_variation in ["offer", "need_reply_priscilla_first", "need_reply_lavinia_first"]:
		for source: Dictionary in state.get("transaction_receipts", {}).values():
			if source.get("day") != fields.day: continue
			var group := {}
			if fields.contact_variation == "offer" and source.get("kind") == "activate_group":
				group = {"state": "AVAILABLE_UNOPENED", "inviter_id": null, "opened_ids": [], "replied_ids": []}
			elif source.get("kind") == "open_group_first" and fields.contact_variation == "need_reply_%s_first" % str(source.get("friend_id")):
				group = {"state": "REPLY_REQUIRED", "inviter_id": source.friend_id, "opened_ids": [source.friend_id], "replied_ids": []}
			if not group.is_empty():
				var expected := _group_context(entry_id, fields.contact_variation, null, group)
				if expected.ok and expected.value == presentation: return true
		return false
	for friend: String in CONTACTS.FRIEND_IDS:
		for message: Dictionary in state.get("messages", {}).get(friend, []):
			if entry_id_for_message(state, friend, message) != entry_id: continue
			if fields.entry_role in ["solo_invitation_offer", "ending_invitation_offer"]: return true
			# Consequences have no live relationship inputs. Validate their closure
			# fields separately; the hospital miss annotation lives in gameplay.
			if fields.entry_role == "consequence_followup":
				var expected := _followup(state, friend, message, fields.entry_id, missed)
				return expected.ok and expected.value == presentation
			var expected := for_message(state, friend, message, {}, {}, cache)
			if expected.ok and expected.value == presentation: return true
	for witness_id: String in state.get("sylvia_hospital_witness_receipts", {}):
		var witness: Dictionary = state.sylvia_hospital_witness_receipts[witness_id]
		if "contact.hospital_care.sylvia.day%d" % int(witness.care_followup_day) != entry_id: continue
		var expected := _followup(state, "sylvia", _care_message(witness_id, witness), entry_id, missed)
		return expected.ok and expected.value == presentation
	return false

static func _care_message(witness_id: String, witness: Dictionary) -> Dictionary:
	return {"message_id": witness.care_followup_entry_id, "type": "hospital_care",
		"target_day": witness.care_followup_day, "parameters": {"witness_id": witness_id}}

static func _group_context(entry_id: String, variation: String, target: Variant, group: Dictionary) -> Dictionary:
	var fields := _constants(entry_id)
	if fields.get("entry_role") != "group_contact_offer": return _fail(&"contacts_frozen_entry_unavailable")
	fields.merge({"group_action_state": group.get("state"), "inviter_id": group.get("inviter_id"),
		"target_participant_id": target, "opened_ids": group.get("opened_ids", []).duplicate(),
		"replied_ids": group.get("replied_ids", []).duplicate(), "contact_variation": variation})
	return FROZEN.build(entry_id, fields)

static func _followup(state: Dictionary, friend: String, message: Dictionary, entry_id: String, missed: Array) -> Dictionary:
	var fields := _constants(entry_id)
	if fields.get("entry_role") != "consequence_followup": return _fail(&"contacts_frozen_entry_unavailable")
	var source_day := int(message.target_day) - 1
	var action_id := "solo:%s:day%d" % [friend, source_day]
	var kind: String = message.type
	var closure := "hospital_care"
	if kind == "hospital_care":
		var witness: Dictionary = state.get("sylvia_hospital_witness_receipts", {}).get(message.parameters.get("witness_id"), {})
		if witness.is_empty(): return _fail(&"contacts_frozen_message_source_invalid")
		action_id = str(witness.get("action_id", ""))
		var source: Dictionary = state.get("schedule_source_receipts", {}).get(witness.get("source_receipt_id"), {})
		if source.get("kind") != "solo_read_acceptance" or source.get("participants") != ["sylvia"] \
				or source.get("action_id") != action_id or source.get("day") != source_day \
				or witness.get("care_followup_day") != message.target_day \
				or witness.get("care_followup_entry_id") != "care.sylvia.day%d" % int(message.target_day):
			return _fail(&"contacts_frozen_message_source_invalid")
		# Schedule Hospital commits the witness before invitation rollover closes
		# its action. This context names the actual care handoff, never a future close.
	else:
		if entry_id.contains(".group."): action_id = "group:priscilla_lavinia:day%d" % source_day
		for transition: Dictionary in _message_operation(state, message).get("state_transitions", []):
			if transition.get("action_id") == action_id: closure = str(transition.get("to_state", ""))
		if closure == "hospital_care": return _fail(&"contacts_frozen_message_source_invalid")
	var reason := kind
	for record: Variant in missed:
		if kind == "missed_question" and record is Dictionary and record.get("friend_id") == friend and record.get("day") == source_day \
				and record.get("missed_reason") == "hospital" and not str(record.get("hospital_miss_receipt_id", "")).is_empty():
			reason = "prevented_by_fainting"
	fields.merge({"source_invitation_id": action_id, "closure_state": closure,
		"miss_reason": reason, "witnessed_hospital": kind == "hospital_care"})
	return FROZEN.build(entry_id, fields)

static func _message_operation(state: Dictionary, message: Dictionary) -> Dictionary:
	for operation: Dictionary in state.get("transaction_receipts", {}).values():
		if message.get("transaction_id") in operation.get("child_transaction_ids", []): return operation
	return {}

static func _message_existed(messages: Array, candidate: Dictionary) -> bool:
	for message: Dictionary in messages:
		if message.get("message_id") == candidate.get("message_id") \
				and message.get("transaction_id") == candidate.get("transaction_id"): return true
	return false

static func _relationship(relationship: Dictionary, attitude: String) -> Dictionary:
	if not relationship.get("relationship_state") is String or typeof(relationship.get("dark_points")) != TYPE_INT:
		return _fail(&"contacts_frozen_relationship_unavailable")
	return _ok({"tier": relationship.relationship_state, "tone": "dark" if relationship.dark_points >= RELATIONSHIP.DARK_TONE_THRESHOLD else "sweet", "attitude": attitude})

static func _constants(entry_id: String) -> Dictionary:
	var schema := FROZEN.schema_for_entry(entry_id)
	if not schema.ok: return {}
	var fields := {}
	for key: String in schema.value.fields:
		var descriptor: Variant = schema.value.fields[key]
		if descriptor is Dictionary and descriptor.has("const"):
			var value: Variant = descriptor["const"]
			fields[key] = int(value) if value is float else value
	return fields

static func _exact(value: Dictionary, keys: Array) -> bool:
	if value.size() != keys.size(): return false
	for key: String in keys:
		if not value.has(key): return false
	return true

static func _ok(value: Dictionary) -> Dictionary:
	return {"ok": true, "value": value}

static func _fail(code: StringName) -> Dictionary:
	return {"ok": false, "code": code}
