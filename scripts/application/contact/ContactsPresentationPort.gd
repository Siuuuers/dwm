class_name ContactsPresentationPort
extends RefCounted

## Detached UI projection over the real Contacts owner. The catalog contains explicitly supplied
## approved plain text keyed by exact message identity. Empty production catalogs are intentional:
## missing prose is a technical failure, never an invitation to print IDs or invent correspondence.
const CONTACT_STATE := preload("res://scripts/domain/contact/ContactInvitationState.gd")
const ORDINARY_REPLIES := preload("res://scripts/domain/contact/OrdinaryReplyEchoState.gd")
const DAY7_FOLLOWUPS := preload("res://scripts/domain/contact/Day7FollowupState.gd")
const LOCALES := ["en", "zh-CN", "zh-HK"]

var _game_state: Object = null
var _command_port: Object = null
var _catalog: Dictionary = {}


func configure(game_state: Object, command_port: Object, catalog: Dictionary = {}) -> Dictionary:
	if game_state == null or not game_state.has_method("get_contact_view") \
			or typeof(game_state.get("contacts")) != TYPE_DICTIONARY \
			or command_port == null or not command_port.has_method("request_open_contact") \
			or not command_port.has_method("request_reply_invitation"):
		return _fail(&"invalid_contacts_presentation_configuration")
	if _game_state != null:
		if _game_state != game_state or _command_port != command_port or _catalog != catalog:
			return _fail(&"contacts_presentation_already_configured")
		return _ok({})
	_game_state = game_state
	_command_port = command_port
	_catalog = catalog.duplicate(true)
	return _ok({})


func get_projection(friend_id: String, primary: String = "en", secondary: String = "") -> Dictionary:
	if _game_state == null:
		return _fail(&"contacts_presentation_unconfigured")
	return _project((_game_state.get("contacts") as Dictionary).duplicate(true),
		int(_game_state.get("day")), friend_id, primary.replace("_", "-"), secondary.replace("_", "-"), _missed_history())


## Mandatory Day 7 cards reuse exact saved messages and the ordinary localized bubble
## projection. Merely obtaining a card never advances a read watermark.
func get_day7_followup_cards(primary: String = "en", secondary: String = "") -> Dictionary:
	if _game_state == null: return _fail(&"contacts_presentation_unconfigured")
	primary = primary.replace("_", "-")
	secondary = secondary.replace("_", "-")
	if primary not in LOCALES or (secondary != "" and secondary not in LOCALES) or primary == secondary:
		return _fail(&"invalid_contacts_projection_request")
	var cards: Array[Dictionary] = []
	if int(_game_state.get("day")) != 7: return _ok({"cards": cards})
	var state: Dictionary = (_game_state.get("contacts") as Dictionary).duplicate(true)
	var missed := _missed_history()
	for row: Dictionary in DAY7_FOLLOWUPS.pending_day7_followups(state):
		var message: Dictionary = row.message
		var friend: String = row.friend_id
		var id: String = message.message_id
		var resolved := _resolve_entry(id, primary, secondary)
		if not resolved.ok: return resolved
		var entries: Array = [resolved.value]
		if _has_hospital_miss(message, friend, missed):
			for role: String in ["explanation", "reaction"]:
				var followup := _resolve_entry(id, primary, secondary, role)
				if not followup.ok: return followup
				entries.append(followup.value)
		cards.append({"message_id": id, "friend_id": friend,
			"sequence": int(message.sequence), "entries": entries})
	return _ok({"cards": cards})


func open_friend(friend_id: String, primary: String = "en", secondary: String = "") -> Dictionary:
	if friend_id not in CONTACT_STATE.FRIEND_IDS:
		return _fail(&"unknown_friend")
	var current := get_projection(friend_id, primary, secondary)
	if not current.get("ok", false):
		return current
	var state: Dictionary = (_game_state.get("contacts") as Dictionary).duplicate(true)
	var day: int = int(_game_state.get("day"))
	if not _needs_open(state, day, friend_id):
		# Viewing empty/history-only threads creates no acceptance or durable read receipt.
		return current
	var guard := _admit_candidate.bind(state, day, friend_id,
		primary.replace("_", "-"), secondary.replace("_", "-"))
	var committed: Dictionary = _command_port.call(&"request_open_contact", friend_id, guard)
	if not committed.get("ok", false):
		return committed
	return get_projection(friend_id, primary, secondary)


