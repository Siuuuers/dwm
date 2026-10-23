extends "res://addons/gut/test.gd"
# Task 5 semantic playback boundary (Seven-Day Flow Plan 01 Task 5; dwm-oyo.2 DEVIATION-9,
# rulings R-AA through R-KK). RED-first discipline, controller ruling (e) adapted to instance
# methods: every new bridge method is reached DYNAMICALLY (has_method guard plus callv on the
# instance), so this suite compiles and fails by NAMED assertions while the production surface is
# still absent - zero SCRIPT_LOAD_FAILED, zero SUITE_NOT_EXECUTED. The two production ports are
# probed by path for the same reason. The fakes are standalone duck-types so they load at RED.
#
# Conditions 6 through 11 of the plan's RED list cannot be driven end to end from real timelines
# (the eight masters contain zero signal events), so they are driven by direct invocation of
# acknowledge_signal and the runtime signal seam - DEVIATION-9 item 10, the same
# fixture-reachability discipline as controller ruling (a).

const PROBE := preload("res://tests/support/DynamicScriptProbe.gd")
const BRIDGE := preload("res://autoload/DialogicBridge.gd")
const ADAPTER := preload("res://scripts/narrative/DialogicRuntimeAdapter.gd")
const FAKE_RUNTIME := preload("res://tests/support/FakeDialogicRuntime.gd")
const FAKE_SIGNAL_PORT := preload("res://tests/support/FakeDialogicSignalCommandPort.gd")
const FAKE_COMPLETION_PORT := preload("res://tests/support/FakeDialogicPlaybackCompletionPort.gd")
const CANONICAL_JSON := preload("res://scripts/validation/CanonicalJsonWriter.gd")

const SIGNAL_PORT_PATH := "res://scripts/application/narrative/DialogicSignalCommandPort.gd"
const COMPLETION_PORT_PATH := "res://scripts/application/narrative/DialogicPlaybackCompletionPort.gd"

const LAVINIA_ENTRY := "contact.ordinary.lavinia.day1"
const LAVINIA_MASTER := "res://dialogic/timelines/en/contacts/lavinia_day1.dtl"
const LAVINIA_LINE_A := "line.contact.ordinary.lavinia.day1.reply.a"
const LAVINIA_LINE_B := "line.contact.ordinary.lavinia.day1.reply.b"
const PAIR_ENTRY := "dating.group.priscilla_lavinia.day2.post_challenge"
const PAIR_ATOM := "atom.pair.day2.group.full"

const RECEIPT_KEYS := ["content_version", "context_fingerprint", "entry_id", "label", "path", "playback_token", "used_fallback"]
const INTENT_KEYS := ["completion_kind", "context_fingerprint", "entry_id", "execution_mode", "playback_token", "stage", "transaction_id"]


## A catalog double that reports a declared locale fallback: the requested locale was unavailable,
## so the EXACT English locator answers with used_fallback true (specification 14.1 / Ruling W).
class FallbackLocatorCatalog:
	static func get_entry(entry_id: String, _locale: String = "") -> Dictionary:
		return {"ok": true, "value": {
			"entry_id": entry_id, "locale": "en", "requested_locale": "zh_HK",
			"path": "res://dialogic/timelines/en/contacts/lavinia_day1.dtl", "label": entry_id, "used_fallback": true,
		}}


## A catalog double whose locator names a master that is not on disk (starts-nothing law, 14.1).
class MissingMasterCatalog:
	static func get_entry(entry_id: String, _locale: String = "") -> Dictionary:
		return {"ok": true, "value": {
			"entry_id": entry_id, "locale": "en", "requested_locale": "en",
			"path": "res://dialogic/timelines/en/fixture_missing_master.dtl", "label": entry_id,
			"used_fallback": false,
		}}


## A catalog double that resolves an id the shipped entry document does not register, so the
## bridge's own record lookup (content_version) must fail closed rather than invent a record.
class GhostRecordCatalog:
	static func get_entry(entry_id: String, _locale: String = "") -> Dictionary:
		return {"ok": true, "value": {
			"entry_id": entry_id, "locale": "en", "requested_locale": "en",
			"path": "res://dialogic/timelines/en/contacts/lavinia_day1.dtl", "label": entry_id, "used_fallback": false,
		}}


## A catalog double that violates the seam contract outright, so the bridge's non-dictionary
## guard on the resolution seam is a reachable law rather than decoration.
class NullResolutionCatalog:
	static func get_entry(_entry_id: String, _locale: String = "") -> Variant:
		return null


func _make_bridge(catalog: Script = null, adapter: RefCounted = null) -> Node:
	var bridge: Node = BRIDGE.new()
	add_child_autofree(bridge)
	var initialized: Dictionary = bridge.initialize(catalog, adapter)
	assert_true(initialized.get("ok", false), "bridge initializes: " + str(initialized))
	return bridge


func _rig(catalog: Script = null, with_signal_port := true, with_completion_port := true) -> Dictionary:
	var runtime: Node = autofree(FAKE_RUNTIME.new())
	var adapter: RefCounted = ADAPTER.new()
	assert_true(adapter.bind_runtime(runtime).get("ok", false), "the fake runtime binds")
	var bridge: Node = _make_bridge(catalog, adapter)
	var signal_port: RefCounted = FAKE_SIGNAL_PORT.new()
	var completion_port: RefCounted = FAKE_COMPLETION_PORT.new()
	if with_signal_port and bridge.has_method("configure_signal_command_port"):
		bridge.call(&"configure_signal_command_port", signal_port)
	if with_completion_port and bridge.has_method("configure_playback_completion_port"):
		bridge.call(&"configure_playback_completion_port", completion_port)
	return {"bridge": bridge, "runtime": runtime, "adapter": adapter,
		"signal_port": signal_port, "completion_port": completion_port}


