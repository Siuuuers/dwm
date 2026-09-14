extends "res://addons/gut/test.gd"
# The Hospital presentation port (Plan 01 Task 8, dwm-p2r.14).
#
# WHAT THIS FILE OWNS. That a Hospital presentation cannot be forged at any of its three seams:
# ancestry (the resolution root and the P01.presentation.completion child), the command (its exact
# bytes and its canonical hash), and the physical completion (only the configured owner may bless
# it). Everything the port refuses here is something a scene, a caller, or a stale restore could
# otherwise have used to advance a stage that never physically happened.
#
# SUBSTRATE. A REAL DesktopIdentityNonceIssuer over a real root store on a GUID-isolated sandbox, a
# real DialogicBridge, and the real DialogicPresentationOwnerAdapter. Every completion child below
# was genuinely derived by the issuer, and every completion was genuinely produced by the runtime's
# end-of-timeline signal. No fake supplies a success.
#
# ANCESTRY NOTE (DEVIATION-4, recorded on dwm-p2r.14). `stage_id` is a producer-supplied string
# rather than an issuer-derived P01.day_resolution.stage child, because Plan 01 Tasks 6/7 never lit
# that row up on the production path. It is still fully projected into the completion child, so
# changing it still breaks the binding -- which is what the tests below assert.

const PORT := preload("res://scripts/application/run/HospitalPresentationPort.gd")
const RUNTIME_ADAPTER := preload("res://scripts/narrative/DialogicRuntimeAdapter.gd")
const OWNER := preload("res://scripts/application/narrative/DialogicPresentationOwnerAdapter.gd")
const ISSUER := preload("res://scripts/application/desktop/DesktopIdentityNonceIssuer.gd")
const ROOT_STORE := preload("res://scripts/infrastructure/identity/DesktopIssuerRootStore.gd")
const NAMESPACE_SOURCE := preload("res://scripts/infrastructure/identity/CryptoDesktopNamespaceSource.gd")
const STATE_SCHEMA := preload("res://scripts/domain/schedule/ScheduleStateSchema.gd")
const FAKE_DATING_OWNER := preload("res://tests/support/FakeDatingPresentationOwner.gd")

const TIMELINE_ID := "hospital.faint"
const STAGE_ID := "resolution.day3:hospital_if_triggered"
const SUBSTAGE_ID := "presentation.intent.hospital.day3"

var _saved_global_contacts: Dictionary = {}
var _owner_receipts: Array[Dictionary] = []
var _runtime: DialogicGameHandler
var _runtime_adapter: RefCounted
var _original_runtime: Node
var _original_runtime_index := 0
var _original_layout: Node
var _original_layout_parent: Node
var _original_layout_index := 0
var _settings: Dictionary = {}
var _persistent: Variant
var _had_persistent := false
var _style_directory: Dictionary = {}
var _native_starts := 0
var _native_ends := 0

var _root_counter := 0
var _issuer: RefCounted
var _bridge: Node
var _owner: RefCounted
var _port: RefCounted
var _root_receipt: Dictionary = {}
var _ready_results: Array = []
var _failures: Array = []
var _fixture_ready := false


