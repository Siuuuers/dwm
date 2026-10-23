extends "res://addons/gut/test.gd"
## RED/GREEN coverage for the production DesktopConditionPolicyPort (Plan 03 Task 7 lines 874-878,
## dwm-oyo.3 slice authorized 2026-08-24 -- see the deviation notes on dwm-p2r.21 / dwm-oyo.3).
##
## SUBSTRATE. The REAL production graph end to end: the real GameState autoload script, the real
## DesktopIdentityNonceIssuer over FakeDesktopIssuerRootStore, and the real
## GameStateDesktopConditionContextPort -- the policy port's one configured dependency. Nothing here
## arms a scripted decision; every decision below is produced by the frozen predicate over live
## GameState condition state, which is exactly what separates this suite from Plan 02's
## FakeDesktopConditionPolicyPort contract fake.
##
## THE FROZEN SURFACE (Plan 02 brief; preserved by Plan 03 line 874): `configure(context_port)`,
## `evaluate({action_receipt, causal_sequence_receipt})`. THE FROZEN PREDICATE (plan line 878):
## `danger = pressure >= 10 or health <= 0`, `trigger = carried_sequela and danger`; no trigger
## yields only the notification intent; Days 1-6 trigger yields Hospital; on Day 7 Dark mode wins,
## then a qualifying pre-action Sylvia read, then hospital_alone. `committed | resolving` rejects a
## new action rather than creating a post-Done faint.

const PROBE := preload("res://tests/support/DynamicScriptProbe.gd")
const PORT_PATH := "res://scripts/application/desktop/DesktopConditionPolicyPort.gd"
const CONTEXT_PORT_PATH := "res://scripts/application/desktop/GameStateDesktopConditionContextPort.gd"
const GAME_STATE_PATH := "res://autoload/GameState.gd"

const ISSUER := preload("res://scripts/application/desktop/DesktopIdentityNonceIssuer.gd")
const FAKE_ROOT_STORE := preload("res://tests/support/FakeDesktopIssuerRootStore.gd")
const ACTION_RECEIPT := preload("res://scripts/domain/desktop/DesktopActionReceipt.gd")
const CANONICAL_JSON := preload("res://scripts/validation/CanonicalJsonWriter.gd")

const RUN_ID := "run-policy"
const BRANCH_ID := "branch-policy"
const GENERATION := 0
const CAUSAL_DAY := "causal-day-policy-1"

## The exact frozen condition-receipt member set (Plan 03 line 874), sorted.
const CONDITION_RECEIPT_KEYS: Array = [
	"action_commit_receipt_id", "action_commit_receipt_provenance", "causal_day_instance",
	"causal_sequence", "causal_sequence_receipt_id", "causal_sequence_receipt_provenance",
	"condition_after", "danger", "day", "decision", "receipt_id", "receipt_provenance",
	"source_receipt_ids", "sylvia_read_receipt_id", "trigger",
]
## The exact frozen destination-intent member set (Plan 03 line 874), sorted.
const DESTINATION_INTENT_KEYS: Array = [
	"accepted_unfulfilled_sources", "causal_day_instance", "day", "intent_id",
	"intent_id_provenance", "kind", "prerequisite_receipt_ids", "source_condition_receipt_id",
	"source_condition_receipt_provenance", "terminal_cause", "terminal_provenance",
]
## The exact frozen notification-intent member set (Plan 03 line 874), sorted.
const NOTIFICATION_INTENT_KEYS: Array = [
	"action_commit_receipt_id", "action_commit_receipt_provenance", "action_kind", "intent_id",
	"intent_id_provenance", "source_condition_receipt_id", "source_condition_receipt_provenance",
]