func _requires_entry_api(bridge: Node) -> bool:
	for method_name: String in ["start_entry", "resume_entry", "acknowledge_signal", "abort_current_entry"]:
		if not bridge.has_method(method_name):
			assert_true(false, "DialogicBridge must declare %s (Task 5 surface)" % method_name)
			return false
	return true


func _invoke(bridge: Node, method_name: StringName, arguments: Array) -> Dictionary:
	var result: Variant = bridge.callv(method_name, arguments)
	return result if typeof(result) == TYPE_DICTIONARY else {}


func _context(stage: String, marker: String) -> Dictionary:
	return {
		"expected_stage": stage,
		"playback_id": "boundary-" + marker,
		"role": "primary",
		"transaction_id": "tx-" + marker,
	}


func _start(rig: Dictionary, entry_id: String, stage: String, marker: String,
		mode: StringName = &"canonical") -> Dictionary:
	return _invoke(rig["bridge"], &"start_entry", [entry_id, _context(stage, marker), mode])


func _token(started: Dictionary) -> String:
	return str((started.get("receipt", {}) as Dictionary).get("playback_token", ""))


func _witness_payload(token: String, receipt_id: String, line_id: String = LAVINIA_LINE_A) -> Dictionary:
	return {"entry_id": LAVINIA_ENTRY, "line_id": line_id, "playback_token": token, "receipt_id": receipt_id}


func test_the_two_production_ports_exist_with_fail_closed_defaults() -> void:
	var both_present := true
	for path: String in [SIGNAL_PORT_PATH, COMPLETION_PORT_PATH]:
		var loaded: Dictionary = PROBE.load_script(path)
		assert_true(loaded.get("ok", false), "%s: %s" % [path, str(loaded)])
		both_present = both_present and loaded.get("ok", false)
	if not both_present:
		return
	var command_port: Variant = PROBE.instantiate(SIGNAL_PORT_PATH)["value"]
	var refused: Dictionary = command_port.commit_signal("entry", &"current_entry", "signal.id", {}, &"canonical")
	assert_false(refused.get("ok", true), "an unconfigured signal command port fails closed")
	assert_eq(str(refused.get("code", "")), "not_configured", str(refused))
	assert_false(str(refused.get("message", "")).is_empty(), "the signal refusal carries a message")
	var completion_port: Variant = PROBE.instantiate(COMPLETION_PORT_PATH)["value"]
	var dropped: Dictionary = completion_port.complete_entry({"entry_id": "entry"})
	assert_false(dropped.get("ok", true), "an unconfigured completion port fails closed")
	assert_eq(str(dropped.get("code", "")), "not_configured", str(dropped))
	assert_false(str(dropped.get("message", "")).is_empty(), "the completion refusal carries a message")


func test_each_port_configures_exactly_once() -> void:
	var bridge := _make_bridge()
	var table: Array = [
		["configure_signal_command_port", FAKE_SIGNAL_PORT, "invalid_signal_command_port", "signal_command_port_already_configured"],
		["configure_playback_completion_port", FAKE_COMPLETION_PORT, "invalid_playback_completion_port", "playback_completion_port_already_configured"],
	]
	for row: Array in table:
		var method := str(row[0])
		if not bridge.has_method(method):
			assert_true(false, "DialogicBridge must declare " + method)
			continue
		var rejected: Dictionary = _invoke(bridge, method, [null])
		assert_eq(str(rejected.get("code", "")), str(row[2]), method + " refuses a null port")
		var methodless: Dictionary = _invoke(bridge, method, [RefCounted.new()])
		assert_eq(str(methodless.get("code", "")), str(row[2]), method + " refuses a port without the method")
		var port: RefCounted = (row[1] as Script).new()
		var first: Dictionary = _invoke(bridge, method, [port])
		assert_true(first.get("ok", false), method + " accepts the first port: " + str(first))
		assert_false(bool((first.get("value", {}) as Dictionary).get("already_configured", true)),
			method + " reports a fresh configuration")
		var again: Dictionary = _invoke(bridge, method, [port])
		assert_true(again.get("ok", false), method + " tolerates the identical instance")
		assert_true(bool((again.get("value", {}) as Dictionary).get("already_configured", false)),
			method + " reports the repeat")
		var replaced: Dictionary = _invoke(bridge, method, [(row[1] as Script).new()])
		assert_eq(str(replaced.get("code", "")), str(row[3]), method + " rejects a replacement instance")


func test_start_entry_starts_the_master_at_the_exact_label() -> void:
	var rig := _rig()
	var bridge: Node = rig["bridge"]
	if not _requires_entry_api(bridge):
		return
	var started := _start(rig, LAVINIA_ENTRY, "current_entry", "c1")
	assert_true(started.get("ok", false), str(started))
	assert_eq(str(started.get("code", "")), "started", "the success envelope follows _start_playback")
	var receipt: Dictionary = started.get("receipt", {})
	var keys: Array = receipt.keys()
	keys.sort()
	assert_eq(keys, RECEIPT_KEYS, "the receipt carries exactly the plan's seven semantic fields")
	assert_eq(str(receipt.get("entry_id", "")), LAVINIA_ENTRY, "the receipt names the entry")
	assert_eq(str(receipt.get("path", "")), LAVINIA_MASTER, "the entry resolves to its master")
	assert_eq(str(receipt.get("label", "")), LAVINIA_ENTRY, "the label is the semantic entry id")
	assert_eq(int(receipt.get("content_version", 0)), 1, "content_version comes from the entry record")
	assert_false(bool(receipt.get("used_fallback", true)), "the default locale is not a fallback")
	assert_true(str(receipt.get("playback_token", "")).begins_with("playback-"),
		"the token is the process-local playback counter")
	var runtime: Node = rig["runtime"]
	assert_true(runtime.calls.has("start:%s:%s" % [LAVINIA_MASTER, LAVINIA_ENTRY]),
		"the runtime received the two-argument labelled start: " + str(runtime.calls))


