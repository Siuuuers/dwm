class_name ContactInvitationState
extends RefCounted

## Stateless contact & invitation state machine (dwm-p2r.6, plan-04 stateless rebuild).
## Every function is static: it takes a primitive `state` Dictionary plus a transaction
## id and returns a frozen CommandResult {ok, code, value:{candidate, message_batch}, receipt}.
## GameState owns one primitive `contacts` bag; no instance state lives here — a failed
## transaction simply discards the returned candidate, so rollback/idempotency are by
## construction. Queries are pure and never mutate the passed state.
## Spec: prompt_docs/requirements/contacts_invitations.md; story/05 §7/§13;
## docs/superpowers/plans/2026-07-22-phase-2r-06-contacts-stateless-reconciliation.md

## The pure Hospital owner supplies the frozen witness facts, so this module validates against
## the SAME constants rather than keeping a second copy of the law (Task 7 Step 7.3).
const ORDINARY_REPLIES := preload("res://scripts/domain/contact/OrdinaryReplyEchoState.gd")
const HOSPITAL_RULES := preload("res://scripts/domain/hospital/HospitalRules.gd")
const CALENDAR := preload("res://scripts/domain/contact/SevenDayCalendar.gd")

## THE canonical friend roster (dwm-pm4): DataCatalog and GameState alias this declaration, so
## adding or renaming a friend is a one-line change with a drift pin watching all three surfaces.
const FRIEND_IDS: Array[String] = ["priscilla", "lavinia", "sylvia"]
## The one counted Priscilla-Lavinia pair and its group-eligible windows.
const GROUP_PAIR: Array[String] = ["priscilla", "lavinia"]
const GROUP_WINDOW_DAYS: Array[int] = CALENDAR.GROUP_DAYS
const GROUP_ACTIVATION_ROUND := 3
const GROUP_PAIR_KEY := "priscilla_lavinia"
const GROUP_OPEN_STATES: Array[String] = ["AVAILABLE_UNOPENED", "REPLY_REQUIRED", "ACCEPTED"]
const _CANONICAL_WRITER := preload("res://scripts/validation/CanonicalJsonWriter.gd")
const _ACTION_RECORD_KEYS: Array[String] = [
	"action_id", "action_kind", "allowed_days", "effect_ids", "motivation_cost",
	"participants", "repeatable", "route_id", "source_receipt_kind",
]
const _SOURCE_RECEIPT_KEYS: Array[String] = [
	"action_id", "day", "kind", "participants", "previous_receipt_id",
	"receipt_id", "receipt_provenance",
]
const _SOURCE_PROVENANCE_KEYS: Array[String] = [
	"child_id", "child_kind", "ordinal", "parent_receipt_id", "schema_version", "source_ids",
]
const _STATE_KEYS: Array[String] = [
	"group_action", "messages", "next_sequence", "read_watermarks",
	"schedule_source_receipts", "solo_actions", "sylvia_hospital_witness_receipts",
	"transaction_receipts",
]
const _MESSAGE_KEYS: Array[String] = [
	"message_id", "parameters", "sequence", "target_day", "transaction_id", "type",
	"variant", "visibility",
]
const _SOLO_ACTION_KEYS: Array[String] = [
	"action_id", "day", "friend_id", "offer_message_id", "reply_transaction_id", "state",
	"transaction_id",
]
const _GROUP_ACTION_KEYS: Array[String] = [
	"action_id", "day", "history_generated", "inviter_id", "opened_ids", "participant_ids",
	"replied_ids", "state", "transaction_id",
]
const _ISSUER_RECEIPT_KEYS: Array[String] = [
	"counter", "namespace", "numeric_value", "purpose", "receipt_id", "token",
]
const _OFFER_SOLO_RECEIPT_KEYS: Array[String] = [
	"action_id", "child_transaction_ids", "day", "friend_id", "kind", "message_ids",
	"message_sequences", "transaction_id",
]
const _OPEN_SOLO_RECEIPT_KEYS: Array[String] = [
	"action_id", "command_issuer_receipt", "day", "friend_id", "kind", "new_watermark",
	"prior_watermark", "source_receipt_id", "transaction_id",
]
const _ACTIVATE_GROUP_RECEIPT_KEYS: Array[String] = [
	"action_id", "child_transaction_ids", "day", "kind", "message_ids", "message_sequences",
	"superseded_action_ids", "transaction_id",
]
const _OPEN_GROUP_RECEIPT_KEYS: Array[String] = [
	"action_id", "child_transaction_ids", "command_issuer_receipt", "day", "friend_id",
	"kind", "message_ids", "message_sequences", "transaction_id",
]
const _REPLY_GROUP_RECEIPT_KEYS: Array[String] = [
	"action_id", "command_issuer_receipt", "day", "friend_id", "from_state", "kind",
	"source_receipt_id", "to_state", "transaction_id",
]
const _RESOLVE_RECEIPT_KEYS: Array[String] = [
	"child_transaction_ids", "counter_deltas", "date_outcome_ids", "day",
	"deferred_twofriends", "group_date_variation", "kind", "message_ids",
	"message_sequences", "pl_window", "state_transitions", "transaction_id",
]

# ---- canonical state shape ----

static func make_defaults() -> Dictionary:
	return {
		"messages": {"priscilla": [], "lavinia": [], "sylvia": []},
		"read_watermarks": {"priscilla": 0, "lavinia": 0, "sylvia": 0},
		"solo_actions": {},
		"group_action": {
			"state": "INACTIVE",
			"action_id": null,
			"day": null,
			"participant_ids": ["priscilla", "lavinia"],
			"inviter_id": null,
			"opened_ids": [],
			"replied_ids": [],
			"history_generated": false,
			"transaction_id": null,
		},
		"schedule_source_receipts": {},
		"sylvia_hospital_witness_receipts": {},
		"transaction_receipts": {},
		"next_sequence": 1,
	}

static func validate_state(state: Dictionary) -> Dictionary:
	if not _has_exact_keys(state, _STATE_KEYS):
		return _fail(&"invalid_state", "Contacts must have the exact canonical member set")
	for key: String in [
		"messages", "read_watermarks", "solo_actions", "group_action",
		"schedule_source_receipts", "sylvia_hospital_witness_receipts",
		"transaction_receipts",
	]:
		if typeof(state.get(key)) != TYPE_DICTIONARY:
			return _fail(&"invalid_state", "%s must be a Dictionary" % key)
	if not _is_integral(state.get("next_sequence")) or int(state["next_sequence"]) < 1:
		return _fail(&"invalid_state", "next_sequence must be a positive integer")
	# OPENED BY TASK 7 (dwm-p2r.14 Step 7.3). Task 3 reserved this index empty; the Hospital
	# transaction now commits the byte-identical witness here, and it outlives the resolution plan
	# so dwm-oyo.4 can consume it. Append-only HANDOFF index, never a second gameplay ledger.
	for witness_id: Variant in state["sylvia_hospital_witness_receipts"]:
		if typeof(witness_id) != TYPE_STRING or str(witness_id).strip_edges().is_empty():
			return _fail(&"invalid_state", "Sylvia witness receipt ids must be nonblank strings")
		var witness_check := _validate_sylvia_witness_shape(
			state["sylvia_hospital_witness_receipts"][witness_id])
		if not witness_check.get("ok", false):
			return _fail(&"invalid_state", "Sylvia hospital witness receipt is invalid",
				{"cause": witness_check.get("code", &"")})
	if not _has_exact_keys(state["messages"], FRIEND_IDS) \
			or not _has_exact_keys(state["read_watermarks"], FRIEND_IDS):
		return _fail(&"invalid_state", "friend indexes must have the exact canonical members")
	var maximum_sequence := 0
	for friend_id: String in FRIEND_IDS:
		if typeof(state["messages"].get(friend_id)) != TYPE_ARRAY:
			return _fail(&"invalid_state", "messages[%s] must be an array" % friend_id)
		var previous_sequence := 0
		for message: Variant in state["messages"][friend_id]:
			var message_check := _validate_message_record(message)
			if not message_check.get("ok", false):
				return message_check
			var sequence: int = (message as Dictionary)["sequence"]
			if sequence <= previous_sequence:
				return _fail(&"invalid_state", "message sequences must ascend per friend")
			previous_sequence = sequence
			maximum_sequence = maxi(maximum_sequence, sequence)
		if not _is_integral(state["read_watermarks"].get(friend_id)) \
				or int(state["read_watermarks"][friend_id]) < 0 \
				or int(state["read_watermarks"][friend_id]) > previous_sequence:
			return _fail(&"invalid_state", "read watermarks must be exact in-range integers")
	if int(state["next_sequence"]) != maximum_sequence + 1:
		return _fail(&"invalid_state", "next_sequence must immediately follow persisted messages")
	for action_id: Variant in state["solo_actions"]:
		var solo_check := _validate_solo_action(state, action_id,
			state["solo_actions"][action_id])
		if not solo_check.get("ok", false):
			return solo_check
	var group_check := _validate_group_action(state, state["group_action"])
	if not group_check.get("ok", false):
		return group_check
	for transaction_id: Variant in state["transaction_receipts"]:
		var operation_check := _validate_transaction_receipt(
			transaction_id, state["transaction_receipts"][transaction_id])
		if not operation_check.get("ok", false):
			return operation_check
		var operation_linkage := _validate_operation_linkage(
			state, str(transaction_id), state["transaction_receipts"][transaction_id])
		if not operation_linkage.get("ok", false):
			return operation_linkage
	for message: Dictionary in state.messages.sylvia:
		if message.type != "hospital_care": continue
		var owners := 0
		for operation: Dictionary in state.transaction_receipts.values():
			var care: Dictionary = operation.get("hospital_care", {})
			for index: int in range(care.get("witness_ids", []).size()):
				if message.transaction_id == "%s:care:%d" % [operation.transaction_id, index] \
						and message.message_id == care.message_ids[index] and message.sequence == care.message_sequences[index]:
					owners += 1
		if owners != 1:
			return _fail(&"invalid_state", "caring history requires one exact consumption owner")
	for receipt_id: Variant in state["schedule_source_receipts"]:
		if typeof(receipt_id) != TYPE_STRING or str(receipt_id).strip_edges().is_empty():
			return _fail(&"invalid_state", "source receipt ids must be nonblank strings")
		var source: Variant = state["schedule_source_receipts"][receipt_id]
		var source_check := _validate_source_receipt_shape(str(receipt_id), source)
		if not source_check.get("ok", false):
			return _fail(&"invalid_state", "schedule source receipt is invalid",
				{"cause": source_check.get("code", &"")})
		var linkage_check := _validate_source_receipt_linkage(state, str(receipt_id), source)
		if not linkage_check.get("ok", false):
			return _fail(&"invalid_state", "schedule source receipt linkage is invalid",
				{"cause": linkage_check.get("code", &"")})
	var ordinary_check := ORDINARY_REPLIES.validate_state(state)
	if not ordinary_check.ok: return ordinary_check
	return {"ok": true, "code": &"ok", "value": {}, "receipt": {}}

## The exact Schedule-Done Sylvia witness record (Task 7 Step 7.3, dwm-p2r.14).
##
## The deltas, attitude and tier transition are FROZEN FACTS recorded for dwm-oyo.4; validating them
## here keeps a malformed handoff from ever reaching disk. Nothing in this module applies them.
##
## `resolution_kind` is pinned to schedule_done on purpose: Plan 03's condition-Hospital flow owns
## its own typed ancestry and must not reach this index through a Plan-01 shaped record.
const SYLVIA_WITNESS_KEYS: Array[String] = [
	"action_id", "affection_delta", "attitude", "care_followup_day", "care_followup_entry_id",
	"dark_delta", "hospital_miss_ordinal", "kind", "resolution_kind", "schedule_entry_id",
	"source_receipt_id", "tier_transition",
]

static func _validate_sylvia_witness_shape(record: Variant) -> Dictionary:
	if typeof(record) != TYPE_DICTIONARY:
		return _fail(&"invalid_sylvia_witness", "the witness record must be an object")
	if str((record as Dictionary).get("resolution_kind", "")) == "condition_hospital":
		return _validate_condition_hospital_witness(record)
	if not _has_exact_keys(record as Dictionary, SYLVIA_WITNESS_KEYS):
		return _fail(&"invalid_sylvia_witness", "the witness record is exact-key")
	var witness := record as Dictionary
	if str(witness["kind"]) != HOSPITAL_RULES.WITNESS_KIND:
		return _fail(&"invalid_sylvia_witness", "kind must be " + HOSPITAL_RULES.WITNESS_KIND)
	if str(witness["resolution_kind"]) != HOSPITAL_RULES.WITNESS_RESOLUTION_KIND:
		return _fail(&"invalid_sylvia_witness",
			"Plan 01 persists only the " + HOSPITAL_RULES.WITNESS_RESOLUTION_KIND + " witness")
	for text_field: String in [
		"action_id", "care_followup_entry_id", "schedule_entry_id", "source_receipt_id",
	]:
		if typeof(witness[text_field]) != TYPE_STRING 				or str(witness[text_field]).strip_edges().is_empty():
			return _fail(&"invalid_sylvia_witness", text_field + " must be a nonblank String")
	for int_field: String in ["care_followup_day", "hospital_miss_ordinal"]:
		if typeof(witness[int_field]) != TYPE_INT or int(witness[int_field]) < 0:
			return _fail(&"invalid_sylvia_witness", int_field + " must be a non-negative int")
	# Type FIRST, then value: a coerced "2" must fail as a bad shape rather than reaching a
	# String-vs-int comparison.
	for delta_field: String in ["affection_delta", "dark_delta"]:
		if typeof(witness[delta_field]) != TYPE_INT:
			return _fail(&"invalid_sylvia_witness", delta_field + " must be a strict int")
	if int(witness["affection_delta"]) != HOSPITAL_RULES.WITNESS_AFFECTION_DELTA 			or int(witness["dark_delta"]) != HOSPITAL_RULES.WITNESS_DARK_DELTA:
		return _fail(&"invalid_sylvia_witness", "the frozen witness deltas may not be rewritten")
	if str(witness["attitude"]) != HOSPITAL_RULES.WITNESS_ATTITUDE 			or str(witness["tier_transition"]) != HOSPITAL_RULES.WITNESS_TIER_TRANSITION:
		return _fail(&"invalid_sylvia_witness", "the frozen witness outcome may not be rewritten")
	return {"ok": true, "code": &"ok"}


## Did a Hospital witness record cover this exact solo action?
##
## Read-only. The witness index is an append-only handoff written by the Hospital transaction; the
## day-end rollover consults it and never consumes, clears, or rewrites it, because dwm-oyo.4 reads
## it after this plan retires.
static func _has_hospital_witness(state: Dictionary, action_id: String) -> bool:
	var index: Variant = state.get("sylvia_hospital_witness_receipts")
	if typeof(index) != TYPE_DICTIONARY:
		return false
	for witness_id: Variant in (index as Dictionary):
		var record: Variant = (index as Dictionary)[witness_id]
		if typeof(record) != TYPE_DICTIONARY:
			continue
		if str((record as Dictionary).get("action_id", "")) == action_id:
			return true
	return false


# ---- solo offer / open (req.contact.history_watermark, req.invitation.solo) ----

static func prepare_offer_solo(state: Dictionary, friend_id: String, day: int, message_id: String, transaction_id: String) -> Dictionary:
	var detached: Dictionary = state.duplicate(true)
	if friend_id not in FRIEND_IDS:
		return _fail(&"unknown_friend", friend_id)
	if day < 1 or day > 7:
		return _fail(&"invalid_day", str(day))
	if transaction_id.is_empty():
		return _fail(&"invalid_transaction", "transaction_id is required")
	# Idempotent replay: an identical prior receipt returns the stored candidate/receipt.
	if detached["transaction_receipts"].has(transaction_id):
		return _replay(detached, transaction_id)
	var action_id := "solo:%s:day%d" % [friend_id, day]
	if detached["solo_actions"].has(action_id):
		return _fail(&"duplicate_action", action_id)
	var sequence := int(detached["next_sequence"])
	var message_tx := "%s:message:0" % transaction_id
	var record := {
		"message_id": message_id,
		"sequence": sequence,
		"type": "solo_offer",
		"variant": "default",
		"target_day": day,
		"parameters": {},
		"visibility": "visible",
		"transaction_id": message_tx,
	}
	(detached["messages"][friend_id] as Array).append(record)
	detached["solo_actions"][action_id] = {
		"action_id": action_id,
		"friend_id": friend_id,
		"day": day,
		"state": "AVAILABLE",
		"offer_message_id": message_id,
		"reply_transaction_id": null,
		"transaction_id": transaction_id,
	}
	detached["next_sequence"] = sequence + 1
	var receipt := {
		"transaction_id": transaction_id,
		"kind": "offer_solo",
		"action_id": action_id,
		"friend_id": friend_id,
		"day": day,
		"child_transaction_ids": [message_tx],
		"message_ids": [message_id],
		"message_sequences": [sequence],
	}
	detached["transaction_receipts"][transaction_id] = receipt
	return _ok(detached, [record], receipt)

## Care and a currently visible invitation share this one preflight/commit candidate. The
## original invitation source receipt remains unchanged for Schedule subscribers.
static func prepare_open_contact(state: Dictionary, friend_id: String, day: int,
		transaction_id: String, command_issuer_receipt: Dictionary,
		identity_issuer: Object, action_record: Dictionary) -> Dictionary:
	if friend_id != "sylvia":
		return _prepare_invitation_open(state, friend_id, day, transaction_id,
			command_issuer_receipt, identity_issuer, action_record)
	var verified := _verify_command(identity_issuer, transaction_id, command_issuer_receipt)
	if not verified.get("ok", false): return verified
	var old: Dictionary = state.transaction_receipts.get(transaction_id, {})
	if old.get("kind") == "open_sylvia_care":
		if old.day != day or old.command_issuer_receipt != command_issuer_receipt:
			return _fail(&"care_command_conflict", transaction_id)
		var checked := validate_state(state)
		return _ok(state.duplicate(true), [], old.duplicate(true)) if checked.ok else checked
	var opened := _prepare_invitation_open(state, friend_id, day, transaction_id,
		command_issuer_receipt, identity_issuer, action_record)
	if not old.is_empty(): return opened
	var pending: Array = get_pending_sylvia_care(state, day)
	if pending.is_empty(): return opened
	if not opened.get("ok", false):
		if str(opened.get("code", "")) not in ["no_offer", "invalid_transition"]: return opened
		var detached := state.duplicate(true)
		var receipt := {"kind": "open_sylvia_care", "transaction_id": transaction_id,
			"friend_id": "sylvia", "day": day, "command_issuer_receipt": command_issuer_receipt.duplicate(true)}
		detached.transaction_receipts[transaction_id] = receipt
		opened = _ok(detached, [], receipt)
	var candidate: Dictionary = opened.value.candidate
	var claim := {"witness_ids": [], "witnesses": {}, "message_ids": [], "message_sequences": []}
	for projected: Dictionary in pending:
		var witness_id: String = projected.parameters.witness_id
		var witness: Dictionary = state.sylvia_hospital_witness_receipts[witness_id]
		var source: Dictionary = state.schedule_source_receipts[witness.source_receipt_id]
		var proof: Dictionary = identity_issuer.validate_child(source.receipt_provenance, &"contact_source")
		if not proof.get("ok", false): return proof
		if witness.resolution_kind == "condition_hospital":
			proof = identity_issuer.validate_child(witness.receipt_provenance, &"sylvia_hospital_witness")
			if not proof.get("ok", false): return proof
		var message := projected.duplicate(true)
		message.sequence = candidate.next_sequence
		message.transaction_id = "%s:care:%d" % [transaction_id, claim.witness_ids.size()]
		candidate.messages.sylvia.append(message)
		candidate.next_sequence += 1
		claim.witness_ids.append(witness_id)
		claim.witnesses[witness_id] = witness.duplicate(true)
		claim.message_ids.append(message.message_id)
		claim.message_sequences.append(message.sequence)
		opened.value.message_batch.append(message.duplicate(true))
	candidate.transaction_receipts[transaction_id]["hospital_care"] = claim
	if str(opened.receipt.get("kind", "")) == "open_sylvia_care":
		opened.receipt = candidate.transaction_receipts[transaction_id].duplicate(true)
	var validated := validate_state(candidate)
	return opened if validated.ok else validated