## A context seam that answers with a child id the one `.16` issuer never minted. Everything else
## delegates to the REAL port, so the only thing under test is the child identity itself.
class _ForgingContextPort extends RefCounted:
	const FORGED_CHILD_ID := "ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff"

	var _inner: Object = null
	var _forge_kind: String = ""
	var _forge_provenance := false

	func _init(inner: Object, forge_kind: String, forge_provenance: bool) -> void:
		_inner = inner
		_forge_kind = forge_kind
		_forge_provenance = forge_provenance

	func snapshot_for(request: Dictionary) -> Dictionary:
		return _inner.call(&"snapshot_for", request)

	func validate_child(provenance: Dictionary, expected_kind: StringName) -> Dictionary:
		return _inner.call(&"validate_child", provenance, expected_kind)

	func derive_child(request: Dictionary) -> Dictionary:
		var derived: Dictionary = _inner.call(&"derive_child", request)
		if str(request.get("child_kind", "")) != _forge_kind or not derived.get("ok", false):
			return derived
		var envelope: Dictionary = derived.duplicate(true)
		var value: Dictionary = envelope["value"]
		value["child_id"] = FORGED_CHILD_ID
		if _forge_provenance:
			(value["provenance"] as Dictionary)["child_id"] = FORGED_CHILD_ID
		return envelope


var _port_script: Script = null
var _context_script: Script = null
var _root_store: FAKE_ROOT_STORE
var _issuer: ISSUER
var _game_state: Node = null
var _context_port: Object = null
var _port: Object = null


func before_each() -> void:
	var port_loaded: Dictionary = PROBE.load_script(PORT_PATH)
	_port_script = port_loaded["value"] if port_loaded.get("ok", false) else null
	var context_loaded: Dictionary = PROBE.load_script(CONTEXT_PORT_PATH)
	_context_script = context_loaded["value"] if context_loaded.get("ok", false) else null
	_root_store = FAKE_ROOT_STORE.new("66".repeat(32), 1)
	_issuer = ISSUER.new()
	assert_true(_issuer.configure(_root_store).get("ok", false))
	_game_state = load(GAME_STATE_PATH).new()
	autofree(_game_state)
	_game_state.reset_game()
	_install_lifecycle_identity(1)
	if _context_script != null:
		_context_port = _context_script.new()
		assert_true(_context_port.configure(_game_state, _issuer).get("ok", false))
	if _port_script != null and _context_port != null:
		_port = _port_script.new()
		var configured: Dictionary = _port.configure(_context_port)
		assert_true(configured.get("ok", false), JSON.stringify(configured))


func _require_port() -> bool:
	var absent: Array[String] = []
	if _context_script == null:
		absent.append(CONTEXT_PORT_PATH)
	if _port_script == null:
		absent.append(PORT_PATH)
	if not absent.is_empty():
		assert_true(false, "the condition-policy modules are absent: " + str(absent))
		return false
	return true


func _install_lifecycle_identity(day: int, dark_mode: bool = false) -> void:
	var receipt: Dictionary = _root_store.mint(&"causal_day_instance").duplicate(true)
	receipt["token"] = CAUSAL_DAY
	_game_state._run_lifecycle.reset(RUN_ID, BRANCH_ID, GENERATION, CAUSAL_DAY,
		{"causal_day_instance_issuer_receipt": receipt}, dark_mode)
	if day != 1:
		var lifecycle: Dictionary = _game_state._run_lifecycle.to_dict()
		lifecycle["day"] = day
		var prepared: Dictionary = _game_state._run_lifecycle.prepare_restore(lifecycle)
		assert_true(prepared.get("ok", false), JSON.stringify(prepared))
		var committed: Dictionary = _game_state._run_lifecycle.commit_restore(
			(prepared["value"] as Dictionary)["candidate"])
		assert_true(committed.get("ok", false), JSON.stringify(committed))


func _mint_transaction() -> Dictionary:
	var issued: Dictionary = _issuer.call(&"issue", &"transaction_id")
	var value: Dictionary = issued["value"]
	return {"transaction_id": str(value["token"]),
		"transaction_issuer_receipt": (value["issuer_receipt"] as Dictionary).duplicate(true)}


