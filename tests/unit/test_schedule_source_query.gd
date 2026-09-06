extends "res://addons/gut/test.gd"

const QUERY := preload("res://scripts/application/schedule/ScheduleSourceQuery.gd")
const CONTACTS := preload("res://scripts/domain/contact/ContactInvitationState.gd")
const REGISTRY := preload("res://scripts/domain/schedule/ScheduleActionRegistry.gd")
const ISSUER := preload("res://scripts/application/desktop/DesktopIdentityNonceIssuer.gd")
const ROOT := preload("res://tests/support/FakeDesktopIssuerRootStore.gd")

var _registry: Object
var _fingerprint := ""
var _issuer: RefCounted


func before_each() -> void:
	var loaded: Dictionary = REGISTRY.load_current()
	assert_true(loaded.get("ok", false), str(loaded))
	_registry = loaded["value"]["registry"]
	_fingerprint = loaded["value"]["registry_fingerprint"]
	_issuer = ISSUER.new()
	assert_true(_issuer.configure(ROOT.new("33".repeat(32), 9))["ok"])


func test_days_one_to_six_put_fixed_ordinary_sources_before_generation_order() -> void:
	var state := CONTACTS.make_defaults()
	state = _offer(state, "sylvia", 1)
	state = _offer(state, "priscilla", 1)
	# Accept in the reverse of generation order.
	state = _accept_solo(state, "priscilla", 1)
	state = _accept_solo(state, "sylvia", 1)
	var result: Dictionary = QUERY.project(state, 1, _registry, _fingerprint)
	assert_true(result.get("ok", false), str(result))
	var sources: Array = result["value"]["sources"]
	assert_eq(_ids(sources), ["training", "working", "rest",
		"solo:sylvia:day1", "solo:priscilla:day1"])
	for source: Dictionary in sources:
		assert_eq(_sorted_keys(source), ["action_id", "source_receipt_id"])


func test_unread_unaccepted_expired_and_group_superseded_sources_are_absent() -> void:
	var unread := _offer(CONTACTS.make_defaults(), "priscilla", 1)
	assert_eq(_ids(_sources(unread, 1)), ["training", "working", "rest"])

	var expired := _accept_solo(unread, "priscilla", 1)
	expired = CONTACTS.prepare_resolve_day_end(expired, 1,
		{"solo_attended_action_ids": []}, "resolve-day1")["value"]["candidate"]
	assert_eq(_ids(_sources(expired, 1)), ["training", "working", "rest"])

	var group := CONTACTS.make_defaults()
	group = _offer(group, "priscilla", 2)
	group = _offer(group, "lavinia", 2)
	group = CONTACTS.prepare_activate_group_after_round(
		group, 2, 2, 3, "activate-group-day2")["value"]["candidate"]
	assert_eq(_ids(_sources(group, 2)), ["training", "working", "rest"],
		"superseded solos and an unaccepted group are absent")


func test_day_seven_uses_fixed_participant_order() -> void:
	var state := CONTACTS.make_defaults()
	state = _offer(state, "sylvia", 7)
	state = _offer(state, "lavinia", 7)
	state = _offer(state, "priscilla", 7)
	state = _accept_solo(state, "sylvia", 7)
	state = _accept_solo(state, "priscilla", 7)
	state = _accept_solo(state, "lavinia", 7)
	assert_eq(_ids(_sources(state, 7)), [
		"solo:priscilla:day7", "solo:lavinia:day7", "solo:sylvia:day7"])


func test_accepted_group_uses_generated_messages_when_activation_has_no_sequences() -> void:
	var state := CONTACTS.make_defaults()
	state = _offer(state, "priscilla", 2)
	state = _offer(state, "lavinia", 2)
	state = CONTACTS.prepare_activate_group_after_round(
		state, 2, 2, 3, "activate-group-day2")["value"]["candidate"]
	state = _open_group(state, "priscilla", 2)
	state = _open_group(state, "lavinia", 2)
	state = _reply_group(state, "lavinia", 2)
	assert_eq(_ids(_sources(state, 2)), ["training", "working", "rest",
		"group:priscilla_lavinia:day2"])


func test_stale_registry_and_malformed_contacts_refuse_without_projection() -> void:
	var state := CONTACTS.make_defaults()
	var stale: Dictionary = QUERY.project(state, 1, _registry, "stale")
	assert_false(stale.get("ok", true))
	assert_eq(str(stale.get("code", "")), "stale_registry_fingerprint")
	var malformed := state.duplicate(true)
	malformed.erase("read_watermarks")
	var result: Dictionary = QUERY.project(malformed, 1, _registry, _fingerprint)
	assert_false(result.get("ok", true))
	assert_eq(str(result.get("code", "")), "invalid_state")


func _offer(state: Dictionary, friend_id: String, day: int) -> Dictionary:
	var action_id := "solo:%s:day%d" % [friend_id, day]
	var result: Dictionary = CONTACTS.prepare_offer_solo(
		state, friend_id, day, "message:%s" % action_id, "offer:%s" % action_id)
	assert_true(result.get("ok", false), str(result))
	return result["value"]["candidate"]


func _accept_solo(state: Dictionary, friend_id: String, day: int) -> Dictionary:
	var action_id := "solo:%s:day%d" % [friend_id, day]
	var issued: Dictionary = _issuer.issue(&"transaction_id")
	var found: Dictionary = _registry.find_record(action_id)
	var result: Dictionary = CONTACTS.prepare_open_contact(state, friend_id, day,
		issued["value"]["token"], issued["value"]["issuer_receipt"], _issuer,
		found["value"]["record"])
	assert_true(result.get("ok", false), str(result))
	return result["value"]["candidate"]


func _open_group(state: Dictionary, friend_id: String, day: int) -> Dictionary:
	var action_id := "group:priscilla_lavinia:day%d" % day
	var issued: Dictionary = _issuer.issue(&"transaction_id")
	var found: Dictionary = _registry.find_record(action_id)
	var result: Dictionary = CONTACTS.prepare_open_contact(state, friend_id, day,
		issued["value"]["token"], issued["value"]["issuer_receipt"], _issuer,
		found["value"]["record"])
	assert_true(result.get("ok", false), str(result))
	return result["value"]["candidate"]


func _reply_group(state: Dictionary, friend_id: String, day: int) -> Dictionary:
	var action_id := "group:priscilla_lavinia:day%d" % day
	var issued: Dictionary = _issuer.issue(&"transaction_id")
	var found: Dictionary = _registry.find_record(action_id)
	var result: Dictionary = CONTACTS.prepare_reply(state, friend_id, day,
		issued["value"]["token"], issued["value"]["issuer_receipt"], _issuer,
		found["value"]["record"])
	assert_true(result.get("ok", false), str(result))
	return result["value"]["candidate"]


func _sources(state: Dictionary, day: int) -> Array:
	var result: Dictionary = QUERY.project(state, day, _registry, _fingerprint)
	assert_true(result.get("ok", false), str(result))
	return result.get("value", {}).get("sources", [])


func _ids(sources: Array) -> Array:
	var result: Array = []
	for source: Dictionary in sources:
		result.append(source["action_id"])
	return result


func _sorted_keys(value: Dictionary) -> Array:
	var keys: Array = value.keys()
	keys.sort()
	return keys
