extends SceneTree

const STATE := preload("res://scripts/domain/contact/ContactInvitationState.gd")
const COMMAND := preload("res://scripts/application/contact/ContactCommandPort.gd")
const PRESENTATION := preload("res://scripts/application/contact/ContactsPresentationPort.gd")
const ISSUER := preload("res://scripts/application/desktop/DesktopIdentityNonceIssuer.gd")
const ROOT := preload("res://tests/support/FakeDesktopIssuerRootStore.gd")

class Owner:
	extends RefCounted
	var contacts: Dictionary = STATE.make_defaults()
	var day := 2
	var issuer: Object
	var commits := 0
	func configure_identity_issuer(value: Object) -> Dictionary:
		issuer = value
		return {"ok": true, "value": {"issuer_instance_id": issuer.get_instance_id()}}
	func get_contact_view(friend: String) -> Dictionary:
		return STATE.get_contact_view(contacts, friend, day).duplicate(true)
	func preview_open_contact(friend: String, id: String, receipt: Dictionary) -> Dictionary:
		return STATE.prepare_open_contact(contacts, friend, day, id, receipt, issuer, _record(friend))
	func open_contact(friend: String, id: String, receipt: Dictionary) -> Dictionary:
		var result := preview_open_contact(friend, id, receipt)
		if result.get("ok", false):
			contacts = result["value"]["candidate"]
			commits += 1
		return result
	func reply_invitation(friend: String, id: String, receipt: Dictionary) -> Dictionary:
		var result: Dictionary = STATE.prepare_reply(contacts, friend, day, id, receipt, issuer, _record(friend))
		if result.get("ok", false):
			contacts = result["value"]["candidate"]
			commits += 1
		return result
	func _record(friend: String) -> Dictionary:
		var group: bool = contacts["group_action"]["state"] in STATE.GROUP_OPEN_STATES
		return {"action_id": "group:priscilla_lavinia:day2" if group else "solo:%s:day2" % friend,
			"action_kind": "group" if group else "solo", "allowed_days": [2], "effect_ids": [],
			"motivation_cost": 1, "participants": ["priscilla", "lavinia"] if group else [friend],
			"repeatable": false, "route_id": "dating",
			"source_receipt_kind": "group_reply_acceptance" if group else "solo_read_acceptance"}

var failures := 0

func _initialize() -> void:
	var owner := Owner.new()
	var command := COMMAND.new()
	var issuer := ISSUER.new()
	_check(issuer.configure(ROOT.new("11".repeat(32), 1))["ok"], "issuer config")
	_check(command.configure(owner, issuer)["ok"], "command config")
	var empty := PRESENTATION.new()
	_check(empty.configure(owner, command)["ok"], "empty catalog config")
	_check(empty.get_projection("")["value"]["entries"].is_empty(), "blank app")
	_check(empty.open_friend("priscilla")["ok"] and owner.commits == 0, "empty navigation is not acceptance")
	owner.contacts = STATE.prepare_offer_solo(owner.contacts, "priscilla", 2, "test.p", "offer.p")["value"]["candidate"]
	var before := owner.contacts.duplicate(true)
	_check(not empty.open_friend("priscilla")["ok"], "missing prose fails")
	_check(owner.contacts == before and owner.commits == 0, "missing prose preserves owner")
	var copy := {"test.p": {"outgoing": false, "texts": {"en": "[b]TEST ONLY[/b]", "zh-CN": "測試文字"}}}
	var presentation := PRESENTATION.new()
	_check(presentation.configure(owner, command, copy)["ok"], "test copy config")
	copy["test.p"]["texts"]["en"] = "caller mutation"
	var projected: Dictionary = presentation.get_projection("priscilla", "en", "zh_CN")
	_check(projected["value"]["entries"][0]["texts"]["en"] == "[b]TEST ONLY[/b]", "catalog ownership and literal text")
	_check(not presentation.open_friend("priscilla", "zh_HK")["ok"] and owner.commits == 0, "missing locale precedes acceptance")
	_check(presentation.open_friend("priscilla")["ok"], "real pure solo acceptance")
	_check(owner.contacts["solo_actions"]["solo:priscilla:day2"]["state"] == "ACCEPTED", "solo accepted")
	_check(not presentation.get_projection("priscilla")["value"]["unread"]["priscilla"], "canonical read watermark")
	_check(presentation.open_friend("priscilla")["ok"] and owner.commits == 1, "accepted history reopens without second acceptance")
	_group_checks(owner, command)
	if failures == 0:
		print("CONTACTS_PRESENTATION_PASS")
	quit(0 if failures == 0 else 1)

func _group_checks(owner: Owner, command: RefCounted) -> void:
	owner.contacts = STATE.make_defaults()
	for friend: String in STATE.GROUP_PAIR:
		owner.contacts = STATE.prepare_offer_solo(owner.contacts, friend, 2, "solo." + friend, "offer." + friend)["value"]["candidate"]
	owner.contacts = STATE.prepare_activate_group_after_round(owner.contacts, 2, 2, 3, "activate.group")["value"]["candidate"]
	owner.commits = 0
	var first_id := "group_offer:priscilla_lavinia:day2:priscilla"
	var second_id := "group_offer:priscilla_lavinia:day2:lavinia"
	var only_first := {first_id: {"outgoing": false, "texts": {"en": "TEST first"}}}
	var partial := PRESENTATION.new()
	_check(partial.configure(owner, command, only_first)["ok"], "partial catalog config")
	var projection: Dictionary = partial.get_projection("")["value"]
	_check(projection["unread"]["priscilla"] and projection["unread"]["lavinia"], "latent linked unread")
	_check(projection["entries"].is_empty(), "latent linked availability has no body")
	var before := owner.contacts.duplicate(true)
	_check(not partial.open_friend("priscilla")["ok"], "missing second materialized copy rejects group open")
	_check(owner.contacts == before and owner.commits == 0, "group preview does not mutate")
	var complete := only_first.duplicate(true)
	complete[second_id] = {"outgoing": false, "texts": {"en": "TEST second"}}
	var full := PRESENTATION.new()
	_check(full.configure(owner, command, complete)["ok"], "complete test group copy")
	var opened: Dictionary = full.open_friend("priscilla")
	_check(opened["ok"] and opened["value"]["reply_required"], "first linked open requires reply")
	_check(opened["value"]["unread"]["lavinia"], "second linked thread stays unread")
	_check(full.reply_to_group("priscilla")["ok"], "real linked reply")
	_check(owner.contacts["group_action"]["state"] == "ACCEPTED", "shared action accepted")
	_check(full.open_friend("lavinia")["ok"], "second linked open after acceptance")
	_check(not full.reply_to_group("lavinia")["ok"], "no invented second acceptance")
	_check(STATE.validate_state(owner.contacts)["ok"], "owner bag receipt invariants still validate")
	var stale_guard := func(_preview: Dictionary) -> Dictionary:
		owner.day = 3
		return {"ok": true}
	_check(command.request_open_contact("lavinia", stale_guard).get("code") == &"contact_preview_stale", "stale preview rejected")

func _check(condition: bool, label: String) -> void:
	if not condition:
		failures += 1
		printerr("FAIL: " + label)
