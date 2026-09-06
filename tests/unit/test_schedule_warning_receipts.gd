extends "res://addons/gut/test.gd"
# Issuer-anchored Schedule warning activation, failed-attempt, and consumed receipts
# (Amendment Plan 03 Task 3 Steps 5-6, dwm-oyo.3; child-identity rows
# P03.warning.activation/dismissal/navigation, plan lines 107-109).
#
# Every identity below is minted by the REAL DesktopIdentityNonceIssuer over a sandboxed
# root store; nothing invents a parallel ID. pending_warning is null or the exact nine-key
# activation record; attempt_receipts maps terminal transaction IDs to the exact eleven-key
# navigation_failed receipt; consumed_warning_receipts maps fingerprint|kind to the exact
# ten-key terminal receipt. The immutable warning_fingerprint_preimage is exactly
# {view_projection, context}; canonical hashing of the STORED preimage equals
# warning_state_fingerprint, and no copy is ever reconstructed from later live owners.
#
# RED VALIDITY (plan Global Constraints line 40): the compiling controller warning surface
# exists; every failure below is a typed wrong-behavior result.

const CONTROLLER := preload("res://scripts/application/schedule/ScheduleViewController.gd")
const RULES := preload("res://scripts/domain/schedule/ScheduleRules.gd")
const REGISTRY := preload("res://scripts/domain/schedule/ScheduleActionRegistry.gd")
const POLICY := preload("res://scripts/domain/schedule/ScheduleWarningPolicy.gd")
const ISSUER := preload("res://scripts/application/desktop/DesktopIdentityNonceIssuer.gd")
const ROOT_STORE := preload("res://scripts/infrastructure/identity/DesktopIssuerRootStore.gd")
const NAMESPACE_SOURCE := preload("res://scripts/infrastructure/identity/CryptoDesktopNamespaceSource.gd")

const CAUSAL_DAY := "causal_day_instance.1111111111111111111111111111111111111111111111111111111111111111"
const PENDING_KEYS: Array = [
	"activation_id", "activation_id_provenance", "attempt_receipts",
	"opened_by_transaction_id", "opened_by_transaction_issuer_receipt", "state",
	"warning_fingerprint_preimage", "warning_kind", "warning_state_fingerprint",
]
const CONSUMED_KEYS: Array = [
	"activation_id", "activation_id_provenance", "receipt_id", "receipt_provenance",
	"terminal_result", "transaction_id", "transaction_issuer_receipt",
	"warning_fingerprint_preimage", "warning_kind", "warning_state_fingerprint",
]
const ATTEMPT_KEYS: Array = [
	"activation_id", "activation_id_provenance", "failure_code", "receipt_id",
	"receipt_provenance", "terminal_result", "transaction_id",
	"transaction_issuer_receipt", "warning_fingerprint_preimage", "warning_kind",
	"warning_state_fingerprint",
]

var _registry: Object = null
var _fingerprint := ""
var _issuer: RefCounted = null
var _root_counter := 0


func before_each() -> void:
	var loaded: Dictionary = REGISTRY.load_current()
	assert_true(loaded.get("ok", false), str(loaded))
	_registry = (loaded.get("value", {}) as Dictionary).get("registry")
	_fingerprint = str((loaded.get("value", {}) as Dictionary).get("registry_fingerprint", ""))
	_issuer = _sandbox_issuer()


func _sandbox_issuer() -> RefCounted:
	var wrapper := OS.get_environment("DWM_TEST_ROOT")
	assert_false(wrapper.strip_edges().is_empty(), "DWM_TEST_ROOT is required")
	_root_counter += 1
	var root := wrapper.path_join("warning-receipts-%d-%d" % [_root_counter, randi()])
	assert_eq(DirAccess.make_dir_recursive_absolute(root), OK)
	var store: RefCounted = ROOT_STORE.new()
	assert_true(store.configure(JsonFileStorage.new(root), NAMESPACE_SOURCE.new())
		.get("ok", false), "root store configured")
	assert_true(store.load_or_create().get("ok", false), "root store initialized")
	var issuer: RefCounted = ISSUER.new()
	assert_true(issuer.configure(store).get("ok", false), "issuer configured")
	return issuer


# ---- helpers ----

func _code(result: Dictionary) -> String:
	return str(result.get("code", ""))


func _keys_of(value: Dictionary) -> Array:
	var keys: Array = value.keys()
	keys.sort()
	return keys


