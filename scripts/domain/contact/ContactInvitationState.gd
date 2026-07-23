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

const FRIEND_IDS: Array[String] = ["priscilla", "lavinia", "sylvia"]
## The one counted Priscilla-Lavinia pair and its group-eligible windows.
const GROUP_PAIR: Array[String] = ["priscilla", "lavinia"]
const GROUP_WINDOW_DAYS: Array[int] = [2, 6]
const GROUP_ACTIVATION_ROUND := 3
const GROUP_PAIR_KEY := "priscilla_lavinia"
const GROUP_OPEN_STATES: Array[String] = ["AVAILABLE_UNOPENED", "REPLY_REQUIRED", "ACCEPTED"]

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
		"transaction_receipts": {},
		"next_sequence": 1,
	}

static func validate_state(state: Dictionary) -> Dictionary:
	for key: String in ["messages", "read_watermarks", "solo_actions", "group_action", "transaction_receipts"]:
		if typeof(state.get(key)) != TYPE_DICTIONARY:
			return _fail(&"invalid_state", "%s must be a Dictionary" % key)
	if not _is_integral(state.get("next_sequence")) or int(state["next_sequence"]) < 1:
		return _fail(&"invalid_state", "next_sequence must be a positive integer")
	for friend_id: String in FRIEND_IDS:
		if typeof(state["messages"].get(friend_id)) != TYPE_ARRAY:
			return _fail(&"invalid_state", "messages[%s] must be an array" % friend_id)
		if not _is_integral(state["read_watermarks"].get(friend_id)):
			return _fail(&"invalid_state", "read_watermarks[%s] must be an integer" % friend_id)
	return {"ok": true, "code": &"ok"}

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

static func prepare_open_contact(state: Dictionary, friend_id: String, day: int, transaction_id: String) -> Dictionary:
	var detached: Dictionary = state.duplicate(true)
	if friend_id not in FRIEND_IDS:
		return _fail(&"unknown_friend", friend_id)
	if transaction_id.is_empty():
		return _fail(&"invalid_transaction", "transaction_id is required")
	if detached["transaction_receipts"].has(transaction_id):
		return _replay(detached, transaction_id)
	# Route to the group open branch when an active group offer covers this friend/day.
	if _routes_to_group(detached, friend_id, day):
		return _open_group(detached, friend_id, transaction_id)
	var prior := int(detached["read_watermarks"][friend_id])
	# Opening marks every message visible on or before `day` read; it never answers.
	var new_watermark := prior
	for record: Dictionary in detached["messages"][friend_id]:
		if str(record["visibility"]) != "visible":
			continue
		if int(record["target_day"]) > day:
			continue
		new_watermark = maxi(new_watermark, int(record["sequence"]))
	detached["read_watermarks"][friend_id] = new_watermark
	var receipt := {
		"transaction_id": transaction_id,
		"kind": "open_contact",
		"friend_id": friend_id,
		"day": day,
		"prior_watermark": prior,
		"new_watermark": new_watermark,
		"child_transaction_ids": [],
		"message_ids": [],
		"message_sequences": [],
	}
	detached["transaction_receipts"][transaction_id] = receipt
	return _ok(detached, [], receipt)

static func prepare_reply(state: Dictionary, friend_id: String, day: int, transaction_id: String) -> Dictionary:
	var detached: Dictionary = state.duplicate(true)
	if friend_id not in FRIEND_IDS:
		return _fail(&"unknown_friend", friend_id)
	if transaction_id.is_empty():
		return _fail(&"invalid_transaction", "transaction_id is required")
	if detached["transaction_receipts"].has(transaction_id):
		return _replay(detached, transaction_id)
	# Route to the group reply branch when an active group offer covers this friend/day.
	if _routes_to_group(detached, friend_id, day):
		return _reply_group(detached, friend_id, transaction_id)
	var action_id := "solo:%s:day%d" % [friend_id, day]
	var action: Variant = detached["solo_actions"].get(action_id)
	if typeof(action) != TYPE_DICTIONARY:
		return _fail(&"no_offer", action_id)
	if str(action["state"]) != "AVAILABLE":
		return _fail(&"invalid_transition", "%s is %s, expected AVAILABLE" % [action_id, action["state"]])
	action["state"] = "ACCEPTED"
	action["reply_transaction_id"] = transaction_id
	var receipt := {
		"transaction_id": transaction_id,
		"kind": "reply_solo",
		"action_id": action_id,
		"friend_id": friend_id,
		"day": day,
		"from_state": "AVAILABLE",
		"to_state": "ACCEPTED",
		"child_transaction_ids": [],
		"message_ids": [],
		"message_sequences": [],
	}
	detached["transaction_receipts"][transaction_id] = receipt
	return _ok(detached, [], receipt)