func _action_receipt(day: int, txn: Dictionary) -> Dictionary:
	var parent_id := str((txn["transaction_issuer_receipt"] as Dictionary)["receipt_id"])
	var source_commit := _issuer.derive_child({
		"child_kind": "shop_quote", "ordinal": 0, "parent_receipt_id": parent_id,
		"source_ids": ["policy-quote-source"],
	})
	assert_true(source_commit.get("ok", false), JSON.stringify(source_commit))
	var action_derived := _issuer.derive_child({
		"child_kind": "desktop_action", "ordinal": 0, "parent_receipt_id": parent_id,
		"source_ids": ["policy-action-source"],
	})
	assert_true(action_derived.get("ok", false), JSON.stringify(action_derived))
	var action_id := str((action_derived["value"] as Dictionary)["child_id"])
	var action_provenance: Dictionary = (action_derived["value"] as Dictionary)["provenance"]
	# Existing predicate cases describe an action that leaves their configured condition intact.
	# The adapter reads this frozen result before source commit, not GameState's current stats.
	var condition := {"health": int(_game_state.get_stat("health")),
		"pressure": int(_game_state.get_stat("pressure")),
		"carried_sequela": _game_state.condition_effects_today.has("sequela")}
	var receipt := {
		"schema_version": 1, "action_kind": "shop_purchase", "run_id": RUN_ID,
		"branch_id": BRANCH_ID, "desktop_timeline_generation": GENERATION,
		"causal_day_instance": CAUSAL_DAY, "day": day,
		"transaction_id": str(txn["transaction_id"]),
		"transaction_issuer_receipt": (txn["transaction_issuer_receipt"] as Dictionary).duplicate(true),
		"source_commit_receipt_id": str((source_commit["value"] as Dictionary)["child_id"]),
		"source_commit_receipt_provenance": (source_commit["value"] as Dictionary)["provenance"],
		"condition_before": condition.duplicate(true),
		"condition_after": condition.duplicate(true),
		"unlock_receipt_ids": [],
		"action_id": action_id, "action_id_provenance": action_provenance,
		"commit_receipt_id": action_id,
		"commit_receipt_provenance": (action_provenance as Dictionary).duplicate(true),
	}
	var validated := ACTION_RECEIPT.validate(receipt)
	assert_true(validated.get("ok", false), JSON.stringify(validated))
	return (validated["value"] as Dictionary)["receipt"]


func _causal_sequence_receipt(action_receipt: Dictionary) -> Dictionary:
	return {
		"receipt_id": "causal-sequence-receipt-" + str(action_receipt["transaction_id"]),
		"receipt_provenance": {"kind": "causal_sequence",
			"transaction_id": str(action_receipt["transaction_id"])},
		"transaction_id": str(action_receipt["transaction_id"]),
		"transaction_issuer_receipt":
			(action_receipt["transaction_issuer_receipt"] as Dictionary).duplicate(true),
		"run_id": RUN_ID, "branch_id": BRANCH_ID, "desktop_timeline_generation": GENERATION,
		"causal_day_instance": CAUSAL_DAY, "source_kind": "shop_purchase",
		"source_commit_receipt_id": str(action_receipt["source_commit_receipt_id"]),
		"source_commit_receipt_provenance":
			(action_receipt["source_commit_receipt_provenance"] as Dictionary).duplicate(true),
		"causal_sequence": 1, "run_revision": 1,
	}


func _request(day: int = 1) -> Dictionary:
	var txn := _mint_transaction()
	var action := _action_receipt(day, txn)
	return {"action_receipt": action, "causal_sequence_receipt": _causal_sequence_receipt(action)}


func _set_condition(health: int, pressure: int, carried_sequela: bool) -> void:
	_game_state.stats[_game_state.STAT_HEALTH] = health
	_game_state.stats[_game_state.STAT_PRESSURE] = pressure
	if carried_sequela and not _game_state.condition_effects_today.has("sequela"):
		_game_state.condition_effects_today.append("sequela")