func _canonical(value: Variant) -> String:
	var emitted: Dictionary = CanonicalJsonWriter.stringify(value)
	assert_true(emitted.get("ok", false), str(emitted))
	return str(emitted.get("value", ""))


func _sha256(text: String) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(text.to_utf8_buffer())
	return context.finish().hex_encode()


func _p(name: String, value: Variant) -> String:
	return name + "=" + _canonical(value)


func _refused(result: Dictionary, code: String, context: String) -> void:
	assert_false(result.get("ok", true), context + " must refuse: " + str(result))
	assert_eq(_code(result), code, context + " typed code")


func _require_dict(value: Variant, context: String) -> bool:
	if typeof(value) == TYPE_DICTIONARY:
		return true
	assert_true(false, context + " must be a Dictionary: " + str(value))
	return false


func _txn() -> Dictionary:
	var issued: Dictionary = _issuer.issue(&"transaction_id")
	assert_true(issued.get("ok", false), str(issued))
	var value: Dictionary = issued.get("value", {})
	return {"id": str(value.get("token", "")),
		"receipt": (value.get("issuer_receipt", {}) as Dictionary).duplicate(true)}


func _context(overrides: Dictionary = {}) -> Dictionary:
	var context := {
		"run_id": "run-fixture",
		"branch_id": "branch-fixture",
		"desktop_timeline_generation": 0,
		"causal_day_instance": CAUSAL_DAY,
		"eligible_unread_date_message_ids": ["msg-1"],
		"accepted_unscheduled_date_ids": [],
		"board_identity": null,
		"board_phase": "NONE",
		"base_round_ordinal": 1,
		"base_opportunity_remaining": false,
		"unfinished_base_board": false,
		"motivation": 1,
	}
	for key: String in overrides:
		context[key] = overrides[key]
	return context


func _warning_controller() -> Object:
	var controller: Object = CONTROLLER.new()
	var configured: Dictionary = controller.configure(_registry, RULES, _fingerprint)
	assert_true(configured.get("ok", false), "configure: " + str(configured))
	var opened: Dictionary = controller.open_day(3, CAUSAL_DAY)
	assert_true(opened.get("ok", false), "open_day: " + str(opened))
	var prepared: Dictionary = controller.prepare_add("rest", null, 0, "d-rest")
	assert_true(prepared.get("ok", false), "prepare_add: " + str(prepared))
	if prepared.get("ok", false):
		var committed: Dictionary = controller.commit(
			(prepared.get("value", {}) as Dictionary).get("candidate", {}))
		assert_true(committed.get("ok", false), "commit: " + str(committed))
	var identity: Dictionary = controller.configure_warning_identity(_issuer)
	assert_true(identity.get("ok", false), "configure_warning_identity: " + str(identity))
	return controller


func test_docket_commands_cannot_change_an_active_warning_or_its_view() -> void:
	var controller := _warning_controller()
	var activation := _activate(controller, _context())
	assert_false((activation["pending"] as Dictionary).is_empty())
	var before := _canonical(_view_of(controller))
	var fingerprint_result: Dictionary = controller.fingerprint()
	var fingerprint: String = fingerprint_result["value"]["fingerprint"]
	for command: Dictionary in [
		{"kind": "append", "action_id": "training", "source_receipt_id": null,
			"draft_entry_id": "blocked-id"},
		{"kind": "move", "draft_entry_id": "d-rest", "target_index": 0},
		{"kind": "remove", "draft_entry_id": "d-rest"},
	]:
		var result: Dictionary = controller.apply_docket_edit(command, fingerprint)
		_refused(result, "warning_modal_active", str(command["kind"]))
		assert_eq(_canonical(_view_of(controller)), before,
			"warning activation and editable state remain byte-equal")


func _view_of(controller: Object) -> Dictionary:
	var snap: Dictionary = controller.snapshot()
	assert_true(snap.get("ok", false), "snapshot: " + str(snap))
	return ((snap.get("value", {}) as Dictionary).get("view", {}) as Dictionary)


func _pending_of(controller: Object) -> Variant:
	return _view_of(controller).get("pending_warning", "MISSING")


func _activate(controller: Object, context: Dictionary) -> Dictionary:
	var txn := _txn()
	var result: Dictionary = controller.request_warning_activation(txn["id"],
		txn["receipt"], context)
	assert_true(result.get("ok", false), "request_warning_activation: " + str(result))
	var pending: Variant = (result.get("value", {}) as Dictionary).get("warning")
	return {"txn": txn, "pending": pending if typeof(pending) == TYPE_DICTIONARY else {}}