func test_start_entry_emits_the_clear_boundary_step_before_the_labelled_start() -> void:
	var rig := _rig()
	var bridge: Node = rig["bridge"]
	if not _requires_entry_api(bridge):
		return
	var steps: Array = []
	bridge.preference_boundary_step.connect(func(step_id: StringName) -> void: steps.append(step_id))
	var started := _start(rig, LAVINIA_ENTRY, "current_entry", "clear")
	assert_true(started.get("ok", false), str(started))
	assert_eq(steps, [&"clear"], "the adapter branch announces the clear boundary (R-BB)")
	var runtime: Node = rig["runtime"]
	var clear_index: int = runtime.calls.find("clear:1")
	var start_index: int = runtime.calls.find("start:%s:%s" % [LAVINIA_MASTER, LAVINIA_ENTRY])
	assert_true(clear_index >= 0 and start_index > clear_index,
		"the physical clear precedes the labelled start: " + str(runtime.calls))


func test_the_start_context_is_frozen_at_start() -> void:
	var rig := _rig()
	var bridge: Node = rig["bridge"]
	if not _requires_entry_api(bridge):
		return
	var context := _context("current_entry", "immutable")
	var canonical: Dictionary = CANONICAL_JSON.stringify(context.duplicate(true))
	assert_true(canonical.get("ok", false), "the fixture context canonicalizes")
	var expected_fingerprint: String = str(canonical.get("value", "")).sha256_text()
	var started := _invoke(bridge, &"start_entry", [LAVINIA_ENTRY, context, &"canonical"])
	assert_true(started.get("ok", false), str(started))
	assert_eq(str((started.get("receipt", {}) as Dictionary).get("context_fingerprint", "")),
		expected_fingerprint, "the receipt fingerprint is the canonical sha256 of the frozen context")
	context["expected_stage"] = "hacked_stage"
	context["transaction_id"] = "hacked_transaction"
	(rig["runtime"] as Node).timeline_ended.emit()
	var intents: Array = (rig["completion_port"] as RefCounted).intents
	assert_eq(intents.size(), 1, "natural completion reaches the configured port exactly once")
	if intents.size() != 1:
		return
	var intent: Dictionary = intents[0]
	var intent_keys: Array = intent.keys()
	intent_keys.sort()
	assert_eq(intent_keys, INTENT_KEYS, "the intent carries exactly the plan's primitive keys")
	assert_eq(str(intent.get("context_fingerprint", "")), expected_fingerprint,
		"caller mutation after start cannot reach the frozen context")
	assert_eq(str(intent.get("stage", "")), "current_entry",
		"the stage is the validated expected_stage, not the mutated one")
	assert_eq(str(intent.get("transaction_id", "")), "tx-immutable", "the transaction id is the frozen one")
	assert_eq(str(intent.get("completion_kind", "")), "natural_end", "physical completion reports natural_end")
	assert_eq(str(intent.get("execution_mode", "")), "canonical", "the intent reports the playback mode")
	assert_eq(str(intent.get("entry_id", "")), LAVINIA_ENTRY, "the intent names the semantic entry")


func test_locale_fallback_propagates_the_exact_english_locator() -> void:
	var rig := _rig(FallbackLocatorCatalog)
	var bridge: Node = rig["bridge"]
	if not _requires_entry_api(bridge):
		return
	var started := _start(rig, LAVINIA_ENTRY, "current_entry", "fallback")
	assert_true(started.get("ok", false), str(started))
	var receipt: Dictionary = started.get("receipt", {})
	assert_true(bool(receipt.get("used_fallback", false)),
		"a declared locale fallback is reported, never hidden")
	assert_eq(str(receipt.get("path", "")), LAVINIA_MASTER,
		"the fallback is the EXACT English master, never a manufactured locale path")
	assert_eq(str(receipt.get("label", "")), LAVINIA_ENTRY, "the fallback keeps the exact English label")
	var runtime: Node = rig["runtime"]
	assert_true(runtime.calls.has("start:%s:%s" % [LAVINIA_MASTER, LAVINIA_ENTRY]),
		"the fallback start is the English locator verbatim")


func test_one_active_entry_with_fresh_tokens_after_abort() -> void:
	var rig := _rig()
	var bridge: Node = rig["bridge"]
	if not _requires_entry_api(bridge):
		return
	var first := _start(rig, LAVINIA_ENTRY, "current_entry", "one-a")
	assert_true(first.get("ok", false), str(first))
	var second := _start(rig, PAIR_ENTRY, "after_full_observation_atom", "one-b")
	assert_false(second.get("ok", true), "a second start while one entry is active must fail")
	assert_eq(str(second.get("code", "")), "entry_already_active", str(second))
	assert_true(str(second.get("message", "")).contains("still active"),
		"the refusal names the standing playback: " + str(second))
	var aborted := _invoke(bridge, &"abort_current_entry", [&"one_active_check"])
	assert_true(aborted.get("ok", false), str(aborted))
	var third := _start(rig, LAVINIA_ENTRY, "current_entry", "one-c")
	assert_true(third.get("ok", false), "after an abort a fresh start succeeds: " + str(third))
	assert_ne(_token(third), _token(first), "every playback issues a fresh process-local token")


func test_a_stale_completion_reaches_no_port() -> void:
	var rig := _rig()
	var bridge: Node = rig["bridge"]
	if not _requires_entry_api(bridge):
		return
	var first := _start(rig, LAVINIA_ENTRY, "current_entry", "stale-a")
	assert_true(first.get("ok", false), str(first))
	var aborted := _invoke(bridge, &"abort_current_entry", [&"stale_check"])
	assert_true(aborted.get("ok", false), str(aborted))
	(rig["runtime"] as Node).timeline_ended.emit()
	var completion_port: RefCounted = rig["completion_port"]
	assert_eq(completion_port.intents.size(), 0,
		"an aborted playback's physical end reaches NO port - the count is pinned, not the silence")
	var second := _start(rig, LAVINIA_ENTRY, "current_entry", "stale-b")
	assert_true(second.get("ok", false), str(second))
	(rig["runtime"] as Node).timeline_ended.emit()
	assert_eq(completion_port.intents.size(), 1, "only the live playback completes")
	if completion_port.intents.size() == 1:
		assert_eq(str((completion_port.intents[0] as Dictionary).get("playback_token", "")),
			_token(second), "the intent carries the live token, never the aborted one")


