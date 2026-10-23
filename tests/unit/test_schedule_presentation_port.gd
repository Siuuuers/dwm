extends "res://addons/gut/test.gd"

const PORT := preload("res://scripts/application/schedule/SchedulePresentationPort.gd")
const CONTROLLER := preload("res://scripts/application/schedule/ScheduleViewController.gd")
const RULES := preload("res://scripts/domain/schedule/ScheduleRules.gd")
const REGISTRY := preload("res://scripts/domain/schedule/ScheduleActionRegistry.gd")
const CONTACTS := preload("res://scripts/domain/contact/ContactInvitationState.gd")
const ISSUER := preload("res://scripts/application/desktop/DesktopIdentityNonceIssuer.gd")
const ROOT := preload("res://tests/support/FakeDesktopIssuerRootStore.gd")

class ContactsOwner extends RefCounted:
	var contacts: Dictionary
	var day: int

class CountingIssuer extends RefCounted:
	var inner: Object
	var issues := 0
	func issue(purpose: StringName) -> Dictionary:
		issues += 1
		return inner.issue(purpose)

class TechnicalFailureController extends RefCounted:
	var inner: Object
	func snapshot() -> Dictionary:
		return inner.snapshot()
	func fingerprint() -> Dictionary:
		return inner.fingerprint()
	func prepare_add(_action_id: String, _source: Variant, _slot: int,
			_probe_id: String) -> Dictionary:
		return {"ok": false, "code": &"registry_transport_failed", "details": {}}
	func apply_docket_edit(command: Dictionary, expected: String) -> Dictionary:
		return inner.apply_docket_edit(command, expected)

var _registry: Object
var _fingerprint := ""
var _controller: Object
var _owner: ContactsOwner
var _issuer: CountingIssuer
var _port: Object


func before_each() -> void:
	var loaded: Dictionary = REGISTRY.load_current()
	assert_true(loaded.get("ok", false), str(loaded))
	_registry = loaded["value"]["registry"]
	_fingerprint = loaded["value"]["registry_fingerprint"]
	_controller = CONTROLLER.new()
	assert_true(_controller.configure(_registry, RULES, _fingerprint)["ok"])
	assert_true(_controller.open_day(1, "presentation-day")["ok"])
	_owner = ContactsOwner.new()
	_owner.contacts = CONTACTS.make_defaults()
	_owner.day = 1
	var real_issuer := ISSUER.new()
	assert_true(real_issuer.configure(ROOT.new("44".repeat(32), 12))["ok"])
	_issuer = CountingIssuer.new()
	_issuer.inner = real_issuer
	_port = PORT.new()
	assert_true(_port.configure(_owner, _controller, _registry, _fingerprint,
		_issuer, _names())["ok"])


func test_project_returns_allowlisted_display_dtos_without_issuing_identity() -> void:
	var result: Dictionary = _port.project("en")
	assert_true(result.get("ok", false), str(result))
	assert_eq(_issuer.issues, 0)
	assert_eq(_sorted_keys(result["value"]), ["day_seven", "entries", "fingerprint", "sources"])
	assert_false(result["value"]["day_seven"])
	assert_eq(result["value"]["entries"], [])
	var sources: Array = result["value"]["sources"]
	assert_eq([sources[0]["id"], sources[1]["id"], sources[2]["id"]],
		["training", "working", "rest"])
	assert_eq(sources[2]["name"], "Rest approved")
	assert_true(sources[2]["compact"] is Texture2D)
	assert_true(sources[2]["folio"] is Texture2D)
	assert_eq(_sorted_keys(sources[2]), ["available", "compact", "folio", "id", "name"])


func test_append_issues_once_then_repeatable_entry_projection_keeps_private_facts_out() -> void:
	var initial: Dictionary = _port.project("en")
	var appended: Dictionary = _port.append("rest", initial["value"]["fingerprint"], "en")
	assert_true(appended.get("ok", false), str(appended))
	assert_eq(_issuer.issues, 1)
	var entry: Dictionary = appended["value"]["entries"][0]
	assert_eq(entry["source_id"], "rest")
	assert_eq(entry["name"], "Rest approved")
	assert_true(entry["folio"] is Texture2D)
	assert_eq(_sorted_keys(entry), ["folio", "id", "name", "source_id"])
	var second: Dictionary = _port.append("rest", appended["value"]["fingerprint"], "zh-CN")
	assert_true(second.get("ok", false), str(second))
	assert_eq(_issuer.issues, 2)
	assert_eq(second["value"]["entries"].size(), 2)
	assert_ne(second["value"]["entries"][0]["id"], second["value"]["entries"][1]["id"])