func before_each() -> void:
	# Let any preceding shared-runtime cleanup settle before detaching its autoload.
	await get_tree().process_frame
	await get_tree().process_frame
	_fixture_ready = false
	_saved_global_contacts = {}
	_owner_receipts = []
	_runtime = null
	_runtime_adapter = null
	_original_runtime = null
	_original_runtime_index = 0
	_original_layout = null
	_original_layout_parent = null
	_original_layout_index = 0
	_settings = {}
	_persistent = null
	_had_persistent = false
	_style_directory = {}
	_native_starts = 0
	_native_ends = 0
	_issuer = null
	_bridge = null
	_owner = null
	_port = null
	_root_receipt = {}
	_ready_results = []
	_failures = []
	_root_counter += 1
	var created: Dictionary = TemporaryStorage.create("hospital-port-%d" % _root_counter)
	assert_true(created.get("ok", false), created.get("message", "temporary storage unavailable"))
	if not created.get("ok", false):
		return
	var root: String = str(created.get("value", ""))
	var store: RefCounted = ROOT_STORE.new()
	assert_true(store.configure(JsonFileStorage.new(root), NAMESPACE_SOURCE.new()).get("ok", false))
	assert_true(store.load_or_create().get("ok", false))
	_issuer = ISSUER.new()
	assert_true(_issuer.configure(store).get("ok", false))

	var issued: Dictionary = _issuer.issue(&"transaction_id")
	assert_true(issued.get("ok", false), str(issued))
	_root_receipt = ((issued["value"] as Dictionary)["issuer_receipt"] as Dictionary).duplicate(true)

	_native_starts = 0
	_native_ends = 0
	_had_persistent = Engine.has_meta("dialogic_persistent_style_info")
	_persistent = Engine.get_meta("dialogic_persistent_style_info", {})
	_style_directory = DialogicStylesUtil.style_directory.duplicate(true)
	_original_runtime = get_node("/root/Dialogic")
	_original_runtime_index = _original_runtime.get_index()
	_original_layout = _original_runtime.Styles.get_layout_node()
	if is_instance_valid(_original_layout) and _original_layout.is_inside_tree():
		_original_layout_parent = _original_layout.get_parent()
		_original_layout_index = _original_layout.get_index()
		_original_layout_parent.remove_child(_original_layout)
	get_tree().remove_meta("dialogic_layout_node")
	get_tree().root.remove_child(_original_runtime)
	_settings = {}
	for key: String in ["dialogic/save/autosave", "dialogic/layout/end_behaviour"]:
		_settings[key] = {
			"exists": ProjectSettings.has_setting(key),
			"value": ProjectSettings.get_setting(key),
		}
	ProjectSettings.set_setting("dialogic/save/autosave", false)
	ProjectSettings.set_setting("dialogic/layout/end_behaviour", 0)
	_runtime = DialogicGameHandler.new()
	_runtime.name = "Dialogic"
	get_tree().root.add_child(_runtime)
	_runtime.History.simple_history_enabled = true
	_runtime.History.save_visited_history_on_save = false
	_runtime.History.save_visited_history_on_autosave = false
	_runtime.timeline_started.connect(func() -> void: _native_starts += 1)
	_runtime.timeline_ended.connect(func() -> void: _native_ends += 1)
	_runtime_adapter = RUNTIME_ADAPTER.new()
	assert_true(_runtime_adapter.bind_runtime(_runtime).get("ok", false))
	_bridge = load("res://autoload/DialogicBridge.gd").new()
	_bridge.name = "TestDialogicBridge"
	add_child(_bridge)
	assert_true(_bridge.initialize(null, _runtime_adapter).get("ok", false))
	_saved_global_contacts = GameState.contacts.duplicate(true)
	# Physical playback fixture uses the real attendance projection, not an owner subclass.
	GameState.contacts.sylvia_hospital_witness_receipts = {"fixture": {
		"kind": "sylvia_hospital_witness", "resolution_kind": "condition_hospital",
		"care_followup_day": 4, "source_receipt_id": "entry.a", "hospital_miss_receipt_id": "miss.a"}}
	_owner = OWNER.new()
	assert_true(_owner.configure(_bridge).get("ok", false))
	_owner.physical_completion_ready.connect(func(receipt: Dictionary): _owner_receipts.append(receipt.duplicate(true)))

	_port = PORT.new()
	assert_true(_port.configure(_issuer, _owner).get("ok", false))
	_port.completion_ready.connect(func(result: Dictionary) -> void:
		_ready_results.append(result.duplicate(true)))
	_port.completion_failed.connect(func(failure: Dictionary) -> void:
		_failures.append(failure.duplicate(true)))
	_fixture_ready = true