func _expected_preimage(controller: Object, context: Dictionary) -> Dictionary:
	var view := _view_of(controller)
	return {
		"view_projection": {
			"day": view.get("day", -1),
			"causal_day_instance": view.get("causal_day_instance", ""),
			"entries": (view.get("entries", []) as Array).duplicate(true),
			"date_entry_seen": view.get("date_entry_seen", false),
		},
		"context": context.duplicate(true),
	}


# ---- configure_warning_identity ----

func test_configure_warning_identity_is_one_time_and_typed() -> void:
	var controller: Object = CONTROLLER.new()
	assert_true(controller.configure(_registry, RULES, _fingerprint).get("ok", false))
	_refused(controller.configure_warning_identity(null),
		"invalid_warning_identity_issuer", "a null issuer")
	_refused(controller.configure_warning_identity(RefCounted.new()),
		"invalid_warning_identity_issuer", "an object without the issuer capabilities")
	var first: Dictionary = controller.configure_warning_identity(_issuer)
	assert_true(first.get("ok", false), str(first))
	assert_eq((first.get("value", {}) as Dictionary).get("already_configured", true),
		false, "the first configuration is fresh")
	var replay: Dictionary = controller.configure_warning_identity(_issuer)
	assert_true(replay.get("ok", false), "an identical replay is idempotent: " + str(replay))
	assert_eq((replay.get("value", {}) as Dictionary).get("already_configured", false),
		true, "the replay reports already_configured")
	_refused(controller.configure_warning_identity(_sandbox_issuer()),
		"warning_identity_already_configured", "a replacement issuer")


func test_activation_fails_closed_without_the_warning_identity() -> void:
	var controller: Object = CONTROLLER.new()
	assert_true(controller.configure(_registry, RULES, _fingerprint).get("ok", false))
	assert_true(controller.open_day(3, CAUSAL_DAY).get("ok", false))
	var txn := _txn()
	_refused(controller.request_warning_activation(txn["id"], txn["receipt"], _context()),
		"warning_identity_unconfigured", "activation before configure_warning_identity")


# ---- activation ----

func test_activation_creates_the_exact_pending_record() -> void:
	var controller := _warning_controller()
	var context := _context()
	var activated := _activate(controller, context)
	var pending: Dictionary = activated["pending"]
	assert_eq(_keys_of(pending), PENDING_KEYS, "the exact nine-key pending record")
	assert_eq(str(pending.get("state", "")), "pending", "state is pending")
	assert_eq(str(pending.get("warning_kind", "")), "unread_invitation",
		"the first eligible kind")
	assert_eq(pending.get("attempt_receipts", {"x": 1}), {}, "no attempts yet")
	assert_eq(str(pending.get("opened_by_transaction_id", "")),
		str((activated["txn"] as Dictionary)["id"]), "opened by the Done transaction")
	assert_eq(_canonical(pending.get("opened_by_transaction_issuer_receipt", {})),
		_canonical((activated["txn"] as Dictionary)["receipt"]),
		"the Done root receipt is stored byte-equal")
	var preimage: Dictionary = pending.get("warning_fingerprint_preimage", {})
	assert_eq(_keys_of(preimage), ["context", "view_projection"],
		"the preimage is exactly {view_projection, context}")
	assert_eq(_canonical(preimage), _canonical(_expected_preimage(controller, context)),
		"the preimage stores the exact projection plus the exact context")
	var digest := str(pending.get("warning_state_fingerprint", ""))
	assert_eq(digest, _sha256(_canonical(preimage)),
		"canonical hashing of the stored preimage equals warning_state_fingerprint")
	var policy_digest: Dictionary = POLICY.warning_state_fingerprint(
		_view_of(controller), context)
	assert_true(policy_digest.get("ok", false), str(policy_digest))
	assert_eq(digest,
		str((policy_digest.get("value", {}) as Dictionary).get("fingerprint", "")),
		"the stored fingerprint is the policy's own")
	var provenance: Dictionary = pending.get("activation_id_provenance", {})
	var proven: Dictionary = _issuer.validate_child(provenance, &"warning")
	assert_true(proven.get("ok", false),
		"the activation child validates through the issuer: " + str(proven))
	assert_eq(str(provenance.get("child_id", "")), str(pending.get("activation_id", "")),
		"the provenance sits adjacent to its own child id")
	assert_eq(str(provenance.get("parent_receipt_id", "")),
		str(((activated["txn"] as Dictionary)["receipt"] as Dictionary)
			.get("receipt_id", "")), "the parent is the request_done transaction receipt")
	assert_eq(int(provenance.get("ordinal", -1)), 0, "the exact ordinal")
	var expected_sources: Array = [
		_p("warning_kind", "unread_invitation"), _p("warning_state_fingerprint", digest),
	]
	expected_sources.sort()
	assert_eq(provenance.get("source_ids", []), expected_sources,
		"the exact P03.warning.activation source projection, lexically sorted")
	assert_eq(_canonical(_pending_of(controller)), _canonical(pending),
		"the saved view carries the pending activation byte-equal")