func test_an_unknown_signal_is_refused() -> void:
	var rig := _rig()
	var bridge: Node = rig["bridge"]
	if not _requires_entry_api(bridge):
		return
	var started := _start(rig, LAVINIA_ENTRY, "current_entry", "unknown-signal")
	assert_true(started.get("ok", false), str(started))
	var payload := {"entry_id": LAVINIA_ENTRY, "playback_token": _token(started), "receipt_id": "r-unknown"}
	var refused := _invoke(bridge, &"acknowledge_signal", ["no.such.signal", payload])
	assert_eq(str(refused.get("code", "")), "SIGNAL_UNKNOWN_SIGNAL", str(refused))
	assert_true(str(refused.get("message", "")).contains("not a registered signal"), str(refused))
	assert_eq((rig["signal_port"] as RefCounted).calls.size(), 0, "no port sees an unknown signal")


func test_a_wrong_payload_is_refused() -> void:
	var rig := _rig()
	var bridge: Node = rig["bridge"]
	if not _requires_entry_api(bridge):
		return
	var started := _start(rig, LAVINIA_ENTRY, "current_entry", "payload")
	assert_true(started.get("ok", false), str(started))
	var token := _token(started)
	var missing := _witness_payload(token, "r-missing")
	missing.erase("receipt_id")
	var refused_missing := _invoke(bridge, &"acknowledge_signal", ["history.line.witness", missing])
	assert_eq(str(refused_missing.get("code", "")), "SIGNAL_PAYLOAD_FIELD_MISSING", str(refused_missing))
	assert_true(str(refused_missing.get("message", "")).contains("omits receipt_id"), str(refused_missing))
	var extra := _witness_payload(token, "r-extra")
	extra["surprise_field"] = "boo"
	var refused_extra := _invoke(bridge, &"acknowledge_signal", ["history.line.witness", extra])
	assert_eq(str(refused_extra.get("code", "")), "SIGNAL_PAYLOAD_FIELD_UNKNOWN", str(refused_extra))
	assert_true(str(refused_extra.get("message", "")).contains("surprise_field"), str(refused_extra))
	assert_eq((rig["signal_port"] as RefCounted).calls.size(), 0, "no port sees a malformed payload")


func test_a_forbidden_source_stage_is_refused() -> void:
	var rig := _rig()
	var bridge: Node = rig["bridge"]
	if not _requires_entry_api(bridge):
		return
	var started := _start(rig, LAVINIA_ENTRY, "current_entry", "stage")
	assert_true(started.get("ok", false), str(started))
	var payload := {
		"entry_id": LAVINIA_ENTRY, "playback_token": _token(started), "receipt_id": "r-stage",
		"reply_id": "reply.ordinary.lavinia.day1.a", "witnessed_line_id": LAVINIA_LINE_A,
	}
	var refused := _invoke(bridge, &"acknowledge_signal", ["message.reply.commit", payload])
	assert_eq(str(refused.get("code", "")), "SIGNAL_STAGE_NOT_ALLOWED", str(refused))
	assert_true(str(refused.get("message", "")).contains("not a legal source stage"), str(refused))
	assert_eq((rig["signal_port"] as RefCounted).calls.size(), 0,
		"message.reply.commit may only rise from awaiting_reply, and the port never sees the attempt")


func test_a_duplicate_identical_receipt_replays_the_stored_receipt() -> void:
	var rig := _rig()
	var bridge: Node = rig["bridge"]
	if not _requires_entry_api(bridge):
		return
	var started := _start(rig, LAVINIA_ENTRY, "current_entry", "dup")
	assert_true(started.get("ok", false), str(started))
	var payload := _witness_payload(_token(started), "r-dup")
	var first := _invoke(bridge, &"acknowledge_signal", ["history.line.witness", payload])
	assert_true(first.get("ok", false), str(first))
	assert_false(bool((first.get("value", {}) as Dictionary).get("duplicate", true)), str(first))
	var receipt: Dictionary = first.get("receipt", {})
	var keys: Array = receipt.keys()
	keys.sort()
	assert_eq(keys, ["entry_id", "playback_token", "receipt_id", "signal_id", "stage"],
		"the acknowledge receipt carries its exact fields")
	var replay := _invoke(bridge, &"acknowledge_signal", ["history.line.witness", payload.duplicate(true)])
	assert_true(replay.get("ok", false), str(replay))
	assert_true(bool((replay.get("value", {}) as Dictionary).get("duplicate", false)),
		"an identical replay reports duplicate")
	assert_eq(replay.get("receipt", {}), receipt, "the replay returns the STORED receipt verbatim")
	assert_eq((rig["signal_port"] as RefCounted).calls.size(), 1,
		"the state owner is invoked exactly once for one receipt id")


func test_a_conflicting_receipt_mutates_nothing() -> void:
	var rig := _rig()
	var bridge: Node = rig["bridge"]
	if not _requires_entry_api(bridge):
		return
	var started := _start(rig, LAVINIA_ENTRY, "current_entry", "conflict")
	assert_true(started.get("ok", false), str(started))
	var original := _witness_payload(_token(started), "r-conflict", LAVINIA_LINE_A)
	var first := _invoke(bridge, &"acknowledge_signal", ["history.line.witness", original])
	assert_true(first.get("ok", false), str(first))
	var conflicting := _witness_payload(_token(started), "r-conflict", LAVINIA_LINE_B)
	var refused := _invoke(bridge, &"acknowledge_signal", ["history.line.witness", conflicting])
	assert_false(refused.get("ok", true), "a receipt id cannot be reused with different bytes")
	assert_eq(str(refused.get("code", "")), "duplicate_transaction_conflict", str(refused))
	assert_true(str(refused.get("message", "")).contains("r-conflict"), str(refused))
	assert_eq((rig["signal_port"] as RefCounted).calls.size(), 1, "the conflict reaches no port")
	var replay := _invoke(bridge, &"acknowledge_signal", ["history.line.witness", original.duplicate(true)])
	assert_true(replay.get("ok", false), "the stored receipt survives the conflict untouched")
	assert_true(bool((replay.get("value", {}) as Dictionary).get("duplicate", false)), str(replay))