func after_each() -> void:
	if not _fixture_ready:
		return
	GameState.contacts = _saved_global_contacts.duplicate(true)
	# Every admitted return-only presentation drains through its real native end
	# before its bridge, owner, layout, or runtime can be destroyed.
	if is_instance_valid(_bridge) and _bridge.has_active_playback():
		await _end_runtime_timeline()
	if is_instance_valid(_bridge):
		_bridge.free()
	for text_node: Node in get_tree().get_nodes_in_group("dialogic_dialog_text"):
		text_node.set_process(false)
	if is_instance_valid(_runtime):
		await _runtime.clear()
		var remaining: Node = _runtime.Styles.get_layout_node()
		if is_instance_valid(remaining):
			remaining.queue_free()
		await get_tree().process_frame
		_runtime.free()
	_owner = null
	_port = null
	_runtime_adapter = null
	get_tree().remove_meta("dialogic_layout_node")
	get_tree().root.add_child(_original_runtime)
	get_tree().root.move_child(_original_runtime, _original_runtime_index)
	if is_instance_valid(_original_layout):
		if is_instance_valid(_original_layout_parent):
			_original_layout_parent.add_child(_original_layout)
			_original_layout_parent.move_child(_original_layout, _original_layout_index)
		get_tree().set_meta("dialogic_layout_node", _original_layout)
	for key: String in _settings:
		ProjectSettings.set_setting(key,
			_settings[key].value if _settings[key].exists else null)
	if _had_persistent:
		Engine.set_meta("dialogic_persistent_style_info", _persistent)
	else:
		Engine.remove_meta("dialogic_persistent_style_info")
	DialogicStylesUtil.style_directory = _style_directory
	_original_layout_parent = null
	_fixture_ready = false


func _require_fixture() -> bool:
	if _fixture_ready:
		return true
	assert_true(false, "the Hospital presentation fixture is unavailable")
	return false


# -------------------------------------------------------------------------------------------------
# configure
# -------------------------------------------------------------------------------------------------

func test_configure_is_idempotent_and_refuses_a_replacement_dependency() -> void:
	if not _require_fixture():
		return
	var replayed: Dictionary = _port.configure(_issuer, _owner)
	assert_true(replayed.get("ok", false))
	assert_true(bool(replayed["value"]["already_configured"]))
	assert_eq(int(replayed["value"]["owner_instance_id"]), _owner.get_instance_id())

	var other: RefCounted = OWNER.new()
	assert_true(other.configure(_bridge).get("ok", false))
	var replaced: Dictionary = _port.configure(_issuer, other)
	assert_false(replaced.get("ok", true), "a configured port never adopts a replacement owner")
	assert_eq(replaced.get("code"), &"presentation_port_already_configured")


func test_an_unconfigured_port_routes_nothing_and_starts_no_physical_presentation() -> void:
	if not _require_fixture():
		return
	var fresh: RefCounted = PORT.new()
	var begun: Dictionary = fresh.begin(_request())
	assert_false(begun.get("ok", true))
	assert_eq(begun.get("code"), &"presentation_port_unconfigured")
	assert_false(fresh.is_ready())
	assert_true(_port.is_ready(), "the configured port reports ready")


func test_the_hospital_port_refuses_a_dating_challenge_owner() -> void:
	if not _require_fixture():
		return
	# A faint presented by the relationship board would be a category error, so the owner check is
	# on the exact adapter script and its declared kind, not on duck-typing.
	var fresh: RefCounted = PORT.new()
	var dating_owner: RefCounted = FAKE_DATING_OWNER.new()
	var configured: Dictionary = fresh.configure(_issuer, dating_owner)
	assert_false(configured.get("ok", true))
	assert_eq(configured.get("code"), &"invalid_physical_owner")


func test_an_incomplete_issuer_or_owner_is_refused() -> void:
	if not _require_fixture():
		return
	var fresh: RefCounted = PORT.new()
	assert_eq(fresh.configure(null, _owner).get("code"), &"invalid_identity_issuer")
	assert_eq(fresh.configure(RefCounted.new(), _owner).get("code"), &"invalid_identity_issuer")
	assert_eq(fresh.configure(_issuer, null).get("code"), &"invalid_physical_owner")


# -------------------------------------------------------------------------------------------------
# begin: shape, route, locator, context
# -------------------------------------------------------------------------------------------------

