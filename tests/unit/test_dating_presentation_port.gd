extends "res://addons/gut/test.gd"
# The Dating presentation port (Plan 01 Task 8, dwm-p2r.14).
#
# THE HEADLINE LAW. This port is DELIBERATELY production-unconfigured. Phase 2R composes no
# relationship-board or challenge owner, so an unconfigured port must fail closed with
# `dating_physical_owner_unconfigured` BEFORE it routes anything or starts anything physical. That
# refusal is the `dwm-oyo.4` handoff stated honestly; a port that quietly did something instead
# would be claiming a playable Dating board that does not exist.
#
# WHY THE REST IS PROVED ANYWAY. The surface dwm-oyo.4 must satisfy is frozen here. Configuring the
# port with `FakeDatingPresentationOwner` exercises the ancestry, command, and completion laws NOW,
# so the real owner plugs into a contract that has already been tested rather than one that rotted.
# The fake is never a bootstrap dependency -- only this suite and the scenario suites configure it.
#
# SUBSTRATE. A REAL DesktopIdentityNonceIssuer over a real root store on a GUID-isolated sandbox.
# Every completion child below was genuinely derived by that issuer.

const PORT := preload("res://scripts/application/run/DatingPresentationPort.gd")
const FAKE_OWNER := preload("res://tests/support/FakeDatingPresentationOwner.gd")
const NARRATIVE_OWNER := preload("res://scripts/application/narrative/DialogicPresentationOwnerAdapter.gd")
const ISSUER := preload("res://scripts/application/desktop/DesktopIdentityNonceIssuer.gd")
const ROOT_STORE := preload("res://scripts/infrastructure/identity/DesktopIssuerRootStore.gd")
const NAMESPACE_SOURCE := preload("res://scripts/infrastructure/identity/CryptoDesktopNamespaceSource.gd")
const STATE_SCHEMA := preload("res://scripts/domain/schedule/ScheduleStateSchema.gd")

const TIMELINE_ID := "dating.solo.sylvia.day3.pre_challenge"
const PAIR_TIMELINE_ID := "dating.twofriends.priscilla_lavinia.day2.pre_challenge"
const STAGE_ID := "resolution.day3:execute_schedule_dates"
const SUBSTAGE_ID := "presentation.intent.date.day3"

var _root_counter := 0
var _issuer: RefCounted
var _owner: RefCounted
var _port: RefCounted
var _root_receipt: Dictionary = {}
var _ready_results: Array = []
var _failures: Array = []


func before_each() -> void:
	_ready_results = []
	_failures = []
	_root_counter += 1
	var result: Dictionary = TemporaryStorage.create("dating-port-%d" % _root_counter)
	assert_true(result.ok, result.get("message", ""))
	if not result.ok:
		return
	var root: String = result.value
	var store: RefCounted = ROOT_STORE.new()
	assert_true(store.configure(JsonFileStorage.new(root), NAMESPACE_SOURCE.new()).get("ok", false))
	assert_true(store.load_or_create().get("ok", false))
	_issuer = ISSUER.new()
	assert_true(_issuer.configure(store).get("ok", false))
	var issued: Dictionary = _issuer.issue(&"transaction_id")
	assert_true(issued.get("ok", false), str(issued))
	_root_receipt = ((issued["value"] as Dictionary)["issuer_receipt"] as Dictionary).duplicate(true)

	_owner = FAKE_OWNER.new()
	_port = PORT.new()
	assert_true(_port.configure(_issuer, _owner).get("ok", false))
	_port.completion_ready.connect(func(result: Dictionary) -> void:
		_ready_results.append(result.duplicate(true)))
	_port.completion_failed.connect(func(failure: Dictionary) -> void:
		_failures.append(failure.duplicate(true)))


# -------------------------------------------------------------------------------------------------
# the deliberate Phase-2R handoff
# -------------------------------------------------------------------------------------------------

func test_an_unconfigured_dating_port_fails_closed_before_routing_or_physical_start() -> void:
	# This is the exact state ApplicationBootstrap leaves the production port in.
	var production: RefCounted = PORT.new()
	assert_false(production.is_ready(),
		"Phase 2R exposes the Dating route as NOT ready, rather than pretending")

	var begun: Dictionary = production.begin(_request())
	assert_false(begun.get("ok", true))
	assert_eq(begun.get("code"), &"dating_physical_owner_unconfigured", str(begun))

	var completed: Dictionary = production.complete({
		"presentation_command": {}, "physical_completion_receipt": {},
	})
	assert_false(completed.get("ok", true))
	assert_eq(completed.get("code"), &"dating_physical_owner_unconfigured")