static func _prepare_invitation_open(state: Dictionary, friend_id: String, day: int,
		transaction_id: String, command_issuer_receipt: Dictionary,
		identity_issuer: Object, action_record: Dictionary) -> Dictionary:
	var detached: Dictionary = state.duplicate(true)
	if friend_id not in FRIEND_IDS:
		return _fail(&"unknown_friend", friend_id)
	if transaction_id.is_empty():
		return _fail(&"invalid_transaction", "transaction_id is required")
	var verified := _verify_command(identity_issuer, transaction_id, command_issuer_receipt)
	if not verified.get("ok", false):
		return verified
	if detached["transaction_receipts"].has(transaction_id):
		return _replay_authenticated(detached, transaction_id, friend_id, day,
			command_issuer_receipt, identity_issuer, &"open")
	# Route to the group open branch when an active group offer covers this friend/day.
	if _routes_to_group(detached, friend_id, day):
		return _open_group(detached, friend_id, transaction_id, command_issuer_receipt)
	var action_id := "solo:%s:day%d" % [friend_id, day]
	var action: Variant = detached["solo_actions"].get(action_id)
	if typeof(action) != TYPE_DICTIONARY:
		return _fail(&"no_offer", action_id)
	if str((action as Dictionary).get("state", "")) != "AVAILABLE":
		return _fail(&"invalid_transition", "%s is not AVAILABLE" % action_id)
	var record_check := _validate_action_record(
		action_record, action_id, "solo", [friend_id], "solo_read_acceptance", day)
	if not record_check.get("ok", false):
		return record_check
	var prior := int(detached["read_watermarks"][friend_id])
	# Opening a solo is the scripted acceptance; there is no second solo reply transition.
	var new_watermark := prior
	for record: Dictionary in detached["messages"][friend_id]:
		if str(record["visibility"]) != "visible":
			continue
		if int(record["target_day"]) > day:
			continue
		new_watermark = maxi(new_watermark, int(record["sequence"]))
	detached["read_watermarks"][friend_id] = new_watermark
	var previous_receipt_id := str((action as Dictionary)["transaction_id"])
	var source := _derive_source(identity_issuer, command_issuer_receipt,
		transaction_id, action_id, day, [friend_id], previous_receipt_id,
		"solo_read_acceptance", "contact_source.solo")
	if not source.get("ok", false):
		return source
	var source_receipt: Dictionary = source["value"]["receipt"]
	(action as Dictionary)["state"] = "ACCEPTED"
	(action as Dictionary)["reply_transaction_id"] = transaction_id
	detached["schedule_source_receipts"][source_receipt["receipt_id"]] = source_receipt.duplicate(true)
	var operation_receipt := {
		"transaction_id": transaction_id,
		"kind": "open_solo_acceptance",
		"friend_id": friend_id,
		"day": day,
		"action_id": action_id,
		"prior_watermark": prior,
		"new_watermark": new_watermark,
		"command_issuer_receipt": command_issuer_receipt.duplicate(true),
		"source_receipt_id": str(source_receipt["receipt_id"]),
	}
	detached["transaction_receipts"][transaction_id] = operation_receipt
	return _ok(detached, [], source_receipt)

static func prepare_reply(state: Dictionary, friend_id: String, day: int,
		transaction_id: String, command_issuer_receipt: Dictionary,
		identity_issuer: Object, action_record: Dictionary) -> Dictionary:
	var detached: Dictionary = state.duplicate(true)
	if friend_id not in FRIEND_IDS:
		return _fail(&"unknown_friend", friend_id)
	if transaction_id.is_empty():
		return _fail(&"invalid_transaction", "transaction_id is required")
	var verified := _verify_command(identity_issuer, transaction_id, command_issuer_receipt)
	if not verified.get("ok", false):
		return verified
	if detached["transaction_receipts"].has(transaction_id):
		return _replay_authenticated(detached, transaction_id, friend_id, day,
			command_issuer_receipt, identity_issuer, &"reply")
	# Route to the group reply branch when an active group offer covers this friend/day.
	if _routes_to_group(detached, friend_id, day):
		return _reply_group(detached, friend_id, transaction_id,
			command_issuer_receipt, identity_issuer, action_record)
	return _fail(&"solo_reply_not_required", "opening a solo offer is its acceptance")

static func prepare_resolve_day_end(state: Dictionary, day: int, attendance: Dictionary, transaction_id: String) -> Dictionary:
	var detached: Dictionary = state.duplicate(true)
	if day < 1 or day > 7:
		return _fail(&"invalid_day", str(day))
	if transaction_id.is_empty():
		return _fail(&"invalid_transaction", "transaction_id is required")
	if detached["transaction_receipts"].has(transaction_id):
		return _replay(detached, transaction_id)
	var ordinary_expiry := ORDINARY_REPLIES.expiry_entry_id(detached, day)
	var attended: Array = attendance.get("solo_attended_action_ids", [])
	# Resolve this day's solo actions in deterministic action_id order so queued
	# records (and their sequences) allocate identically on every replay.
	var action_ids: Array = []
	for action_id: String in detached["solo_actions"]:
		if int(detached["solo_actions"][action_id]["day"]) == day:
			action_ids.append(action_id)
	action_ids.sort()
	var state_transitions: Array = []
	var message_batch: Array = []
	var message_ids: Array = []
	var message_sequences: Array = []
	var child_transaction_ids: Array = []
	for action_id: String in action_ids:
		var action: Dictionary = detached["solo_actions"][action_id]
		var from_state := str(action["state"])
		var to_state := ""
		var queued_type := ""
		if day == 7:
			# Day 7 closes every unresolved action silently.
			if from_state == "AVAILABLE" or from_state == "ACCEPTED":
				to_state = "RESOLVED_RUN_END"
		elif from_state == "AVAILABLE":
			# Un-replied (unread OR opened-unanswered) both draw the nevermind (§13).
			to_state = "RESOLVED_UNANSWERED"
			queued_type = "nevermind"
		elif from_state == "ACCEPTED":
			if action_id in attended:
				to_state = "RESOLVED_ATTENDED"
			else:
				to_state = "RESOLVED_MISSED"
				# A friend who WITNESSED the faint already knows why the date did not happen, so
				# she sends care the next day instead of asking what happened (Task 7 Step 7.3).
				# The date is still missed; only the question is suppressed.
				if not _has_hospital_witness(detached, action_id):
					queued_type = "missed_question"
		if to_state.is_empty():
			continue  # already resolved on a prior day-end; leave untouched
		action["state"] = to_state
		state_transitions.append({"action_id": action_id, "from_state": from_state, "to_state": to_state})
		if queued_type.is_empty():
			continue
		var friend_id := str(action["friend_id"])
		var target_day := day + 1
		var sequence := int(detached["next_sequence"])
		var message_tx := "%s:message:%d" % [transaction_id, child_transaction_ids.size()]
		var message_id := "%s:%s:day%d" % [queued_type, friend_id, target_day]
		var record := {
			"message_id": message_id,
			"sequence": sequence,
			"type": queued_type,
			"variant": "default",
			"target_day": target_day,
			"parameters": {},
			"visibility": "visible",
			"transaction_id": message_tx,
		}
		(detached["messages"][friend_id] as Array).append(record)
		detached["next_sequence"] = sequence + 1
		message_batch.append(record)
		message_ids.append(message_id)
		message_sequences.append(sequence)
		child_transaction_ids.append(message_tx)
	# ---- group day-end resolution (plan-04 table; §7 PL counter is added in Cycle B) ----
	var date_outcome_ids: Array = []
	var counter_deltas: Dictionary = {}
	var group_date_variation: Variant = null
	var deferred_twofriends: Variant = null
	var group: Dictionary = detached["group_action"]
	var group_state := str(group["state"])
	if group_state in GROUP_OPEN_STATES:
		var group_outcome := str(attendance.get("group_outcome", "not_scheduled"))
		var replied_ids: Array = group["replied_ids"]
		var to_group := ""
		if day == 7:
			to_group = "RESOLVED_RUN_END"  # lingering window closes silently
		elif int(group["day"]) == day:
			if group_state == "AVAILABLE_UNOPENED" and replied_ids.is_empty():
				to_group = "RESOLVED_UNANSWERED"  # wholly untouched -> busy to both
				for recipient: String in GROUP_PAIR:
					_queue_group_message(detached, recipient, "busy", day + 1, transaction_id, message_batch, message_ids, message_sequences, child_transaction_ids)
			elif group_state == "REPLY_REQUIRED" and replied_ids.is_empty():
				to_group = "RESOLVED_UNANSWERED"  # opened but unanswered -> nevermind to both
				for recipient: String in GROUP_PAIR:
					_queue_group_message(detached, recipient, "nevermind", day + 1, transaction_id, message_batch, message_ids, message_sequences, child_transaction_ids)
			elif group_state == "ACCEPTED" and group_outcome == "attended":
				to_group = "RESOLVED_ATTENDED"
				if replied_ids.size() == 1:
					group_date_variation = "judgmental"
					var unreplied := _other_participant(str(replied_ids[0]))
					_queue_group_message(detached, unreplied, "judge", day + 1, transaction_id, message_batch, message_ids, message_sequences, child_transaction_ids)
				else:
					group_date_variation = "normal"
			elif group_state == "ACCEPTED" and group_outcome in ["not_scheduled", "not_attended", "prevented_by_fainting"]:
				to_group = "RESOLVED_MISSED"
				date_outcome_ids.append("date.group.priscilla_lavinia.missed.day%d" % day)
				deferred_twofriends = {"route_id": "dating", "action_id": str(group["action_id"]), "after_hospital": group_outcome == "prevented_by_fainting"}
				# Hospital owns its distinct fainting miss in Task 7. Contacts retains the
				# deferred marker here, but must not also author the ordinary miss messages.
				if group_outcome != "prevented_by_fainting":
					for recipient: String in GROUP_PAIR:
						_queue_group_message(detached, recipient, "missed_question", day + 1, transaction_id, message_batch, message_ids, message_sequences, child_transaction_ids)
			else:
				return _fail(&"invalid_attendance", "%s / %s" % [group_state, group_outcome])
		if not to_group.is_empty():
			state_transitions.append({"action_id": str(group["action_id"]), "from_state": group_state, "to_state": to_group})
			group["state"] = to_group
	# ---- §7 four-way counted Priscilla-Lavinia window (group window days only) ----
	var pl_window: Variant = null
	if day in GROUP_WINDOW_DAYS:
		pl_window = _classify_pl_window(day, group_state, attendance)
		if pl_window["counts"]:
			counter_deltas["pl_window_counts.priscilla_lavinia"] = 1
	var receipt := {
		"transaction_id": transaction_id,
		"kind": "resolve_day_end",
		"day": day,
		"state_transitions": state_transitions,
		"child_transaction_ids": child_transaction_ids,
		"message_ids": message_ids,
		"message_sequences": message_sequences,
		"date_outcome_ids": date_outcome_ids,
		"group_date_variation": group_date_variation,
		"deferred_twofriends": deferred_twofriends,
		"pl_window": pl_window,
		"counter_deltas": counter_deltas,
	}
	# Unanswered ordinary entries are virtual: their invisible tombstone belongs to
	# this existing closure, without allocating history, a sequence or a watermark.
	if not ordinary_expiry.is_empty():
		receipt["ordinary_expired_entry_id"] = ordinary_expiry
	detached["transaction_receipts"][transaction_id] = receipt
	return _ok(detached, message_batch, receipt)

static func prepare_activate_group_after_round(state: Dictionary, day: int, rounds_before: int, rounds_after: int, transaction_id: String) -> Dictionary:
	var detached: Dictionary = state.duplicate(true)
	if transaction_id.is_empty():
		return _fail(&"invalid_transaction", "transaction_id is required")
	if detached["transaction_receipts"].has(transaction_id):
		var recorded: Variant = detached["transaction_receipts"][transaction_id]
		if not recorded is Dictionary or recorded.get("kind") != "activate_group" \
				or recorded.get("day") != day or rounds_before != GROUP_ACTIVATION_ROUND - 1 \
				or rounds_after != GROUP_ACTIVATION_ROUND:
			return _fail(&"group_activation_replay_mismatch", transaction_id)
		return _replay(detached, transaction_id)
	if day not in GROUP_WINDOW_DAYS:
		return _fail(&"not_group_window", str(day))
	if rounds_before != GROUP_ACTIVATION_ROUND - 1 or rounds_after != GROUP_ACTIVATION_ROUND:
		return _fail(&"not_activation_round", "%d->%d" % [rounds_before, rounds_after])
	var previous: Dictionary = detached["group_action"]
	if str(previous["state"]) != "INACTIVE":
		if previous["state"] not in ["RESOLVED_UNANSWERED", "RESOLVED_ATTENDED", "RESOLVED_MISSED"] \
				or typeof(previous["day"]) != TYPE_INT or int(previous["day"]) >= day:
			return _fail(&"group_not_inactive", str(previous["state"]))
		var valid := validate_state(state)
		if not valid.ok: return valid
	# Predicate: both solos must be unread, AVAILABLE, unreplied (a failure changes nothing).
	var superseded_action_ids: Array = []
	for participant: String in GROUP_PAIR:
		var solo_id := "solo:%s:day%d" % [participant, day]
		var action: Variant = detached["solo_actions"].get(solo_id)
		if typeof(action) != TYPE_DICTIONARY:
			return _fail(&"missing_solo", solo_id)
		if str(action["state"]) != "AVAILABLE":
			return _fail(&"solo_not_available", solo_id)
		if action["reply_transaction_id"] != null:
			return _fail(&"solo_already_replied", solo_id)
		var sequence := _offer_sequence(detached, action)
		if sequence <= 0:
			return _fail(&"missing_offer_record", solo_id)
		if sequence <= int(detached["read_watermarks"][participant]):
			return _fail(&"solo_already_read", solo_id)
		superseded_action_ids.append(solo_id)
	# Atomic success: supersede both solos, hide their offers, open the group.
	for participant: String in GROUP_PAIR:
		var solo_id := "solo:%s:day%d" % [participant, day]
		var action: Dictionary = detached["solo_actions"][solo_id]
		action["state"] = "SUPERSEDED"
		for record: Dictionary in detached["messages"][participant]:
			if str(record["message_id"]) == str(action["offer_message_id"]):
				record["visibility"] = "superseded_hidden"
	var action_id := "group:%s:day%d" % [GROUP_PAIR_KEY, day]
	detached["group_action"] = {
		"state": "AVAILABLE_UNOPENED",
		"action_id": action_id,
		"day": day,
		"participant_ids": ["priscilla", "lavinia"],
		"inviter_id": null,
		"opened_ids": [],
		"replied_ids": [],
		"history_generated": false,
		"transaction_id": transaction_id,
	}
	var receipt := {
		"transaction_id": transaction_id,
		"kind": "activate_group",
		"action_id": action_id,
		"day": day,
		"superseded_action_ids": superseded_action_ids,
		"child_transaction_ids": [],
		"message_ids": [],
		"message_sequences": [],
	}
	detached["transaction_receipts"][transaction_id] = receipt
	if previous["state"] != "INACTIVE":
		var valid := validate_state(detached)
		if not valid.ok: return valid
	return _ok(detached, [], receipt)

# ---- pure queries ----

static func get_unread_count(state: Dictionary, friend_id: String, day: int) -> int:
	var watermark := int(state["read_watermarks"].get(friend_id, 0))
	var count := get_pending_sylvia_care(state, day).size() if friend_id == "sylvia" else 0
	for record: Dictionary in state["messages"].get(friend_id, []):
		if record.get("type") == "hospital_care": continue
		if str(record["visibility"]) != "visible":
			continue
		if int(record["target_day"]) > day:
			continue
		if int(record["sequence"]) > watermark:
			count += 1
	return count

static func is_reply_required(state: Dictionary, friend_id: String) -> bool:
	var group: Dictionary = state.get("group_action", {})
	return friend_id in GROUP_PAIR and str(group.get("state", "")) == "REPLY_REQUIRED" \
		and friend_id in group.get("opened_ids", [])

static func is_date_addable(state: Dictionary, action_id: String) -> bool:
	if str(state["group_action"]["action_id"]) == action_id:
		return str(state["group_action"]["state"]) == "ACCEPTED"
	var action: Variant = state["solo_actions"].get(action_id)
	return typeof(action) == TYPE_DICTIONARY and str(action["state"]) == "ACCEPTED"

static func get_contact_view(state: Dictionary, friend_id: String, day: int) -> Dictionary:
	# The player-visible message list for a friend on a given day (hidden records excluded).
	var visible: Array = []
	for record: Dictionary in state["messages"].get(friend_id, []):
		if str(record["visibility"]) != "visible":
			continue
		if int(record["target_day"]) > day:
			continue
		visible.append(record)
	if friend_id == "sylvia": visible.append_array(get_pending_sylvia_care(state, day))
	return {"messages": visible}

static func get_schedule_source_receipt(state: Dictionary, receipt_id: String) -> Dictionary:
	if receipt_id.strip_edges().is_empty():
		return _fail(&"invalid_source_receipt_id", "receipt_id must be nonblank")
	var index: Variant = state.get("schedule_source_receipts")
	if typeof(index) != TYPE_DICTIONARY or not (index as Dictionary).has(receipt_id):
		return _fail(&"schedule_source_receipt_absent", receipt_id)
	var receipt: Variant = (index as Dictionary)[receipt_id]
	var shape := _validate_source_receipt_shape(receipt_id, receipt)
	if not shape.get("ok", false):
		return shape
	return {"ok": true, "code": &"ok", "value": {"receipt": (receipt as Dictionary).duplicate(true)}, "receipt": {}}