func _install_source(action_id: String, day: int, participants: Array) -> Dictionary:
	var txn := _mint_transaction()
	var parent_id := str((txn["transaction_issuer_receipt"] as Dictionary)["receipt_id"])
	var derived := _issuer.derive_child({
		"child_kind": "contact_source", "ordinal": 0, "parent_receipt_id": parent_id,
		"source_ids": ["source:" + action_id],
	})
	assert_true(derived.get("ok", false), JSON.stringify(derived))
	var source := {
		"action_id": action_id, "day": day, "kind": "solo_read_acceptance",
		"participants": participants.duplicate(true), "previous_receipt_id": "",
		"receipt_id": str((derived["value"] as Dictionary)["child_id"]),
		"receipt_provenance": (derived["value"] as Dictionary)["provenance"],
	}
	(_game_state.contacts["schedule_source_receipts"] as Dictionary)[source["receipt_id"]] = \
		source.duplicate(true)
	return source


static func _projection(name: String, value: Variant) -> String:
	var emitted: Dictionary = CANONICAL_JSON.stringify(value)
	return name + "=" + str(emitted["value"])


# ---- module presence ----

func test_policy_port_script_loads() -> void:
	var loaded: Dictionary = PROBE.load_script(PORT_PATH)
	assert_true(loaded.get("ok", false), "DesktopConditionPolicyPort.gd must load")


# ---- configure (the frozen one-argument API) ----

func test_configure_rejects_null_and_a_context_without_the_capability() -> void:
	if not _require_port():
		return
	var fresh: Object = _port_script.new()
	var null_result: Dictionary = fresh.configure(null)
	assert_false(null_result.get("ok", true))
	assert_eq(null_result.get("code"), &"invalid_context_port")
	var bare: Dictionary = fresh.configure(RefCounted.new())
	assert_false(bare.get("ok", true))
	assert_eq(bare.get("code"), &"invalid_context_port")


func test_configure_identical_replay_is_idempotent_and_replacement_is_refused() -> void:
	if not _require_port():
		return
	var replay: Dictionary = _port.configure(_context_port)
	assert_true(replay.get("ok", false), JSON.stringify(replay))
	assert_true(bool((replay.get("value", {}) as Dictionary).get("already_configured", false)))
	var other: Object = _context_script.new()
	assert_true(other.configure(_game_state, _issuer).get("ok", false))
	var replaced: Dictionary = _port.configure(other)
	assert_false(replaced.get("ok", true))
	assert_eq(replaced.get("code"), &"port_already_configured")


func test_evaluate_before_configure_fails_closed() -> void:
	if not _require_port():
		return
	var fresh: Object = _port_script.new()
	var result: Dictionary = fresh.evaluate(_request())
	assert_false(result.get("ok", true))
	assert_eq(result.get("code"), &"port_not_configured")


func test_evaluate_rejects_a_request_with_extra_or_missing_keys() -> void:
	if not _require_port():
		return
	var request := _request()
	request["extra"] = 1
	var extra: Dictionary = _port.evaluate(request)
	assert_false(extra.get("ok", true))
	assert_eq(extra.get("code"), &"condition_request_invalid")
	var missing: Dictionary = _port.evaluate({"action_receipt": request["action_receipt"]})
	assert_false(missing.get("ok", true))
	assert_eq(missing.get("code"), &"condition_request_invalid")


# ---- the frozen predicate and decisions ----