func test_a_valid_intent_returns_the_canonical_command_and_nothing_else() -> void:
	if not _require_fixture():
		return
	var request := _request()
	var begun: Dictionary = _port.begin(request)
	assert_true(begun.get("ok", false), str(begun))
	if not begun.get("ok", false): return
	assert_eq(begun.get("code"), &"ok")
	assert_eq(begun["receipt"], {}, "port success carries an empty receipt")
	var keys: Array = (begun["value"] as Dictionary).keys()
	assert_eq(keys, ["presentation_command"], "the value carries only the command")

	var command: Dictionary = begun["value"]["presentation_command"]
	var expected_keys: Array = PORT.REQUEST_KEYS.duplicate()
	expected_keys.append_array(["command_sha256", "physical_token"])
	expected_keys.sort()
	var command_keys: Array = command.keys()
	command_keys.sort()
	assert_eq(command_keys, expected_keys,
		"the canonical command is the exact request plus hash and token")
	assert_eq(str(command["command_sha256"]),
		str((STATE_SCHEMA.canonical_sha256(request)["value"] as Dictionary)["sha256"]),
		"command_sha256 is the canonical hash of the exact request bytes")
	assert_false(str(command["physical_token"]).strip_edges().is_empty())


func test_the_request_member_set_is_exact() -> void:
	if not _require_fixture():
		return
	var extra := _request()
	extra["ending_id"] = "ending.alone"
	assert_eq(_port.begin(extra).get("code"), &"invalid_presentation_intent",
		"no caller field rides along into a presentation")
	var missing := _request()
	missing.erase("context")
	assert_eq(_port.begin(missing).get("code"), &"invalid_presentation_intent")


func test_a_dating_route_is_refused_by_the_hospital_port() -> void:
	if not _require_fixture():
		return
	var request := _request()
	request["route_id"] = "dating"
	var begun: Dictionary = _port.begin(request)
	assert_false(begun.get("ok", true))
	assert_eq(begun.get("code"), &"presentation_route_mismatch")


func test_an_unregistered_locator_is_refused() -> void:
	if not _require_fixture():
		return
	var request := _request({"timeline_id": "not.a.registered.timeline"})
	var begun: Dictionary = _port.begin(request)
	assert_false(begun.get("ok", true))
	assert_eq(begun.get("code"), &"unregistered_presentation_timeline")


func test_the_hospital_context_member_set_and_kind_are_exact() -> void:
	if not _require_fixture():
		return
	for mutation: Dictionary in [
		{"kind": "solo"},
		{"kind": "hospital", "day": 0},
		{"kind": "hospital", "day": 8},
	]:
		var context := _context()
		context.merge(mutation, true)
		var begun: Dictionary = _port.begin(_request({"context": context}))
		assert_false(begun.get("ok", true), str(mutation))
		assert_eq(begun.get("code"), &"invalid_presentation_context", str(mutation))

	var extra := _context()
	extra["ending_id"] = "ending.alone"
	assert_eq(_port.begin(_request({"context": extra})).get("code"),
		&"invalid_presentation_context", "the context carries no outcome field")


func test_hospital_context_arrays_must_be_sorted_and_unique() -> void:
	if not _require_fixture():
		return
	# Hospital owns no semantic order for either array, so an unsorted or repeated member is a
	# different preimage wearing the same meaning -- and H(context) would silently differ.
	for bad: Array in [["b", "a"], ["a", "a"], ["a", ""], [1]]:
		var context := _context()
		context["source_entry_ids"] = bad
		var begun: Dictionary = _port.begin(_request({"context": context}))
		assert_false(begun.get("ok", true), str(bad))
		assert_eq(begun.get("code"), &"invalid_presentation_context", str(bad))


# -------------------------------------------------------------------------------------------------
# begin: ancestry
# -------------------------------------------------------------------------------------------------

func test_an_unverified_resolution_root_is_refused_before_any_physical_start() -> void:
	if not _require_fixture():
		return
	var request := _request()
	var forged: Dictionary = (request["resolution_issuer_receipt"] as Dictionary).duplicate(true)
	forged["receipt_id"] = "root.forged"
	request["resolution_issuer_receipt"] = forged
	var begun: Dictionary = _port.begin(request)
	assert_false(begun.get("ok", true))
	assert_true(begun.get("code") in [&"presentation_root_unverified",
		&"presentation_completion_unverified"], str(begun))


func test_a_locally_derived_completion_id_is_refused() -> void:
	if not _require_fixture():
		return
	var request := _request()
	request["completion_transaction_id"] = "completion.i.made.this.up"
	var begun: Dictionary = _port.begin(request)
	assert_false(begun.get("ok", true))
	assert_eq(begun.get("code"), &"presentation_completion_unverified")