func test_the_dating_port_refuses_the_narrative_owner() -> void:
	# A date presented by the faint adapter would be a category error. The kinds are disjoint.
	var bridge: Node = load("res://autoload/DialogicBridge.gd").new()
	add_child_autofree(bridge)
	var narrative: RefCounted = NARRATIVE_OWNER.new()
	assert_true(narrative.configure(bridge).get("ok", false))
	var fresh: RefCounted = PORT.new()
	var configured: Dictionary = fresh.configure(_issuer, narrative)
	assert_false(configured.get("ok", true))
	assert_eq(configured.get("code"), &"invalid_physical_owner")


func test_configure_is_idempotent_and_refuses_a_replacement_dependency() -> void:
	var replayed: Dictionary = _port.configure(_issuer, _owner)
	assert_true(replayed.get("ok", false))
	assert_true(bool(replayed["value"]["already_configured"]))
	var replaced: Dictionary = _port.configure(_issuer, FAKE_OWNER.new())
	assert_false(replaced.get("ok", true))
	assert_eq(replaced.get("code"), &"presentation_port_already_configured")


# -------------------------------------------------------------------------------------------------
# begin: shape, route, locator, context
# -------------------------------------------------------------------------------------------------

func test_a_valid_solo_intent_returns_the_canonical_command() -> void:
	var request := _request()
	var begun: Dictionary = _port.begin(request)
	assert_true(begun.get("ok", false), str(begun))
	assert_eq(begun["receipt"], {})
	var command: Dictionary = begun["value"]["presentation_command"]
	assert_eq(str(command["command_sha256"]),
		str((STATE_SCHEMA.canonical_sha256(request)["value"] as Dictionary)["sha256"]))
	assert_eq(str(command["physical_token"]), FAKE_OWNER.derive_token(
		str(request["completion_transaction_id"]), str(command["command_sha256"])))
	assert_eq((_owner.started_commands as Array).size(), 1, "the challenge started exactly once")


func test_a_hospital_route_is_refused_by_the_dating_port() -> void:
	var request := _request()
	request["route_id"] = "hospital"
	assert_eq(_port.begin(request).get("code"), &"presentation_route_mismatch")


func test_an_unregistered_locator_is_refused() -> void:
	assert_eq(_port.begin(_request({"timeline_id": "not.registered"})).get("code"),
		&"unregistered_presentation_timeline")


func test_the_three_dating_context_kinds_are_accepted_and_others_are_not() -> void:
	for kind: String in ["solo", "group", "twofriends_if_deferred"]:
		assert_true(PORT.CONTEXT_KINDS.has(kind), kind + " is an accepted dating kind")
	var context := _context()
	context["kind"] = "hospital"
	assert_eq(_port.begin(_request({"context": context})).get("code"),
		&"invalid_presentation_context")


func test_the_dating_context_member_set_is_exact() -> void:
	var extra := _context()
	extra["ending_id"] = "ending.sylvia"
	assert_eq(_port.begin(_request({"context": extra})).get("code"),
		&"invalid_presentation_context", "the context carries no ending or outcome field")
	var missing := _context()
	missing.erase("participants")
	assert_eq(_port.begin(_request({"context": missing})).get("code"),
		&"invalid_presentation_context")


func test_a_solo_names_exactly_one_participant() -> void:
	for participants: Array in [[], ["sylvia", "lavinia"]]:
		var context := _context()
		context["participants"] = participants
		assert_eq(_port.begin(_request({"context": context})).get("code"),
			&"invalid_presentation_context", str(participants))


func test_the_pair_order_is_priscilla_then_lavinia_and_is_never_sorted() -> void:
	# The P-L order is owned by the pair's own invitation law, so alphabetical order is WRONG here.
	var reversed := _pair_context()
	reversed["participants"] = ["lavinia", "priscilla"]
	var begun: Dictionary = _port.begin(_request({
		"context": reversed, "timeline_id": PAIR_TIMELINE_ID,
	}))
	assert_false(begun.get("ok", true), "alphabetical order is not the semantic pair order")
	assert_eq(begun.get("code"), &"invalid_presentation_context")


func test_a_deferred_pair_intent_is_accepted_in_the_canonical_order() -> void:
	var request := _pair_request()
	var begun: Dictionary = _port.begin(request)
	assert_true(begun.get("ok", false), str(begun))
	assert_eq(((begun["value"]["presentation_command"] as Dictionary)["context"]
		as Dictionary)["participants"], ["priscilla", "lavinia"])


# -------------------------------------------------------------------------------------------------
# begin: ancestry
# -------------------------------------------------------------------------------------------------

func test_a_locally_derived_completion_id_is_refused() -> void:
	var request := _request()
	request["completion_transaction_id"] = "completion.invented"
	assert_eq(_port.begin(request).get("code"), &"presentation_completion_unverified")