func test_a_safe_action_yields_no_departure_with_only_the_notification_intent() -> void:
	if not _require_port():
		return
	var request := _request()
	var result: Dictionary = _port.evaluate(request)
	assert_true(result.get("ok", false), JSON.stringify(result))
	var value: Dictionary = result["value"]
	var value_keys: Array = value.keys()
	value_keys.sort()
	assert_eq(value_keys, ["condition_receipt", "destination_intent", "notification_intent"])
	var condition: Dictionary = value["condition_receipt"]
	assert_eq(str(condition["decision"]), "no_departure")
	assert_false(bool(condition["danger"]))
	assert_false(bool(condition["trigger"]))
	assert_eq(value["destination_intent"], null)
	var notification: Variant = value["notification_intent"]
	assert_eq(typeof(notification), TYPE_DICTIONARY)
	var notification_keys: Array = (notification as Dictionary).keys()
	notification_keys.sort()
	assert_eq(notification_keys, NOTIFICATION_INTENT_KEYS)
	assert_eq(result["receipt"], condition, "the outer receipt is the exact condition receipt")


func test_danger_without_carried_sequela_still_yields_no_departure() -> void:
	if not _require_port():
		return
	_set_condition(6, 11, false)
	var result: Dictionary = _port.evaluate(_request())
	assert_true(result.get("ok", false), JSON.stringify(result))
	var condition: Dictionary = (result["value"] as Dictionary)["condition_receipt"]
	assert_true(bool(condition["danger"]))
	assert_false(bool(condition["trigger"]))
	assert_eq(str(condition["decision"]), "no_departure")
	assert_eq((result["value"] as Dictionary)["destination_intent"], null)


func test_a_days_one_to_six_trigger_yields_hospital_day() -> void:
	if not _require_port():
		return
	_set_condition(0, 3, true)
	var source := _install_source("solo:priscilla:day1", 1, ["priscilla"])
	var result: Dictionary = _port.evaluate(_request())
	assert_true(result.get("ok", false), JSON.stringify(result))
	var value: Dictionary = result["value"]
	var condition: Dictionary = value["condition_receipt"]
	assert_true(bool(condition["danger"]))
	assert_true(bool(condition["trigger"]))
	assert_eq(str(condition["decision"]), "hospital_day")
	assert_eq(condition["source_receipt_ids"], [str(source["receipt_id"])])
	var keys: Array = condition.keys()
	keys.sort()
	assert_eq(keys, CONDITION_RECEIPT_KEYS)
	assert_eq(value["notification_intent"], null,
		"departure and notification are mutually exclusive")
	var intent: Dictionary = value["destination_intent"]
	var intent_keys: Array = intent.keys()
	intent_keys.sort()
	assert_eq(intent_keys, DESTINATION_INTENT_KEYS)
	assert_eq(str(intent["kind"]), "hospital_day")
	assert_eq(intent["terminal_cause"], null)
	assert_eq(intent["terminal_provenance"], null)
	assert_eq((intent["accepted_unfulfilled_sources"] as Array).size(), 1)
	var expected_prerequisites: Array = [str(condition["receipt_id"]),
		str((_last_action(result))["commit_receipt_id"])]
	expected_prerequisites.sort()
	assert_eq(intent["prerequisite_receipt_ids"], expected_prerequisites)


func test_a_day7_trigger_with_dark_mode_yields_day7_dark_alone() -> void:
	if not _require_port():
		return
	_install_lifecycle_identity(7, true)
	_set_condition(0, 3, true)
	_install_source("solo:sylvia:day7", 7, ["sylvia"])
	var result: Dictionary = _port.evaluate(_request(7))
	assert_true(result.get("ok", false), JSON.stringify(result))
	var value: Dictionary = result["value"]
	assert_eq(str((value["condition_receipt"] as Dictionary)["decision"]), "day7_dark_alone")
	var intent: Dictionary = value["destination_intent"]
	assert_eq(str(intent["kind"]), "day7_terminal")
	assert_eq(str(intent["terminal_cause"]), "dark_mode_alone")
	assert_eq(intent["terminal_provenance"], null)
	assert_eq(intent["accepted_unfulfilled_sources"], [],
		"a condition-driven Day 7 intent carries an empty accepted-source array")