func test_activation_with_no_eligible_warning_proceeds() -> void:
	var controller := _warning_controller()
	var context := _context({"eligible_unread_date_message_ids": []})
	var txn := _txn()
	var result: Dictionary = controller.request_warning_activation(txn["id"],
		txn["receipt"], context)
	assert_true(result.get("ok", false), str(result))
	assert_null((result.get("value", {}) as Dictionary).get("warning", "x"),
		"no eligible warning: Done proceeds")
	assert_null(_pending_of(controller), "nothing is left pending")


func test_repeating_the_same_done_command_returns_the_same_activation() -> void:
	var controller := _warning_controller()
	var context := _context()
	var activated := _activate(controller, context)
	var txn: Dictionary = activated["txn"]
	var repeat: Dictionary = controller.request_warning_activation(txn["id"],
		txn["receipt"], context)
	assert_true(repeat.get("ok", false), "the same Done command is idempotent: "
		+ str(repeat))
	assert_eq(_canonical((repeat.get("value", {}) as Dictionary).get("warning", {})),
		_canonical(activated["pending"]), "the same pending activation returns byte-equal")


func test_a_different_done_command_while_open_rejects() -> void:
	var controller := _warning_controller()
	var context := _context()
	var activated := _activate(controller, context)
	var other := _txn()
	_refused(controller.request_warning_activation(other["id"], other["receipt"], context),
		"warning_modal_active", "a different Done command while the modal is open")
	assert_eq(_canonical(_pending_of(controller)), _canonical(activated["pending"]),
		"the rejection mutates nothing")


func test_a_forged_transaction_root_is_refused() -> void:
	var controller := _warning_controller()
	var txn := _txn()
	var forged: Dictionary = (txn["receipt"] as Dictionary).duplicate(true)
	forged["token"] = "forged-token"
	_refused(controller.request_warning_activation(txn["id"], forged, _context()),
		"invalid_warning_transaction_root", "a ledger-unverifiable root")
	assert_null(_pending_of(controller), "nothing is activated")


func test_activation_validates_the_context() -> void:
	var controller := _warning_controller()
	var context := _context()
	context.erase("motivation")
	var txn := _txn()
	_refused(controller.request_warning_activation(txn["id"], txn["receipt"], context),
		"invalid_warning_context", "an invalid context is typed, never guessed")


# ---- terminals ----