func test_every_projected_field_binds_the_completion_child() -> void:
	for mutation: Dictionary in [
		{"resolution_id": "resolution.other"},
		{"stage_id": "resolution.day3:other_stage"},
		{"substage_id": "presentation.intent.other"},
		{"timeline_id": "dating.solo.sylvia.day4.pre_challenge"},
	]:
		var begun: Dictionary = _port.begin(_request(mutation))
		assert_false(begun.get("ok", true), str(mutation))
		assert_eq(begun.get("code"), &"presentation_completion_unverified", str(mutation))


func test_a_changed_participant_list_breaks_the_completion_binding() -> void:
	# Participants are part of H(context), so a date with a different friend cannot reuse a
	# completion child anchored to the original one.
	var drifted := _context()
	drifted["participants"] = ["lavinia"]
	var begun: Dictionary = _port.begin(_request({"context": drifted}))
	assert_false(begun.get("ok", true))
	assert_eq(begun.get("code"), &"presentation_completion_unverified")


func test_an_unverified_resolution_root_is_refused() -> void:
	var request := _request()
	var forged: Dictionary = (request["resolution_issuer_receipt"] as Dictionary).duplicate(true)
	forged["receipt_id"] = "root.forged"
	request["resolution_issuer_receipt"] = forged
	var begun: Dictionary = _port.begin(request)
	assert_false(begun.get("ok", true))
	assert_true(begun.get("code") in [&"presentation_root_unverified",
		&"presentation_completion_unverified"], str(begun))


# -------------------------------------------------------------------------------------------------
# complete
# -------------------------------------------------------------------------------------------------

func test_a_trusted_challenge_completion_produces_the_exact_frozen_receipt_once() -> void:
	var request := _request()
	assert_true(_port.begin(request).get("ok", false))
	_owner.finish(str(request["completion_transaction_id"]), {"challenge": "cleared"})

	assert_eq(_ready_results.size(), 1)
	var receipt: Dictionary = (_ready_results[0] as Dictionary)["receipt"]
	var keys: Array = receipt.keys()
	keys.sort()
	assert_eq(keys, PORT.COMPLETION_RECEIPT_KEYS)
	assert_eq(str(receipt["receipt_id"]), str(request["completion_transaction_id"]))
	assert_eq(str(receipt["route_id"]), "dating")
	assert_eq(str(receipt["physical_owner_kind"]), "dating_challenge")
	assert_eq(receipt["receipt_provenance"], request["completion_transaction_provenance"])


func test_a_deferred_pair_completes_through_the_port_carrying_its_own_pair_bytes() -> void:
	# THE PORT IS THE CEILING HERE, deliberately. Phase 2R routes the deferred pair to `dating`, and
	# the Dating route is fail-closed until dwm-oyo.4 configures a real owner, so no routed scene can
	# reach this path and no end-to-end claim is available to make. A round trip through the port
	# against `FakeDatingPresentationOwner` is the strongest honest proof there is.
	#
	# WHY IT IS NOT REDUNDANT. Every other `complete()` test in this suite runs `_request()`, whose
	# context kind is `solo`. The pair reached only `begin()`, so its completion child, its command
	# bytes and its locator were never carried through settlement.
	var request := _pair_request()
	var begun: Dictionary = _port.begin(request)
	assert_true(begun.get("ok", false), str(begun))
	var command: Dictionary = begun["value"]["presentation_command"]
	assert_eq(command["context"], _pair_context(),
		"the deferred-pair context reaches the owner unaltered and unsorted")

	_owner.finish(str(request["completion_transaction_id"]), {"challenge": "cleared"})

	assert_true(_failures.is_empty(), str(_failures))
	assert_eq(_ready_results.size(), 1, "the pair settles exactly once")
	var receipt: Dictionary = (_ready_results[0] as Dictionary)["receipt"]
	var keys: Array = receipt.keys()
	keys.sort()
	assert_eq(keys, PORT.COMPLETION_RECEIPT_KEYS)
	assert_eq(str(receipt["receipt_id"]), str(request["completion_transaction_id"]))
	assert_eq(receipt["receipt_provenance"], request["completion_transaction_provenance"])
	assert_eq(str(receipt["route_id"]), "dating")
	assert_eq(str(receipt["physical_owner_kind"]), "dating_challenge")
	assert_eq(str(receipt["timeline_id"]), PAIR_TIMELINE_ID,
		"the settled receipt names the pair locator, never the solo one")
	assert_eq(str(receipt["command_sha256"]),
		str((STATE_SCHEMA.canonical_sha256(request)["value"] as Dictionary)["sha256"]),
		"the receipt is bound to the pair request's own canonical bytes")
	assert_eq(str(receipt["physical_token"]), FAKE_OWNER.derive_token(
		str(request["completion_transaction_id"]), str(receipt["command_sha256"])))
	assert_eq((receipt["physical_completion_receipt"] as Dictionary)["result"],
		{"challenge": "cleared"}, "the port reports the owner's own physical result and no more")