func test_a_completion_child_of_the_wrong_kind_or_parent_is_refused() -> void:
	if not _require_fixture():
		return
	var wrong_kind := _completion_child(_context(), &"hospital_miss")
	var by_kind: Dictionary = _port.begin(_request({
		"completion_transaction_id": str(wrong_kind["child_id"]),
		"completion_transaction_provenance": wrong_kind["provenance"],
	}))
	assert_false(by_kind.get("ok", true))
	assert_eq(by_kind.get("code"), &"presentation_completion_unverified")

	var other_root: Dictionary = _issuer.issue(&"transaction_id")["value"]["issuer_receipt"]
	var foreign := _completion_child(_context(), PORT.COMPLETION_CHILD_KIND,
		str(other_root["receipt_id"]))
	var by_parent: Dictionary = _port.begin(_request({
		"completion_transaction_id": str(foreign["child_id"]),
		"completion_transaction_provenance": foreign["provenance"],
	}))
	assert_false(by_parent.get("ok", true))
	assert_eq(by_parent.get("code"), &"presentation_completion_unverified")


func test_every_projected_field_binds_the_completion_child() -> void:
	if not _require_fixture():
		return
	# The completion child is anchored to the EXACT bytes it was derived for. Change any projected
	# member and the honest child must stop matching.
	for mutation: Dictionary in [
		{"resolution_id": "resolution.other"},
		{"stage_id": "resolution.day3:some_other_stage"},
		{"substage_id": "presentation.intent.other"},
		{"timeline_id": "contact.lavinia.day1"},
	]:
		var begun: Dictionary = _port.begin(_request(mutation))
		assert_false(begun.get("ok", true), str(mutation))
		assert_eq(begun.get("code"), &"presentation_completion_unverified", str(mutation))


func test_a_changed_context_preimage_breaks_the_completion_binding() -> void:
	if not _require_fixture():
		return
	# H(context) is a projected member, so a context that presents different bytes cannot reuse a
	# completion child derived for the original ones.
	var drifted := _context()
	drifted["day"] = 4
	var begun: Dictionary = _port.begin(_request({"context": drifted}))
	assert_false(begun.get("ok", true))
	assert_eq(begun.get("code"), &"presentation_completion_unverified")


# -------------------------------------------------------------------------------------------------
# begin: command identity
# -------------------------------------------------------------------------------------------------

func test_a_byte_identical_replay_returns_the_identical_command_and_token() -> void:
	if not _require_fixture():
		return
	var request := _request()
	var first: Dictionary = _port.begin(request)
	assert_true(first.get("ok", false), str(first))
	if not first.get("ok", false): return
	var second: Dictionary = _port.begin(request.duplicate(true))
	assert_true(second.get("ok", false), str(second))
	if not second.get("ok", false): return
	assert_eq(second["value"]["presentation_command"], first["value"]["presentation_command"],
		"an unfinished restore reconstructs the SAME command and token")


func test_a_drifted_replay_cannot_overwrite_the_stored_command() -> void:
	if not _require_fixture():
		return
	# Every request member is either projected into the completion child or is ancestry, so drifted
	# bytes are refused by the BINDING before the command-identity guard is even reached. What
	# matters for a restore is what survives the refusal: the honest command, unchanged.
	var request := _request()
	var begun: Dictionary = _port.begin(request)
	assert_true(begun.get("ok", false), str(begun))
	if not begun.get("ok", false): return
	var honest: Dictionary = begun["value"]["presentation_command"]

	var drifted := request.duplicate(true)
	(drifted["context"] as Dictionary)["source_entry_ids"] = ["entry.z"]
	var refused: Dictionary = _port.begin(drifted)
	assert_false(refused.get("ok", true))
	assert_eq(refused.get("code"), &"presentation_completion_unverified",
		"drifted bytes break the completion binding first")

	var replayed: Dictionary = _port.begin(request)
	assert_true(replayed.get("ok", false), str(replayed))
	if not replayed.get("ok", false): return
	assert_eq(replayed["value"]["presentation_command"], honest,
		"the refused attempt left the stored command untouched")