static func validate_schedule_source_receipt(state: Dictionary, receipt_id: String,
		action_record: Dictionary, expected_day: int) -> Dictionary:
	var found := get_schedule_source_receipt(state, receipt_id)
	if not found.get("ok", false):
		return found
	var receipt: Dictionary = found["value"]["receipt"]
	var action_id := str(receipt["action_id"])
	var kind := str(receipt["kind"])
	var expected_action_kind := "solo" if kind == "solo_read_acceptance" else "group"
	var expected_source_kind := kind
	var record_check := _validate_action_record(action_record, action_id,
		expected_action_kind, receipt["participants"], expected_source_kind, expected_day)
	if not record_check.get("ok", false):
		return record_check
	if typeof(receipt["day"]) != TYPE_INT or int(receipt["day"]) != expected_day:
		return _fail(&"schedule_source_day_mismatch", str(receipt["day"]))
	var linkage := _validate_source_receipt_linkage(state, receipt_id, receipt)
	if not linkage.get("ok", false):
		return linkage
	var provenance: Variant = receipt["receipt_provenance"]
	if typeof(provenance) != TYPE_DICTIONARY or not _has_exact_keys(provenance,
			_SOURCE_PROVENANCE_KEYS):
		return _fail(&"schedule_source_provenance_malformed", receipt_id)
	if str((provenance as Dictionary).get("child_id", "")) != receipt_id \
			or str((provenance as Dictionary).get("child_kind", "")) != "contact_source" \
			or typeof((provenance as Dictionary).get("ordinal")) != TYPE_INT \
			or int((provenance as Dictionary)["ordinal"]) != 0:
		return _fail(&"schedule_source_provenance_mismatch", receipt_id)
	return {"ok": true, "code": &"ok", "value": {"receipt": receipt.duplicate(true)}, "receipt": {}}

# ---- internals ----

static func _classify_pl_window(day: int, pre_group_state: String, attendance: Dictionary) -> Dictionary:
	# One rule (story/05 §7): did Angela solo-date either woman this window?
	var attended: Array = attendance.get("solo_attended_action_ids", [])
	for participant: String in GROUP_PAIR:
		if ("solo:%s:day%d" % [participant, day]) in attended:
			return {"outcome": "prevented", "counts": false, "visible": false}
	# Solo-dated neither: the pair always meets and counts once; flavor by group state.
	if pre_group_state not in GROUP_OPEN_STATES:
		return {"outcome": "private_offscreen", "counts": true, "visible": false}
	if pre_group_state == "ACCEPTED":
		if str(attendance.get("group_outcome", "not_scheduled")) == "attended":
			return {"outcome": "group", "counts": true, "visible": true}
		return {"outcome": "missed", "counts": true, "visible": true}
	return {"outcome": "private_visible", "counts": true, "visible": true}

static func _queue_group_message(detached: Dictionary, recipient: String, msg_type: String, target_day: int, transaction_id: String, message_batch: Array, message_ids: Array, message_sequences: Array, child_transaction_ids: Array) -> void:
	var sequence := int(detached["next_sequence"])
	var message_tx := "%s:message:%d" % [transaction_id, child_transaction_ids.size()]
	var record := {
		"message_id": "%s:%s:day%d" % [msg_type, recipient, target_day],
		"sequence": sequence,
		"type": msg_type,
		"variant": "default",
		"target_day": target_day,
		"parameters": {},
		"visibility": "visible",
		"transaction_id": message_tx,
	}
	(detached["messages"][recipient] as Array).append(record)
	detached["next_sequence"] = sequence + 1
	message_batch.append(record)
	message_ids.append(str(record["message_id"]))
	message_sequences.append(sequence)
	child_transaction_ids.append(message_tx)

static func _routes_to_group(state: Dictionary, friend_id: String, day: int) -> bool:
	var group: Dictionary = state["group_action"]
	if str(group["state"]) not in GROUP_OPEN_STATES:
		return false
	return friend_id in GROUP_PAIR and int(group["day"]) == day

static func _other_participant(friend_id: String) -> String:
	return GROUP_PAIR[1] if friend_id == GROUP_PAIR[0] else GROUP_PAIR[0]

static func _canonical_participants(ids: Array) -> Array:
	var ordered: Array = []
	for participant: String in GROUP_PAIR:
		if participant in ids:
			ordered.append(participant)
	return ordered

static func _group_offer_record(action_id: String, recipient: String, inviter_id: String, day: int, variant: String, sequence: int, message_tx: String) -> Dictionary:
	return {
		"message_id": "group_offer:%s:day%d:%s" % [GROUP_PAIR_KEY, day, recipient],
		"sequence": sequence,
		"type": "group_offer",
		"variant": variant,
		"target_day": day,
		"parameters": {"action_id": action_id, "inviter_id": inviter_id},
		"visibility": "visible",
		"transaction_id": message_tx,
	}

static func _open_group(detached: Dictionary, friend_id: String, transaction_id: String,
		command_issuer_receipt: Dictionary) -> Dictionary:
	var group: Dictionary = detached["group_action"]
	var day := int(group["day"])
	var action_id := str(group["action_id"])
	if str(group["state"]) == "AVAILABLE_UNOPENED":
		# First open: the opener becomes presentation-only inviter; two records appear.
		group["inviter_id"] = friend_id
		group["opened_ids"] = [friend_id]
		group["history_generated"] = true
		group["state"] = "REPLY_REQUIRED"
		var other := _other_participant(friend_id)
		var inviter_seq := int(detached["next_sequence"])
		var inviter_tx := "%s:message:0" % transaction_id
		var inviter_record := _group_offer_record(action_id, friend_id, friend_id, day, "first_open", inviter_seq, inviter_tx)
		(detached["messages"][friend_id] as Array).append(inviter_record)
		var other_seq := inviter_seq + 1
		var other_tx := "%s:message:1" % transaction_id
		var other_record := _group_offer_record(action_id, other, friend_id, day, "second_open", other_seq, other_tx)
		(detached["messages"][other] as Array).append(other_record)
		detached["next_sequence"] = other_seq + 1
		# Advance only the inviter's watermark through their own new record.
		detached["read_watermarks"][friend_id] = maxi(int(detached["read_watermarks"][friend_id]), inviter_seq)
		var receipt := {
			"transaction_id": transaction_id,
			"kind": "open_group_first",
			"action_id": action_id,
			"day": day,
			"friend_id": friend_id,
			"child_transaction_ids": [inviter_tx, other_tx],
			"message_ids": [str(inviter_record["message_id"]), str(other_record["message_id"])],
			"message_sequences": [inviter_seq, other_seq],
			"command_issuer_receipt": command_issuer_receipt.duplicate(true),
		}
		detached["transaction_receipts"][transaction_id] = receipt
		return _ok(detached, [inviter_record, other_record], receipt)
	# Second open: append nothing; advance only this participant's watermark.
	if friend_id not in group["opened_ids"]:
		(group["opened_ids"] as Array).append(friend_id)
		group["opened_ids"] = _canonical_participants(group["opened_ids"])
	var new_watermark := int(detached["read_watermarks"][friend_id])
	for record: Dictionary in detached["messages"][friend_id]:
		if str(record["visibility"]) != "visible" or int(record["target_day"]) > day:
			continue
		new_watermark = maxi(new_watermark, int(record["sequence"]))
	detached["read_watermarks"][friend_id] = new_watermark
	var second_receipt := {
		"transaction_id": transaction_id,
		"kind": "open_group_second",
		"action_id": action_id,
		"day": day,
		"friend_id": friend_id,
		"child_transaction_ids": [],
		"message_ids": [],
		"message_sequences": [],
		"command_issuer_receipt": command_issuer_receipt.duplicate(true),
	}
	detached["transaction_receipts"][transaction_id] = second_receipt
	return _ok(detached, [], second_receipt)

static func _reply_group(detached: Dictionary, friend_id: String, transaction_id: String,
		command_issuer_receipt: Dictionary, identity_issuer: Object,
		action_record: Dictionary) -> Dictionary:
	var group: Dictionary = detached["group_action"]
	if str(group["state"]) != "REPLY_REQUIRED":
		return _fail(&"invalid_transition", "group is %s" % group["state"])
	var action_id := str(group["action_id"])
	var day := int(group["day"])
	var record_check := _validate_action_record(action_record, action_id, "group",
		GROUP_PAIR, "group_reply_acceptance", day)
	if not record_check.get("ok", false):
		return record_check
	var previous_receipt_id := str(group["transaction_id"])
	var source := _derive_source(identity_issuer, command_issuer_receipt,
		transaction_id, action_id, day, GROUP_PAIR, previous_receipt_id,
		"group_reply_acceptance", "contact_source.group")
	if not source.get("ok", false):
		return source
	var source_receipt: Dictionary = source["value"]["receipt"]
	var from_state := str(group["state"])
	group["replied_ids"] = [friend_id]
	group["state"] = "ACCEPTED"
	detached["schedule_source_receipts"][source_receipt["receipt_id"]] = source_receipt.duplicate(true)
	var operation_receipt := {
		"transaction_id": transaction_id,
		"kind": "reply_group",
		"action_id": action_id,
		"day": day,
		"friend_id": friend_id,
		"from_state": from_state,
		"to_state": "ACCEPTED",
		"command_issuer_receipt": command_issuer_receipt.duplicate(true),
		"source_receipt_id": str(source_receipt["receipt_id"]),
	}
	detached["transaction_receipts"][transaction_id] = operation_receipt
	return _ok(detached, [], source_receipt)

static func _offer_sequence(state: Dictionary, action: Dictionary) -> int:
	for record: Dictionary in state["messages"].get(str(action["friend_id"]), []):
		if str(record["message_id"]) == str(action["offer_message_id"]):
			return int(record["sequence"])
	return 0

static func _verify_command(identity_issuer: Object, command_id: String,
		command_issuer_receipt: Dictionary) -> Dictionary:
	if identity_issuer == null or not identity_issuer.has_method("verify_issued") \
			or not identity_issuer.has_method("derive_child") \
			or not identity_issuer.has_method("validate_child"):
		return _fail(&"identity_issuer_unconfigured", "an identity issuer is required")
	if command_issuer_receipt.is_empty():
		return _fail(&"command_issuer_receipt_required", "a full issuer receipt is required")
	var verified: Variant = identity_issuer.call(
		&"verify_issued", command_issuer_receipt, &"transaction_id")
	if typeof(verified) != TYPE_DICTIONARY or not (verified as Dictionary).get("ok", false):
		return _fail(&"command_issuer_receipt_invalid", "issuer verification failed",
			{"cause": (verified as Dictionary).get("code", &"") if typeof(verified) == TYPE_DICTIONARY else &"invalid_result"})
	if str(command_issuer_receipt.get("token", "")) != command_id:
		return _fail(&"command_id_receipt_mismatch", command_id)
	return {"ok": true, "code": &"ok", "value": {}, "receipt": {}}

static func _validate_action_record(record: Dictionary, action_id: String,
		action_kind: String, participants: Array, source_kind: String, day: int) -> Dictionary:
	if not _has_exact_keys(record, _ACTION_RECORD_KEYS):
		return _fail(&"schedule_action_record_malformed", action_id)
	if typeof(record["action_id"]) != TYPE_STRING or record["action_id"] != action_id \
			or typeof(record["action_kind"]) != TYPE_STRING or record["action_kind"] != action_kind \
			or typeof(record["participants"]) != TYPE_ARRAY \
			or not _is_exact_string_array(record["participants"], participants) \
			or typeof(record["source_receipt_kind"]) != TYPE_STRING \
			or record["source_receipt_kind"] != source_kind:
		return _fail(&"schedule_action_record_mismatch", action_id)
	if typeof(record["allowed_days"]) != TYPE_ARRAY \
			or not _is_strict_day_array(record["allowed_days"]) \
			or not _is_exact_int_array(record["allowed_days"], [day]):
		return _fail(&"schedule_action_day_mismatch", str(day))
	if typeof(record["effect_ids"]) != TYPE_ARRAY \
			or not _is_sorted_unique_string_array(record["effect_ids"]) \
			or not (record["effect_ids"] as Array).is_empty() \
			or typeof(record["motivation_cost"]) != TYPE_INT or record["motivation_cost"] != 1 \
			or typeof(record["repeatable"]) != TYPE_BOOL or record["repeatable"]:
		return _fail(&"schedule_action_record_mismatch", action_id)
	var expected_route: Variant = null if day == 7 else "dating"
	if record["route_id"] != expected_route \
			or (expected_route == null and record["route_id"] != null) \
			or (expected_route != null and typeof(record["route_id"]) != TYPE_STRING):
		return _fail(&"schedule_action_record_mismatch", action_id)
	return {"ok": true, "code": &"ok", "value": {}, "receipt": {}}

static func _derive_source(identity_issuer: Object, command_issuer_receipt: Dictionary,
		command_id: String, action_id: String, day: int, participants: Array,
		previous_receipt_id: String, source_kind: String, role: String) -> Dictionary:
	if previous_receipt_id.strip_edges().is_empty():
		return _fail(&"source_predecessor_absent", action_id)
	var sources: Array[String] = []
	for pair: Array in [
		["role", role], ["command_id", command_id], ["kind", source_kind],
		["action_id", action_id], ["day", day], ["participants", participants],
		["previous_receipt_id", previous_receipt_id],
	]:
		var projected := _project(str(pair[0]), pair[1])
		if not projected.get("ok", false):
			return projected
		sources.append(str(projected["value"]))
	sources.sort()
	var request := {
		"parent_receipt_id": str(command_issuer_receipt["receipt_id"]),
		"child_kind": &"contact_source",
		"ordinal": 0,
		"source_ids": sources,
	}
	var derived: Variant = identity_issuer.call(&"derive_child", request)
	if typeof(derived) != TYPE_DICTIONARY or not (derived as Dictionary).get("ok", false):
		return _fail(&"schedule_source_derivation_failed", action_id,
			{"cause": (derived as Dictionary).get("code", &"") if typeof(derived) == TYPE_DICTIONARY else &"invalid_result"})
	var value: Variant = (derived as Dictionary).get("value")
	if typeof(value) != TYPE_DICTIONARY or typeof((value as Dictionary).get("provenance")) != TYPE_DICTIONARY:
		return _fail(&"schedule_source_derivation_malformed", action_id)
	var provenance: Dictionary = (value as Dictionary)["provenance"]
	var child_id := str((value as Dictionary).get("child_id", ""))
	if child_id.is_empty() or provenance.get("child_id") != child_id \
			or (derived as Dictionary).get("receipt") != provenance:
		return _fail(&"schedule_source_derivation_malformed", action_id)
	var validated: Variant = identity_issuer.call(&"validate_child", provenance, &"contact_source")
	if typeof(validated) != TYPE_DICTIONARY or not (validated as Dictionary).get("ok", false):
		return _fail(&"schedule_source_derivation_invalid", action_id)
	var receipt := {
		"receipt_id": child_id,
		"receipt_provenance": provenance.duplicate(true),
		"kind": source_kind,
		"action_id": action_id,
		"day": day,
		"participants": participants.duplicate(true),
		"previous_receipt_id": previous_receipt_id,
	}
	return {"ok": true, "code": &"ok", "value": {"receipt": receipt}, "receipt": {}}

static func _project(path: String, value: Variant) -> Dictionary:
	var normalized: Variant = String(value) if typeof(value) == TYPE_STRING_NAME else value
	var emitted: Dictionary = _CANONICAL_WRITER.stringify(normalized)
	if not emitted.get("ok", false):
		return _fail(&"schedule_source_projection_invalid", path)
	return {"ok": true, "code": &"ok", "value": "%s=%s" % [path, str(emitted["value"])], "receipt": {}}

static func _replay_authenticated(detached: Dictionary, transaction_id: String,
		friend_id: String, day: int, command_issuer_receipt: Dictionary,
		identity_issuer: Object, operation: StringName) -> Dictionary:
	var stored: Variant = detached["transaction_receipts"][transaction_id]
	if typeof(stored) != TYPE_DICTIONARY:
		return _fail(&"command_transaction_conflict", transaction_id)
	var receipt: Dictionary = stored
	var expected_kinds := ["open_solo_acceptance", "open_group_first", "open_group_second"] \
		if operation == &"open" else ["reply_group"]
	if str(receipt.get("kind", "")) not in expected_kinds \
			or str(receipt.get("friend_id", "")) != friend_id \
			or int(receipt.get("day", -1)) != day \
			or receipt.get("command_issuer_receipt") != command_issuer_receipt:
		return _fail(&"command_transaction_conflict", transaction_id)
	var operation_linkage := _validate_operation_linkage(detached, transaction_id, receipt)
	if not operation_linkage.get("ok", false):
		return operation_linkage
	var source_id := str(receipt.get("source_receipt_id", ""))
	var outer: Dictionary = receipt.duplicate(true)
	if not source_id.is_empty():
		var found := get_schedule_source_receipt(detached, source_id)
		if not found.get("ok", false):
			return found
		var linkage := _validate_source_receipt_linkage(detached, source_id,
			found["value"]["receipt"])
		if not linkage.get("ok", false):
			return linkage
		var source_receipt: Dictionary = found["value"]["receipt"]
		var validated: Variant = identity_issuer.call(
			&"validate_child", source_receipt["receipt_provenance"], &"contact_source")
		var validated_value: Variant = (validated as Dictionary).get("value") \
			if typeof(validated) == TYPE_DICTIONARY else null
		if typeof(validated) != TYPE_DICTIONARY \
				or not (validated as Dictionary).get("ok", false) \
				or typeof(validated_value) != TYPE_DICTIONARY \
				or (validated_value as Dictionary).get("provenance") \
					!= source_receipt["receipt_provenance"]:
			return _fail(&"schedule_source_derivation_invalid",
				"authenticated replay could not reproduce the retained source child")
		outer = source_receipt
	return _ok(detached, [], outer)

static func _replay(detached: Dictionary, transaction_id: String) -> Dictionary:
	var receipt: Dictionary = detached["transaction_receipts"][transaction_id]
	return _ok(detached, [], receipt)