func test_a_day7_trigger_with_a_preexisting_sylvia_read_yields_sylvia_special() -> void:
	if not _require_port():
		return
	_install_lifecycle_identity(7)
	_set_condition(0, 3, true)
	_install_source("solo:sylvia:day7", 7, ["sylvia"])
	var result: Dictionary = _port.evaluate(_request(7))
	assert_true(result.get("ok", false), JSON.stringify(result))
	var value: Dictionary = result["value"]
	assert_eq(str((value["condition_receipt"] as Dictionary)["decision"]), "day7_sylvia_special")
	assert_eq(str((value["destination_intent"] as Dictionary)["terminal_cause"]), "sylvia_special")


func test_a_day7_trigger_alone_yields_day7_hospital_alone() -> void:
	if not _require_port():
		return
	_install_lifecycle_identity(7)
	_set_condition(0, 3, true)
	var result: Dictionary = _port.evaluate(_request(7))
	assert_true(result.get("ok", false), JSON.stringify(result))
	var value: Dictionary = result["value"]
	assert_eq(str((value["condition_receipt"] as Dictionary)["decision"]), "day7_hospital_alone")
	assert_eq(str((value["destination_intent"] as Dictionary)["terminal_cause"]), "hospital_alone")


func test_a_resolving_schedule_rejects_a_new_action() -> void:
	if not _require_port():
		return
	_set_condition(0, 3, true)
	var begun: Dictionary = _game_state._run_lifecycle.begin_day_resolution(
		"post-done-resolution", {"schema_version": 1, "day": 1, "registry_fingerprint": null,
			"entries": [], "commit_receipt": null}, [], null, null, {})
	assert_true(begun.get("ok", false), JSON.stringify(begun))
	var result: Dictionary = _port.evaluate(_request())
	assert_false(result.get("ok", true))
	assert_eq(result.get("code"), &"condition_post_done_action")


# ---- child identity derivation (the P03.condition.* rows) ----

func test_the_condition_receipt_is_the_exact_p03_condition_decision_child() -> void:
	if not _require_port():
		return
	var request := _request()
	var action: Dictionary = request["action_receipt"]
	var sequence: Dictionary = request["causal_sequence_receipt"]
	var result: Dictionary = _port.evaluate(request)
	assert_true(result.get("ok", false), JSON.stringify(result))
	var condition: Dictionary = (result["value"] as Dictionary)["condition_receipt"]
	var source_ids: Array = [
		_projection("action_commit_receipt_id", str(action["commit_receipt_id"])),
		_projection("causal_sequence_receipt_id", str(sequence["receipt_id"])),
	]
	source_ids.sort()
	var expected: Dictionary = _issuer.derive_child({
		"child_kind": "condition", "ordinal": 0,
		"parent_receipt_id": str((action["transaction_issuer_receipt"] as Dictionary)["receipt_id"]),
		"source_ids": source_ids,
	})
	assert_true(expected.get("ok", false), JSON.stringify(expected))
	assert_eq(str(condition["receipt_id"]), str((expected["value"] as Dictionary)["child_id"]))
	assert_eq(condition["receipt_provenance"], (expected["value"] as Dictionary)["provenance"])
	var validated: Dictionary = _issuer.validate_child(condition["receipt_provenance"], &"condition")
	assert_true(validated.get("ok", false), JSON.stringify(validated))