func reply_to_group(friend_id: String, primary: String = "en", secondary: String = "") -> Dictionary:
	var current := get_projection(friend_id, primary, secondary)
	if not current.get("ok", false):
		return current
	if not current["value"]["reply_required"]:
		return _fail(&"contact_reply_not_required")
	var committed: Dictionary = _command_port.call(&"request_reply_invitation", friend_id)
	if not committed.get("ok", false):
		return committed
	return get_projection(friend_id, primary, secondary)


func prepare_ordinary_reply(friend_id: String, reply_id: String, primary: String = "en") -> Dictionary:
	if not _ordinary_enabled(): return _fail(&"ordinary_reply_unconfigured")
	return _command_port.prepare_ordinary_reply(friend_id, reply_id, primary.replace("_", "-"))


func acknowledge_ordinary_reply(command: Dictionary, rendered_line: Dictionary,
		primary: String = "en", secondary: String = "") -> Dictionary:
	if not _ordinary_enabled(): return _fail(&"ordinary_reply_unconfigured")
	var committed: Dictionary = _command_port.acknowledge_ordinary_reply(command, rendered_line)
	if not committed.get("ok", false): return committed
	return get_projection(str(command.friend_id), primary, secondary)


func get_pending_ordinary_reply() -> Dictionary:
	if not _ordinary_enabled(): return _ok({})
	return _command_port.get_pending_ordinary_reply()


func cancel_pending_ordinary_reply(command: Dictionary) -> Dictionary:
	if not _ordinary_enabled(): return _ok({"cancelled": false})
	return _command_port.cancel_pending_ordinary_reply(command)


func _ordinary_enabled() -> bool:
	return _game_state != null and _game_state.has_method("preview_ordinary_reply") \
		and _command_port != null and _command_port.has_method("prepare_ordinary_reply")


func _admit_candidate(preview: Dictionary, prior: Dictionary, day: int, selected: String,
		primary: String, secondary: String) -> Dictionary:
	var candidate: Variant = preview.get("value", {}).get("candidate")
	if typeof(candidate) != TYPE_DICTIONARY:
		return _fail(&"contact_preview_malformed")
	for friend_id: String in CONTACT_STATE.FRIEND_IDS:
		if friend_id != selected and candidate["messages"][friend_id] == prior["messages"][friend_id]:
			continue
		var admitted := _project(candidate, day, friend_id, primary, secondary, _missed_history())
		if not admitted.get("ok", false):
			return admitted
	return _ok({})


func _needs_open(state: Dictionary, day: int, friend_id: String) -> bool:
	if friend_id == "sylvia" and not CONTACT_STATE.get_pending_sylvia_care(state, day).is_empty():
		return true
	var group: Dictionary = state["group_action"]
	if friend_id in CONTACT_STATE.GROUP_PAIR and group.get("day") == day \
			and group["state"] in CONTACT_STATE.GROUP_OPEN_STATES:
		return friend_id not in group["opened_ids"] \
			or CONTACT_STATE.get_unread_count(state, friend_id, day) > 0
	var solo: Dictionary = state["solo_actions"].get("solo:%s:day%d" % [friend_id, day], {})
	return solo.get("state", "") == "AVAILABLE"


func _project(state: Dictionary, day: int, friend_id: String, primary: String, secondary: String, missed: Array = []) -> Dictionary:
	if (friend_id != "" and friend_id not in CONTACT_STATE.FRIEND_IDS) \
			or primary not in LOCALES or (secondary != "" and secondary not in LOCALES) \
			or primary == secondary:
		return _fail(&"invalid_contacts_projection_request")
	var unread := {}
	var group: Dictionary = state["group_action"]
	for friend: String in CONTACT_STATE.FRIEND_IDS:
		unread[friend] = CONTACT_STATE.get_unread_count(state, friend, day) > 0 \
			or (friend in CONTACT_STATE.GROUP_PAIR and group.get("day") == day \
				and group["state"] == "AVAILABLE_UNOPENED")
	var ordinary_choices: Array = []
	var ordinary: Dictionary = {}
	if _ordinary_enabled():
		for friend: String in CONTACT_STATE.FRIEND_IDS:
			var available: Dictionary = ORDINARY_REPLIES.available(state, day, friend, primary)
			if not available.get("ok", false): return available
			if not available.value.is_empty(): unread[friend] = true
			if friend == friend_id: ordinary = available.value
	var entries: Array = []
	if friend_id != "":
		var messages: Array = CONTACT_STATE.get_contact_view(state, friend_id, day)["messages"]
		messages.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["sequence"]) < int(b["sequence"]))
		var seen := {}
		for message: Dictionary in messages:
			var id: String = str(message["message_id"])
			if seen.has(id):
				return _fail(&"duplicate_contact_content_identity")
			seen[id] = true
			var resolved: Dictionary = _resolve_ordinary_entry(state, message, primary, secondary) \
				if message.get("type") in ORDINARY_REPLIES.MESSAGE_KINDS else _resolve_entry(id, primary, secondary)
			if not resolved.get("ok", false):
				return resolved
			entries.append(resolved["value"])
			if _has_hospital_miss(message, friend_id, missed):
				for role: String in ["explanation", "reaction"]:
					var followup := _resolve_entry(id, primary, secondary, role)
					if not followup.ok: return followup
					entries.append(followup.value)

	if not ordinary.is_empty():
		var texts := {primary: ordinary.incoming_text}
		if not secondary.is_empty():
			var translated: Dictionary = ORDINARY_REPLIES.available(state, day, friend_id, secondary)
			if not translated.get("ok", false): return translated
			texts[secondary] = translated.value.incoming_text
		entries.append({"id": ordinary.entry_id, "outgoing": false, "texts": texts})
		ordinary_choices = ordinary.choices.duplicate(true)
	return _ok({"friend_id": friend_id, "entries": entries, "unread": unread,
		"ordinary_choices": ordinary_choices,
		"reply_required": friend_id != "" and group.get("day") == day \
			and CONTACT_STATE.is_reply_required(state, friend_id)})