func test_dismissal_consumes_with_an_exact_terminal_receipt() -> void:
	var controller := _warning_controller()
	var context := _context()
	var activated := _activate(controller, context)
	var pending: Dictionary = activated["pending"]
	var digest := str(pending.get("warning_state_fingerprint", ""))
	var term := _txn()
	var resolved: Dictionary = controller.resolve_warning(term["id"], term["receipt"],
		{"outcome": "dismissed"})
	assert_true(resolved.get("ok", false), str(resolved))
	assert_eq(_keys_of(resolved.get("value", {})), ["receipt"],
		"the terminal value is exactly {receipt}")
	var receipt: Dictionary = (resolved.get("value", {}) as Dictionary).get("receipt", {})
	assert_eq(_keys_of(receipt), CONSUMED_KEYS, "the exact ten-key consumed receipt")
	assert_eq(str(receipt.get("terminal_result", "")), "dismissed", "dismissal terminal")
	assert_eq(str(receipt.get("transaction_id", "")), str(term["id"]),
		"the terminal transaction is stored")
	assert_eq(str(receipt.get("activation_id", "")), str(pending.get("activation_id", "")),
		"the receipt names its activation")
	assert_ne(str(receipt.get("receipt_id", "")), str(pending.get("activation_id", "")),
		"no terminal path reuses the activation ID")
	assert_eq(_canonical(receipt.get("warning_fingerprint_preimage", {})),
		_canonical(pending.get("warning_fingerprint_preimage", {})),
		"every preimage copy is detached and byte-equal")
	var provenance: Dictionary = receipt.get("receipt_provenance", {})
	var proven: Dictionary = _issuer.validate_child(provenance, &"warning")
	assert_true(proven.get("ok", false), "a distinct terminal warning child: " + str(proven))
	assert_eq(str(provenance.get("parent_receipt_id", "")),
		str((term["receipt"] as Dictionary).get("receipt_id", "")),
		"the parent is the terminal resolve_warning transaction receipt")
	var expected_sources: Array = [
		_p("activation_id", str(pending.get("activation_id", ""))),
		_p("outcome", "dismissed"),
		_p("warning_kind", "unread_invitation"),
		_p("warning_state_fingerprint", digest),
	]
	expected_sources.sort()
	assert_eq(provenance.get("source_ids", []), expected_sources,
		"the exact P03.warning.dismissal source projection")
	var view := _view_of(controller)
	assert_null(view.get("pending_warning", "x"),
		"a successful terminal removes the pending activation")
	var consumed: Dictionary = view.get("consumed_warning_receipts", {})
	var key := digest + "|unread_invitation"
	assert_true(consumed.has(key), "consumed receipts key by fingerprint|kind")
	assert_eq(_canonical(consumed.get(key, {})), _canonical(receipt),
		"the durable consumed receipt is byte-equal")


func test_navigation_success_stores_the_navigation_child() -> void:
	var controller := _warning_controller()
	var activated := _activate(controller, _context())
	var pending: Dictionary = activated["pending"]
	var term := _txn()
	var resolved: Dictionary = controller.resolve_warning(term["id"], term["receipt"],
		{"outcome": "navigation_committed", "intent": "contacts_list"})
	assert_true(resolved.get("ok", false), str(resolved))
	var receipt: Dictionary = (resolved.get("value", {}) as Dictionary).get("receipt", {})
	assert_eq(_keys_of(receipt), CONSUMED_KEYS, "the exact ten-key consumed receipt")
	assert_eq(str(receipt.get("terminal_result", "")), "navigation_committed",
		"navigation success terminal")
	var provenance: Dictionary = receipt.get("receipt_provenance", {})
	var proven: Dictionary = _issuer.validate_child(provenance, &"navigation")
	assert_true(proven.get("ok", false),
		"navigation receipts come from child_kind navigation: " + str(proven))
	var expected_sources: Array = [
		_p("activation_id", str(pending.get("activation_id", ""))),
		_p("intent", "contacts_list"),
		_p("warning_kind", "unread_invitation"),
	]
	expected_sources.sort()
	assert_eq(provenance.get("source_ids", []), expected_sources,
		"the exact P03.warning.navigation source projection")
	assert_null(_pending_of(controller), "the activation is removed after durability")


func test_failed_navigation_appends_an_attempt_and_keeps_the_activation() -> void:
	var controller := _warning_controller()
	var activated := _activate(controller, _context())
	var pending: Dictionary = activated["pending"]
	var term := _txn()
	var resolved: Dictionary = controller.resolve_warning(term["id"], term["receipt"],
		{"outcome": "navigation_failed", "intent": "contacts_list",
			"failure_code": "route_unavailable"})
	assert_true(resolved.get("ok", false), str(resolved))
	var receipt: Dictionary = (resolved.get("value", {}) as Dictionary).get("receipt", {})
	assert_eq(_keys_of(receipt), ATTEMPT_KEYS, "the exact eleven-key attempt receipt")
	assert_eq(str(receipt.get("terminal_result", "")), "navigation_failed", "the terminal")
	assert_eq(str(receipt.get("failure_code", "")), "route_unavailable", "the failure code")
	var proven: Dictionary = _issuer.validate_child(
		receipt.get("receipt_provenance", {}), &"navigation")
	assert_true(proven.get("ok", false), "attempts are navigation children: " + str(proven))
	var live: Variant = _pending_of(controller)
	if not _require_dict(live, "the pending activation"):
		return
	assert_eq(str((live as Dictionary).get("activation_id", "")),
		str(pending.get("activation_id", "")), "the activation is unchanged")
	var attempts: Dictionary = (live as Dictionary).get("attempt_receipts", {})
	assert_true(attempts.has(str(term["id"])),
		"the attempt is durable under its terminal transaction ID")
	assert_eq(_canonical(attempts.get(str(term["id"]), {})), _canonical(receipt),
		"the durable attempt receipt is byte-equal")
	assert_eq(((_view_of(controller)).get("consumed_warning_receipts", {}) as Dictionary)
		.size(), 0, "a failed route never enters the consumed map")


