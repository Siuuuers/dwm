class_name ContactInvitationState
extends RefCounted

## Pure contacts & invitation state machine (dwm-p2r.6).
## Append-only per-friend message history with monotonic sequence watermarks;
## solo-offer state machine (unread -> reply_required -> replied, or superseded);
## restorable via to_dict/from_dict. No Node/scene dependency.
## Spec: prompt_docs/requirements/contacts_invitations.md, story/05 §7/§13.

const FRIEND_IDS: Array[String] = ["priscilla", "lavinia", "sylvia"]
const MESSAGE_KINDS: Array[String] = [
	"daily_message", "solo_offer", "group_offer", "nevermind", "busy", "guilt",
]
const OFFER_STATES: Array[String] = ["unread", "reply_required", "replied", "superseded"]
## The one counted Priscilla-Lavinia pair and its group-eligible windows.
const GROUP_PAIR: Array[String] = ["priscilla", "lavinia"]
const GROUP_WINDOW_DAYS: Array[int] = [2, 6]
const GROUP_ACTIVATION_ROUND := 3

# {friend_id: Array[{seq:int, kind:String, state:String, day:int}]}, ascending seq.
var _history: Dictionary = {}
# {day: {"inviter_id": String, "schedulable": bool}} for the active group window.
var _group: Dictionary = {}
# {day: {"outcome": String, "counts": bool, "visible": bool}} resolved P-L windows.
var _pl_windows: Dictionary = {}
var _pair_counter: int = 0

func _init() -> void:
	for friend_id: String in FRIEND_IDS:
		_history[friend_id] = []

# ---- history / watermark ----

func get_watermark(friend_id: String) -> int:
	var entries: Array = _history.get(friend_id, [])
	return int(entries[-1]["seq"]) if not entries.is_empty() else 0

func get_history(friend_id: String) -> Array:
	return (_history.get(friend_id, []) as Array).duplicate(true)

func generate_message(friend_id: String, kind: StringName, day: int) -> Dictionary:
	if friend_id not in FRIEND_IDS:
		return _fail(&"unknown_friend", friend_id)
	if String(kind) not in MESSAGE_KINDS:
		return _fail(&"unknown_message_kind", String(kind))
	if day < 1 or day > 7:
		return _fail(&"invalid_day", str(day))
	# Idempotent: an existing (day, kind) entry for this friend is a no-op.
	var existing := _find_entry(friend_id, String(kind), day)
	if not existing.is_empty():
		return {"ok": true, "code": &"ok", "value": {"appended": false, "entry": existing.duplicate(true)}}
	var entry := {
		"seq": get_watermark(friend_id) + 1,
		"kind": String(kind),
		"state": "unread" if String(kind) in ["solo_offer", "group_offer"] else "posted",
		"day": day,
	}
	(_history[friend_id] as Array).append(entry)
	return {"ok": true, "code": &"ok", "value": {"appended": true, "entry": entry.duplicate(true)}}

# ---- solo-offer state machine ----

func get_solo_state(friend_id: String, day: int) -> StringName:
	var entry := _find_entry(friend_id, "solo_offer", day)
	return StringName(str(entry.get("state", ""))) if not entry.is_empty() else &""

func has_unread_solo(friend_id: String, day: int) -> bool:
	return get_solo_state(friend_id, day) == &"unread"

func open_solo_offer(friend_id: String, day: int) -> Dictionary:
	return _transition_solo(friend_id, day, &"unread", &"reply_required")

func reply_solo_offer(friend_id: String, day: int) -> Dictionary:
	return _transition_solo(friend_id, day, &"reply_required", &"replied")

func supersede_solo(friend_id: String, day: int) -> Dictionary:
	var entry := _find_mutable_entry(friend_id, "solo_offer", day)
	if entry.is_empty():
		return _fail(&"no_solo_offer", "%s day %d" % [friend_id, day])
	# Only an un-replied offer can be superseded; a replied one is committed.
	if str(entry["state"]) == "replied":
		return _fail(&"offer_already_replied", friend_id)
	entry["state"] = "superseded"
	return {"ok": true, "code": &"ok"}

func resolve_solo_offers_at_day_end(day: int) -> Dictionary:
	# nevermind fires for any un-replied offer (unread OR reply_required); superseded
	# and replied are silent (story/05 §13).
	var nevermind: Array = []
	for friend_id: String in FRIEND_IDS:
		var state := get_solo_state(friend_id, day)
		if state == &"unread" or state == &"reply_required":
			nevermind.append(friend_id)
	return {"ok": true, "code": &"ok", "value": {"nevermind_friend_ids": nevermind}}

# ---- group activation (req.invitation.group_activation) ----

func can_activate_group(day: int, minesweeper_rounds_finished: int) -> bool:
	if day not in GROUP_WINDOW_DAYS:
		return false
	if minesweeper_rounds_finished < GROUP_ACTIVATION_ROUND:
		return false
	for friend_id: String in GROUP_PAIR:
		if not has_unread_solo(friend_id, day):
			return false
	return true

