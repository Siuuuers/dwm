class_name ContactsPresentationPort
extends RefCounted

## Detached UI projection over the real Contacts owner. The catalog contains explicitly supplied
## approved plain text keyed by exact message identity. Empty production catalogs are intentional:
## missing prose is a technical failure, never an invitation to print IDs or invent correspondence.
const CONTACT_STATE := preload("res://scripts/domain/contact/ContactInvitationState.gd")
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
		int(_game_state.get("day")), friend_id, primary.replace("_", "-"), secondary.replace("_", "-"))


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


func _admit_candidate(preview: Dictionary, prior: Dictionary, day: int, selected: String,
		primary: String, secondary: String) -> Dictionary:
	var candidate: Variant = preview.get("value", {}).get("candidate")
	if typeof(candidate) != TYPE_DICTIONARY:
		return _fail(&"contact_preview_malformed")
	for friend_id: String in CONTACT_STATE.FRIEND_IDS:
		if friend_id != selected and candidate["messages"][friend_id] == prior["messages"][friend_id]:
			continue
		var admitted := _project(candidate, day, friend_id, primary, secondary)
		if not admitted.get("ok", false):
			return admitted
	return _ok({})


func _needs_open(state: Dictionary, day: int, friend_id: String) -> bool:
	var group: Dictionary = state["group_action"]
	if friend_id in CONTACT_STATE.GROUP_PAIR and group.get("day") == day \
			and group["state"] in CONTACT_STATE.GROUP_OPEN_STATES:
		return friend_id not in group["opened_ids"] \
			or CONTACT_STATE.get_unread_count(state, friend_id, day) > 0
	var solo: Dictionary = state["solo_actions"].get("solo:%s:day%d" % [friend_id, day], {})
	return solo.get("state", "") == "AVAILABLE"


func _project(state: Dictionary, day: int, friend_id: String, primary: String, secondary: String) -> Dictionary:
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
			var resolved := _resolve_entry(id, primary, secondary)
			if not resolved.get("ok", false):
				return resolved
			entries.append(resolved["value"])
	return _ok({"friend_id": friend_id, "entries": entries, "unread": unread,
		"reply_required": friend_id != "" and group.get("day") == day \
			and CONTACT_STATE.is_reply_required(state, friend_id)})


func _resolve_entry(id: String, primary: String, secondary: String) -> Dictionary:
	var copy: Variant = _catalog.get(id)
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