func test_rehearsal_denies_the_state_capable_commit() -> void:
	var rig := _rig()
	var bridge: Node = rig["bridge"]
	if not _requires_entry_api(bridge):
		return
	var rehearsed := _start(rig, PAIR_ENTRY, "after_full_observation_atom", "rehearse", &"rehearsal")
	assert_true(rehearsed.get("ok", false), "rehearsal may start a granted entry: " + str(rehearsed))
	var payload := {
		"combination_id": "combo-boundary", "entry_id": PAIR_ENTRY,
		"playback_token": _token(rehearsed), "presentation_atom_id": PAIR_ATOM,
		"receipt_id": "r-rehearsal",
	}
	var denied := _invoke(bridge, &"acknowledge_signal", ["pair.combination.witness", payload])
	assert_false(denied.get("ok", true), "rehearsal may not commit a state-capable signal")
	assert_eq(str(denied.get("code", "")), "rehearsal_commit_denied", str(denied))
	assert_true(str(denied.get("message", "")).contains("rehearsal"),
		"the denial names the rehearsal mode, distinguishing it from every grant refusal (R-HH)")
	assert_eq((rig["signal_port"] as RefCounted).calls.size(), 0, "the denial reaches no port")
	var aborted := _invoke(bridge, &"abort_current_entry", [&"rehearsal_done"])
	assert_true(aborted.get("ok", false), str(aborted))
	var canonical := _start(rig, PAIR_ENTRY, "after_full_observation_atom", "canonical")
	assert_true(canonical.get("ok", false), str(canonical))
	var canonical_payload := payload.duplicate(true)
	canonical_payload["playback_token"] = _token(canonical)
	canonical_payload["receipt_id"] = "r-canonical"
	var committed := _invoke(bridge, &"acknowledge_signal", ["pair.combination.witness", canonical_payload])
	assert_true(committed.get("ok", false),
		"the SAME payload commits in canonical mode, so only the mode was denied: " + str(committed))
	assert_eq((rig["signal_port"] as RefCounted).calls.size(), 1, "canonical commit reaches the port")


func test_acknowledge_requires_an_active_entry_and_a_live_token() -> void:
	var rig := _rig()
	var bridge: Node = rig["bridge"]
	if not _requires_entry_api(bridge):
		return
	var idle := _invoke(bridge, &"acknowledge_signal", ["history.line.witness", _witness_payload("playback-1", "r-idle")])
	assert_eq(str(idle.get("code", "")), "no_active_entry", str(idle))
	var started := _start(rig, LAVINIA_ENTRY, "current_entry", "token")
	assert_true(started.get("ok", false), str(started))
	var stale := _invoke(bridge, &"acknowledge_signal", ["history.line.witness", _witness_payload("playback-9999", "r-stale")])
	assert_eq(str(stale.get("code", "")), "stale_playback_token", str(stale))
	assert_true(str(stale.get("message", "")).contains("playback-9999"), str(stale))
	assert_eq((rig["signal_port"] as RefCounted).calls.size(), 0, "no port sees a stale token")


func test_abort_reports_aborted_and_never_natural_end() -> void:
	var rig := _rig()
	var bridge: Node = rig["bridge"]
	if not _requires_entry_api(bridge):
		return
	var idle := _invoke(bridge, &"abort_current_entry", [&"nothing_running"])
	assert_eq(str(idle.get("code", "")), "no_active_entry", str(idle))
	var started := _start(rig, LAVINIA_ENTRY, "current_entry", "abort")
	assert_true(started.get("ok", false), str(started))
	var aborted := _invoke(bridge, &"abort_current_entry", [&"player_quit"])
	assert_true(aborted.get("ok", false), str(aborted))
	assert_eq(str(aborted.get("code", "")), "aborted", str(aborted))
	var receipt: Dictionary = aborted.get("receipt", {})
	assert_eq(str(receipt.get("entry_id", "")), LAVINIA_ENTRY, "the abort names the entry")
	assert_eq(str(receipt.get("playback_token", "")), _token(started), "the abort names the token")
	assert_eq(str(receipt.get("completion_kind", "")), "aborted",
		"an abort can never masquerade as natural completion")
	assert_eq(str(receipt.get("reason_code", "")), "player_quit", "the caller's reason survives")
	assert_eq((rig["completion_port"] as RefCounted).intents.size(), 0, "the completion port is NOT called")
	assert_true((rig["runtime"] as Node).calls.has("end_timeline:true"),
		"the physical playback is halted, not left running")


func test_resume_entry_revalidates_and_issues_a_fresh_token() -> void:
	var rig := _rig()
	var bridge: Node = rig["bridge"]
	if not _requires_entry_api(bridge):
		return
	var started := _start(rig, LAVINIA_ENTRY, "current_entry", "resume")
	assert_true(started.get("ok", false), str(started))
	var old_token := _token(started)
	(rig["runtime"] as Node).timeline_ended.emit()
	assert_eq((rig["completion_port"] as RefCounted).intents.size(), 1, "the first playback completed")
	var checkpoint := {
		"content_version": 1,
		"entry_id": LAVINIA_ENTRY,
		"frozen_context": _context("current_entry", "resume"),
		"stage": "current_entry",
		"transaction_id": "tx-resume",
	}
	var resumed := _invoke(bridge, &"resume_entry", [checkpoint, &"canonical"])
	assert_true(resumed.get("ok", false), str(resumed))
	assert_eq(str(resumed.get("code", "")), "started", "resume follows the started envelope")
	var fresh_token := _token(resumed)
	assert_true(fresh_token.begins_with("resume-"), "restore issues a fresh resume token: " + fresh_token)
	assert_ne(fresh_token, old_token, "an old-process token is never reissued")
	var runtime: Node = rig["runtime"]
	assert_eq(runtime.calls.count("start:%s:%s" % [LAVINIA_MASTER, LAVINIA_ENTRY]), 2,
		"resume physically starts the exact master and label again")
	var stale := _invoke(bridge, &"acknowledge_signal", ["history.line.witness", _witness_payload(old_token, "r-old")])
	assert_eq(str(stale.get("code", "")), "stale_playback_token",
		"the pre-resume token is stale by exact string equality")


