extends "res://addons/gut/test.gd"

const CONTACTS := preload("res://scripts/domain/contact/ContactInvitationState.gd")
const PRESENTATION := preload("res://scripts/application/contact/ContactsPresentationPort.gd")
const CATALOG := preload("res://scripts/application/contact/ProvisionalCorrespondenceCatalog.gd")


class Owner extends RefCounted:
	var contacts: Dictionary = CONTACTS.make_defaults()
	var missed_invitations: Array = []
	var day := 2

	func get_contact_view(friend_id: String) -> Dictionary:
		return CONTACTS.get_contact_view(contacts, friend_id, day)

	# ContactsPresentationPort uses capability discovery to include the ordinary projection.
	func preview_ordinary_reply(_friend_id: String, _reply_id: String, _locale: String,
			_command_id: String, _receipt: Dictionary) -> Dictionary:
		return {"ok": false}


class Commands extends RefCounted:
	var calls := 0

	func request_open_contact(_friend_id: String, _guard: Callable) -> Dictionary:
		calls += 1
		return {"ok": false}

	func request_reply_invitation(_friend_id: String) -> Dictionary:
		calls += 1
		return {"ok": false}

	func prepare_ordinary_reply(_friend_id: String, _reply_id: String,
			_locale: String) -> Dictionary:
		calls += 1
		return {"ok": false}


func test_previous_day_followup_precedes_next_day_ordinary_in_the_same_thread() -> void:
	var state: Dictionary = CONTACTS.make_defaults()
	state = _offer(state, "sylvia", 1)
	state = _resolve_day_one(state)
	assert_true(CONTACTS.validate_state(state).ok)
	assert_eq(_message_ids(state.messages.sylvia), [
		"solo:sylvia:day1",
		"nevermind:sylvia:day2",
	])
	assert_eq(_message_sequences(state.messages.sylvia), [1, 2],
		"the causal follow-up appends after retained Day 1 history")

	var fixture := _projection(state, "sylvia")
	var projected: Dictionary = fixture.projected
	assert_eq(_entry_ids(projected.value.entries), [
		"solo:sylvia:day1",
		"nevermind:sylvia:day2",
		"contact.ordinary.sylvia.day2",
	])
	assert_eq(projected.value.ordinary_choices.size(), 3)
	_assert_projection_is_read_only(fixture)


func test_previous_day_followup_precedes_new_invitation_in_the_same_thread() -> void:
	var state: Dictionary = CONTACTS.make_defaults()
	state = _offer(state, "priscilla", 1)
	state = _resolve_day_one(state)
	state = _offer(state, "priscilla", 2)
	assert_true(CONTACTS.validate_state(state).ok)
	assert_eq(_message_ids(state.messages.priscilla), [
		"solo:priscilla:day1",
		"nevermind:priscilla:day2",
		"solo:priscilla:day2",
	])
	assert_eq(_message_sequences(state.messages.priscilla), [1, 2, 3],
		"the new invitation appends after the prior-day causal follow-up")

	var fixture := _projection(state, "priscilla")
	var projected: Dictionary = fixture.projected
	assert_eq(_entry_ids(projected.value.entries), [
		"solo:priscilla:day1",
		"nevermind:priscilla:day2",
		"solo:priscilla:day2",
	])
	assert_eq(projected.value.ordinary_choices, [],
		"Day 2 ordinary belongs to Sylvia, never Priscilla's invitation thread")
	_assert_projection_is_read_only(fixture)


func _offer(state: Dictionary, friend_id: String, day: int) -> Dictionary:
	var offered: Dictionary = CONTACTS.prepare_offer_solo(state, friend_id, day,
		"solo:%s:day%d" % [friend_id, day], "offer:%s:day%d" % [friend_id, day])
	assert_true(offered.ok, str(offered))
	return offered.value.candidate


func _resolve_day_one(state: Dictionary) -> Dictionary:
	var resolved: Dictionary = CONTACTS.prepare_resolve_day_end(state, 1,
		{"solo_attended_action_ids": []}, "resolve:day1")
	assert_true(resolved.ok, str(resolved))
	return resolved.value.candidate


func _projection(state: Dictionary, friend_id: String) -> Dictionary:
	var owner := Owner.new()
	owner.contacts = state.duplicate(true)
	var commands := Commands.new()
	var port := PRESENTATION.new()
	assert_true(port.configure(owner, commands, CATALOG.build()).ok)
	var before: Dictionary = owner.contacts.duplicate(true)
	var projected: Dictionary = port.get_projection(friend_id, "en", "zh-CN")
	assert_true(projected.ok, str(projected))
	return {"owner": owner, "commands": commands, "port": port,
		"before": before, "projected": projected, "friend_id": friend_id}


func _assert_projection_is_read_only(fixture: Dictionary) -> void:
	var repeated: Dictionary = fixture.port.get_projection(fixture.friend_id, "en", "zh-CN")
	assert_eq(repeated, fixture.projected)
	assert_eq(fixture.owner.contacts, fixture.before)
	assert_eq(fixture.commands.calls, 0)


func _entry_ids(entries: Array) -> Array[String]:
	var out: Array[String] = []
	for entry: Dictionary in entries:
		out.append(str(entry.id))
	return out


func _message_ids(messages: Array) -> Array[String]:
	var out: Array[String] = []
	for message: Dictionary in messages:
		out.append(str(message.message_id))
	return out


func _message_sequences(messages: Array) -> Array[int]:
	var out: Array[int] = []
	for message: Dictionary in messages:
		out.append(int(message.sequence))
	return out