func test_a_bypassed_binding_still_conflicts_on_command_identity() -> void:
	if not _require_fixture():
		return
	# Defence in depth for the same law: complete() compares the supplied command against the one
	# this port actually issued, so a command mutated AFTER begin() is a conflict, not a completion.
	var request := _request()
	var begun: Dictionary = _port.begin(request)
	assert_true(begun.get("ok", false), str(begun))
	if not begun.get("ok", false): return
	var command: Dictionary = begun["value"]["presentation_command"]
	var tampered: Dictionary = command.duplicate(true)
	tampered["command_sha256"] = "0".repeat(64)
	await _end_runtime_timeline()
	var result: Dictionary = _port.complete({
		"presentation_command": tampered,
		"physical_completion_receipt": _emitted_owner_receipt(request),
	})
	assert_false(result.get("ok", true))
	assert_eq(result.get("code"), &"presentation_command_conflict")


# -------------------------------------------------------------------------------------------------
# complete
# -------------------------------------------------------------------------------------------------

func test_a_trusted_owner_completion_produces_the_exact_frozen_receipt_once() -> void:
	if not _require_fixture():
		return
	var request := _request()
	var begun: Dictionary = _port.begin(request)
	assert_true(begun.get("ok", false), str(begun))
	if not begun.get("ok", false): return
	await _end_runtime_timeline()

	assert_eq(_ready_results.size(), 1, "exactly one completion is published")
	assert_true(_failures.is_empty(), str(_failures))
	if _ready_results.is_empty(): return
	var result: Dictionary = _ready_results[0]
	assert_true(result.get("ok", false))
	var receipt: Dictionary = result["receipt"]
	var keys: Array = receipt.keys()
	keys.sort()
	assert_eq(keys, PORT.COMPLETION_RECEIPT_KEYS, "the completion receipt member set is exact")
	assert_eq(str(receipt["receipt_id"]), str(request["completion_transaction_id"]),
		"receipt_id is exactly the completion transaction id")
	assert_eq(receipt["receipt_provenance"], request["completion_transaction_provenance"],
		"receipt_provenance is exactly the completion transaction provenance")
	assert_eq(str(receipt["route_id"]), "hospital")
	assert_eq(str(receipt["physical_owner_kind"]), "narrative")
	assert_eq(str(receipt["stage_id"]), STAGE_ID)
	assert_eq(str(receipt["substage_id"]), SUBSTAGE_ID)
	assert_eq(result["value"]["completion_receipt"], receipt,
		"value and receipt carry the same bytes")


func test_a_duplicate_owner_emission_returns_the_same_receipt_without_a_second_publication() -> void:
	if not _require_fixture():
		return
	var request := _request()
	assert_true(_port.begin(request).get("ok", false))
	await _end_runtime_timeline()
	assert_eq(_ready_results.size(), 1, "the real native end published its first completion")
	if _ready_results.is_empty(): return
	var first: Dictionary = (_ready_results[0] as Dictionary)["receipt"]

	# A restored owner replaying its settled record must not publish a second completion.
	_owner.physical_completion_ready.emit(_emitted_owner_receipt(request))
	assert_eq(_ready_results.size(), 1, "no second coordinator publication")
	var replayed: Dictionary = _port.begin(request)
	assert_true(replayed.get("ok", false), str(replayed))
	if not replayed.get("ok", false): return
	var settled: Dictionary = _port.complete({
		"presentation_command": replayed["value"]["presentation_command"],
		"physical_completion_receipt": _emitted_owner_receipt(request),
	})
	assert_true(settled.get("ok", false), str(settled))
	assert_eq(settled["receipt"], first, "the byte-identical receipt comes back")


func test_a_scene_authored_receipt_never_reaches_a_stage() -> void:
	if not _require_fixture():
		return
	var request := _request()
	var begun: Dictionary = _port.begin(request)
	assert_true(begun.get("ok", false), str(begun))
	if not begun.get("ok", false): return
	var command: Dictionary = begun["value"]["presentation_command"]
	var forged := {
		"owner_kind": "narrative",
		"physical_token": str(command["physical_token"]),
		"command_sha256": str(command["command_sha256"]),
		"completion_transaction_id": str(command["completion_transaction_id"]),
		"status": "completed",
		"result": {"outcome": "recovered"},
	}
	var result: Dictionary = _port.complete({
		"presentation_command": command,
		"physical_completion_receipt": forged,
	})
	assert_false(result.get("ok", true),
		"a perfectly shaped receipt for a timeline that never ended is untrusted")
	assert_eq(result.get("code"), &"physical_completion_untrusted")