func test_resume_rejects_checkpoint_defects() -> void:
	var rig := _rig()
	var bridge: Node = rig["bridge"]
	if not _requires_entry_api(bridge):
		return
	var wrong_keys := _invoke(bridge, &"resume_entry", [{"entry_id": LAVINIA_ENTRY}, &"canonical"])
	assert_eq(str(wrong_keys.get("code", "")), "invalid_resume_checkpoint", str(wrong_keys))
	var base := {
		"content_version": 1, "entry_id": LAVINIA_ENTRY,
		"frozen_context": _context("current_entry", "defect"),
		"stage": "current_entry", "transaction_id": "tx-defect",
	}
	var drifted: Dictionary = base.duplicate(true)
	drifted["content_version"] = 999
	var version := _invoke(bridge, &"resume_entry", [drifted, &"canonical"])
	assert_eq(str(version.get("code", "")), "entry_content_version_mismatch", str(version))
	assert_true(str(version.get("message", "")).contains("999"), str(version))
	var wrong_stage: Dictionary = base.duplicate(true)
	wrong_stage["stage"] = "awaiting_reply"
	var stage := _invoke(bridge, &"resume_entry", [wrong_stage, &"canonical"])
	assert_eq(str(stage.get("code", "")), "resume_stage_mismatch", str(stage))
	var wrong_transaction: Dictionary = base.duplicate(true)
	wrong_transaction["transaction_id"] = "tx-other"
	var transaction := _invoke(bridge, &"resume_entry", [wrong_transaction, &"canonical"])
	assert_eq(str(transaction.get("code", "")), "resume_transaction_mismatch", str(transaction))
	var unknown: Dictionary = base.duplicate(true)
	unknown["entry_id"] = "contact.ordinary.nobody.day9"
	var unknown_result := _invoke(bridge, &"resume_entry", [unknown, &"canonical"])
	assert_eq(str(unknown_result.get("code", "")), "ENTRY_MANIFEST_UNKNOWN_ENTRY", str(unknown_result))
	var retired: Dictionary = base.duplicate(true)
	retired["entry_id"] = "ending.lavinia.true"
	var retired_result := _invoke(bridge, &"resume_entry", [retired, &"canonical"])
	assert_eq(str(retired_result.get("code", "")), "ENTRY_MANIFEST_RETIRED_ENTRY", str(retired_result))
	assert_true(str(retired_result.get("message", "")).contains("retired"), str(retired_result))
	var bad_mode := _invoke(bridge, &"resume_entry", [base.duplicate(true), &"debug"])
	assert_eq(str(bad_mode.get("code", "")), "invalid_execution_mode", str(bad_mode))
	var bad_frozen: Dictionary = base.duplicate(true)
	bad_frozen["frozen_context"] = {"expected_stage": "current_entry"}
	var frozen_refused := _invoke(bridge, &"resume_entry", [bad_frozen, &"canonical"])
	assert_eq(str(frozen_refused.get("code", "")), "invalid_playback_context", str(frozen_refused))


func test_start_entry_rejects_bad_modes_contexts_and_unknown_ids() -> void:
	var rig := _rig()
	var bridge: Node = rig["bridge"]
	if not _requires_entry_api(bridge):
		return
	var bad_mode := _invoke(bridge, &"start_entry", [LAVINIA_ENTRY, _context("current_entry", "mode"), &"debug"])
	assert_eq(str(bad_mode.get("code", "")), "invalid_execution_mode", str(bad_mode))
	assert_true(str(bad_mode.get("message", "")).contains("debug"), str(bad_mode))
	var bad_context := _invoke(bridge, &"start_entry", [LAVINIA_ENTRY, {"expected_stage": "current_entry"}, &"canonical"])
	assert_eq(str(bad_context.get("code", "")), "invalid_playback_context", str(bad_context))
	var unknown := _invoke(bridge, &"start_entry", ["contact.ordinary.nobody.day9", _context("current_entry", "unknown"), &"canonical"])
	assert_eq(str(unknown.get("code", "")), "ENTRY_MANIFEST_UNKNOWN_ENTRY", str(unknown))
	assert_true(str(unknown.get("message", "")).contains("not a registered semantic entry"), str(unknown))
	var retired := _invoke(bridge, &"start_entry", ["ending.priscilla.true", _context("current_entry", "retired"), &"canonical"])
	assert_eq(str(retired.get("code", "")), "ENTRY_MANIFEST_RETIRED_ENTRY", str(retired))
	assert_true(str(retired.get("message", "")).contains("retired"), str(retired))
	var uncanonical := _invoke(bridge, &"start_entry", [LAVINIA_ENTRY, {
		"expected_stage": "current_entry", "playback_id": "boundary-canon",
		"role": "primary", "transaction_id": RefCounted.new(),
	}, &"canonical"])
	assert_eq(str(uncanonical.get("code", "")), "context_not_canonical",
		"a context the canonical writer refuses cannot start: " + str(uncanonical))
	var runtime: Node = rig["runtime"]
	for call: String in runtime.calls:
		assert_false(call.begins_with("start:"), "no rejection may start playback: " + call)