func test_a_restored_owner_reemission_returns_the_same_receipt_without_a_second_publication() -> void:
	var request := _request()
	assert_true(_port.begin(request).get("ok", false))
	_owner.finish(str(request["completion_transaction_id"]), {"challenge": "cleared"})
	var first: Dictionary = (_ready_results[0] as Dictionary)["receipt"]

	_owner.reemit(str(request["completion_transaction_id"]))
	assert_eq(_ready_results.size(), 1, "an identical restored emission publishes nothing new")
	assert_true(_failures.is_empty(), str(_failures))
	assert_eq((_ready_results[0] as Dictionary)["receipt"], first)


func test_a_scene_authored_challenge_result_never_reaches_a_stage() -> void:
	var request := _request()
	var command: Dictionary = _port.begin(request)["value"]["presentation_command"]
	var forged := {
		"owner_kind": "dating_challenge",
		"physical_token": str(command["physical_token"]),
		"command_sha256": str(command["command_sha256"]),
		"completion_transaction_id": str(command["completion_transaction_id"]),
		"status": "completed",
		"result": {"outcome": "attended", "affection_delta": 99},
	}
	var result: Dictionary = _port.complete({
		"presentation_command": command,
		"physical_completion_receipt": forged,
	})
	assert_false(result.get("ok", true), "a challenge that never ended cannot be reported as one")
	assert_eq(result.get("code"), &"physical_completion_untrusted")


func test_owner_receipt_drift_is_refused() -> void:
	var request := _request()
	var command: Dictionary = _port.begin(request)["value"]["presentation_command"]
	_owner.finish(str(request["completion_transaction_id"]), {"challenge": "cleared"})
	var honest: Dictionary = ((_ready_results[0] as Dictionary)["receipt"]
		as Dictionary)["physical_completion_receipt"]

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


func test_an_owner_failure_publishes_exactly_one_failure_and_no_completion() -> void:
	assert_true(_port.begin(_request()).get("ok", false))
	_owner.fail({"ok": false, "code": &"challenge_abandoned"})
	assert_eq(_failures.size(), 1)
	assert_true(_ready_results.is_empty())


# -------------------------------------------------------------------------------------------------
# helpers
# -------------------------------------------------------------------------------------------------

func _context() -> Dictionary:
	return {
		"kind": "solo",
		"day": 3,
		"schedule_entry_id": "entry.sylvia.day3",
		"participants": ["sylvia"],
	}


func _pair_context() -> Dictionary:
	return {
		"kind": "twofriends_if_deferred",
		"day": 2,
		"schedule_entry_id": "entry.pair.day2",
		"participants": ["priscilla", "lavinia"],
	}


func _request(overrides: Dictionary = {}) -> Dictionary:
	return _build_request(_context(), TIMELINE_ID, overrides)


func _pair_request() -> Dictionary:
	return _build_request(_pair_context(), PAIR_TIMELINE_ID, {})


## Builds a request whose completion child is derived for the BASE bytes, so an honest case passes
## and every mutated one breaks the binding rather than a shape check.
func _build_request(base_context: Dictionary, timeline_id: String,
		overrides: Dictionary) -> Dictionary:
	var request := {
		"resolution_id": "resolution.day3",
		"resolution_issuer_receipt": _root_receipt.duplicate(true),
		"stage_id": STAGE_ID,
		"substage_id": SUBSTAGE_ID,
		"route_id": "dating",
		"timeline_id": timeline_id,
		"context": base_context.duplicate(true),
		"completion_transaction_id": "",
		"completion_transaction_provenance": {},
	}
	var child := _completion_child(base_context, timeline_id)
	request["completion_transaction_id"] = str(child["child_id"])
	request["completion_transaction_provenance"] = child["provenance"]
	for key: Variant in overrides:
		request[str(key)] = overrides[key]
	return request


func _completion_child(context: Dictionary, timeline_id: String) -> Dictionary:
	var context_sha256: String = str(
		(STATE_SCHEMA.canonical_sha256(context)["value"] as Dictionary)["sha256"])
	var tokens: Array = [
		_project("role", "presentation.completion"),
		_project("resolution_id", "resolution.day3"),
		_project("stage_id", STAGE_ID),
		_project("substage_id", SUBSTAGE_ID),
		_project("route_id", "dating"),
		_project("timeline_id", timeline_id),
		_project("context_sha256", context_sha256),
	]
	tokens.sort()
	var derived: Dictionary = _issuer.derive_child({
		"parent_receipt_id": str(_root_receipt["receipt_id"]),
		"child_kind": PORT.COMPLETION_CHILD_KIND,
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