func test_owner_receipt_drift_is_refused_before_any_stage_mutation() -> void:
	if not _require_fixture():
		return
	var request := _request()
	var begun: Dictionary = _port.begin(request)
	assert_true(begun.get("ok", false), str(begun))
	if not begun.get("ok", false): return
	var command: Dictionary = begun["value"]["presentation_command"]
	await _end_runtime_timeline()
	var honest := _emitted_owner_receipt(request)

	for field: String in ["owner_kind", "physical_token", "command_sha256",
			"completion_transaction_id", "status"]:
		var drifted: Dictionary = honest.duplicate(true)
		drifted[field] = "drifted"
		var result: Dictionary = _port.complete({
			"presentation_command": command,
			"physical_completion_receipt": drifted,
		})
		assert_false(result.get("ok", true), field)
		assert_eq(result.get("code"), &"physical_completion_untrusted", field)


func test_a_command_this_port_never_issued_is_refused() -> void:
	if not _require_fixture():
		return
	var request := _request()
	var command := request.duplicate(true)
	command["command_sha256"] = "a".repeat(64)
	command["physical_token"] = "narrative_presentation.forged"
	var result: Dictionary = _port.complete({
		"presentation_command": command,
		"physical_completion_receipt": {},
	})
	assert_false(result.get("ok", true))
	assert_eq(result.get("code"), &"physical_completion_untrusted")


func test_a_tampered_command_is_a_conflict_not_a_completion() -> void:
	if not _require_fixture():
		return
	var request := _request()
	var begun: Dictionary = _port.begin(request)
	assert_true(begun.get("ok", false), str(begun))
	if not begun.get("ok", false): return
	var command: Dictionary = begun["value"]["presentation_command"]
	await _end_runtime_timeline()
	var tampered: Dictionary = command.duplicate(true)
	tampered["timeline_id"] = "contact.ordinary.lavinia.day1"
	var result: Dictionary = _port.complete({
		"presentation_command": tampered,
		"physical_completion_receipt": _emitted_owner_receipt(request),
	})
	assert_false(result.get("ok", true))
	assert_eq(result.get("code"), &"presentation_command_conflict")


func test_the_complete_request_member_set_is_exact() -> void:
	if not _require_fixture():
		return
	assert_eq(_port.complete({"presentation_command": {}}).get("code"),
		&"invalid_presentation_completion")
	assert_eq(_port.complete({
		"presentation_command": {}, "physical_completion_receipt": {}, "extra": 1,
	}).get("code"), &"invalid_presentation_completion")


func test_an_owner_failure_publishes_exactly_one_failure_and_no_completion() -> void:
	if not _require_fixture():
		return
	assert_true(_port.begin(_request()).get("ok", false))
	_owner.physical_completion_failed.emit({"ok": false, "code": &"narrative_runtime_halted"})
	assert_eq(_failures.size(), 1)
	assert_true(_ready_results.is_empty(), "a failure never publishes a completion")


func test_an_emission_for_an_unknown_command_fails_rather_than_completing() -> void:
	if not _require_fixture():
		return
	assert_true(_port.begin(_request()).get("ok", false))
	_owner.physical_completion_ready.emit({
		"owner_kind": "narrative", "physical_token": "t", "command_sha256": "s",
		"completion_transaction_id": "completion.unknown", "status": "completed", "result": {},
	})
	assert_eq(_failures.size(), 1)
	assert_eq((_failures[0] as Dictionary).get("code"), &"physical_completion_untrusted")
	assert_true(_ready_results.is_empty())


# -------------------------------------------------------------------------------------------------
# helpers
# -------------------------------------------------------------------------------------------------