static func prepare_resolve_day_end(state: Dictionary, day: int, attendance: Dictionary, transaction_id: String) -> Dictionary:
	var detached: Dictionary = state.duplicate(true)
	if day < 1 or day > 7:
		return _fail(&"invalid_day", str(day))
	if transaction_id.is_empty():
		return _fail(&"invalid_transaction", "transaction_id is required")
	if detached["transaction_receipts"].has(transaction_id):
		return _replay(detached, transaction_id)
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
				deferred_twofriends = {"route_id": "twofriends", "action_id": str(group["action_id"]), "after_hospital": group_outcome == "prevented_by_fainting"}
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
	detached["transaction_receipts"][transaction_id] = receipt
	return _ok(detached, message_batch, receipt)

static func prepare_activate_group_after_round(state: Dictionary, day: int, rounds_before: int, rounds_after: int, transaction_id: String) -> Dictionary:
	var detached: Dictionary = state.duplicate(true)
	if transaction_id.is_empty():
		return _fail(&"invalid_transaction", "transaction_id is required")
	if detached["transaction_receipts"].has(transaction_id):
		return _replay(detached, transaction_id)
	if day not in GROUP_WINDOW_DAYS:
		return _fail(&"not_group_window", str(day))
	if rounds_before != GROUP_ACTIVATION_ROUND - 1 or rounds_after != GROUP_ACTIVATION_ROUND:
		return _fail(&"not_activation_round", "%d->%d" % [rounds_before, rounds_after])
	if str(detached["group_action"]["state"]) != "INACTIVE":
		return _fail(&"group_not_inactive", str(detached["group_action"]["state"]))
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
	return _ok(detached, [], receipt)

# ---- pure queries ----

static func get_unread_count(state: Dictionary, friend_id: String, day: int) -> int:
	var watermark := int(state["read_watermarks"].get(friend_id, 0))
	var count := 0
	for record: Dictionary in state["messages"].get(friend_id, []):
		if str(record["visibility"]) != "visible":
			continue
		if int(record["target_day"]) > day:
			continue
		if int(record["sequence"]) > watermark:
			count += 1
	return count

static func is_reply_required(state: Dictionary, friend_id: String) -> bool:
	# An AVAILABLE (offered, unanswered) solo action whose offer has been read.
	var watermark := int(state["read_watermarks"].get(friend_id, 0))
	for action_id: String in state["solo_actions"]:
		var action: Dictionary = state["solo_actions"][action_id]
		if str(action["friend_id"]) != friend_id or str(action["state"]) != "AVAILABLE":
			continue
		if _offer_sequence(state, action) <= watermark:
			return true
	return false

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
	return {"messages": visible}

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

static func _open_group(detached: Dictionary, friend_id: String, transaction_id: String) -> Dictionary:
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
	}
	detached["transaction_receipts"][transaction_id] = second_receipt
	return _ok(detached, [], second_receipt)

static func _reply_group(detached: Dictionary, friend_id: String, transaction_id: String) -> Dictionary:
	var group: Dictionary = detached["group_action"]
	if str(group["state"]) not in ["REPLY_REQUIRED", "ACCEPTED"]:
		return _fail(&"invalid_transition", "group is %s" % group["state"])
	if friend_id in group["replied_ids"]:
		return _fail(&"invalid_transition", "%s already replied" % friend_id)
	var from_state := str(group["state"])
	(group["replied_ids"] as Array).append(friend_id)
	group["replied_ids"] = _canonical_participants(group["replied_ids"])
	group["state"] = "ACCEPTED"
	var receipt := {
		"transaction_id": transaction_id,
		"kind": "reply_group",
		"action_id": str(group["action_id"]),
		"day": int(group["day"]),
		"friend_id": friend_id,
		"from_state": from_state,
		"to_state": "ACCEPTED",
		"child_transaction_ids": [],
		"message_ids": [],
		"message_sequences": [],
	}
	detached["transaction_receipts"][transaction_id] = receipt
	return _ok(detached, [], receipt)

static func _offer_sequence(state: Dictionary, action: Dictionary) -> int:
	for record: Dictionary in state["messages"].get(str(action["friend_id"]), []):
		if str(record["message_id"]) == str(action["offer_message_id"]):
			return int(record["sequence"])
	return 0

static func _replay(detached: Dictionary, transaction_id: String) -> Dictionary:
	var receipt: Dictionary = detached["transaction_receipts"][transaction_id]
	return _ok(detached, [], receipt)

static func _is_integral(value: Variant) -> bool:
	# JSON round-trips integers as floats, so accept an integral number of either type.
	if typeof(value) == TYPE_INT:
		return true
	return typeof(value) == TYPE_FLOAT and is_finite(value) and value == floorf(value)

static func _ok(candidate: Dictionary, message_batch: Array, receipt: Dictionary) -> Dictionary:
	return {"ok": true, "code": &"ok", "value": {"candidate": candidate, "message_batch": message_batch}, "receipt": receipt}

static func _fail(code: StringName, message: String) -> Dictionary:
	return {"ok": false, "code": code, "message": message}