func test_an_identical_failed_navigation_retry_returns_the_original() -> void:
	var controller := _warning_controller()
	var _activated := _activate(controller, _context())
	var term := _txn()
	var resolution := {"outcome": "navigation_failed", "intent": "contacts_list",
		"failure_code": "route_unavailable"}
	var first: Dictionary = controller.resolve_warning(term["id"], term["receipt"],
		resolution.duplicate(true))
	assert_true(first.get("ok", false), str(first))
	var retry: Dictionary = controller.resolve_warning(term["id"], term["receipt"],
		resolution.duplicate(true))
	assert_true(retry.get("ok", false), "an identical retry is idempotent: " + str(retry))
	assert_eq(_canonical((retry.get("value", {}) as Dictionary).get("receipt", {})),
		_canonical((first.get("value", {}) as Dictionary).get("receipt", {})),
		"the original navigation_failed receipt returns byte-equal")
	var live: Variant = _pending_of(controller)
	if not _require_dict(live, "the kept activation"):
		return
	assert_eq(((live as Dictionary).get("attempt_receipts", {}) as Dictionary).size(), 1,
		"no second attempt receipt is appended")


func test_duplicate_successful_terminal_input_returns_the_original() -> void:
	var controller := _warning_controller()
	var _activated := _activate(controller, _context())
	var term := _txn()
	var first: Dictionary = controller.resolve_warning(term["id"], term["receipt"],
		{"outcome": "dismissed"})
	assert_true(first.get("ok", false), str(first))
	var repeat: Dictionary = controller.resolve_warning(term["id"], term["receipt"],
		{"outcome": "dismissed"})
	assert_true(repeat.get("ok", false), "duplicate terminal input is idempotent: "
		+ str(repeat))
	assert_eq(_canonical((repeat.get("value", {}) as Dictionary).get("receipt", {})),
		_canonical((first.get("value", {}) as Dictionary).get("receipt", {})),
		"the original consumed receipt returns byte-equal")
	assert_eq(((_view_of(controller)).get("consumed_warning_receipts", {}) as Dictionary)
		.size(), 1, "nothing was appended twice")


func test_conflicting_transaction_reuse_fails_without_mutation() -> void:
	var controller := _warning_controller()
	var _activated := _activate(controller, _context())
	var term := _txn()
	var failed: Dictionary = controller.resolve_warning(term["id"], term["receipt"],
		{"outcome": "navigation_failed", "intent": "contacts_list",
			"failure_code": "route_unavailable"})
	assert_true(failed.get("ok", false), str(failed))
	var before := _canonical(_view_of(controller))
	_refused(controller.resolve_warning(term["id"], term["receipt"],
		{"outcome": "dismissed"}),
		"warning_transaction_conflict", "reusing an attempt transaction differently")
	assert_eq(_canonical(_view_of(controller)), before, "the conflict mutates nothing")
	var term2 := _txn()
	assert_true(controller.resolve_warning(term2["id"], term2["receipt"],
		{"outcome": "dismissed"}).get("ok", false), "the dismissal lands")
	var settled := _canonical(_view_of(controller))
	_refused(controller.resolve_warning(term2["id"], term2["receipt"],
		{"outcome": "navigation_committed", "intent": "contacts_list"}),
		"warning_transaction_conflict", "reusing a consumed transaction differently")
	assert_eq(_canonical(_view_of(controller)), settled, "the conflict mutates nothing")