## Waits for the shipped return-only Hospital timeline to reach Dialogic's own natural end. The
## native signal count proves this completion came from the isolated runtime, not a bridge callback.
func _end_runtime_timeline() -> void:
	for attempt in 100:
		if _native_ends > 0:
			break
		await get_tree().create_timer(0.02).timeout
	assert_eq(_native_starts, 1, "the shipped Hospital timeline physically started exactly once")
	assert_eq(_native_ends, 1, "the shipped return-only Hospital timeline naturally ended exactly once")


## Returns detached bytes captured from the real configured owner's completion signal.
func _emitted_owner_receipt(request: Dictionary) -> Dictionary:
	for receipt: Dictionary in _owner_receipts:
		if str(receipt.completion_transaction_id) == str(request.completion_transaction_id):
			return receipt.duplicate(true)
	fail_test("the requested owner receipt has not actually been emitted")
	return {}


func _context() -> Dictionary:
	return {
		"kind": "hospital",
		"day": 3,
		"source_entry_ids": ["entry.a", "entry.b"],
		"miss_receipt_ids": ["miss.a"],
	}


## Builds a request whose completion child is GENUINELY derived for its own final bytes, so every
## honest case passes and every mutated one breaks the binding rather than a shape check.
func _request(overrides: Dictionary = {}) -> Dictionary:
	var request := {
		"resolution_id": "resolution.day3",
		"resolution_issuer_receipt": _root_receipt.duplicate(true),
		"stage_id": STAGE_ID,
		"substage_id": SUBSTAGE_ID,
		"route_id": "hospital",
		"timeline_id": TIMELINE_ID,
		"context": _context(),
		"completion_transaction_id": "",
		"completion_transaction_provenance": {},
	}
	var derives_child := not overrides.has("completion_transaction_provenance")
	for key: Variant in overrides:
		request[str(key)] = overrides[key]
	if derives_child:
		# Derived from the BASE bytes deliberately: a mutation test then supplies an honest child
		# that no longer projects the mutated request, which is exactly the drift being proved.
		var base := {
			"resolution_id": "resolution.day3", "stage_id": STAGE_ID, "substage_id": SUBSTAGE_ID,
			"route_id": "hospital", "timeline_id": TIMELINE_ID, "context": _context(),
		}
		var child := _completion_child(base["context"], PORT.COMPLETION_CHILD_KIND, "", base)
		request["completion_transaction_id"] = str(child["child_id"])
		request["completion_transaction_provenance"] = child["provenance"]
	return request


## Derives one real P01.presentation.completion child through the real issuer.
func _completion_child(context: Dictionary, child_kind: StringName, parent_receipt_id: String = "",
		projection: Dictionary = {}) -> Dictionary:
	var fields := {
		"resolution_id": "resolution.day3", "stage_id": STAGE_ID, "substage_id": SUBSTAGE_ID,
		"route_id": "hospital", "timeline_id": TIMELINE_ID,
	}
	for key: Variant in projection:
		if str(key) != "context":
			fields[str(key)] = projection[key]
	var context_sha256: String = str(
		(STATE_SCHEMA.canonical_sha256(context)["value"] as Dictionary)["sha256"])
	var tokens: Array = [
		_project("role", "presentation.completion"),
		_project("resolution_id", str(fields["resolution_id"])),
		_project("stage_id", str(fields["stage_id"])),
		_project("substage_id", str(fields["substage_id"])),
		_project("route_id", str(fields["route_id"])),
		_project("timeline_id", str(fields["timeline_id"])),
		_project("context_sha256", context_sha256),
	]
	tokens.sort()
	var parent := parent_receipt_id if parent_receipt_id != "" else str(_root_receipt["receipt_id"])
	var derived: Dictionary = _issuer.derive_child({
		"parent_receipt_id": parent,
		"child_kind": child_kind,
		"ordinal": 0,
		"source_ids": tokens,
	})
	assert_true(derived.get("ok", false), str(derived))
	return {
		"child_id": str((derived["value"] as Dictionary)["child_id"]),
		"provenance": ((derived["value"] as Dictionary)["provenance"] as Dictionary).duplicate(true),
	}


func _project(path: String, value: Variant) -> String:
	return path + "=" + str(
		(STATE_SCHEMA.canonical_json(value)["value"] as Dictionary)["text"])