func test_a_missing_master_starts_nothing() -> void:
	var rig := _rig(MissingMasterCatalog)
	var bridge: Node = rig["bridge"]
	if not _requires_entry_api(bridge):
		return
	var refused := _start(rig, LAVINIA_ENTRY, "current_entry", "missing")
	assert_false(refused.get("ok", true), "a locator whose master is absent starts nothing (14.1)")
	assert_eq(str(refused.get("code", "")), "entry_master_missing", str(refused))
	var runtime: Node = rig["runtime"]
	for call: String in runtime.calls:
		assert_false(call.begins_with("start:"), "nothing starts on a missing master: " + call)
	var follow_up := _invoke(bridge, &"abort_current_entry", [&"should_be_idle"])
	assert_eq(str(follow_up.get("code", "")), "no_active_entry", "the refusal left no active playback")


func test_an_unregistered_record_fails_closed() -> void:
	var rig := _rig(GhostRecordCatalog)
	var bridge: Node = rig["bridge"]
	if not _requires_entry_api(bridge):
		return
	var refused := _start(rig, "fixture.ghost.entry", "current_entry", "ghost")
	assert_false(refused.get("ok", true), "an id outside the shipped document cannot start")
	assert_eq(str(refused.get("code", "")), "entry_record_missing", str(refused))
	var runtime: Node = rig["runtime"]
	for call: String in runtime.calls:
		assert_false(call.begins_with("start:"), "nothing starts without a registered record: " + call)
	var null_rig := _rig(NullResolutionCatalog)
	var broken := _start(null_rig, LAVINIA_ENTRY, "current_entry", "null-catalog")
	assert_eq(str(broken.get("code", "")), "entry_resolution_failed",
		"a seam that returns no dictionary fails closed: " + str(broken))


func test_port_rejection_pauses_playback_and_stores_nothing() -> void:
	var rig := _rig()
	var bridge: Node = rig["bridge"]
	if not _requires_entry_api(bridge):
		return
	var started := _start(rig, LAVINIA_ENTRY, "current_entry", "reject")
	assert_true(started.get("ok", false), str(started))
	var signal_port: RefCounted = rig["signal_port"]
	signal_port.next_result = {"ok": false, "code": &"consequence_rejected", "message": "owner said no", "details": {}}
	var payload := _witness_payload(_token(started), "r-reject")
	var refused := _invoke(bridge, &"acknowledge_signal", ["history.line.witness", payload])
	assert_false(refused.get("ok", true), str(refused))
	assert_eq(str(refused.get("code", "")), "consequence_rejected",
		"the state owner's rejection reaches the caller verbatim")
	assert_true(bool((rig["runtime"] as Node).paused),
		"a rejected boundary pauses playback so no consequence-dependent prose can show")
	assert_eq(signal_port.calls.size(), 1, "the rejection was a real port call")
	signal_port.next_result = {"ok": true, "code": &"ok", "value": {}, "receipt": {}}
	var retried := _invoke(bridge, &"acknowledge_signal", ["history.line.witness", payload.duplicate(true)])
	assert_true(retried.get("ok", false), str(retried))
	assert_false(bool((retried.get("value", {}) as Dictionary).get("duplicate", true)),
		"a rejected acknowledgement stored NOTHING, so the retry is fresh, not a replay")
	assert_eq(signal_port.calls.size(), 2, "the retry reaches the port again")


func test_completion_without_a_port_reports_misconfiguration() -> void:
	var rig := _rig(null, true, false)
	var bridge: Node = rig["bridge"]
	if not _requires_entry_api(bridge):
		return
	var failures: Array = []
	bridge.narrative_validation_failed.connect(func(result: Dictionary) -> void: failures.append(result.duplicate(true)))
	var started := _start(rig, LAVINIA_ENTRY, "current_entry", "no-port")
	assert_true(started.get("ok", false), str(started))
	(rig["runtime"] as Node).timeline_ended.emit()
	assert_eq(failures.size(), 1, "a completion with no configured port is reported, not swallowed")
	if failures.size() == 1:
		assert_eq(str((failures[0] as Dictionary).get("code", "")), "playback_completion_port_not_configured",
			str(failures[0]))
	(rig["runtime"] as Node).timeline_ended.emit()
	assert_eq(failures.size(), 1, "the entry cleared on the first end, so a duplicate end emits nothing")


func test_the_entry_surface_requires_initialization() -> void:
	var bridge: Node = BRIDGE.new()
	add_child_autofree(bridge)
	if not _requires_entry_api(bridge):
		return
	var started := _invoke(bridge, &"start_entry", [LAVINIA_ENTRY, _context("current_entry", "uninit"), &"canonical"])
	assert_eq(str(started.get("code", "")), "not_initialized", str(started))
	var resumed := _invoke(bridge, &"resume_entry", [{
		"content_version": 1, "entry_id": LAVINIA_ENTRY,
		"frozen_context": _context("current_entry", "uninit"),
		"stage": "current_entry", "transaction_id": "tx-uninit",
	}, &"canonical"])
	assert_eq(str(resumed.get("code", "")), "not_initialized", str(resumed))


func test_an_active_ending_playback_also_blocks_a_semantic_start() -> void:
	var rig := _rig()
	var bridge: Node = rig["bridge"]
	if not _requires_entry_api(bridge):
		return
	var ending: Dictionary = bridge.start_ending_id("ending.sylvia.special", {
		"expected_stage": "PRIMARY_PENDING", "playback_id": "run:primary",
		"role": "primary", "transaction_id": "run:primary:complete",
	})
	assert_true(ending.get("ok", false), str(ending))
	var refused := _start(rig, LAVINIA_ENTRY, "current_entry", "ending-active")
	assert_eq(str(refused.get("code", "")), "entry_already_active",
		"the one-active-playback law spans both vocabularies: " + str(refused))


