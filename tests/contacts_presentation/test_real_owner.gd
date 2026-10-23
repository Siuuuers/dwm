extends SceneTree

const GAME_STATE := preload("res://autoload/GameState.gd")
const BOOTSTRAP := preload("res://autoload/ApplicationBootstrap.gd")
const CONTACT := preload("res://scripts/domain/contact/ContactInvitationState.gd")
const COMMAND := preload("res://scripts/application/contact/ContactCommandPort.gd")
const PRESENTATION := preload("res://scripts/application/contact/ContactsPresentationPort.gd")
const ISSUER := preload("res://scripts/application/desktop/DesktopIdentityNonceIssuer.gd")
const ROOT := preload("res://tests/support/FakeDesktopIssuerRootStore.gd")
const HOST := preload("res://scripts/domain/desktop/DesktopAppHostState.gd")

class DesktopReceiver:
	extends Node
	var port: Object
	var host: Object
	var configured_day := 0
	var evictions := 0
	var reject_projection := false
	func configure_contacts(presentation: Object, _locale: Object, _profile: Object,
			host_owner: Object, day: int) -> Dictionary:
		port = presentation
		host = host_owner
		configured_day = day
		if reject_projection:
			return {"ok": false, "code": &"test_restored_projection_unavailable"}
		return {"ok": true}
	func dispatch_desktop_eviction(_command: Dictionary) -> Dictionary:
		evictions += 1
		return {"ok": true}

class FatalSpy:
	extends RefCounted
	var failures: Array = []
	func latch_fatal(failure: Dictionary) -> void:
		failures.append(failure)
	func guard_external(_operation: StringName) -> Dictionary:
		return {"ok": failures.is_empty()}

var failures := 0
var mutation_signals := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var state: Node = GAME_STATE.new()
	state.name = "GameState"
	root.add_child(state)
	state.reset_game()
	var issuer := ISSUER.new()
	_check(issuer.configure(ROOT.new("22".repeat(32), 1))["ok"], "issuer")
	var command := COMMAND.new()
	_check(command.configure(state, issuer)["ok"], "real owner injection")
	state.contacts = CONTACT.prepare_offer_solo(state.contacts, "priscilla", 1, "test.real.p", "test.offer.p")["value"]["candidate"]
	state.save_relevant_state_changed.connect(func() -> void: mutation_signals += 1)
	state.contact_open_committed.connect(func(_result: Dictionary) -> void: mutation_signals += 1)
	var before: Dictionary = state.contacts.duplicate(true)
	var command_proof: Dictionary = issuer.issue(&"transaction_id")["value"]
	var preview: Dictionary = state.preview_open_contact("priscilla", command_proof["token"], command_proof["issuer_receipt"])
	_check(preview.get("ok", false), "real preview uses registry and issuer")
	_check(state.contacts == before and mutation_signals == 0, "real preview changes no owner state or signals")
	_check(preview["value"]["candidate"]["solo_actions"]["solo:priscilla:day1"]["state"] == "ACCEPTED", "preview prepares actual acceptance")
	preview["value"]["candidate"]["messages"]["priscilla"].clear()
	_check(state.contacts == before, "preview detached")
	var view: Dictionary = state.get_contact_view("priscilla")
	view["messages"][0]["message_id"] = "caller overwrite"
	_check(state.contacts == before, "GameState view detached")
	var denied: Dictionary = state.preview_open_contact("priscilla", "unissued", {})
	_check(not denied.get("ok", false) and state.contacts == before, "preview authenticates")
	var empty := PRESENTATION.new()
	_check(empty.configure(state, command)["ok"], "empty real owner presentation")
	_check(not empty.open_friend("priscilla")["ok"] and state.contacts == before, "missing copy prevents real mutation")
	var full := PRESENTATION.new()
	_check(full.configure(state, command, {"test.real.p": {"outgoing": false, "texts": {"en": "TEST ONLY real owner"}}})["ok"], "fixture presentation")
	_check(full.open_friend("priscilla")["ok"], "guarded real owner open")
	_check(mutation_signals == 2, "one actual commit publishes expected owner signals")
	_check(CONTACT.validate_state(state.contacts)["ok"], "real committed state validates")
	_check(full.open_friend("priscilla")["ok"] and mutation_signals == 2, "history revisit creates no repeat acceptance")
	_bootstrap_check(state, command)
	state.free()
	if failures == 0:
		print("CONTACTS_REAL_OWNER_PASS")
	quit(0 if failures == 0 else 1)