func test_the_notification_intent_is_the_exact_p03_condition_notification_child() -> void:
	if not _require_port():
		return
	var request := _request()
	var action: Dictionary = request["action_receipt"]
	var result: Dictionary = _port.evaluate(request)
	assert_true(result.get("ok", false), JSON.stringify(result))
	var value: Dictionary = result["value"]
	var condition: Dictionary = value["condition_receipt"]
	var notification: Dictionary = value["notification_intent"]
	var source_ids: Array = [
		_projection("condition_receipt_id", str(condition["receipt_id"])),
		_projection("action_commit_receipt_id", str(action["commit_receipt_id"])),
		_projection("action_kind", str(action["action_kind"])),
	]
	source_ids.sort()
	var expected: Dictionary = _issuer.derive_child({
		"child_kind": "notification_intent", "ordinal": 0,
		"parent_receipt_id": str((action["transaction_issuer_receipt"] as Dictionary)["receipt_id"]),
		"source_ids": source_ids,
	})
	assert_true(expected.get("ok", false), JSON.stringify(expected))
	assert_eq(str(notification["intent_id"]), str((expected["value"] as Dictionary)["child_id"]))
	assert_eq(str(notification["source_condition_receipt_id"]), str(condition["receipt_id"]))
	var validated: Dictionary = _issuer.validate_child(
		notification["intent_id_provenance"], &"notification_intent")
	assert_true(validated.get("ok", false), JSON.stringify(validated))


func test_the_destination_intent_is_the_exact_p03_condition_destination_child() -> void:
	if not _require_port():
		return
	_set_condition(0, 3, true)
	var request := _request()
	var action: Dictionary = request["action_receipt"]
	var result: Dictionary = _port.evaluate(request)
	assert_true(result.get("ok", false), JSON.stringify(result))
	var value: Dictionary = result["value"]
	var condition: Dictionary = value["condition_receipt"]
	var intent: Dictionary = value["destination_intent"]
	var source_ids: Array = [
		_projection("condition_receipt_id", str(condition["receipt_id"])),
		_projection("action_commit_receipt_id", str(action["commit_receipt_id"])),
	]
	source_ids.sort()
	var expected: Dictionary = _issuer.derive_child({
		"child_kind": "destination_intent", "ordinal": 0,
		"parent_receipt_id": str((action["transaction_issuer_receipt"] as Dictionary)["receipt_id"]),
		"source_ids": source_ids,
	})
	assert_true(expected.get("ok", false), JSON.stringify(expected))
	assert_eq(str(intent["intent_id"]), str((expected["value"] as Dictionary)["child_id"]))
	var validated: Dictionary = _issuer.validate_child(
		intent["intent_id_provenance"], &"destination_intent")
	assert_true(validated.get("ok", false), JSON.stringify(validated))


func test_identical_replay_returns_byte_identical_children() -> void:
	if not _require_port():
		return
	var request := _request()
	var first: Dictionary = _port.evaluate(request)
	assert_true(first.get("ok", false), JSON.stringify(first))
	var second: Dictionary = _port.evaluate(request)
	assert_true(second.get("ok", false), JSON.stringify(second))
	assert_eq(first["value"], second["value"],
		"the derivation is pure, so a replay reproduces the same bytes")


func test_a_day_six_trigger_still_yields_hospital_day() -> void:
	if not _require_port():
		return
	_install_lifecycle_identity(6)
	_set_condition(0, 3, true)
	var source := _install_source("solo:priscilla:day6", 6, ["priscilla"])
	var result: Dictionary = _port.evaluate(_request(6))
	assert_true(result.get("ok", false), JSON.stringify(result))
	var value: Dictionary = result["value"]
	var condition: Dictionary = value["condition_receipt"]
	assert_eq(int(condition["day"]), 6)
	assert_eq(str(condition["decision"]), "hospital_day",
		"day 6 is the LAST hospital_day; the frozen boundary is day <= 6, never day <= 5")
	assert_eq(str((value["destination_intent"] as Dictionary)["kind"]), "hospital_day")
	assert_eq(condition["source_receipt_ids"], [str(source["receipt_id"])])


func test_pressure_at_exactly_ten_is_danger_and_triggers() -> void:
	if not _require_port():
		return
	_set_condition(6, 10, true)
	var result: Dictionary = _port.evaluate(_request())
	assert_true(result.get("ok", false), JSON.stringify(result))
	var condition: Dictionary = (result["value"] as Dictionary)["condition_receipt"]
	assert_true(bool(condition["danger"]),
		"the frozen predicate is pressure >= 10, so exactly 10 is ALREADY danger with health 6")
	assert_true(bool(condition["trigger"]))
	assert_eq(str(condition["decision"]), "hospital_day")