func activate_group(day: int) -> Dictionary:
	if day not in GROUP_WINDOW_DAYS:
		return _fail(&"not_group_window", str(day))
	if is_group_active(day):
		return {"ok": true, "code": &"ok", "value": {"appended": false}}
	for friend_id: String in GROUP_PAIR:
		# Supersede each participant's solo offer, then post an unread group offer.
		var superseded := supersede_solo(friend_id, day)
		if not superseded.get("ok", false):
			return superseded
		var generated := generate_message(friend_id, &"group_offer", day)
		if not generated.get("ok", false):
			return generated
	_group[day] = {"inviter_id": "", "schedulable": false}
	return {"ok": true, "code": &"ok", "value": {"appended": true}}

func is_group_active(day: int) -> bool:
	return _group.has(day)

func get_group_state(friend_id: String, day: int) -> StringName:
	var entry := _find_entry(friend_id, "group_offer", day)
	return StringName(str(entry.get("state", ""))) if not entry.is_empty() else &""

# ---- group resolution (req.invitation.group_resolution) ----

func open_group_offer(friend_id: String, day: int) -> Dictionary:
	if friend_id not in GROUP_PAIR:
		return _fail(&"not_group_participant", friend_id)
	if not is_group_active(day):
		return _fail(&"no_active_group", str(day))
	var opened := _transition_group(friend_id, day, &"unread", &"reply_required")
	if not opened.get("ok", false):
		return opened
	# The first participant opened becomes the inviter (variation / image only).
	if str(_group[day]["inviter_id"]).is_empty():
		_group[day]["inviter_id"] = friend_id
	return {"ok": true, "code": &"ok", "value": {"inviter_id": str(_group[day]["inviter_id"])}}

func get_group_inviter(day: int) -> String:
	return str(_group.get(day, {}).get("inviter_id", ""))

func reply_group_offer(friend_id: String, day: int) -> Dictionary:
	if not is_group_active(day):
		return _fail(&"no_active_group", str(day))
	var inviter := get_group_inviter(day)
	# FLOWS §5.1 machine gate: the non-inviter cannot reply before the inviter.
	if not inviter.is_empty() and friend_id != inviter and get_group_state(inviter, day) != &"replied":
		return _fail(&"need_reply_inviter_first", inviter)
	var replied := _transition_group(friend_id, day, &"reply_required", &"replied")
	if not replied.get("ok", false):
		return replied
	_group[day]["schedulable"] = true
	return {"ok": true, "code": &"ok"}

func is_group_schedulable(day: int) -> bool:
	return bool(_group.get(day, {}).get("schedulable", false))

# ---- run-end Priscilla-Lavinia window (req.invitation.run_end, story/05 §7) ----

## Resolves one counted P-L window on the single rule: did Angela solo-date either
## woman? Idempotent per day; increments the pair counter once when the window counts.
## `solo_dated_participant_ids` are which of the pair Angela solo-dated this window.
func resolve_pl_window(day: int, solo_dated_participant_ids: Array, group_attended: bool) -> Dictionary:
	if day not in GROUP_WINDOW_DAYS:
		return _fail(&"not_group_window", str(day))
	if _pl_windows.has(day):
		var stored: Dictionary = _pl_windows[day]
		return {"ok": true, "code": &"ok", "value": {
			"outcome": StringName(str(stored["outcome"])), "counts": bool(stored["counts"]),
			"visible": bool(stored["visible"]), "already_resolved": true}}
	var outcome := _classify_pl_window(day, solo_dated_participant_ids, group_attended)
	_pl_windows[day] = {"outcome": String(outcome["outcome"]), "counts": outcome["counts"], "visible": outcome["visible"]}
	if outcome["counts"]:
		_pair_counter += 1
	outcome["already_resolved"] = false
	return {"ok": true, "code": &"ok", "value": outcome}

func get_pair_counter() -> int:
	return _pair_counter

func should_route_pl_epilogue() -> bool:
	return _pair_counter >= 2

func _classify_pl_window(day: int, solo_dated_participant_ids: Array, group_attended: bool) -> Dictionary:
	# Prevented: Angela solo-dated either woman -> no meeting, no count.
	for participant: Variant in solo_dated_participant_ids:
		if str(participant) in GROUP_PAIR:
			return {"outcome": &"prevented", "counts": false, "visible": false}
	# Solo-dated neither: the pair always meets and counts; flavor by group-offer state.
	if not is_group_active(day):
		return {"outcome": &"private_offscreen", "counts": true, "visible": false}
	if group_attended:
		return {"outcome": &"group", "counts": true, "visible": true}
	if is_group_schedulable(day):
		return {"outcome": &"missed", "counts": true, "visible": true}
	return {"outcome": &"private_visible", "counts": true, "visible": true}

# ---- serialization ----

func to_dict() -> Dictionary:
	return {
		"schema": "contact_invitation_state.v1",
		"history": _history.duplicate(true),
		"group": _group.duplicate(true),
		"pl_windows": _pl_windows.duplicate(true),
		"pair_counter": _pair_counter,
	}

