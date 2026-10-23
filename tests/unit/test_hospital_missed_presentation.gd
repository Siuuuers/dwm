extends "res://addons/gut/test.gd"
const CONTACTS := preload("res://scripts/domain/contact/ContactInvitationState.gd")
const PORT := preload("res://scripts/application/contact/ContactsPresentationPort.gd")
const CATALOG := preload("res://scripts/application/contact/ProvisionalCorrespondenceCatalog.gd")

class Owner extends RefCounted:
	var contacts: Dictionary = CONTACTS.make_defaults()
	var missed_invitations: Array = []
	var day := 7
	func get_contact_view(friend: String) -> Dictionary:
		return CONTACTS.get_contact_view(contacts, friend, day)

class Commands extends RefCounted:
	var calls := 0
	func request_open_contact(_friend: String, _guard: Callable) -> Dictionary:
		calls += 1
		return {"ok": false}
	func request_reply_invitation(_friend: String) -> Dictionary:
		calls += 1
		return {"ok": false}

func _message(friend: String, source_day: int, kind: String = "missed_question") -> Dictionary:
	return {"message_id": "%s:%s:day%d" % [kind, friend, source_day + 1], "sequence": 1,
		"type": kind, "variant": "default", "target_day": source_day + 1, "parameters": {},
		"visibility": "visible", "transaction_id": "message:fixture"}

func _miss(friend: String, source_day: int) -> Dictionary:
	return {"friend_id": friend, "source": "solo", "day": source_day, "missed_reason": "hospital",
		"source_receipt_id": "accepted:" + friend, "hospital_miss_receipt_id": "hospital:" + friend}

func test_hospital_miss_presents_question_scripted_explanation_and_friend_reaction_once() -> void:
	for friend: String in ["priscilla", "lavinia"]:
		var owner := Owner.new()
		var commands := Commands.new()
		owner.contacts.messages[friend] = [_message(friend, 2)]
		owner.contacts.next_sequence = 2
		owner.missed_invitations = [_miss(friend, 2)]
		var before := owner.contacts.duplicate(true)
		var misses := owner.missed_invitations.duplicate(true)
		var port := PORT.new()
		assert_true(port.configure(owner, commands, CATALOG.build()).ok)
		var projected: Dictionary = port.get_projection(friend, "en", "zh-CN")
		assert_true(projected.ok, str(projected))
		if not projected.ok: continue
		var rows: Array = projected.value.entries
		assert_eq(rows.size(), 3)
		assert_false(rows[0].outgoing)
		assert_true(rows[1].outgoing)
		assert_false(rows[2].outgoing)
		assert_eq(rows[0].id, _message(friend, 2).message_id)
		assert_true(rows[1].texts.en.contains("hospital"))
		assert_ne(rows[2].texts.en, rows[0].texts.en)
		assert_eq(port.get_projection(friend, "en", "zh-CN"), projected)
		assert_eq(owner.contacts, before)
		assert_eq(owner.missed_invitations, misses)
		assert_eq(commands.calls, 0)

func test_hospital_reason_requires_matching_friend_day_and_durable_miss_receipt() -> void:
	var owner := Owner.new()
	owner.contacts.messages.priscilla = [_message("priscilla", 2)]
	owner.contacts.next_sequence = 2
	var port := PORT.new()
	assert_true(port.configure(owner, Commands.new(), CATALOG.build()).ok)
	var matching := _miss("priscilla", 2)
	for change: Dictionary in [{"friend_id": "lavinia"}, {"day": 1}, {"missed_reason": "ordinary"}, {"hospital_miss_receipt_id": ""}]:
		var wrong := matching.duplicate(true)
		wrong.merge(change, true)
		owner.missed_invitations = [wrong]
		assert_eq(port.get_projection("priscilla").value.entries.size(), 1)
	owner.missed_invitations = [matching, matching.duplicate(true)]
	assert_eq(port.get_projection("priscilla").value.entries.size(), 3, "receipt lookup does not duplicate presentation")

func test_unread_expiry_and_sylvia_never_gain_a_fabricated_hospital_explanation() -> void:
	for friend: String in ["priscilla", "sylvia"]:
		var owner := Owner.new()
		owner.contacts.messages[friend] = [_message(friend, 1, "nevermind")]
		owner.contacts.next_sequence = 2
		owner.missed_invitations = [_miss(friend, 1)]
		var port := PORT.new()
		assert_true(port.configure(owner, Commands.new(), CATALOG.build()).ok)
		assert_eq(port.get_projection(friend).value.entries.size(), 1)

func test_missing_hospital_translation_refuses_projection_without_mutating_contacts() -> void:
	var owner := Owner.new()
	owner.contacts.messages.priscilla = [_message("priscilla", 2)]
	owner.contacts.next_sequence = 2
	owner.missed_invitations = [_miss("priscilla", 2)]
	var catalog := CATALOG.build()
	catalog["missed_question:priscilla:day3"].hospital_followup.reaction.texts.erase("zh-CN")
	var before := owner.contacts.duplicate(true)
	var port := PORT.new()
	assert_true(port.configure(owner, Commands.new(), catalog).ok)
	assert_eq(port.get_projection("priscilla", "en", "zh-CN").code, &"contact_translation_unavailable")
	assert_eq(owner.contacts, before)