func test_resolution_shape_and_missing_pending_are_typed() -> void:
	var controller := _warning_controller()
	var term := _txn()
	_refused(controller.resolve_warning(term["id"], term["receipt"],
		{"outcome": "dismissed"}), "no_pending_warning",
		"a terminal without an open activation")
	var _activated := _activate(controller, _context())
	_refused(controller.resolve_warning(term["id"], term["receipt"],
		{"outcome": "vanished"}), "invalid_warning_resolution", "an unknown outcome")
	_refused(controller.resolve_warning(term["id"], term["receipt"],
		{"outcome": "navigation_committed"}), "invalid_warning_resolution",
		"navigation without its intent")
	_refused(controller.resolve_warning(term["id"], term["receipt"],
		{"outcome": "navigation_failed", "intent": "contacts_list"}),
		"invalid_warning_resolution", "a failed navigation without its failure code")
	_refused(controller.resolve_warning(term["id"], term["receipt"],
		{"outcome": "dismissed", "intent": "contacts_list"}),
		"invalid_warning_resolution", "a dismissal carries no intent")


func test_the_preimage_is_detached_from_live_owners() -> void:
	var controller := _warning_controller()
	var context := _context()
	var activated := _activate(controller, context)
	var expected := _canonical((activated["pending"] as Dictionary)
		.get("warning_fingerprint_preimage", {}))
	context["motivation"] = 99
	(context["eligible_unread_date_message_ids"] as Array).clear()
	var prepared: Dictionary = controller.prepare_add("training", null, 1, "d-late")
	assert_true(prepared.get("ok", false), str(prepared))
	assert_true(controller.commit(
		(prepared.get("value", {}) as Dictionary).get("candidate", {})).get("ok", false),
		"editing while the modal is open never rebuilds the preimage")
	var live: Variant = _pending_of(controller)
	if not _require_dict(live, "the still-pending activation"):
		return
	assert_eq(_canonical((live as Dictionary).get("warning_fingerprint_preimage", {})),
		expected, "the stored preimage is never reconstructed from later live owners")


# ---- review fixes: transaction crossover, retry projection, configure order ----

func test_a_terminal_reusing_the_activation_transaction_is_refused() -> void:
	var controller := _warning_controller()
	var activated := _activate(controller, _context())
	var txn: Dictionary = activated["txn"]
	var before := _canonical(_view_of(controller))
	_refused(controller.resolve_warning(txn["id"], txn["receipt"],
		{"outcome": "dismissed"}), "warning_transaction_conflict",
		"the activation's own transaction as a terminal")
	assert_eq(_canonical(_view_of(controller)), before, "the refusal mutates nothing")


func test_an_activation_reusing_a_terminal_transaction_is_refused() -> void:
	var controller := _warning_controller()
	var context := _context()
	var _activated := _activate(controller, context)
	var term := _txn()
	assert_true(controller.resolve_warning(term["id"], term["receipt"],
		{"outcome": "dismissed"}).get("ok", false), "the dismissal lands")
	_refused(controller.request_warning_activation(term["id"], term["receipt"], context),
		"warning_transaction_conflict", "a consumed terminal transaction as a Done root")
	assert_null(_pending_of(controller), "nothing is reopened")
	var second := _warning_controller()
	var _activated2 := _activate(second, context)
	var attempt_txn := _txn()
	assert_true(second.resolve_warning(attempt_txn["id"], attempt_txn["receipt"],
		{"outcome": "navigation_failed", "intent": "contacts_list",
			"failure_code": "route_unavailable"}).get("ok", false), "the attempt lands")
	_refused(second.request_warning_activation(attempt_txn["id"],
		attempt_txn["receipt"], context), "warning_transaction_conflict",
		"a failed-attempt transaction as a Done root")


func test_a_different_intent_failed_navigation_retry_conflicts() -> void:
	var controller := _warning_controller()
	var _activated := _activate(controller, _context())
	var term := _txn()
	var first: Dictionary = controller.resolve_warning(term["id"], term["receipt"],
		{"outcome": "navigation_failed", "intent": "contacts_list",
			"failure_code": "route_unavailable"})
	assert_true(first.get("ok", false), str(first))
	var before := _canonical(_view_of(controller))
	_refused(controller.resolve_warning(term["id"], term["receipt"],
		{"outcome": "navigation_failed", "intent": "minesweeper",
			"failure_code": "route_unavailable"}), "warning_transaction_conflict",
		"an identical outcome with a different intent is different bytes")
	assert_eq(_canonical(_view_of(controller)), before, "the conflict mutates nothing")


func test_an_invalid_replacement_issuer_is_refused_as_invalid() -> void:
	var controller := _warning_controller()
	_refused(controller.configure_warning_identity(null),
		"invalid_warning_identity_issuer",
		"validity is checked before the replacement law")