func test_move_remove_return_fresh_projection_and_stale_or_unknown_append_do_not_issue() -> void:
	var first: Dictionary = _port.append("rest", _port.project("en")["value"]["fingerprint"], "en")
	var second: Dictionary = _port.append("training", first["value"]["fingerprint"], "en")
	var moved: Dictionary = _port.move(second["value"]["entries"][1]["id"], 0,
		second["value"]["fingerprint"], "en")
	assert_true(moved.get("ok", false), str(moved))
	assert_eq(moved["value"]["entries"][0]["source_id"], "training")
	var removed: Dictionary = _port.remove(moved["value"]["entries"][0]["id"],
		moved["value"]["fingerprint"], "en")
	assert_true(removed.get("ok", false), str(removed))
	assert_eq(removed["value"]["entries"].size(), 1)
	var issued_before := _issuer.issues
	assert_eq(str(_port.append("rest", "stale", "en")["code"]), "stale_view_fingerprint")
	assert_eq(str(_port.append("unknown", removed["value"]["fingerprint"], "en")["code"]),
		"schedule_source_unavailable")
	assert_eq(_issuer.issues, issued_before)


func test_wrong_owner_day_and_sparse_view_refuse_public_projection() -> void:
	_owner.day = 2
	assert_eq(str(_port.project("en")["code"]), "schedule_owner_day_mismatch")
	_owner.day = 1
	var prepared: Dictionary = _controller.prepare_add("rest", null, 4, "sparse")
	assert_true(_controller.commit(prepared["value"]["candidate"])["ok"])
	assert_eq(str(_port.project("en")["code"]), "sparse_schedule_view")

func test_full_docket_publishes_unavailable_without_issuing_then_removal_reopens_sources() -> void:
	var current: Dictionary = _port.project("en")
	for index in 7:
		current = _port.append("rest",current.value.fingerprint,"en")
		assert_true(current.ok,str(current))
	for source: Dictionary in current.value.sources: assert_false(source.available)
	var issued := _issuer.issues
	var refused: Dictionary = _port.append("rest",current.value.fingerprint,"en")
	assert_false(refused.ok)
	assert_eq(_issuer.issues,issued)
	var reopened: Dictionary = _port.remove(current.value.entries[0].id,current.value.fingerprint,"en")
	assert_true(reopened.ok)
	for source: Dictionary in reopened.value.sources: assert_true(source.available)


func test_prepare_add_technical_failure_is_propagated_instead_of_marked_unavailable() -> void:
	var failing := TechnicalFailureController.new()
	failing.inner = _controller
	var port := PORT.new()
	assert_true(port.configure(_owner, failing, _registry, _fingerprint,
		_issuer, _names())["ok"])
	var result: Dictionary = port.project("en")
	assert_false(result.get("ok", true))
	assert_eq(str(result.get("code", "")), "registry_transport_failed")


func test_existing_date_with_forged_missing_receipt_aborts_projection() -> void:
	var prepared: Dictionary = _controller.prepare_add(
		"solo:priscilla:day1", "forged-missing-receipt", 0, "forged-date")
	assert_true(prepared.get("ok", false), str(prepared))
	assert_true(_controller.commit(prepared["value"]["candidate"])["ok"])
	var result: Dictionary = _port.project("en")
	assert_false(result.get("ok", true))
	assert_eq(str(result.get("code", "")), "schedule_source_receipt_absent")


func test_day_seven_same_choice_returns_unchanged_without_unused_identity() -> void:
	var day7_owner := ContactsOwner.new()
	day7_owner.day = 7
	var action_id := "solo:priscilla:day7"
	var offered: Dictionary = CONTACTS.prepare_offer_solo(CONTACTS.make_defaults(),
		"priscilla", 7, "message-day7", "offer-day7")
	var command: Dictionary = _issuer.inner.issue(&"transaction_id")
	var record: Dictionary = _registry.find_record(action_id)["value"]["record"]
	var accepted: Dictionary = CONTACTS.prepare_open_contact(offered["value"]["candidate"],
		"priscilla", 7, command["value"]["token"], command["value"]["issuer_receipt"],
		_issuer.inner, record)
	day7_owner.contacts = accepted["value"]["candidate"]
	var day7_controller := CONTROLLER.new()
	assert_true(day7_controller.configure(_registry, RULES, _fingerprint)["ok"])
	assert_true(day7_controller.open_day(7, "presentation-day7")["ok"])
	var day7_port := PORT.new()
	assert_true(day7_port.configure(day7_owner, day7_controller, _registry, _fingerprint,
		_issuer, _names())["ok"])
	var initial: Dictionary = day7_port.project("en")
	var chosen: Dictionary = day7_port.append(action_id, initial["value"]["fingerprint"], "en")
	assert_true(chosen.get("ok", false), str(chosen))
	var issue_count := _issuer.issues
	var repeated: Dictionary = day7_port.append(action_id,
		chosen["value"]["fingerprint"], "en")
	assert_true(repeated.get("ok", false), str(repeated))
	assert_eq(repeated["value"], chosen["value"])
	assert_eq(_issuer.issues, issue_count)


func _names() -> Dictionary:
	var snapshot: Dictionary = _registry.snapshot(_fingerprint)
	var result: Dictionary = {}
	for action_id: String in snapshot["value"]["records"]:
		result[action_id] = {
			"en": "Rest approved" if action_id == "rest" else "Approved source",
			"zh-CN": "已批准来源", "zh-HK": "已批准來源",
		}
	return result


func _sorted_keys(value: Dictionary) -> Array:
	var keys: Array = value.keys()
	keys.sort()
	return keys