static func _validate_message_record(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY or not _has_exact_keys(value, _MESSAGE_KEYS):
		return _fail(&"invalid_state", "message records have one exact shape")
	var record: Dictionary = value
	if typeof(record["message_id"]) != TYPE_STRING or str(record["message_id"]).strip_edges().is_empty() \
			or typeof(record["sequence"]) != TYPE_INT or int(record["sequence"]) < 1 \
			or typeof(record["target_day"]) != TYPE_INT \
			or int(record["target_day"]) < 1 or int(record["target_day"]) > 7 \
			or typeof(record["transaction_id"]) != TYPE_STRING \
			or str(record["transaction_id"]).strip_edges().is_empty() \
			or typeof(record["type"]) != TYPE_STRING \
			or str(record["type"]) not in [
				"solo_offer", "group_offer", "nevermind", "missed_question", "busy", "judge", "hospital_care",
				"ordinary_incoming", "ordinary_reply", "ordinary_response"] \
			or typeof(record["variant"]) != TYPE_STRING \
			or typeof(record["visibility"]) != TYPE_STRING \
			or str(record["visibility"]) not in ["visible", "superseded_hidden"] \
			or typeof(record["parameters"]) != TYPE_DICTIONARY:
		return _fail(&"invalid_state", "message record primitives are invalid")
	if record["type"] == "group_offer":
		if record["variant"] not in ["first_open", "second_open"] \
				or not _has_exact_keys(record["parameters"], ["action_id", "inviter_id"]) \
				or typeof(record["parameters"]["action_id"]) != TYPE_STRING \
				or str(record["parameters"]["action_id"]).strip_edges().is_empty() \
				or typeof(record["parameters"]["inviter_id"]) != TYPE_STRING \
				or str(record["parameters"]["inviter_id"]) not in GROUP_PAIR:
			return _fail(&"invalid_state", "group-offer message parameters are invalid")
	elif record["type"] in ORDINARY_REPLIES.MESSAGE_KINDS:
		if record.variant != "default" or not _has_exact_keys(record.parameters, ["reply_transaction_id"]) \
				or not record.parameters.reply_transaction_id is String or record.parameters.reply_transaction_id.is_empty():
			return _fail(&"invalid_state", "ordinary history requires its reply owner")
	elif record["type"] == "hospital_care":
		if record.variant != "default" or not _has_exact_keys(record.parameters, ["witness_id"]) \
				or not record.parameters.witness_id is String or record.parameters.witness_id.is_empty():
			return _fail(&"invalid_state", "Hospital care requires its exact witness identity")
	elif record["variant"] != "default" or not (record["parameters"] as Dictionary).is_empty():
		return _fail(&"invalid_state", "ordinary contact messages use default/empty parameters")
	return {"ok": true, "code": &"ok", "value": {}, "receipt": {}}

static func _validate_solo_action(state: Dictionary, action_key: Variant, value: Variant) -> Dictionary:
	if typeof(action_key) != TYPE_STRING or typeof(value) != TYPE_DICTIONARY \
			or not _has_exact_keys(value, _SOLO_ACTION_KEYS):
		return _fail(&"invalid_state", "solo actions have exact string keys and records")
	var action: Dictionary = value
	if typeof(action["action_id"]) != TYPE_STRING or action["action_id"] != action_key \
			or typeof(action["friend_id"]) != TYPE_STRING or action["friend_id"] not in FRIEND_IDS \
			or typeof(action["day"]) != TYPE_INT or int(action["day"]) < 1 or int(action["day"]) > 7 \
			or action["action_id"] != "solo:%s:day%d" % [action["friend_id"], action["day"]] \
			or typeof(action["state"]) != TYPE_STRING or action["state"] not in [
				"AVAILABLE", "ACCEPTED", "SUPERSEDED", "RESOLVED_UNANSWERED",
				"RESOLVED_ATTENDED", "RESOLVED_MISSED", "RESOLVED_RUN_END"] \
			or typeof(action["offer_message_id"]) != TYPE_STRING \
			or str(action["offer_message_id"]).strip_edges().is_empty() \
			or typeof(action["transaction_id"]) != TYPE_STRING \
			or str(action["transaction_id"]).strip_edges().is_empty():
		return _fail(&"invalid_state", "solo action primitives are invalid")
	if action["reply_transaction_id"] != null \
			and (typeof(action["reply_transaction_id"]) != TYPE_STRING \
			or str(action["reply_transaction_id"]).strip_edges().is_empty()):
		return _fail(&"invalid_state", "solo reply transaction must be null or a nonblank string")
	var found_offer := false
	for message: Variant in state["messages"][action["friend_id"]]:
		if typeof(message) == TYPE_DICTIONARY \
				and (message as Dictionary).get("message_id") == action["offer_message_id"] \
				and (message as Dictionary).get("type") == "solo_offer" \
				and (message as Dictionary).get("target_day") == action["day"] \
				and (message as Dictionary).get("transaction_id") == "%s:message:0" % action["transaction_id"]:
			found_offer = true
			break
	if not found_offer:
		return _fail(&"invalid_state", "solo action offer message linkage is absent")
	return {"ok": true, "code": &"ok", "value": {}, "receipt": {}}

static func _validate_group_action(state: Dictionary, value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY or not _has_exact_keys(value, _GROUP_ACTION_KEYS):
		return _fail(&"invalid_state", "group action has one exact record shape")
	var group: Dictionary = value
	if typeof(group["state"]) != TYPE_STRING or group["state"] not in [
			"INACTIVE", "AVAILABLE_UNOPENED", "REPLY_REQUIRED", "ACCEPTED",
			"RESOLVED_UNANSWERED", "RESOLVED_ATTENDED", "RESOLVED_MISSED", "RESOLVED_RUN_END"] \
			or not _is_exact_string_array(group["participant_ids"], GROUP_PAIR) \
			or not _is_canonical_participant_subset(group["opened_ids"]) \
			or not _is_canonical_participant_subset(group["replied_ids"]) \
			or typeof(group["history_generated"]) != TYPE_BOOL:
		return _fail(&"invalid_state", "group action primitives are invalid")
	if group["state"] == "INACTIVE":
		if group["action_id"] != null or group["day"] != null or group["inviter_id"] != null \
				or not (group["opened_ids"] as Array).is_empty() \
				or not (group["replied_ids"] as Array).is_empty() or group["history_generated"] \
				or group["transaction_id"] != null:
			return _fail(&"invalid_state", "inactive group action differs from exact defaults")
		return {"ok": true, "code": &"ok", "value": {}, "receipt": {}}
	if typeof(group["action_id"]) != TYPE_STRING \
			or typeof(group["day"]) != TYPE_INT or int(group["day"]) not in GROUP_WINDOW_DAYS \
			or group["action_id"] != "group:%s:day%d" % [GROUP_PAIR_KEY, group["day"]] \
			or typeof(group["transaction_id"]) != TYPE_STRING \
			or str(group["transaction_id"]).strip_edges().is_empty():
		return _fail(&"invalid_state", "active group identity primitives are invalid")
	if group["inviter_id"] != null \
			and (typeof(group["inviter_id"]) != TYPE_STRING or group["inviter_id"] not in GROUP_PAIR):
		return _fail(&"invalid_state", "group inviter is outside the canonical pair")
	if group["state"] == "AVAILABLE_UNOPENED":
		if group["inviter_id"] != null or not (group["opened_ids"] as Array).is_empty() \
				or not (group["replied_ids"] as Array).is_empty() or group["history_generated"]:
			return _fail(&"invalid_state", "unopened group state is internally inconsistent")
	elif group["state"] == "REPLY_REQUIRED":
		if group["inviter_id"] == null or (group["opened_ids"] as Array).is_empty() \
				or not (group["replied_ids"] as Array).is_empty() or not group["history_generated"]:
			return _fail(&"invalid_state", "reply-required group state is internally inconsistent")
	elif group["state"] in ["ACCEPTED", "RESOLVED_ATTENDED", "RESOLVED_MISSED"]:
		if group["inviter_id"] == null or (group["opened_ids"] as Array).is_empty() \
				or (group["replied_ids"] as Array).size() != 1 or not group["history_generated"]:
			return _fail(&"invalid_state", "accepted group state is internally inconsistent")
	return {"ok": true, "code": &"ok", "value": {}, "receipt": {}}

static func _validate_transaction_receipt(transaction_key: Variant, value: Variant) -> Dictionary:
	if typeof(transaction_key) != TYPE_STRING or str(transaction_key).strip_edges().is_empty() \
			or typeof(value) != TYPE_DICTIONARY:
		return _fail(&"invalid_state", "transaction receipts require string keys and dictionaries")
	var receipt: Dictionary = value
	if typeof(receipt.get("transaction_id")) != TYPE_STRING \
			or receipt.get("transaction_id") != transaction_key \
			or typeof(receipt.get("kind")) != TYPE_STRING:
		return _fail(&"invalid_state", "transaction receipt identity is invalid")
	if receipt.has("hospital_care"):
		var care_shape := _validate_care_claim(receipt)
		if not care_shape.ok: return care_shape
	match receipt["kind"]:
		"ordinary_reply", "ordinary_echo_presented":
			return ORDINARY_REPLIES.validate_receipt(receipt)
		"open_sylvia_care":
			if not _has_exact_keys(receipt, ["kind", "transaction_id", "friend_id", "day", "command_issuer_receipt", "hospital_care"]):
				return _fail(&"invalid_state", "care-only operation has exact keys")
			return _validate_command_receipt(receipt.command_issuer_receipt, receipt.transaction_id)
		"offer_solo":
			return _validate_offer_operation(receipt)
		"open_solo_acceptance":
			return _validate_open_solo_operation(receipt)
		"activate_group":
			return _validate_activate_group_operation(receipt)
		"open_group_first", "open_group_second":
			return _validate_open_group_operation(receipt)
		"reply_group":
			return _validate_reply_group_operation(receipt)
		"resolve_day_end":
			return _validate_resolve_operation(receipt)
	return _fail(&"invalid_state", "transaction receipt kind is outside the Task-3 union")

static func _validate_offer_operation(receipt: Dictionary) -> Dictionary:
	if not _has_exact_keys(receipt, _OFFER_SOLO_RECEIPT_KEYS) \
			or typeof(receipt["friend_id"]) != TYPE_STRING or receipt["friend_id"] not in FRIEND_IDS \
			or typeof(receipt["day"]) != TYPE_INT or int(receipt["day"]) < 1 or int(receipt["day"]) > 7 \
			or typeof(receipt["action_id"]) != TYPE_STRING \
			or receipt["action_id"] != "solo:%s:day%d" % [receipt["friend_id"], receipt["day"]] \
			or not _is_string_array(receipt["child_transaction_ids"]) \
			or not _is_string_array(receipt["message_ids"]) \
			or not _is_int_array(receipt["message_sequences"]) \
			or (receipt["child_transaction_ids"] as Array).size() != 1 \
			or (receipt["message_ids"] as Array).size() != 1 \
			or (receipt["message_sequences"] as Array).size() != 1:
		return _fail(&"invalid_state", "solo-offer operation is invalid")
	return {"ok": true, "code": &"ok", "value": {}, "receipt": {}}

static func _validate_open_solo_operation(receipt: Dictionary) -> Dictionary:
	if not _has_exact_keys(receipt, _OPEN_SOLO_RECEIPT_KEYS + (["hospital_care"] if receipt.has("hospital_care") else [])) \
			or typeof(receipt["friend_id"]) != TYPE_STRING or receipt["friend_id"] not in FRIEND_IDS \
			or typeof(receipt["day"]) != TYPE_INT or int(receipt["day"]) < 1 or int(receipt["day"]) > 7 \
			or typeof(receipt["action_id"]) != TYPE_STRING \
			or receipt["action_id"] != "solo:%s:day%d" % [receipt["friend_id"], receipt["day"]] \
			or typeof(receipt["prior_watermark"]) != TYPE_INT or int(receipt["prior_watermark"]) < 0 \
			or typeof(receipt["new_watermark"]) != TYPE_INT \
			or int(receipt["new_watermark"]) < int(receipt["prior_watermark"]) \
			or typeof(receipt["source_receipt_id"]) != TYPE_STRING \
			or not _is_prefixed_digest(receipt["source_receipt_id"], "contact_source."):
		return _fail(&"invalid_state", "solo-open operation is invalid")
	return _validate_command_receipt(receipt["command_issuer_receipt"], receipt["transaction_id"])

static func _validate_activate_group_operation(receipt: Dictionary) -> Dictionary:
	var expected_superseded: Array = []
	if typeof(receipt.get("day")) == TYPE_INT:
		for participant: String in GROUP_PAIR:
			expected_superseded.append("solo:%s:day%d" % [participant, receipt["day"]])
	if not _has_exact_keys(receipt, _ACTIVATE_GROUP_RECEIPT_KEYS) \
			or typeof(receipt["day"]) != TYPE_INT or int(receipt["day"]) not in GROUP_WINDOW_DAYS \
			or typeof(receipt["action_id"]) != TYPE_STRING \
			or receipt["action_id"] != "group:%s:day%d" % [GROUP_PAIR_KEY, receipt["day"]] \
			or not _is_exact_string_array(receipt["superseded_action_ids"], expected_superseded) \
			or not _is_exact_string_array(receipt["child_transaction_ids"], []) \
			or not _is_exact_string_array(receipt["message_ids"], []) \
			or not _is_exact_int_array(receipt["message_sequences"], []):
		return _fail(&"invalid_state", "group-activation operation is invalid")
	return {"ok": true, "code": &"ok", "value": {}, "receipt": {}}

static func _validate_open_group_operation(receipt: Dictionary) -> Dictionary:
	if not _has_exact_keys(receipt, _OPEN_GROUP_RECEIPT_KEYS) \
			or receipt["kind"] not in ["open_group_first", "open_group_second"] \
			or typeof(receipt["day"]) != TYPE_INT or int(receipt["day"]) not in GROUP_WINDOW_DAYS \
			or typeof(receipt["friend_id"]) != TYPE_STRING or receipt["friend_id"] not in GROUP_PAIR \
			or typeof(receipt["action_id"]) != TYPE_STRING \
			or receipt["action_id"] != "group:%s:day%d" % [GROUP_PAIR_KEY, receipt["day"]] \
			or not _is_string_array(receipt["child_transaction_ids"]) \
			or not _is_string_array(receipt["message_ids"]) \
			or not _is_int_array(receipt["message_sequences"]):
		return _fail(&"invalid_state", "group-open operation is invalid")
	var expected_size := 2 if receipt["kind"] == "open_group_first" else 0
	if (receipt["child_transaction_ids"] as Array).size() != expected_size \
			or (receipt["message_ids"] as Array).size() != expected_size \
			or (receipt["message_sequences"] as Array).size() != expected_size:
		return _fail(&"invalid_state", "group-open child arrays are invalid")
	return _validate_command_receipt(receipt["command_issuer_receipt"], receipt["transaction_id"])

static func _validate_reply_group_operation(receipt: Dictionary) -> Dictionary:
	if not _has_exact_keys(receipt, _REPLY_GROUP_RECEIPT_KEYS) \
			or typeof(receipt["day"]) != TYPE_INT or int(receipt["day"]) not in GROUP_WINDOW_DAYS \
			or typeof(receipt["friend_id"]) != TYPE_STRING or receipt["friend_id"] not in GROUP_PAIR \
			or typeof(receipt["action_id"]) != TYPE_STRING \
			or receipt["action_id"] != "group:%s:day%d" % [GROUP_PAIR_KEY, receipt["day"]] \
			or typeof(receipt["from_state"]) != TYPE_STRING or receipt["from_state"] != "REPLY_REQUIRED" \
			or typeof(receipt["to_state"]) != TYPE_STRING or receipt["to_state"] != "ACCEPTED" \
			or typeof(receipt["source_receipt_id"]) != TYPE_STRING \
			or not _is_prefixed_digest(receipt["source_receipt_id"], "contact_source."):
		return _fail(&"invalid_state", "group-reply operation is invalid")
	return _validate_command_receipt(receipt["command_issuer_receipt"], receipt["transaction_id"])

static func _validate_resolve_operation(receipt: Dictionary) -> Dictionary:
	if not _has_exact_keys(receipt, _RESOLVE_RECEIPT_KEYS + (["ordinary_expired_entry_id"] if receipt.has("ordinary_expired_entry_id") else [])) \
			or typeof(receipt["day"]) != TYPE_INT or int(receipt["day"]) < 1 or int(receipt["day"]) > 7 \
			or not _is_string_array(receipt["child_transaction_ids"]) \
			or not _is_string_array(receipt["message_ids"]) \
			or not _is_int_array(receipt["message_sequences"]) \
			or not _is_string_array(receipt["date_outcome_ids"]) \
			or (receipt["child_transaction_ids"] as Array).size() != (receipt["message_ids"] as Array).size() \
			or (receipt["message_ids"] as Array).size() != (receipt["message_sequences"] as Array).size() \
			or typeof(receipt["state_transitions"]) != TYPE_ARRAY \
			or typeof(receipt["counter_deltas"]) != TYPE_DICTIONARY:
		return _fail(&"invalid_state", "day-end operation primitives are invalid")
	if receipt.has("ordinary_expired_entry_id"):
		var entry_id := ORDINARY_REPLIES.entry_id_for_day(receipt.day)
		if entry_id.is_empty() or not receipt.ordinary_expired_entry_id is String \
				or receipt.ordinary_expired_entry_id != entry_id:
			return _fail(&"invalid_state", "ordinary expiry must identify this day's registered entry")
	for transition: Variant in receipt["state_transitions"]:
		if typeof(transition) != TYPE_DICTIONARY \
				or not _has_exact_keys(transition, ["action_id", "from_state", "to_state"]) \
				or typeof((transition as Dictionary)["action_id"]) != TYPE_STRING \
				or str((transition as Dictionary)["action_id"]).strip_edges().is_empty() \
				or typeof((transition as Dictionary)["from_state"]) != TYPE_STRING \
				or typeof((transition as Dictionary)["to_state"]) != TYPE_STRING:
			return _fail(&"invalid_state", "day-end transition record is invalid")
	if receipt["group_date_variation"] != null \
			and (typeof(receipt["group_date_variation"]) != TYPE_STRING \
			or receipt["group_date_variation"] not in ["judgmental", "normal"]):
		return _fail(&"invalid_state", "group date variation is invalid")
	if receipt["deferred_twofriends"] != null:
		var deferred: Variant = receipt["deferred_twofriends"]
		if typeof(deferred) != TYPE_DICTIONARY \
				or not _has_exact_keys(deferred, ["action_id", "after_hospital", "route_id"]) \
				or typeof((deferred as Dictionary)["action_id"]) != TYPE_STRING \
				or str((deferred as Dictionary)["action_id"]).strip_edges().is_empty() \
				or typeof((deferred as Dictionary)["after_hospital"]) != TYPE_BOOL \
				or typeof((deferred as Dictionary)["route_id"]) != TYPE_STRING \
				or (deferred as Dictionary)["route_id"] != "dating":
			return _fail(&"invalid_state", "deferred two-friends record is invalid")
	if receipt["pl_window"] != null:
		var window: Variant = receipt["pl_window"]
		if typeof(window) != TYPE_DICTIONARY \
				or not _has_exact_keys(window, ["counts", "outcome", "visible"]) \
				or typeof((window as Dictionary)["counts"]) != TYPE_BOOL \
				or typeof((window as Dictionary)["visible"]) != TYPE_BOOL \
				or typeof((window as Dictionary)["outcome"]) != TYPE_STRING \
				or (window as Dictionary)["outcome"] not in [
					"prevented", "private_offscreen", "private_visible", "group", "missed"]:
			return _fail(&"invalid_state", "PL-window record is invalid")
	for key: Variant in receipt["counter_deltas"]:
		if typeof(key) != TYPE_STRING or str(key).strip_edges().is_empty() \
				or typeof(receipt["counter_deltas"][key]) != TYPE_INT:
			return _fail(&"invalid_state", "counter deltas require string/int primitives")
	return {"ok": true, "code": &"ok", "value": {}, "receipt": {}}

static func _validate_command_receipt(value: Variant, transaction_id: String) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY or not _has_exact_keys(value, _ISSUER_RECEIPT_KEYS):
		return _fail(&"invalid_state", "authenticated operations retain one exact issuer receipt")
	var receipt: Dictionary = value
	if typeof(receipt["receipt_id"]) != TYPE_STRING \
			or not _is_prefixed_digest(receipt["receipt_id"], "issuer_receipt.") \
			or typeof(receipt["purpose"]) != TYPE_STRING or receipt["purpose"] != "transaction_id" \
			or typeof(receipt["namespace"]) != TYPE_STRING \
			or not _is_prefixed_digest(receipt["namespace"], "") \
			or typeof(receipt["counter"]) != TYPE_INT or int(receipt["counter"]) < 1 \
			or typeof(receipt["token"]) != TYPE_STRING or receipt["token"] != transaction_id \
			or not _is_prefixed_digest(receipt["token"], "transaction_id.") \
			or receipt["numeric_value"] != null:
		return _fail(&"invalid_state", "authenticated operation issuer receipt primitives are invalid")
	return {"ok": true, "code": &"ok", "value": {}, "receipt": {}}

static func _validate_operation_linkage(state: Dictionary, transaction_id: String,
		value: Variant) -> Dictionary:
	var shape := _validate_transaction_receipt(transaction_id, value)
	if not shape.get("ok", false):
		return shape
	var receipt: Dictionary = value
	if receipt.has("hospital_care"):
		var care_link := _validate_care_linkage(state, receipt)
		if not care_link.ok or receipt.kind == "open_sylvia_care": return care_link
	match receipt["kind"]:
		"ordinary_reply", "ordinary_echo_presented":
			# Cross-row ownership is checked once by validate_state below.
			return {"ok": true}
		"offer_solo":
			return _validate_offer_linkage(state, receipt)
		"open_solo_acceptance":
			return _validate_open_solo_linkage(state, receipt)
		"activate_group":
			return _validate_activate_group_linkage(state, receipt)
		"open_group_first", "open_group_second", "reply_group":
			return _validate_group_history_linkage(state, receipt["action_id"], receipt["day"])
		"resolve_day_end":
			return _validate_resolve_linkage(state, receipt)
	return _fail(&"invalid_state", "operation linkage is outside the Task-3 union")


static func _validate_offer_linkage(state: Dictionary, receipt: Dictionary) -> Dictionary:
	var actions: Variant = state.get("solo_actions")
	if typeof(actions) != TYPE_DICTIONARY or not (actions as Dictionary).has(receipt["action_id"]):
		return _fail(&"invalid_state", "solo-offer action linkage is absent")
	var action_value: Variant = (actions as Dictionary)[receipt["action_id"]]
	if typeof(action_value) != TYPE_DICTIONARY:
		return _fail(&"invalid_state", "solo-offer action linkage is malformed")
	var action: Dictionary = action_value
	if action.get("transaction_id") != receipt["transaction_id"] \
			or action.get("friend_id") != receipt["friend_id"] \
			or action.get("day") != receipt["day"] \
			or action.get("offer_message_id") != receipt["message_ids"][0] \
			or receipt["child_transaction_ids"][0] \
				!= "%s:message:0" % receipt["transaction_id"]:
		return _fail(&"invalid_state", "solo-offer action and operation differ")
	var message := _find_exact_message(state, receipt["friend_id"],
		receipt["message_ids"][0], receipt["child_transaction_ids"][0],
		receipt["message_sequences"][0])
	if message.is_empty() or message.get("type") != "solo_offer" \
			or message.get("target_day") != receipt["day"]:
		return _fail(&"invalid_state", "solo-offer operation does not own its retained message")
	var action_state: Variant = action.get("state")
	var reply_id: Variant = action.get("reply_transaction_id")
	var expected_visibility: String = "superseded_hidden" if action_state == "SUPERSEDED" else "visible"
	if message.get("visibility") != expected_visibility:
		return _fail(&"invalid_state", "solo-offer visibility differs from its action lineage")
	if action_state == "AVAILABLE":
		var watermarks: Variant = state.get("read_watermarks")
		if typeof(watermarks) != TYPE_DICTIONARY \
				or typeof((watermarks as Dictionary).get(receipt["friend_id"])) != TYPE_INT \
				or (watermarks as Dictionary)[receipt["friend_id"]] >= message["sequence"]:
			return _fail(&"invalid_state", "available solo offer is already covered by its watermark")
	if action_state == "SUPERSEDED":
		var group := _group_for_day(state, int(action["day"]))
		var activation: Variant = state.get("transaction_receipts", {}).get(group.get("transaction_id"))
		if group.get("action_id") != "group:%s:day%d" % [GROUP_PAIR_KEY, action["day"]] \
				or not activation is Dictionary or activation.get("kind") != "activate_group" \
				or receipt["action_id"] not in activation.get("superseded_action_ids", []):
			return _fail(&"invalid_state", "superseded solo action has no owning group activation")
		var source_index: Variant = state.get("schedule_source_receipts")
		if typeof(source_index) != TYPE_DICTIONARY:
			return _fail(&"invalid_state", "superseded solo source index is absent")
		for source_value: Variant in (source_index as Dictionary).values():
			if typeof(source_value) == TYPE_DICTIONARY \
					and (source_value as Dictionary).get("action_id") == receipt["action_id"]:
				return _fail(&"invalid_state", "superseded solo action retains a source receipt")
	var accepted_lineage: bool = action_state in [
		"ACCEPTED", "RESOLVED_ATTENDED", "RESOLVED_MISSED"] \
		or (action_state == "RESOLVED_RUN_END" and reply_id != null)
	if accepted_lineage:
		if typeof(reply_id) != TYPE_STRING \
				or typeof(state.get("transaction_receipts")) != TYPE_DICTIONARY \
				or not state["transaction_receipts"].has(reply_id):
			return _fail(&"invalid_state", "accepted solo action has no retained opening")
		var opening: Variant = state["transaction_receipts"][reply_id]
		if typeof(opening) != TYPE_DICTIONARY \
				or (opening as Dictionary).get("kind") != "open_solo_acceptance" \
				or (opening as Dictionary).get("action_id") != receipt["action_id"]:
			return _fail(&"invalid_state", "accepted solo opening lineage differs")
	elif reply_id != null:
		return _fail(&"invalid_state", "unaccepted solo action retains a reply transaction")
	return {"ok": true, "code": &"ok", "value": {}, "receipt": {}}


static func _validate_open_solo_linkage(state: Dictionary, receipt: Dictionary) -> Dictionary:
	var actions: Variant = state.get("solo_actions")
	if typeof(actions) != TYPE_DICTIONARY or not (actions as Dictionary).has(receipt["action_id"]):
		return _fail(&"invalid_state", "solo-open action linkage is absent")
	var action_value: Variant = (actions as Dictionary)[receipt["action_id"]]
	if typeof(action_value) != TYPE_DICTIONARY:
		return _fail(&"invalid_state", "solo-open action linkage is malformed")
	var action: Dictionary = action_value
	if action.get("friend_id") != receipt["friend_id"] or action.get("day") != receipt["day"] \
			or action.get("reply_transaction_id") != receipt["transaction_id"] \
			or action.get("state") not in [
				"ACCEPTED", "RESOLVED_ATTENDED", "RESOLVED_MISSED", "RESOLVED_RUN_END"]:
		return _fail(&"invalid_state", "solo-open action lineage differs")
	var predecessor_id: Variant = action.get("transaction_id")
	if typeof(predecessor_id) != TYPE_STRING \
			or typeof(state.get("transaction_receipts")) != TYPE_DICTIONARY \
			or not state["transaction_receipts"].has(predecessor_id):
		return _fail(&"invalid_state", "solo-open predecessor is absent")
	var predecessor: Variant = state["transaction_receipts"][predecessor_id]
	var predecessor_shape := _validate_transaction_receipt(predecessor_id, predecessor)
	if not predecessor_shape.get("ok", false) \
			or (predecessor as Dictionary).get("kind") != "offer_solo" \
			or (predecessor as Dictionary).get("action_id") != receipt["action_id"]:
		return _fail(&"invalid_state", "solo-open predecessor differs from its offer")
	var offer_link := _validate_offer_linkage(state, predecessor)
	if not offer_link.get("ok", false):
		return offer_link
	var offer_sequence: int = predecessor["message_sequences"][0]
	if receipt["prior_watermark"] >= offer_sequence \
			or receipt["new_watermark"] < offer_sequence \
			or typeof(state.get("read_watermarks")) != TYPE_DICTIONARY \
			or typeof(state["read_watermarks"].get(receipt["friend_id"])) != TYPE_INT \
			or receipt["new_watermark"] > state["read_watermarks"][receipt["friend_id"]]:
		return _fail(&"invalid_state", "solo-open watermark does not cover its exact offer")
	var source_index: Variant = state.get("schedule_source_receipts")
	if typeof(source_index) != TYPE_DICTIONARY \
			or not (source_index as Dictionary).has(receipt["source_receipt_id"]):
		return _fail(&"invalid_state", "solo-open source receipt is absent")
	var source: Variant = (source_index as Dictionary)[receipt["source_receipt_id"]]
	if typeof(source) != TYPE_DICTIONARY \
			or (source as Dictionary).get("previous_receipt_id") != predecessor_id \
			or _source_command_id(source) != receipt["transaction_id"]:
		return _fail(&"invalid_state", "solo-open source receipt lineage differs")
	return {"ok": true, "code": &"ok", "value": {}, "receipt": {}}


static func _validate_activate_group_linkage(state: Dictionary, receipt: Dictionary) -> Dictionary:
	var group_value: Variant = _group_for_day(state, receipt["day"])
	if typeof(group_value) != TYPE_DICTIONARY:
		return _fail(&"invalid_state", "group activation has no retained action")
	var group: Dictionary = group_value
	if group.get("transaction_id") != receipt["transaction_id"] \
			or group.get("action_id") != receipt["action_id"] \
			or group.get("day") != receipt["day"]:
		return _fail(&"invalid_state", "group activation differs from its retained action")
	var actions: Variant = state.get("solo_actions")
	if typeof(actions) != TYPE_DICTIONARY:
		return _fail(&"invalid_state", "group activation supersession index is absent")
	for action_id: String in receipt["superseded_action_ids"]:
		if not (actions as Dictionary).has(action_id):
			return _fail(&"invalid_state", "group activation superseded action is absent")
		var action_value: Variant = (actions as Dictionary)[action_id]
		if typeof(action_value) != TYPE_DICTIONARY \
				or (action_value as Dictionary).get("state") != "SUPERSEDED" \
				or (action_value as Dictionary).get("reply_transaction_id") != null:
			return _fail(&"invalid_state", "group activation supersession lineage differs")
		var offer_id: Variant = (action_value as Dictionary).get("transaction_id")
		if typeof(offer_id) != TYPE_STRING \
				or typeof(state.get("transaction_receipts")) != TYPE_DICTIONARY \
				or not state["transaction_receipts"].has(offer_id):
			return _fail(&"invalid_state", "superseded solo offer operation is absent")
		var offer: Variant = state["transaction_receipts"][offer_id]
		var offer_shape := _validate_transaction_receipt(offer_id, offer)
		if not offer_shape.get("ok", false) \
				or (offer as Dictionary).get("kind") != "offer_solo" \
				or (offer as Dictionary).get("action_id") != action_id:
			return _fail(&"invalid_state", "superseded solo offer operation differs")
		var offer_link := _validate_offer_linkage(state, offer)
		if not offer_link.get("ok", false):
			return offer_link
	return _validate_group_history_linkage(state, receipt["action_id"], receipt["day"])


## The current slot is a view; earlier window facts remain in the original operation receipts.
## Reconstruct only a completed older window, then use the same history/source validators.
static func _group_for_day(state: Dictionary, day: int) -> Dictionary:
	var current: Variant = state.get("group_action")
	if not current is Dictionary: return {}
	if current.get("day") == null or day >= int(current.get("day", 0)):
		return current
	var operations: Variant = state.get("transaction_receipts")
	if not operations is Dictionary: return {}
	var action_id := "group:%s:day%d" % [GROUP_PAIR_KEY, day]
	var activation: Dictionary = {}
	var first: Dictionary = {}
	var reply: Dictionary = {}
	var opened: Array = []
	var resolution: Dictionary = {}
	for key: Variant in operations:
		var operation: Variant = operations[key]
		if not operation is Dictionary: return {}
		if operation.get("action_id") == action_id:
			if not _validate_transaction_receipt(key, operation).ok or operation.get("day") != day:
				return {}
			match operation.get("kind"):
				"activate_group":
					if not activation.is_empty(): return {}
					activation = operation
				"open_group_first":
					if not first.is_empty(): return {}
					first = operation
					if operation.friend_id not in opened: opened.append(operation.friend_id)
				"open_group_second":
					if operation.friend_id not in opened: opened.append(operation.friend_id)
				"reply_group":
					if not reply.is_empty(): return {}
					reply = operation
		if operation.get("kind") == "resolve_day_end":
			if not _validate_transaction_receipt(key, operation).ok: return {}
			for transition: Dictionary in operation.state_transitions:
				if transition.action_id != action_id: continue
				if not resolution.is_empty() or operation.day != day: return {}
				resolution = transition
	if activation.is_empty():
		return make_defaults().group_action if first.is_empty() and opened.is_empty() \
			and reply.is_empty() and resolution.is_empty() else {}
	if resolution.is_empty(): return {}
	var group: Dictionary = make_defaults().group_action
	group.merge({"action_id": action_id, "day": day, "transaction_id": activation.transaction_id,
		"inviter_id": first.get("friend_id"), "opened_ids": _canonical_participants(opened),
		"replied_ids": [] if reply.is_empty() else [reply.friend_id], "history_generated": not first.is_empty()}, true)
	var before := _group_pre_resolution_state(group)
	if resolution.from_state != before \
			or not _is_valid_group_resolution_transition(group, before, resolution.to_state, day): return {}
	group.state = resolution.to_state
	return group if _validate_group_action(state, group).ok else {}


static func _validate_group_history_linkage(state: Dictionary, action_id: String,
		day: int) -> Dictionary:
	var group_value: Variant = _group_for_day(state, day)
	var operations: Variant = state.get("transaction_receipts")
	if typeof(group_value) != TYPE_DICTIONARY or typeof(operations) != TYPE_DICTIONARY:
		return _fail(&"invalid_state", "group history indexes are absent")
	var group: Dictionary = group_value
	if group.get("action_id") != action_id or group.get("day") != day:
		return _fail(&"invalid_state", "group history identity differs")
	var activation_id: Variant = group.get("transaction_id")
	if typeof(activation_id) != TYPE_STRING or not (operations as Dictionary).has(activation_id):
		return _fail(&"invalid_state", "group activation operation is absent")
	var activation: Variant = (operations as Dictionary)[activation_id]
	var activation_shape := _validate_transaction_receipt(activation_id, activation)
	if not activation_shape.get("ok", false) \
			or (activation as Dictionary).get("kind") != "activate_group" \
			or (activation as Dictionary).get("action_id") != action_id \
			or (activation as Dictionary).get("day") != day:
		return _fail(&"invalid_state", "group activation operation differs")
	var first_opens: Array[Dictionary] = []
	var second_opens: Array[Dictionary] = []
	var replies: Array[Dictionary] = []
	for transaction_key: Variant in (operations as Dictionary):
		var operation: Variant = (operations as Dictionary)[transaction_key]
		if typeof(operation) != TYPE_DICTIONARY \
				or (operation as Dictionary).get("action_id") != action_id \
				or (operation as Dictionary).get("day") != day:
			continue
		match (operation as Dictionary).get("kind"):
			"open_group_first":
				var first_shape := _validate_open_group_operation(operation)
				if not first_shape.get("ok", false):
					return first_shape
				first_opens.append(operation)
			"open_group_second":
				var second_shape := _validate_open_group_operation(operation)
				if not second_shape.get("ok", false):
					return second_shape
				second_opens.append(operation)
			"reply_group":
				var reply_shape := _validate_reply_group_operation(operation)
				if not reply_shape.get("ok", false):
					return reply_shape
				replies.append(operation)
	if first_opens.size() > 1 or replies.size() > 1:
		return _fail(&"invalid_state", "group history has duplicate first-open or reply operations")
	if first_opens.is_empty():
		if not second_opens.is_empty() or not replies.is_empty() \
				or group.get("inviter_id") != null \
				or not _is_exact_string_array(group.get("opened_ids"), []) \
				or not _is_exact_string_array(group.get("replied_ids"), []) \
				or group.get("history_generated") != false:
			return _fail(&"invalid_state", "unopened group retains impossible history")
		return {"ok": true, "code": &"ok", "value": {}, "receipt": {}}
	var first: Dictionary = first_opens[0]
	var inviter: String = first["friend_id"]
	if group.get("inviter_id") != inviter or group.get("history_generated") != true:
		return _fail(&"invalid_state", "group inviter differs from the first opener")
	var recipients: Array = [inviter, _other_participant(inviter)]
	if first["message_sequences"][1] != first["message_sequences"][0] + 1:
		return _fail(&"invalid_state", "group first-open message sequences are not paired")
	for index: int in range(recipients.size()):
		var expected_child := "%s:message:%d" % [first["transaction_id"], index]
		var expected_message := "group_offer:%s:day%d:%s" % [
			GROUP_PAIR_KEY, day, recipients[index]]
		if first["child_transaction_ids"][index] != expected_child \
				or first["message_ids"][index] != expected_message:
			return _fail(&"invalid_state", "group first-open paired tuple differs")
		var retained := _find_exact_message(state, recipients[index], expected_message,
			expected_child, first["message_sequences"][index])
		var expected_record := _group_offer_record(action_id, recipients[index], inviter,
			day, "first_open" if index == 0 else "second_open",
			first["message_sequences"][index], expected_child)
		if retained != expected_record:
			return _fail(&"invalid_state", "group first-open retained message differs")
	var expected_opened: Array = [inviter]
	for second: Dictionary in second_opens:
		if second["friend_id"] not in expected_opened:
			expected_opened.append(second["friend_id"])
	expected_opened = _canonical_participants(expected_opened)
	if not _is_exact_string_array(group.get("opened_ids"), expected_opened):
		return _fail(&"invalid_state", "group opened participants differ from open operations")
	if typeof(state.get("read_watermarks")) != TYPE_DICTIONARY:
		return _fail(&"invalid_state", "group watermarks are absent")
	for index: int in range(recipients.size()):
		if recipients[index] in expected_opened \
				and (typeof(state["read_watermarks"].get(recipients[index])) != TYPE_INT \
				or state["read_watermarks"][recipients[index]] < first["message_sequences"][index]):
			return _fail(&"invalid_state", "group open watermark does not cover its exact message")
	if replies.is_empty():
		if not _is_exact_string_array(group.get("replied_ids"), []):
			return _fail(&"invalid_state", "group replied participants lack a reply operation")
		if group.get("state") in ["ACCEPTED", "RESOLVED_ATTENDED", "RESOLVED_MISSED"]:
			return _fail(&"invalid_state", "accepted group history has no reply operation")
	else:
		var reply: Dictionary = replies[0]
		if not _is_exact_string_array(group.get("replied_ids"), [reply["friend_id"]]) \
				or group.get("state") not in [
					"ACCEPTED", "RESOLVED_ATTENDED", "RESOLVED_MISSED", "RESOLVED_RUN_END"]:
			return _fail(&"invalid_state", "group reply operation differs from retained action")
		var source_index: Variant = state.get("schedule_source_receipts")
		if typeof(source_index) != TYPE_DICTIONARY \
				or not (source_index as Dictionary).has(reply["source_receipt_id"]):
			return _fail(&"invalid_state", "group reply source receipt is absent")
	return {"ok": true, "code": &"ok", "value": {}, "receipt": {}}


static func _validate_resolve_linkage(state: Dictionary, receipt: Dictionary) -> Dictionary:
	var derived := _derive_expected_resolution_envelope(state, receipt)
	if not derived.get("ok", false):
		return derived
	var expected: Dictionary = derived["value"]["envelope"]
	for key: String in expected:
		if receipt[key] != expected[key]:
			return _fail(&"invalid_state", "day-end operation differs from its canonical envelope",
				{"member": key})
	return {"ok": true, "code": &"ok", "value": {}, "receipt": {}}


static func _derive_expected_resolution_envelope(state: Dictionary,
		receipt: Dictionary) -> Dictionary:
	var transaction_id: String = receipt["transaction_id"]
	var day: int = receipt["day"]
	var claimed_elsewhere := _resolution_actions_claimed_elsewhere(state, transaction_id)
	var transitions: Array = []
	var message_specs: Array = []
	var actions: Variant = state.get("solo_actions")
	if typeof(actions) != TYPE_DICTIONARY:
		return _fail(&"invalid_state", "day-end solo action index is absent")
	var action_ids: Array = (actions as Dictionary).keys()
	action_ids.sort()
	for action_id_value: Variant in action_ids:
		var action_id: String = action_id_value
		var action_value: Variant = (actions as Dictionary)[action_id]
		if typeof(action_value) != TYPE_DICTIONARY:
			return _fail(&"invalid_state", "day-end solo action is malformed")
		var action: Dictionary = action_value
		var to_state: String = action.get("state", "")
		if action.get("day") != day or not to_state.begins_with("RESOLVED_") \
				or claimed_elsewhere.has(action_id):
			continue
		var from_state: String = "ACCEPTED" if action.get("reply_transaction_id") != null else "AVAILABLE"
		if not _is_valid_solo_resolution_transition(from_state, to_state, day):
			return _fail(&"invalid_state", "resolved solo action has no canonical day-end transition")
		transitions.append({"action_id": action_id, "from_state": from_state, "to_state": to_state})
		if to_state == "RESOLVED_UNANSWERED":
			message_specs.append({"friend_id": action["friend_id"], "type": "nevermind"})
		elif to_state == "RESOLVED_MISSED" and not _has_hospital_witness(state, action_id):
			message_specs.append({"friend_id": action["friend_id"], "type": "missed_question"})

	var group_value: Variant = _group_for_day(state, day)
	if typeof(group_value) != TYPE_DICTIONARY:
		return _fail(&"invalid_state", "day-end group action is absent")
	var group: Dictionary = group_value
	var group_transition: Variant = null
	var group_action_id: Variant = group.get("action_id")
	var group_to: String = str(group.get("state", ""))
	var group_matches_day: bool = day == 7 or group.get("day") == day
	if typeof(group_action_id) == TYPE_STRING and group_matches_day \
			and group_to.begins_with("RESOLVED_") \
			and not claimed_elsewhere.has(group_action_id):
		var group_from: String = _group_pre_resolution_state(group)
		if not _is_valid_group_resolution_transition(group, group_from, group_to, day):
			return _fail(&"invalid_state", "resolved group action has no canonical day-end transition")
		group_transition = {
			"action_id": group_action_id,
			"from_state": group_from,
			"to_state": group_to,
		}
		transitions.append(group_transition)

	var owned_messages := _resolution_owned_messages(state, transaction_id)
	var date_outcome_ids: Array = []
	var group_date_variation: Variant = null
	var deferred_twofriends: Variant = null
	if typeof(group_transition) == TYPE_DICTIONARY:
		match (group_transition as Dictionary)["to_state"]:
			"RESOLVED_UNANSWERED":
				var unanswered_type: String = "busy" \
					if (group_transition as Dictionary)["from_state"] == "AVAILABLE_UNOPENED" \
					else "nevermind"
				for participant: String in GROUP_PAIR:
					message_specs.append({"friend_id": participant, "type": unanswered_type})
			"RESOLVED_ATTENDED":
				if not _is_exact_string_array(group.get("replied_ids"), []) \
						and (group["replied_ids"] as Array).size() == 1:
					group_date_variation = "judgmental"
					message_specs.append({
						"friend_id": _other_participant(group["replied_ids"][0]),
						"type": "judge",
					})
				else:
					group_date_variation = "normal"
			"RESOLVED_MISSED":
				date_outcome_ids.append("date.group.priscilla_lavinia.missed.day%d" % day)
				var after_hospital: bool = owned_messages.size() == message_specs.size()
				deferred_twofriends = {
					"route_id": "dating",
					"action_id": group_action_id,
					"after_hospital": after_hospital,
				}
				if not after_hospital:
					for participant: String in GROUP_PAIR:
						message_specs.append({"friend_id": participant, "type": "missed_question"})

	var message_projection := _derive_expected_resolution_messages(
		state, transaction_id, day, message_specs, owned_messages)
	if not message_projection.get("ok", false):
		return message_projection
	var pre_group_state: String = str(group.get("state", "INACTIVE"))
	if typeof(group_transition) == TYPE_DICTIONARY:
		pre_group_state = (group_transition as Dictionary)["from_state"]
	var pl_window: Variant = null
	var counter_deltas: Dictionary = {}
	if day in GROUP_WINDOW_DAYS:
		var attended_pair: bool = false
		for transition: Dictionary in transitions:
			if transition["action_id"] in [
					"solo:priscilla:day%d" % day, "solo:lavinia:day%d" % day] \
					and transition["to_state"] == "RESOLVED_ATTENDED":
				attended_pair = true
				break
		if attended_pair:
			pl_window = {"outcome": "prevented", "counts": false, "visible": false}
		elif pre_group_state not in GROUP_OPEN_STATES:
			pl_window = {"outcome": "private_offscreen", "counts": true, "visible": false}
		elif pre_group_state == "ACCEPTED":
			var group_outcome: String = "group" \
				if typeof(group_transition) == TYPE_DICTIONARY \
				and (group_transition as Dictionary)["to_state"] == "RESOLVED_ATTENDED" \
				else "missed"
			pl_window = {"outcome": group_outcome, "counts": true, "visible": true}
		else:
			pl_window = {"outcome": "private_visible", "counts": true, "visible": true}
		if pl_window["counts"]:
			counter_deltas["pl_window_counts.priscilla_lavinia"] = 1
	var messages: Dictionary = message_projection["value"]
	return {
		"ok": true,
		"code": &"ok",
		"value": {"envelope": {
			"state_transitions": transitions,
			"child_transaction_ids": messages["child_transaction_ids"],
			"message_ids": messages["message_ids"],
			"message_sequences": messages["message_sequences"],
			"date_outcome_ids": date_outcome_ids,
			"group_date_variation": group_date_variation,
			"deferred_twofriends": deferred_twofriends,
			"pl_window": pl_window,
			"counter_deltas": counter_deltas,
		}},
		"receipt": {},
	}


static func _resolution_actions_claimed_elsewhere(state: Dictionary,
		transaction_id: String) -> Dictionary:
	var claimed: Dictionary = {}
	var operations: Variant = state.get("transaction_receipts")
	if typeof(operations) != TYPE_DICTIONARY:
		return claimed
	for other_id: Variant in (operations as Dictionary):
		if other_id == transaction_id:
			continue
		var other: Variant = (operations as Dictionary)[other_id]
		if typeof(other) != TYPE_DICTIONARY or (other as Dictionary).get("kind") != "resolve_day_end" \
				or typeof((other as Dictionary).get("state_transitions")) != TYPE_ARRAY:
			continue
		for transition: Variant in (other as Dictionary)["state_transitions"]:
			if typeof(transition) == TYPE_DICTIONARY \
					and typeof((transition as Dictionary).get("action_id")) == TYPE_STRING:
				claimed[(transition as Dictionary)["action_id"]] = true
	return claimed


static func _group_pre_resolution_state(group: Dictionary) -> String:
	if not group.get("replied_ids", []).is_empty():
		return "ACCEPTED"
	if group.get("history_generated", false):
		return "REPLY_REQUIRED"
	return "AVAILABLE_UNOPENED"


static func _resolution_owned_messages(state: Dictionary, transaction_id: String) -> Array:
	var owned: Array = []
	var messages: Variant = state.get("messages")
	if typeof(messages) != TYPE_DICTIONARY:
		return owned
	var prefix := "%s:message:" % transaction_id
	for friend_id: String in FRIEND_IDS:
		var records: Variant = (messages as Dictionary).get(friend_id)
		if typeof(records) != TYPE_ARRAY:
			continue
		for record: Variant in records:
			if typeof(record) == TYPE_DICTIONARY \
					and str((record as Dictionary).get("transaction_id", "")).begins_with(prefix):
				owned.append(record)
	return owned


static func _derive_expected_resolution_messages(state: Dictionary, transaction_id: String,
		day: int, specs: Array, owned_messages: Array) -> Dictionary:
	if owned_messages.size() != specs.size():
		return _fail(&"invalid_state", "day-end retained message ownership is not bijective")
	var child_transaction_ids: Array = []
	var message_ids: Array = []
	var message_sequences: Array = []
	for index: int in range(specs.size()):
		var spec: Dictionary = specs[index]
		var child_id := "%s:message:%d" % [transaction_id, index]
		var expected_id := "%s:%s:day%d" % [spec["type"], spec["friend_id"], day + 1]
		var retained := _find_message_by_child_transaction(state, child_id)
		if retained.is_empty():
			return _fail(&"invalid_state", "day-end retained message child is absent")
		var expected_record := {
			"message_id": expected_id,
			"sequence": retained.get("sequence"),
			"type": spec["type"],
			"variant": "default",
			"target_day": day + 1,
			"parameters": {},
			"visibility": "visible",
			"transaction_id": child_id,
		}
		if retained != expected_record:
			return _fail(&"invalid_state", "day-end retained message semantics differ")
		child_transaction_ids.append(child_id)
		message_ids.append(expected_id)
		message_sequences.append(retained["sequence"])
	return {"ok": true, "code": &"ok", "value": {
		"child_transaction_ids": child_transaction_ids,
		"message_ids": message_ids,
		"message_sequences": message_sequences,
	}, "receipt": {}}


static func _find_message_by_child_transaction(state: Dictionary,
		child_transaction_id: String) -> Dictionary:
	var found: Dictionary = {}
	var messages: Variant = state.get("messages")
	if typeof(messages) != TYPE_DICTIONARY:
		return found
	for friend_id: String in FRIEND_IDS:
		var records: Variant = (messages as Dictionary).get(friend_id)
		if typeof(records) != TYPE_ARRAY:
			continue
		for record: Variant in records:
			if typeof(record) == TYPE_DICTIONARY \
					and (record as Dictionary).get("transaction_id") == child_transaction_id:
				if not found.is_empty():
					return {}
				found = record
	return found


static func _is_valid_solo_resolution_transition(from_state: String, to_state: String,
		day: int) -> bool:
	if day == 7:
		return from_state in ["AVAILABLE", "ACCEPTED"] and to_state == "RESOLVED_RUN_END"
	if from_state == "AVAILABLE":
		return to_state == "RESOLVED_UNANSWERED"
	return from_state == "ACCEPTED" and to_state in ["RESOLVED_ATTENDED", "RESOLVED_MISSED"]


static func _is_valid_group_resolution_transition(group: Dictionary, from_state: String,
		to_state: String, receipt_day: int) -> bool:
	if receipt_day == 7:
		return from_state in GROUP_OPEN_STATES and to_state == "RESOLVED_RUN_END"
	if group.get("day") != receipt_day:
		return false
	if from_state in ["AVAILABLE_UNOPENED", "REPLY_REQUIRED"]:
		return to_state == "RESOLVED_UNANSWERED"
	return from_state == "ACCEPTED" and to_state in ["RESOLVED_ATTENDED", "RESOLVED_MISSED"]


static func _find_exact_message(state: Dictionary, friend_id: String, message_id: String,
		child_transaction_id: String, sequence: int) -> Dictionary:
	var messages: Variant = state.get("messages")
	if typeof(messages) != TYPE_DICTIONARY \
			or typeof((messages as Dictionary).get(friend_id)) != TYPE_ARRAY:
		return {}
	for record_value: Variant in (messages as Dictionary)[friend_id]:
		if typeof(record_value) != TYPE_DICTIONARY:
			continue
		var record: Dictionary = record_value
		if record.get("message_id") == message_id \
				and record.get("transaction_id") == child_transaction_id \
				and record.get("sequence") == sequence:
			return record
	return {}


static func _find_exact_message_any_friend(state: Dictionary, message_id: String,
		child_transaction_id: String, sequence: int) -> Dictionary:
	for friend_id: String in FRIEND_IDS:
		var found := _find_exact_message(state, friend_id, message_id,
			child_transaction_id, sequence)
		if not found.is_empty():
			return found
	return {}


static func _validate_source_receipt_linkage(state: Dictionary, receipt_id: String,
		value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return _fail(&"schedule_source_linkage_invalid", receipt_id)
	var receipt: Dictionary = value
	var command_id := _source_command_id(receipt)
	if command_id.is_empty() or typeof(state.get("transaction_receipts")) != TYPE_DICTIONARY \
			or not state["transaction_receipts"].has(command_id):
		return _fail(&"schedule_source_command_operation_absent", receipt_id)
	var operation: Variant = state["transaction_receipts"][command_id]
	var operation_check := _validate_transaction_receipt(command_id, operation)
	if not operation_check.get("ok", false):
		return _fail(&"schedule_source_command_operation_invalid", receipt_id,
			{"cause": operation_check.get("code", &"")})
	var operation_linkage := _validate_operation_linkage(state, command_id, operation)
	if not operation_linkage.get("ok", false):
		return _fail(&"schedule_source_command_operation_invalid", receipt_id,
			{"cause": operation_linkage.get("code", &"")})
	var op: Dictionary = operation
	var expected_operation := "open_solo_acceptance" \
		if receipt["kind"] == "solo_read_acceptance" else "reply_group"
	if op["kind"] != expected_operation or op["source_receipt_id"] != receipt_id \
			or op["action_id"] != receipt["action_id"] or op["day"] != receipt["day"] \
			or op["command_issuer_receipt"]["token"] != command_id \
			or receipt["receipt_provenance"]["parent_receipt_id"] \
				!= op["command_issuer_receipt"]["receipt_id"]:
		return _fail(&"schedule_source_command_operation_mismatch", receipt_id)
	var predecessor_id: String = receipt["previous_receipt_id"]
	if not state["transaction_receipts"].has(predecessor_id):
		return _fail(&"schedule_source_predecessor_absent", predecessor_id)
	var predecessor: Variant = state["transaction_receipts"][predecessor_id]
	var predecessor_check := _validate_transaction_receipt(predecessor_id, predecessor)
	if not predecessor_check.get("ok", false):
		return _fail(&"schedule_source_predecessor_invalid", predecessor_id)
	var predecessor_linkage := _validate_operation_linkage(state, predecessor_id, predecessor)
	if not predecessor_linkage.get("ok", false):
		return _fail(&"schedule_source_predecessor_invalid", predecessor_id,
			{"cause": predecessor_linkage.get("code", &"")})
	var prior: Dictionary = predecessor
	if receipt["kind"] == "solo_read_acceptance":
		var friend_id: String = receipt["participants"][0]
		if prior["kind"] != "offer_solo" or prior["action_id"] != receipt["action_id"] \
				or prior["friend_id"] != friend_id or prior["day"] != receipt["day"] \
				or op["friend_id"] != friend_id \
				or typeof(state.get("solo_actions")) != TYPE_DICTIONARY \
				or not state["solo_actions"].has(receipt["action_id"]):
			return _fail(&"schedule_source_predecessor_mismatch", predecessor_id)
		var action: Variant = state["solo_actions"][receipt["action_id"]]
		if typeof(action) != TYPE_DICTIONARY \
				or (action as Dictionary).get("transaction_id") != predecessor_id \
				or (action as Dictionary).get("reply_transaction_id") != command_id:
			return _fail(&"schedule_source_action_linkage_mismatch", receipt_id)
	else:
		if prior["kind"] != "activate_group" or prior["action_id"] != receipt["action_id"] \
				or prior["day"] != receipt["day"] or op["friend_id"] not in GROUP_PAIR \
				or typeof(state.get("group_action")) != TYPE_DICTIONARY:
			return _fail(&"schedule_source_predecessor_mismatch", predecessor_id)
		var group: Dictionary = _group_for_day(state, receipt["day"])
		if group.get("transaction_id") != predecessor_id \
				or group.get("action_id") != receipt["action_id"] \
				or op["friend_id"] not in group.get("replied_ids", []):
			return _fail(&"schedule_source_action_linkage_mismatch", receipt_id)
	return {"ok": true, "code": &"ok", "value": {}, "receipt": {}}

static func _source_command_id(receipt: Dictionary) -> String:
	var provenance: Variant = receipt.get("receipt_provenance")
	if typeof(provenance) != TYPE_DICTIONARY or typeof((provenance as Dictionary).get("source_ids")) != TYPE_ARRAY:
		return ""
	for source: Variant in (provenance as Dictionary)["source_ids"]:
		if typeof(source) != TYPE_STRING or not str(source).begins_with("command_id="):
			continue
		var decoded: Variant = JSON.parse_string(str(source).substr("command_id=".length()))
		return str(decoded) if typeof(decoded) == TYPE_STRING else ""
	return ""

static func _validate_source_receipt_shape(receipt_id: String, value: Variant) -> Dictionary:
	if receipt_id.strip_edges().is_empty() or typeof(value) != TYPE_DICTIONARY:
		return _fail(&"schedule_source_receipt_malformed", receipt_id)
	var receipt: Dictionary = value
	if not _has_exact_keys(receipt, _SOURCE_RECEIPT_KEYS):
		return _fail(&"schedule_source_receipt_malformed", receipt_id)
	if typeof(receipt["receipt_id"]) != TYPE_STRING or receipt["receipt_id"] != receipt_id \
			or not _is_prefixed_digest(receipt_id, "contact_source."):
		return _fail(&"schedule_source_receipt_id_mismatch", receipt_id)
	if typeof(receipt["kind"]) != TYPE_STRING \
			or str(receipt["kind"]) not in ["solo_read_acceptance", "group_reply_acceptance"]:
		return _fail(&"schedule_source_receipt_kind_invalid", receipt_id)
	if typeof(receipt["action_id"]) != TYPE_STRING \
			or str(receipt["action_id"]).strip_edges().is_empty():
		return _fail(&"schedule_source_receipt_action_invalid", receipt_id)
	if typeof(receipt["day"]) != TYPE_INT or int(receipt["day"]) < 1 or int(receipt["day"]) > 7:
		return _fail(&"schedule_source_receipt_day_invalid", receipt_id)
	if typeof(receipt["participants"]) != TYPE_ARRAY:
		return _fail(&"schedule_source_receipt_participants_invalid", receipt_id)
	var participants: Array = receipt["participants"]
	for participant: Variant in participants:
		if typeof(participant) != TYPE_STRING or str(participant).strip_edges().is_empty():
			return _fail(&"schedule_source_receipt_participants_invalid", receipt_id)
	var kind := str(receipt["kind"])
	var day := int(receipt["day"])
	var action_id := str(receipt["action_id"])
	var role := "contact_source.solo"
	if kind == "solo_read_acceptance":
		if participants.size() != 1 or str(participants[0]) not in FRIEND_IDS \
				or action_id != "solo:%s:day%d" % [participants[0], day]:
			return _fail(&"schedule_source_receipt_action_mismatch", receipt_id)
	else:
		role = "contact_source.group"
		if participants != GROUP_PAIR \
				or action_id != "group:%s:day%d" % [GROUP_PAIR_KEY, day]:
			return _fail(&"schedule_source_receipt_action_mismatch", receipt_id)
	if typeof(receipt["previous_receipt_id"]) != TYPE_STRING \
			or str(receipt["previous_receipt_id"]).strip_edges().is_empty():
		return _fail(&"schedule_source_predecessor_invalid", receipt_id)

	var provenance_value: Variant = receipt["receipt_provenance"]
	if typeof(provenance_value) != TYPE_DICTIONARY \
			or not _has_exact_keys(provenance_value, _SOURCE_PROVENANCE_KEYS):
		return _fail(&"schedule_source_provenance_malformed", receipt_id)
	var provenance: Dictionary = provenance_value
	if typeof(provenance["schema_version"]) != TYPE_INT or provenance["schema_version"] != 1 \
			or typeof(provenance["parent_receipt_id"]) != TYPE_STRING \
			or not _is_prefixed_digest(str(provenance["parent_receipt_id"]), "issuer_receipt.") \
			or typeof(provenance["child_kind"]) != TYPE_STRING \
			or provenance["child_kind"] != "contact_source" \
			or typeof(provenance["ordinal"]) != TYPE_INT or provenance["ordinal"] != 0 \
			or typeof(provenance["child_id"]) != TYPE_STRING \
			or provenance["child_id"] != receipt_id:
		return _fail(&"schedule_source_provenance_mismatch", receipt_id)
	if typeof(provenance["source_ids"]) != TYPE_ARRAY:
		return _fail(&"schedule_source_projection_malformed", receipt_id)
	var source_ids: Array = provenance["source_ids"]
	if source_ids.size() != 7:
		return _fail(&"schedule_source_projection_mismatch", receipt_id)
	var previous_source := ""
	var command_source_count := 0
	for source_value: Variant in source_ids:
		if typeof(source_value) != TYPE_STRING or str(source_value).strip_edges().is_empty():
			return _fail(&"schedule_source_projection_malformed", receipt_id)
		var source := str(source_value)
		if not previous_source.is_empty() and source <= previous_source:
			return _fail(&"schedule_source_projection_unsorted", receipt_id)
		previous_source = source
		if source.begins_with("command_id="):
			if not _is_transaction_projection(source):
				return _fail(&"schedule_source_command_projection_invalid", receipt_id)
			command_source_count += 1
	if command_source_count != 1:
		return _fail(&"schedule_source_command_projection_invalid", receipt_id)
	for pair: Array in [
		["role", role], ["kind", kind], ["action_id", action_id], ["day", day],
		["participants", participants], ["previous_receipt_id", receipt["previous_receipt_id"]],
	]:
		var projected := _project(str(pair[0]), pair[1])
		if not projected.get("ok", false) or str(projected.get("value", "")) not in source_ids:
			return _fail(&"schedule_source_projection_mismatch", receipt_id)
	return {"ok": true, "code": &"ok", "value": {}, "receipt": {}}

static func _is_transaction_projection(source: String) -> bool:
	var encoded := source.substr("command_id=".length())
	var decoded: Variant = JSON.parse_string(encoded)
	if typeof(decoded) != TYPE_STRING or JSON.stringify(decoded) != encoded:
		return false
	return _is_prefixed_digest(str(decoded), "transaction_id.")

static func _is_prefixed_digest(value: String, prefix: String) -> bool:
	if not value.begins_with(prefix) or value.length() != prefix.length() + 64:
		return false
	var digest := value.substr(prefix.length())
	for index: int in range(digest.length()):
		if "0123456789abcdef".find(digest.substr(index, 1)) < 0:
			return false
	return true

static func _has_exact_keys(value: Variant, expected: Array) -> bool:
	if typeof(value) != TYPE_DICTIONARY or (value as Dictionary).size() != expected.size():
		return false
	for key: Variant in expected:
		if not (value as Dictionary).has(key):
			return false
	return true

static func _is_string_array(value: Variant) -> bool:
	if typeof(value) != TYPE_ARRAY:
		return false
	for item: Variant in value:
		if typeof(item) != TYPE_STRING or str(item).strip_edges().is_empty():
			return false
	return true

static func _is_int_array(value: Variant) -> bool:
	if typeof(value) != TYPE_ARRAY:
		return false
	for item: Variant in value:
		if typeof(item) != TYPE_INT:
			return false
	return true

static func _is_exact_string_array(value: Variant, expected: Array) -> bool:
	if not _is_string_array(value) or (value as Array).size() != expected.size():
		return false
	for index: int in range(expected.size()):
		if typeof(expected[index]) != TYPE_STRING or (value as Array)[index] != expected[index]:
			return false
	return true

static func _is_exact_int_array(value: Variant, expected: Array) -> bool:
	if not _is_int_array(value) or (value as Array).size() != expected.size():
		return false
	for index: int in range(expected.size()):
		if typeof(expected[index]) != TYPE_INT or (value as Array)[index] != expected[index]:
			return false
	return true

static func _is_sorted_unique_string_array(value: Variant) -> bool:
	if not _is_string_array(value):
		return false
	var previous := ""
	for item: Variant in value:
		if not previous.is_empty() and str(item) <= previous:
			return false
		previous = str(item)
	return true

static func _is_strict_day_array(value: Variant) -> bool:
	if typeof(value) != TYPE_ARRAY or (value as Array).is_empty():
		return false
	var previous := 0
	for item: Variant in value:
		if typeof(item) != TYPE_INT or int(item) < 1 or int(item) > 7 or int(item) <= previous:
			return false
		previous = int(item)
	return true

static func _is_canonical_participant_subset(value: Variant) -> bool:
	if typeof(value) != TYPE_ARRAY:
		return false
	var expected: Array = []
	for participant: String in GROUP_PAIR:
		if participant in (value as Array):
			expected.append(participant)
	return _is_exact_string_array(value, expected)

static func _is_integral(value: Variant) -> bool:
	return typeof(value) == TYPE_INT

static func _ok(candidate: Dictionary, message_batch: Array, receipt: Dictionary) -> Dictionary:
	return {"ok": true, "code": &"ok", "value": {"candidate": candidate, "message_batch": message_batch}, "receipt": receipt}

static func _fail(code: StringName, message: String, details: Dictionary = {}) -> Dictionary:
	return {"ok": false, "code": code, "message": message, "details": details.duplicate(true)}


## Additive pre-Done witness variant: it binds the source invitation and Hospital miss,
## never a fabricated committed Schedule entry. Schedule-Done keeps its original exact shape.
static func _validate_condition_hospital_witness(record: Dictionary) -> Dictionary:
	var keys := ["action_id", "affection_delta", "attitude", "care_followup_day",
		"care_followup_entry_id", "dark_delta", "hospital_miss_receipt_id", "kind",
		"receipt_id", "receipt_provenance", "resolution_kind", "resolution_receipt_id",
		"source_receipt_id", "tier_transition"]
	if not _has_exact_keys(record, keys): return _fail(&"invalid_sylvia_witness", "condition Hospital witness is exact-key")
	if record.kind != "sylvia_hospital_witness" or record.resolution_kind != "condition_hospital" \
			or record.attitude != HOSPITAL_RULES.WITNESS_ATTITUDE \
			or record.tier_transition != HOSPITAL_RULES.WITNESS_TIER_TRANSITION:
		return _fail(&"invalid_sylvia_witness", "condition Hospital witness has changed fixed facts")
	for key: String in ["affection_delta", "dark_delta", "care_followup_day"]:
		if typeof(record[key]) != TYPE_INT: return _fail(&"invalid_sylvia_witness", "strict integers required")
	if record.affection_delta != 2 or record.dark_delta != 1 or record.care_followup_day < 2 or record.care_followup_day > 7:
		return _fail(&"invalid_sylvia_witness", "condition Hospital witness has changed fixed amounts")
	for key: String in ["receipt_id", "resolution_receipt_id", "source_receipt_id", "hospital_miss_receipt_id", "action_id", "care_followup_entry_id"]:
		if typeof(record[key]) != TYPE_STRING or str(record[key]).is_empty():
			return _fail(&"invalid_sylvia_witness", "condition Hospital witness identity is missing")
	var provenance: Variant = record.receipt_provenance
	var sources: Array = [record.resolution_receipt_id, record.source_receipt_id, record.hospital_miss_receipt_id]
	sources.sort()
	if not provenance is Dictionary or provenance.get("child_id") != record.receipt_id \
			or provenance.get("child_kind") != "sylvia_hospital_witness" \
			or typeof(provenance.get("parent_receipt_id")) != TYPE_STRING \
			or str(provenance.get("parent_receipt_id", "")).is_empty() \
			or provenance.get("source_ids") != sources:
		return _fail(&"invalid_sylvia_witness", "condition Hospital witness ancestry differs")
	return {"ok": true, "code": &"ok"}

## Read-only prospective care. It becomes history only in prepare_open_contact's accepted
## candidate; the caller persists that candidate with the frozen relationship consequence.
static func get_pending_sylvia_care(state: Dictionary, day: int) -> Array:
	var entries: Array = []
	if day < 2 or day > 7: return entries
	var ids: Array = state.get("sylvia_hospital_witness_receipts", {}).keys()
	ids.sort()
	for witness_id: String in ids:
		var checked := _validate_care_witness(state, witness_id)
		if not checked.ok: continue
		var witness: Dictionary = state.sylvia_hospital_witness_receipts[witness_id]
		if int(witness.care_followup_day) > day or _care_consumed(state, witness_id): continue
		entries.append({"message_id": witness.care_followup_entry_id, "sequence": int(state.next_sequence) + entries.size(),
			"type": "hospital_care", "variant": "default", "target_day": witness.care_followup_day,
			"parameters": {"witness_id": witness_id}, "visibility": "visible", "transaction_id": witness_id})
	return entries

static func _care_consumed(state: Dictionary, witness_id: String) -> bool:
	for receipt: Dictionary in state.transaction_receipts.values():
		if witness_id in receipt.get("hospital_care", {}).get("witness_ids", []): return true
	return false

static func _validate_care_witness(state: Dictionary, witness_id: String) -> Dictionary:
	var raw: Variant = state.get("sylvia_hospital_witness_receipts", {}).get(witness_id)
	var checked := _validate_sylvia_witness_shape(raw)
	if not checked.ok: return checked
	var witness: Dictionary = raw
	for other_id: String in state.sylvia_hospital_witness_receipts:
		if other_id != witness_id and state.sylvia_hospital_witness_receipts[other_id].get("action_id") == witness.action_id:
			return _fail(&"invalid_care_witness_source", "one invitation cannot issue two care handoffs")
	var source: Dictionary = state.get("schedule_source_receipts", {}).get(witness.source_receipt_id, {})
	var action: Dictionary = state.get("solo_actions", {}).get(witness.action_id, {})
	if source.get("kind") != "solo_read_acceptance" or source.get("participants") != ["sylvia"] \
			or source.get("action_id") != witness.action_id or source.get("receipt_id") != witness.source_receipt_id \
			or action.get("friend_id") != "sylvia" or action.get("state") != "RESOLVED_MISSED" \
			or action.get("day") != source.get("day") \
			or not CALENDAR.is_solo_day("sylvia", int(source.get("day", 0))) \
			or witness.care_followup_day != int(source.day) + 1 \
			or witness.care_followup_entry_id != "care.sylvia.day%d" % witness.care_followup_day:
		return _fail(&"invalid_care_witness_source", witness_id)
	if witness.resolution_kind == "condition_hospital":
		if witness.receipt_id != witness_id: return _fail(&"invalid_care_witness_source", witness_id)
	elif not witness_id.ends_with(":hospital_if_triggered"):
		return _fail(&"invalid_care_witness_source", witness_id)
	var transition := {"action_id": witness.action_id, "from_state": "ACCEPTED", "to_state": "RESOLVED_MISSED"}
	for closure: Dictionary in state.transaction_receipts.values():
		if closure.get("kind") == "resolve_day_end" and closure.get("day") == source.day \
				and transition in closure.get("state_transitions", []):
			if witness.resolution_kind == "condition_hospital" and closure.transaction_id != witness.resolution_receipt_id:
				continue
			return {"ok": true}
	return _fail(&"invalid_care_witness_source", witness_id)

static func _validate_care_claim(receipt: Dictionary) -> Dictionary:
	var claim: Variant = receipt.get("hospital_care")
	if receipt.get("kind") not in ["open_solo_acceptance", "open_sylvia_care"] \
			or receipt.get("friend_id") != "sylvia" or typeof(receipt.get("day")) != TYPE_INT \
			or int(receipt.day) < 2 or int(receipt.day) > 7 or not claim is Dictionary \
			or not _has_exact_keys(claim, ["witness_ids", "witnesses", "message_ids", "message_sequences"]) \
			or not _is_sorted_unique_string_array(claim.witness_ids) or claim.witness_ids.is_empty() \
			or not claim.witnesses is Dictionary or not _has_exact_keys(claim.witnesses, claim.witness_ids) \
			or not _is_string_array(claim.message_ids) or not _is_int_array(claim.message_sequences) \
			or claim.message_ids.size() != claim.witness_ids.size() or claim.message_sequences.size() != claim.witness_ids.size():
		return _fail(&"invalid_state", "Hospital care claim is malformed")
	return {"ok": true}

static func _validate_care_linkage(state: Dictionary, receipt: Dictionary) -> Dictionary:
	var claim: Dictionary = receipt.hospital_care
	for index: int in range(claim.witness_ids.size()):
		var witness_id: String = claim.witness_ids[index]
		var checked := _validate_care_witness(state, witness_id)
		if not checked.ok: return checked
		var witness: Dictionary = state.sylvia_hospital_witness_receipts[witness_id]
		if witness != claim.witnesses[witness_id] or witness.care_followup_day > receipt.day \
				or witness.care_followup_entry_id != claim.message_ids[index]:
			return _fail(&"invalid_state", "Hospital care changed its frozen witness")
		var message := _find_exact_message(state, "sylvia", claim.message_ids[index],
			"%s:care:%d" % [receipt.transaction_id, index], claim.message_sequences[index])
		if message.get("type") != "hospital_care" or message.get("target_day") != witness.care_followup_day \
				or message.get("parameters") != {"witness_id": witness_id} or message.get("visibility") != "visible":
			return _fail(&"invalid_state", "Hospital care history is not owned by its consumption")
		for other: Dictionary in state.transaction_receipts.values():
			if other.transaction_id != receipt.transaction_id and witness_id in other.get("hospital_care", {}).get("witness_ids", []):
				return _fail(&"invalid_state", "Hospital care witness was consumed twice")
	return {"ok": true}


static func prepare_reply_ordinary(state: Dictionary, day: int, reply_id: String, locale: String,
		command_id: String, issuer_receipt: Dictionary, rendered_line: Dictionary, identity_issuer: Object) -> Dictionary:
	var checked := validate_state(state)
	if not checked.ok: return checked
	var verified := _verify_command(identity_issuer, command_id, issuer_receipt)
	if not verified.ok: return verified
	return ORDINARY_REPLIES.prepare_reply(state, day, reply_id, locale, command_id, issuer_receipt, rendered_line)

static func prepare_satisfy_ordinary_echo(state: Dictionary, echo_id: String, atom_id: String,
		command_id: String, issuer_receipt: Dictionary, presented: Dictionary, identity_issuer: Object) -> Dictionary:
	var checked := validate_state(state)
	if not checked.ok: return checked
	var verified := _verify_command(identity_issuer, command_id, issuer_receipt)
	if not verified.ok: return verified
	return ORDINARY_REPLIES.prepare_echo_presented(state, echo_id, atom_id, command_id, issuer_receipt, presented)

# Scene Contacts use only the installed successor registration. These pure
# candidate builders do not commit Run bytes or authenticate a screen draw.
const _SCENE_MANIFEST := preload("res://scripts/narrative/DialogicEntryManifest.gd")
const _SCENE_BAG_KEYS := ["schema_version", "messages", "read_watermarks", "transaction_receipts", "next_sequence"]
const _SCENE_CONTEXT_KEYS := ["identity", "scene_occurrence", "registration_sha256", "contacts_sha256"]
const _SCENE_IDENTITY_KEYS := ["run_id", "branch_id", "desktop_timeline_generation", "causal_day_instance", "causal_day_instance_issuer_receipt"]
const _SCENE_RECEIPT_KEYS := ["kind", "transaction_id", "command_issuer_receipt", "context", "definitions_sha256", "registration_sha256", "source_fact_ids", "result"]
const _SCENE_MESSAGE_KEYS := ["message_id", "definition_id", "friend_id", "sequence", "transaction_id", "direction", "reply_id"]
const _SCENE_LOCALES := ["en", "zh-CN", "zh-HK", "ja", "ko"]

static func make_scene_defaults() -> Dictionary:
	return {"schema_version": 2, "messages": {"priscilla": [], "lavinia": [], "sylvia": []},
		"read_watermarks": {"priscilla": 0, "lavinia": 0, "sylvia": 0},
		"transaction_receipts": {}, "next_sequence": 1}

## A calls this pure row validator during full-B admission. No retained registry.
static func validate_scene_definitions(definitions: Variant) -> Dictionary:
	if not _s_json(definitions) or not _has_exact_keys(definitions, ["kind", "schema_version", "messages", "replies"]) \
			or definitions.kind != "scene_contact_definitions" or typeof(definitions.schema_version) != TYPE_INT \
			or definitions.schema_version != 1 or not definitions.messages is Array or not definitions.replies is Array:
		return _s_fail("scene_contact_definitions_invalid")
	var messages := {}
	var replies := {}
	var facts := {}
	var previous := ""
	for row: Variant in definitions.messages:
		if not _has_exact_keys(row, ["definition_id", "friend_id", "texts", "message_fact_ids", "read_fact_ids"]) \
				or not _s_id(row.definition_id) or row.definition_id <= previous or row.friend_id not in FRIEND_IDS \
				or not _s_texts(row.texts): return _s_fail("scene_contact_message_definition_invalid")
		previous = row.definition_id
		for field: String in ["message_fact_ids", "read_fact_ids"]:
			if not _s_claim_facts(row[field], facts): return _s_fail("scene_contact_fact_definition_invalid")
		messages[row.definition_id] = row.duplicate(true)
	previous = ""
	for row: Variant in definitions.replies:
		if not _has_exact_keys(row, ["reply_id", "definition_id", "line_id", "texts", "source_fact_ids"]) \
				or not _s_id(row.reply_id) or row.reply_id <= previous or not _s_id(row.definition_id) \
				or not messages.has(row.definition_id) or not _s_id(row.line_id) or not _s_texts(row.texts) \
				or not _s_claim_facts(row.source_fact_ids, facts): return _s_fail("scene_contact_reply_definition_invalid")
		previous = row.reply_id
		replies[row.reply_id] = row.duplicate(true)
	return {"ok": true, "value": {"messages": messages, "replies": replies,
		"definitions_sha256": _s_hash(definitions)}}

static func capture_scene_definitions(registration_sha256: String) -> Dictionary:
	var loaded: Dictionary = _SCENE_MANIFEST.scene_registration()
	if not loaded.get("ok", false): return loaded
	var bundle: Variant = loaded.get("value")
	if not bundle is Dictionary or typeof(bundle.get("schema_version")) != TYPE_INT or bundle.schema_version != 2 \
			or not bundle.has("contact_definitions") or not _s_digest(registration_sha256) \
			or _s_hash(bundle) != registration_sha256: return _s_fail("scene_contact_registration_unbound")
	# scene_registration is the existing frozen/validated owner. Its full B binds
	# every table, including these definitions; saved state cannot select a bundle.
	return validate_scene_definitions(bundle.contact_definitions)

static func validate_scene_state(state: Dictionary, registration_sha256: String, identity_issuer: Object) -> Dictionary:
	var selected := capture_scene_definitions(registration_sha256)
	if not selected.get("ok", false): return selected
	return _s_validate_state(state, registration_sha256, identity_issuer, selected.value)

static func _s_validate_state(state: Dictionary, registration_sha256: String, issuer: Object, definitions: Dictionary) -> Dictionary:
	if not _s_json(state) or not _has_exact_keys(state, _SCENE_BAG_KEYS) \
			or typeof(state.schema_version) != TYPE_INT or state.schema_version != 2 \
			or not _has_exact_keys(state.messages, FRIEND_IDS) or not _has_exact_keys(state.read_watermarks, FRIEND_IDS) \
			or not state.transaction_receipts is Dictionary or typeof(state.next_sequence) != TYPE_INT or state.next_sequence < 1:
		return _s_fail("scene_contacts_invalid")
	for friend: String in FRIEND_IDS:
		if not state.messages[friend] is Array or typeof(state.read_watermarks[friend]) != TYPE_INT:
			return _s_fail("scene_contacts_invalid")
	var by_prior := {}
	var run_id := ""
	for command_id: Variant in state.transaction_receipts:
		var receipt: Variant = state.transaction_receipts[command_id]
		if not _s_id(command_id) or not _has_exact_keys(receipt, _SCENE_RECEIPT_KEYS) \
				or not _s_id(receipt.kind) or not _s_id(receipt.transaction_id) \
				or not _s_digest(receipt.registration_sha256) or not _s_digest(receipt.definitions_sha256) \
				or receipt.transaction_id != command_id or receipt.registration_sha256 != registration_sha256 \
				or receipt.definitions_sha256 != definitions.definitions_sha256 \
				or not receipt.command_issuer_receipt is Dictionary or not _has_exact_keys(receipt.context, _SCENE_CONTEXT_KEYS) or not _s_digest(receipt.context.contacts_sha256):
			return _s_fail("scene_contact_receipt_invalid")
		if not _has_exact_keys(receipt.context.identity, _SCENE_IDENTITY_KEYS) or not _s_id(receipt.context.identity.run_id):
			return _s_fail("scene_contact_identity_invalid")
		if run_id != "" and receipt.context.identity.run_id != run_id: return _s_fail("scene_contact_run_changed")
		run_id = receipt.context.identity.run_id
		var prior: String = receipt.context.contacts_sha256
		if by_prior.has(prior): return _s_fail("scene_contact_receipt_fork")
		by_prior[prior] = receipt
	var candidate := make_scene_defaults()
	var remaining: int = by_prior.size()
	while remaining > 0:
		var prior := _s_hash(candidate)
		if not by_prior.has(prior): return _s_fail("scene_contact_receipt_disconnected")
		var receipt: Dictionary = by_prior[prior]
		var applied := _s_apply(candidate, receipt, definitions, registration_sha256, issuer)
		if not applied.get("ok", false): return applied
		candidate = applied.value.candidate
		by_prior.erase(prior)
		remaining -= 1
	if not _s_equal(candidate, state): return _s_fail("scene_contact_state_linkage_invalid")
	return {"ok": true}

static func prepare_scene_message(state: Dictionary, definition_id: String, command_id: String,
		proof: Dictionary, context: Dictionary, issuer: Object) -> Dictionary:
	return _s_prepare(state, "scene_message", {"definition_id": definition_id}, command_id, proof, context, issuer)

static func prepare_scene_read(state: Dictionary, friend_id: String, command_id: String,
		proof: Dictionary, context: Dictionary, issuer: Object) -> Dictionary:
	return _s_prepare(state, "scene_read", {"friend_id": friend_id}, command_id, proof, context, issuer)

static func prepare_scene_reply(state: Dictionary, reply_id: String, incoming_message_id: String, locale: String,
		command_id: String, proof: Dictionary, context: Dictionary, rendered_line: Dictionary, issuer: Object) -> Dictionary:
	return _s_prepare(state, "scene_reply", {"reply_id": reply_id, "incoming_message_id": incoming_message_id,
		"locale": locale, "rendered_line": rendered_line}, command_id, proof, context, issuer)

static func _s_prepare(state: Dictionary, kind: String, request: Dictionary, command_id: String,
		proof: Dictionary, context: Dictionary, issuer: Object) -> Dictionary:
	if not _has_exact_keys(context, _SCENE_CONTEXT_KEYS) or not _s_digest(context.registration_sha256):
		return _s_fail("scene_contact_context_invalid")
	var registered := capture_scene_definitions(context.registration_sha256)
	if not registered.get("ok", false): return registered
	var valid := _s_validate_state(state, context.registration_sha256, issuer, registered.value)
	if not valid.get("ok", false): return valid
	var verified := _s_verify(context, command_id, proof, context.registration_sha256, issuer)
	if not verified.get("ok", false): return verified
	if state.transaction_receipts.has(command_id):
		var prior: Dictionary = state.transaction_receipts[command_id]
		if prior.kind != kind or not _s_equal(prior.context, context) or not _s_equal(prior.command_issuer_receipt, proof):
			return _s_fail("scene_contact_command_conflict")
		for key: String in request:
			if not prior.result.has(key) or not _s_equal(prior.result[key], request[key]): return _s_fail("scene_contact_command_conflict")
		return _ok(state.duplicate(true), [], prior.duplicate(true))
	if context.contacts_sha256 != _s_hash(state): return _s_fail("scene_contact_context_stale")
	var receipt := {"kind": kind, "transaction_id": command_id, "command_issuer_receipt": proof.duplicate(true),
		"context": context.duplicate(true), "definitions_sha256": registered.value.definitions_sha256,
		"registration_sha256": context.registration_sha256, "source_fact_ids": [], "result": request.duplicate(true)}
	return _s_apply(state, receipt, registered.value, context.registration_sha256, issuer, true)

static func _s_apply(state: Dictionary, receipt: Dictionary, definitions: Dictionary,
		registration_sha256: String, issuer: Object, preparing: bool = false) -> Dictionary:
	var verified := _s_verify(receipt.context, receipt.transaction_id, receipt.command_issuer_receipt, registration_sha256, issuer)
	if not verified.get("ok", false): return verified
	if receipt.context.contacts_sha256 != _s_hash(state) or not receipt.result is Dictionary:
		return _s_fail("scene_contact_context_stale")
	var candidate: Dictionary = state.duplicate(true)
	var result := {}
	var source_facts: Array = []
	var batch: Array = []
	var command: String = receipt.transaction_id
	var input: Dictionary = receipt.result
	match receipt.kind:
		"scene_message":
			if not _s_id(input.get("definition_id")) or not definitions.messages.has(input.definition_id): return _s_fail("scene_contact_definition_missing")
			var row: Dictionary = definitions.messages[input.definition_id]
			for prior: Dictionary in state.transaction_receipts.values():
				if prior.kind == "scene_message" and prior.result.definition_id == row.definition_id \
						and prior.context.scene_occurrence == receipt.context.scene_occurrence: return _s_fail("scene_contact_message_already_emitted")
			source_facts = row.message_fact_ids.duplicate()
			result = {"definition_id": row.definition_id, "message_id": command, "sequence": state.next_sequence}
			batch.append(_s_message(command, row, state.next_sequence, "incoming", null))
		"scene_read":
			if input.get("friend_id") not in FRIEND_IDS: return _s_fail("unknown_friend")
			var friend: String = input.friend_id
			var ids: Array = []
			var through: int = state.read_watermarks[friend]
			for message: Dictionary in state.messages[friend]:
				if message.sequence <= state.read_watermarks[friend]: continue
				through = maxi(through, message.sequence)
				if message.direction == "incoming":
					ids.append(message.message_id)
					for fact: String in definitions.messages[message.definition_id].read_fact_ids:
						if source_facts.has(fact): return _s_fail("scene_contact_fact_multiply_owned")
						source_facts.append(fact)
			if ids.is_empty(): return _s_fail("scene_contact_nothing_to_read")
			result = {"friend_id": friend, "message_ids": ids, "through_sequence": through}
			candidate.read_watermarks[friend] = through
		"scene_reply":
			if not _s_id(input.get("reply_id")) or not definitions.replies.has(input.reply_id) \
					or not _s_id(input.get("incoming_message_id")) or input.get("locale") not in _SCENE_LOCALES:
				return _s_fail("scene_contact_reply_invalid")
			var reply: Dictionary = definitions.replies[input.reply_id]
			var row: Dictionary = definitions.messages[reply.definition_id]
			var incoming := _s_find_message(state, input.incoming_message_id)
			if incoming.is_empty() or incoming.direction != "incoming" or incoming.definition_id != reply.definition_id \
					or incoming.sequence > state.read_watermarks[row.friend_id] or _s_replied(state, incoming.message_id):
				return _s_fail("scene_contact_reply_unavailable")
			var text := _s_localized(reply.texts, input.locale)
			var rendered := {"view_token": command, "line_id": reply.line_id, "text": text}
			if text.is_empty() or not input.get("rendered_line") is Dictionary \
					or not ORDINARY_REPLIES.validate_scene_rendered_line(command, reply.line_id, text, input.rendered_line).get("ok", false):
				return _s_fail("scene_contact_reply_not_acknowledged")
			source_facts = reply.source_fact_ids.duplicate()
			result = {"definition_id": reply.definition_id, "reply_id": reply.reply_id,
				"incoming_message_id": incoming.message_id, "message_id": command, "sequence": state.next_sequence,
				"locale": input.locale, "rendered_line": rendered}
			batch.append(_s_message(command, row, state.next_sequence, "outgoing", reply.reply_id))
		_:
			return _s_fail("scene_contact_kind_invalid")
	source_facts.sort()
	for prior: Dictionary in state.transaction_receipts.values():
		for fact: String in source_facts:
			if prior.source_fact_ids.has(fact): return _s_fail("scene_contact_fact_multiply_owned")
	var actual: Dictionary = receipt.duplicate(true)
	actual.result = result
	actual.source_fact_ids = source_facts
	if not preparing and not _s_equal(actual, receipt): return _s_fail("scene_contact_result_mismatch")
	for message: Dictionary in batch:
		candidate.messages[message.friend_id].append(message)
		candidate.next_sequence += 1
	candidate.transaction_receipts[command] = actual
	return _ok(candidate, batch, actual.duplicate(true))

static func validate_scene_facts(state: Dictionary, source_fact_ids: Array,
		registration_sha256: String, identity_issuer: Object) -> Dictionary:
	var checked := validate_scene_state(state, registration_sha256, identity_issuer)
	if not checked.get("ok", false): return checked
	if not _s_sorted_ids(source_fact_ids): return _s_fail("scene_contact_fact_request_invalid")
	var resolved: Array = []
	for fact: String in source_fact_ids:
		var matched: Dictionary = {}
		for receipt: Dictionary in state.transaction_receipts.values():
			if not receipt.source_fact_ids.has(fact): continue
			if not matched.is_empty(): return _s_fail("scene_contact_fact_multiply_owned")
			matched = receipt
		if matched.is_empty(): return _s_fail("scene_contact_fact_unresolved")
		resolved.append({"source_fact_id": fact, "transaction_id": matched.transaction_id, "receipt": matched.duplicate(true)})
	return {"ok": true, "value": {"receipts": resolved}}

static func scene_reply_choices(state: Dictionary, friend_id: String, locale: String, registration_sha256: String) -> Dictionary:
	var loaded := capture_scene_definitions(registration_sha256)
	if not loaded.get("ok", false): return loaded
	if friend_id not in FRIEND_IDS or locale not in _SCENE_LOCALES or not _s_projection_shape(state):
		return _s_fail("scene_contact_reply_invalid")
	var choices: Array = []
	for reply: Dictionary in loaded.value.replies.values():
		var row: Dictionary = loaded.value.messages[reply.definition_id]
		if row.friend_id != friend_id: continue
		var matches: Array = []
		for message: Dictionary in state.messages[friend_id]:
			if message.direction == "incoming" and message.definition_id == reply.definition_id \
					and message.sequence <= state.read_watermarks[friend_id] and not _s_replied(state, message.message_id): matches.append(message)
		if matches.size() > 1: return _s_fail("scene_contact_reply_ambiguous")
		if matches.size() == 1:
			var text := _s_localized(reply.texts, locale)
			if text.is_empty(): return _s_fail("scene_contact_translation_unavailable")
			choices.append({"reply_id": reply.reply_id, "incoming_message_id": matches[0].message_id,
				"line_id": reply.line_id, "text": text})
	return {"ok": true, "value": choices}

static func scene_message_text(message: Dictionary, locale: String, registration_sha256: String) -> Dictionary:
	var loaded := capture_scene_definitions(registration_sha256)
	if not loaded.get("ok", false): return loaded
	if not _s_json(message) or not _has_exact_keys(message, _SCENE_MESSAGE_KEYS) or locale not in _SCENE_LOCALES \
			or not _s_id(message.definition_id) or message.direction not in ["incoming", "outgoing"] \
			or not loaded.value.messages.has(message.definition_id): return _s_fail("scene_contact_message_invalid")
	var row: Dictionary = loaded.value.messages[message.definition_id]
	if row.friend_id != message.friend_id: return _s_fail("scene_contact_message_invalid")
	if message.direction == "outgoing":
		if not _s_id(message.reply_id) or not loaded.value.replies.has(message.reply_id): return _s_fail("scene_contact_reply_invalid")
		row = loaded.value.replies[message.reply_id]
		if row.definition_id != message.definition_id: return _s_fail("scene_contact_reply_invalid")
	var text := _s_localized(row.texts, locale)
	return {"ok": true, "value": text} if not text.is_empty() else _s_fail("scene_contact_translation_unavailable")

static func _s_verify(context: Dictionary, command_id: String, proof: Dictionary, registration: String, issuer: Object) -> Dictionary:
	if not _s_json(context) or not _has_exact_keys(context, _SCENE_CONTEXT_KEYS) \
			or not _has_exact_keys(context.identity, _SCENE_IDENTITY_KEYS) or not _s_id(context.scene_occurrence) \
			or context.registration_sha256 != registration or not _s_digest(registration) or not _s_digest(context.contacts_sha256):
		return _s_fail("scene_contact_context_invalid")
	if typeof(context.identity.desktop_timeline_generation) != TYPE_INT or context.identity.desktop_timeline_generation < 0:
		return _s_fail("scene_contact_identity_invalid")
	for key: String in ["run_id", "branch_id", "causal_day_instance"]:
		if not _s_id(context.identity[key]): return _s_fail("scene_contact_identity_invalid")
	if not context.identity.causal_day_instance_issuer_receipt is Dictionary or issuer == null \
			or not issuer.has_method("verify_issued"): return _s_fail("scene_contact_issuer_unavailable")
	var causal: Dictionary = context.identity.causal_day_instance_issuer_receipt
	if causal.get("token") != context.identity.causal_day_instance: return _s_fail("scene_contact_identity_invalid")
	var verified: Variant = issuer.call(&"verify_issued", causal.duplicate(true), &"causal_day_instance")
	if not verified is Dictionary or not verified.get("ok", false): return _s_fail("scene_contact_identity_invalid")
	return _verify_command(issuer, command_id, proof)

static func _s_message(command: String, row: Dictionary, sequence: int, direction: String, reply_id: Variant) -> Dictionary:
	return {"message_id": command, "definition_id": row.definition_id, "friend_id": row.friend_id,
		"sequence": sequence, "transaction_id": command, "direction": direction, "reply_id": reply_id}

static func _s_find_message(state: Dictionary, id: String) -> Dictionary:
	for friend: String in FRIEND_IDS:
		for message: Dictionary in state.messages[friend]:
			if message.message_id == id: return message
	return {}

static func _s_replied(state: Dictionary, incoming: String) -> bool:
	for receipt: Dictionary in state.transaction_receipts.values():
		if receipt.kind == "scene_reply" and receipt.result.incoming_message_id == incoming: return true
	return false

static func _s_claim_facts(ids: Variant, claimed: Dictionary) -> bool:
	if not _s_sorted_ids(ids): return false
	for id: String in ids:
		if claimed.has(id): return false
		claimed[id] = true
	return true

static func _s_sorted_ids(ids: Variant) -> bool:
	if not ids is Array: return false
	var previous := ""
	for id: Variant in ids:
		if not _s_id(id) or id <= previous: return false
		previous = id
	return true

static func _s_texts(texts: Variant) -> bool:
	if not texts is Dictionary or not texts.has("en"): return false
	for locale: Variant in texts:
		if typeof(locale) != TYPE_STRING or locale not in _SCENE_LOCALES or typeof(texts[locale]) != TYPE_STRING \
				or texts[locale].strip_edges().is_empty(): return false
		for index in range(texts[locale].length()):
			var code: int = texts[locale].unicode_at(index)
			if (code < 32 and code != 10) or code == 127: return false
	return true

static func _s_localized(texts: Dictionary, locale: String) -> String:
	return texts.get(locale, texts.en if locale in ["ja", "ko"] else "")

static func _s_id(value: Variant) -> bool:
	return typeof(value) == TYPE_STRING and not value.strip_edges().is_empty()

static func _s_digest(value: Variant) -> bool:
	if typeof(value) != TYPE_STRING or value.length() != 64: return false
	for i in range(64):
		if value[i] not in "0123456789abcdef": return false
	return true

static func _s_json(value: Variant, depth: int = 0) -> bool:
	if depth > 128: return false
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_STRING: return true
		TYPE_ARRAY:
			for child: Variant in value:
				if not _s_json(child, depth + 1): return false
			return true
		TYPE_DICTIONARY:
			for key: Variant in value:
				if typeof(key) != TYPE_STRING or not _s_json(value[key], depth + 1): return false
			return true
	return false

static func _s_hash(value: Variant) -> String:
	var encoded: Dictionary = _CANONICAL_WRITER.stringify(value)
	return str(encoded.value).sha256_text() if encoded.get("ok", false) else ""

static func _s_equal(a: Variant, b: Variant) -> bool:
	return _s_json(a) and _s_json(b) and _s_hash(a) == _s_hash(b)

static func _s_fail(code: String) -> Dictionary:
	return _fail(StringName(code), "")

static func _s_projection_shape(state: Dictionary) -> bool:
	if not _s_json(state) or not _has_exact_keys(state, _SCENE_BAG_KEYS) or state.schema_version != 2 \
			or not _has_exact_keys(state.messages, FRIEND_IDS) or not _has_exact_keys(state.read_watermarks, FRIEND_IDS) \
			or not state.transaction_receipts is Dictionary: return false
	for friend: String in FRIEND_IDS:
		if not state.messages[friend] is Array or typeof(state.read_watermarks[friend]) != TYPE_INT: return false
		for message: Variant in state.messages[friend]:
			if not _has_exact_keys(message, _SCENE_MESSAGE_KEYS) or typeof(message.sequence) != TYPE_INT \
					or not _s_id(message.message_id) or not _s_id(message.definition_id) \
					or message.friend_id != friend or message.direction not in ["incoming", "outgoing"]: return false
	for receipt: Variant in state.transaction_receipts.values():
		if not _has_exact_keys(receipt, _SCENE_RECEIPT_KEYS) or receipt.kind not in ["scene_message", "scene_read", "scene_reply"] \
				or not receipt.result is Dictionary: return false
		if receipt.kind == "scene_reply" and not _s_id(receipt.result.get("incoming_message_id")): return false
	return true