static func from_dict(data: Dictionary) -> Dictionary:
	if str(data.get("schema", "")) != "contact_invitation_state.v1":
		return _fail(&"invalid_schema", str(data.get("schema", "")))
	if typeof(data.get("history")) != TYPE_DICTIONARY:
		return _fail(&"invalid_history", "history must be a Dictionary")
	if typeof(data.get("group")) != TYPE_DICTIONARY:
		return _fail(&"invalid_group", "group must be a Dictionary")
	if typeof(data.get("pl_windows")) != TYPE_DICTIONARY:
		return _fail(&"invalid_pl_windows", "pl_windows must be a Dictionary")
	if typeof(data.get("pair_counter")) != TYPE_INT or int(data["pair_counter"]) < 0:
		return _fail(&"invalid_pair_counter", "pair_counter must be a non-negative integer")
	var state: RefCounted = (load("res://scripts/domain/contact/ContactInvitationState.gd") as GDScript).new()
	for friend_id: String in FRIEND_IDS:
		var entries: Variant = data["history"].get(friend_id, [])
		if typeof(entries) != TYPE_ARRAY:
			return _fail(&"invalid_history", "history[%s] must be an array" % friend_id)
		var previous_seq := 0
		var restored: Array = []
		for raw: Variant in entries:
			if typeof(raw) != TYPE_DICTIONARY:
				return _fail(&"invalid_history", "entry must be an object")
			var entry := raw as Dictionary
			var keys := entry.keys()
			keys.sort()
			if keys != ["day", "kind", "seq", "state"]:
				return _fail(&"invalid_history", "unexpected entry keys: " + str(keys))
			var seq := int(entry["seq"])
			if seq <= previous_seq:
				return _fail(&"invalid_history", "sequences must ascend for " + friend_id)
			previous_seq = seq
			if str(entry["kind"]) not in MESSAGE_KINDS:
				return _fail(&"invalid_history", "unknown kind: " + str(entry["kind"]))
			restored.append({"seq": seq, "kind": str(entry["kind"]), "state": str(entry["state"]), "day": int(entry["day"])})
		state._history[friend_id] = restored
	for day_key: Variant in data["group"]:
		var window: Variant = data["group"][day_key]
		if typeof(window) != TYPE_DICTIONARY:
			return _fail(&"invalid_group", "group window must be an object")
		var window_keys := (window as Dictionary).keys()
		window_keys.sort()
		if window_keys != ["inviter_id", "schedulable"]:
			return _fail(&"invalid_group", "unexpected group window keys: " + str(window_keys))
		state._group[int(str(day_key))] = {
			"inviter_id": str(window["inviter_id"]),
			"schedulable": bool(window["schedulable"]),
		}
	for day_key: Variant in data["pl_windows"]:
		var window: Variant = data["pl_windows"][day_key]
		if typeof(window) != TYPE_DICTIONARY:
			return _fail(&"invalid_pl_windows", "window must be an object")
		var window_keys := (window as Dictionary).keys()
		window_keys.sort()
		if window_keys != ["counts", "outcome", "visible"]:
			return _fail(&"invalid_pl_windows", "unexpected window keys: " + str(window_keys))
		state._pl_windows[int(str(day_key))] = {
			"outcome": str(window["outcome"]), "counts": bool(window["counts"]), "visible": bool(window["visible"])}
	state._pair_counter = int(data["pair_counter"])
	return {"ok": true, "code": &"ok", "value": {"state": state}}

# ---- internals ----

func _find_entry(friend_id: String, kind: String, day: int) -> Dictionary:
	for entry: Dictionary in _history.get(friend_id, []):
		if str(entry["kind"]) == kind and int(entry["day"]) == day:
			return entry
	return {}

func _find_mutable_entry(friend_id: String, kind: String, day: int) -> Dictionary:
	# Returns the live entry reference (not a copy) so callers can mutate state.
	for entry: Dictionary in _history.get(friend_id, []):
		if str(entry["kind"]) == kind and int(entry["day"]) == day:
			return entry
	return {}

func _transition_solo(friend_id: String, day: int, from_state: StringName, to_state: StringName) -> Dictionary:
	return _transition_offer(friend_id, "solo_offer", day, from_state, to_state)

func _transition_group(friend_id: String, day: int, from_state: StringName, to_state: StringName) -> Dictionary:
	return _transition_offer(friend_id, "group_offer", day, from_state, to_state)

func _transition_offer(friend_id: String, kind: String, day: int, from_state: StringName, to_state: StringName) -> Dictionary:
	var entry := _find_mutable_entry(friend_id, kind, day)
	if entry.is_empty():
		return _fail(&"no_offer", "%s %s day %d" % [friend_id, kind, day])
	if StringName(str(entry["state"])) != from_state:
		return _fail(&"invalid_transition", "%s is %s, expected %s" % [friend_id, entry["state"], from_state])
	entry["state"] = String(to_state)
	return {"ok": true, "code": &"ok"}

static func _fail(code: StringName, message: String) -> Dictionary:
	return {"ok": false, "code": code, "message": message}