func test_an_active_semantic_entry_blocks_an_ending_start() -> void:
	# Reviewer I-1: the one-active law is BIDIRECTIONAL. The forward direction (ending blocks
	# entry) is pinned above; this pins the reverse, so no ending can cancel a live semantic
	# entry and later masquerade its completion through the entry branch.
	var rig := _rig()
	var bridge: Node = rig["bridge"]
	if not _requires_entry_api(bridge):
		return
	var started := _start(rig, LAVINIA_ENTRY, "current_entry", "excl-a")
	assert_true(started.get("ok", false), str(started))
	var ending: Dictionary = bridge.start_ending_id("ending.sylvia.special", {
		"expected_stage": "PRIMARY_PENDING", "playback_id": "run:primary",
		"role": "primary", "transaction_id": "run:primary:complete",
	})
	assert_false(ending.get("ok", true), "an ending may not cancel a live semantic entry")
	assert_eq(str(ending.get("code", "")), "entry_already_active", str(ending))
	(rig["runtime"] as Node).timeline_ended.emit()
	assert_eq((rig["completion_port"] as RefCounted).intents.size(), 1,
		"the live semantic entry still completes normally after the refused ending")


func test_an_active_semantic_entry_blocks_a_legacy_timeline_start() -> void:
	# Reviewer I-1, second half: the legacy id surface remains on the presentation owner adapter,
	# so it must refuse too - in its own
	# legacy failure shape - rather than physically replacing the semantic playback.
	var rig := _rig()
	var bridge: Node = rig["bridge"]
	if not _requires_entry_api(bridge):
		return
	var failures: Array = []
	bridge.timeline_failed.connect(func(result: Dictionary) -> void: failures.append(result.duplicate(true)))
	var started := _start(rig, LAVINIA_ENTRY, "current_entry", "excl-b")
	assert_true(started.get("ok", false), str(started))
	var legacy: Dictionary = bridge.start_timeline_id("hospital.faint", {"kind": "hospital"})
	if legacy.get("ok", false):
		# RED-phase tidy-up only: never leave a physically started timeline running.
		var dialogic := bridge.get_node_or_null("/root/Dialogic")
		if dialogic != null and dialogic.has_method("clear"):
			dialogic.call("clear", 1)
	assert_false(legacy.get("ok", true), "a legacy id start may not cancel a live semantic entry")
	assert_eq(str(legacy.get("reason", "")), "semantic_entry_active",
		"the legacy surface refuses in its own legacy shape: " + str(legacy))
	assert_eq(failures.size(), 1, "the refusal is announced on timeline_failed")
	var completion_port: RefCounted = rig["completion_port"]
	(rig["runtime"] as Node).timeline_ended.emit()
	assert_eq(completion_port.intents.size(), 1, "the live entry still completes with its own intent")
	if completion_port.intents.size() == 1:
		assert_eq(str((completion_port.intents[0] as Dictionary).get("entry_id", "")), LAVINIA_ENTRY,
			"the completion belongs to the semantic entry, never the refused legacy start")


func test_an_ending_completion_clears_the_retained_timeline_and_abort_stays_silent() -> void:
	# Reviewer I-2: _start_playback retains its timeline id, and before this law the ending
	# branch consumed the end signal WITHOUT clearing it - so a later semantic abort's halt
	# provoked the generic branch into a phantom timeline_finished for a timeline that never
	# finished. The completion an abort provokes must be silent everywhere.
	var rig := _rig()
	var bridge: Node = rig["bridge"]
	if not _requires_entry_api(bridge):
		return
	var finished: Array = []
	bridge.timeline_finished.connect(func(timeline_id: String, _result: Dictionary) -> void: finished.append(timeline_id))
	var ending: Dictionary = bridge.start_ending_id("ending.sylvia.special", {
		"expected_stage": "PRIMARY_PENDING", "playback_id": "run:primary",
		"role": "primary", "transaction_id": "run:primary:complete",
	})
	assert_true(ending.get("ok", false), str(ending))
	(rig["runtime"] as Node).timeline_ended.emit()
	assert_eq(bridge.get_current_timeline_id(), "",
		"the ending branch clears the timeline it retained at start")
	var started := _start(rig, LAVINIA_ENTRY, "current_entry", "post-ending")
	assert_true(started.get("ok", false), "after a completed ending a semantic entry may start: " + str(started))
	var aborted := _invoke(bridge, &"abort_current_entry", [&"player_quit"])
	assert_true(aborted.get("ok", false), str(aborted))
	assert_true(finished.is_empty(),
		"an abort can never provoke a phantom legacy timeline_finished: " + str(finished))


func test_a_refused_runtime_start_leaves_no_active_entry() -> void:
	var unbound_adapter: RefCounted = ADAPTER.new()
	var bridge: Node = _make_bridge(null, unbound_adapter)
	if not _requires_entry_api(bridge):
		return
	var refused := _invoke(bridge, &"start_entry", [LAVINIA_ENTRY, _context("current_entry", "unbound"), &"canonical"])
	assert_false(refused.get("ok", true), str(refused))
	assert_eq(str(refused.get("code", "")), "runtime_start_failed", str(refused))
	var follow_up := _invoke(bridge, &"abort_current_entry", [&"should_be_idle"])
	assert_eq(str(follow_up.get("code", "")), "no_active_entry", "a refused start left no active playback")


func test_signal_commit_without_a_port_fails_closed() -> void:
	var rig := _rig(null, false, true)
	var bridge: Node = rig["bridge"]
	if not _requires_entry_api(bridge):
		return
	var started := _start(rig, LAVINIA_ENTRY, "current_entry", "no-signal-port")
	assert_true(started.get("ok", false), str(started))
	var refused := _invoke(bridge, &"acknowledge_signal", ["history.line.witness", _witness_payload(_token(started), "r-no-port")])
	assert_false(refused.get("ok", true), str(refused))
	assert_eq(str(refused.get("code", "")), "signal_command_port_not_configured", str(refused))
	assert_true(str(refused.get("message", "")).contains("configure"), str(refused))