func _resolve_ordinary_entry(state: Dictionary, message: Dictionary, primary: String, secondary: String) -> Dictionary:
	var texts := {}
	var entry: Dictionary = {}
	for locale: String in [primary, secondary]:
		if locale.is_empty(): continue
		var resolved: Dictionary = ORDINARY_REPLIES.resolve_history_message(state, message, locale)
		if not resolved.get("ok", false): return resolved
		entry = {"id": resolved.value.id, "outgoing": resolved.value.outgoing}
		texts[locale] = resolved.value.text
	entry["texts"] = texts
	return _ok(entry)


func _resolve_entry(id: String, primary: String, secondary: String, hospital_role: String = "") -> Dictionary:
	var copy: Variant = _catalog.get(id)
	if not hospital_role.is_empty():
		if not copy is Dictionary or not copy.get("hospital_followup") is Dictionary:
			return _fail(&"contact_content_unavailable", id)
		copy = copy.hospital_followup.get(hospital_role)
		id += ":hospital:" + hospital_role
	if typeof(copy) != TYPE_DICTIONARY or typeof(copy.get("texts")) != TYPE_DICTIONARY \
			or typeof(copy.get("outgoing")) != TYPE_BOOL:
		return _fail(&"contact_content_unavailable", id)
	var texts := {}
	for locale: String in [primary, secondary]:
		if locale == "":
			continue
		var body: Variant = copy["texts"].get(locale)
		if typeof(body) != TYPE_STRING or body.strip_edges().is_empty():
			return _fail(&"contact_translation_unavailable", id)
		texts[locale] = body
	var entry := {"id": id, "outgoing": copy["outgoing"], "texts": texts}
	if copy.has("timestamp"):
		var stamp: Variant = copy["timestamp"]
		if typeof(stamp) != TYPE_STRING or not _valid_timestamp(stamp):
			return _fail(&"invalid_contact_authored_time", id)
		entry["timestamp"] = stamp
	return _ok(entry)


func _missed_history() -> Array:
	var missed: Variant = _game_state.get("missed_invitations")
	return missed.duplicate(true) if missed is Array else []

static func _has_hospital_miss(message: Dictionary, friend_id: String, missed: Array) -> bool:
	if friend_id not in ["priscilla", "lavinia"] or message.get("type") != "missed_question": return false
	for record: Variant in missed:
		if record is Dictionary and record.get("friend_id") == friend_id and record.get("missed_reason") == "hospital" \
				and typeof(record.get("day")) == TYPE_INT and int(message.get("target_day", 0)) == int(record.day) + 1 \
				and record.get("hospital_miss_receipt_id") is String and not record.hospital_miss_receipt_id.is_empty():
			return true
	return false

func _valid_timestamp(stamp: String) -> bool:
	if stamp.length() != 5 or stamp[2] != ":":
		return false
	for index: int in [0, 1, 3, 4]:
		if stamp.unicode_at(index) < 48 or stamp.unicode_at(index) > 57:
			return false
	return stamp.substr(0, 2).to_int() < 24 and stamp.substr(3, 2).to_int() < 60


static func _ok(value: Dictionary) -> Dictionary:
	return {"ok": true, "code": &"ok", "value": value, "receipt": {}}


static func _fail(code: StringName, entry_id: String = "") -> Dictionary:
	return {"ok": false, "code": code, "details": {"entry_id": entry_id}, "receipt": {}}