func _bootstrap_check(state: Node, command: RefCounted) -> void:
	var bootstrap: Node = BOOTSTRAP.new()
	# Real manual startup does no persistence work. Mark only the isolated fixture's retained
	# dependencies ready; full application startup is deliberately outside this seam test.
	_check(bootstrap.start(BOOTSTRAP.MODE_TEST_MANUAL)["ok"], "real manual bootstrap avoids user I/O")
	root.add_child(bootstrap)
	var receiver := DesktopReceiver.new()
	root.add_child(receiver)
	_check(not bootstrap.configure_contacts_desktop(receiver)["ok"], "bootstrap rejects absent owners")
	var host := HOST.new()
	host.reset(state.day)
	bootstrap.set("_contact_command_port", command)
	bootstrap.set("_desktop_host_state", host)
	var startup: Dictionary = bootstrap.get("_state")
	startup["ready"] = true
	_check(bootstrap.configure_contacts_desktop(receiver)["ok"], "real bootstrap configures presentation seam")
	_check(receiver.host == host and receiver.configured_day == state.day, "same retained host and actual day")
	var retained: Object = receiver.port
	_check(bootstrap.configure_contacts_desktop(receiver)["ok"] and receiver.port == retained, "bootstrap reuses one presentation port")
	_check(not receiver.port.get_projection("priscilla")["ok"], "bootstrap production catalog stays honestly empty")
	var eviction_port: Object = bootstrap.get("_desktop_eviction_port")
	var eviction_id := eviction_port.get_instance_id()
	var fatal_spy := FatalSpy.new()
	bootstrap.set("_application_gate", fatal_spy)
	host.open_app(&"contacts", state.day)
	receiver.free()
	# Routes destroy the old desktop while Dating/Hospital owns the scene. The day owner then
	# publishes the next day; eviction must clear the cache without calling the freed view.
	bootstrap.call("_on_day_changed", 2)
	_check(fatal_spy.failures.is_empty(), "no fatal when routed desktop is already destroyed")
	_check(host.get_state()["current_day"] == 2 and host.get_state()["cached_app_ids"].is_empty(), "day change clears cache without a view")
	state.get("_run_lifecycle").set("_day", 2)
	var replacement := DesktopReceiver.new()
	root.add_child(replacement)
	_check(bootstrap.configure_contacts_desktop(replacement)["ok"], "new desktop binds after old view is freed")
	_check((bootstrap.get("_desktop_eviction_port") as Object).get_instance_id() == eviction_id, "one retained eviction adapter across views")
	host.open_app(&"contacts", 2)
	bootstrap.call("_on_day_changed", 3)
	_check(replacement.evictions == 1 and fatal_spy.failures.is_empty(), "live replacement receives exactly one eviction")
	state.get("_run_lifecycle").set("_day", 3)
	host.open_app(&"contacts", 3)
	var unavailable := DesktopReceiver.new()
	unavailable.reject_projection = true
	root.add_child(unavailable)
	var host_before: Dictionary = host.get_state().duplicate(true)
	var contacts_before: Dictionary = state.contacts.duplicate(true)
	var signals_before := mutation_signals
	var failed_mount: Dictionary = bootstrap.configure_contacts_desktop(unavailable)
	_check(failed_mount.get("code") == &"test_restored_projection_unavailable", "restored projection failure remains visible")
	_check(unavailable.port == retained and unavailable.host == host, "failed view still receives retained dependencies")
	_check(host.get_state() == host_before and state.contacts == contacts_before \
		and mutation_signals == signals_before, "failed view configuration does not mutate app or correspondence state")
	bootstrap.call("_on_day_changed", 4)
	_check(unavailable.evictions == 1 and replacement.evictions == 1,
		"owner day change evicts failed current view once, not previous live view")
	_check(host.get_state()["current_day"] == 4 and host.get_state()["cached_app_ids"].is_empty(),
		"failed view eviction clears host cache for next day")
	_check(fatal_spy.failures.is_empty() and state.contacts == contacts_before \
		and mutation_signals == signals_before, "failed-view eviction has no other owner mutations or fatal")
	unavailable.free()
	replacement.free()
	bootstrap.free()

func _check(condition: bool, label: String) -> void:
	if not condition:
		failures += 1
		printerr("FAIL: " + label)