func test_a_child_id_the_issuer_never_minted_is_refused() -> void:
	if not _require_port():
		return
	_set_condition(0, 3, true)
	var port: Object = _port_script.new()
	assert_true(port.configure(
		_ForgingContextPort.new(_context_port, "condition", true)).get("ok", false))
	var result: Dictionary = port.evaluate(_request())
	assert_false(result.get("ok", true),
		"a child id the issuer never minted must never reach the day's condition receipt")
	assert_eq(result.get("code"), &"condition_child_unverified", JSON.stringify(result))


func test_a_derived_child_disagreeing_with_its_own_provenance_is_refused() -> void:
	if not _require_port():
		return
	_set_condition(0, 3, true)
	var port: Object = _port_script.new()
	assert_true(port.configure(
		_ForgingContextPort.new(_context_port, "condition", false)).get("ok", false))
	var result: Dictionary = port.evaluate(_request())
	assert_false(result.get("ok", true),
		"the derived id and its provenance must agree before either is persisted")
	assert_eq(result.get("code"), &"condition_child_unverified", JSON.stringify(result))


func _last_action(result: Dictionary) -> Dictionary:
	var condition: Dictionary = (result["value"] as Dictionary)["condition_receipt"]
	return {"commit_receipt_id": str(condition["action_commit_receipt_id"])}

func test_prepared_round_loss_crossing_pressure_ten_departs_before_source_commit() -> void:
	if not _require_port():
		return
	_set_condition(6, 9, true)
	var source := _install_source("solo:priscilla:day1", 1, ["priscilla"])
	var request := _request()
	request["action_receipt"]["action_kind"] = "minesweeper_round"
	request["causal_sequence_receipt"]["source_kind"] = "minesweeper_round"
	request["action_receipt"]["condition_after"]["pressure"] = 10
	var before: Dictionary = _game_state.to_save_dict().duplicate(true)
	var result: Dictionary = _port.evaluate(request)
	assert_true(result.get("ok", false), str(result))
	if not result.get("ok", false):
		return
	var condition: Dictionary = result["value"]["condition_receipt"]
	assert_eq(condition["condition_after"], {"health": 6, "pressure": 10, "carried_sequela": true})
	assert_true(condition["danger"])
	assert_true(condition["trigger"])
	assert_eq(condition["decision"], "hospital_day",
		"the prepared loss triggers the existing threshold while live pressure is still 9")
	assert_eq(condition["source_receipt_ids"], [source["receipt_id"]],
		"preexisting Schedule sources still come from live Contacts")
	assert_eq(result["value"]["notification_intent"], null)
	assert_eq(_game_state.to_save_dict(), before, "condition evaluation cannot commit the action")


func test_prepared_relief_below_pressure_ten_does_not_depart_while_live_state_is_dangerous() -> void:
	if not _require_port():
		return
	_set_condition(6, 10, true)
	var request := _request()
	request["action_receipt"]["condition_after"]["pressure"] = 9
	var before: Dictionary = _game_state.to_save_dict().duplicate(true)
	var result: Dictionary = _port.evaluate(request)
	assert_true(result.get("ok", false), str(result))
	if not result.get("ok", false):
		return
	var condition: Dictionary = result["value"]["condition_receipt"]
	assert_eq(condition["condition_after"], {"health": 6, "pressure": 9, "carried_sequela": true})
	assert_false(condition["danger"])
	assert_false(condition["trigger"])
	assert_eq(condition["decision"], "no_departure",
		"prepared relief leaves danger before the source changes live pressure")
	assert_eq(result["value"]["destination_intent"], null)
	assert_not_null(result["value"]["notification_intent"])
	assert_eq(_game_state.to_save_dict(), before, "evaluation remains read-only at live pressure 10")
