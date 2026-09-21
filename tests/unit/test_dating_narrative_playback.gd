extends "res://addons/gut/test.gd"

const PLAYBACK := preload("res://scripts/application/run/DatingNarrativePlayback.gd")

class Bridge extends RefCounted:
	signal entry_playback_failed(playback_token: String, entry_id: String, result: Dictionary)
	var completion_port: Object
	var starts: Array[Dictionary] = []
	var active: Dictionary = {}
	var last_intent: Dictionary = {}
	var completion_result: Dictionary = {}
	var fail_start := false
	var complete_during_start := false
	var receipt_overrides: Dictionary = {}
	var allow_abort := false
	var abort_calls := 0

	func configure_playback_completion_port(port: Object) -> Dictionary:
		if completion_port != null and completion_port != port: return {"ok": false}
		completion_port = port
		return {"ok": true}

	func start_entry(entry_id: String, context: Dictionary, execution_mode: StringName = &"canonical") -> Dictionary:
		if not active.is_empty(): return {"ok": false, "code": &"fixture_playback_active"}
		starts.append({"entry_id": entry_id, "context": context.duplicate(true), "execution_mode": execution_mode})
		if fail_start: return {"ok": false, "code": &"fixture_start_failure"}
		var receipt := {"entry_id": entry_id, "playback_token": "playback-%d" % starts.size(),
			"context_fingerprint": JSON.stringify(context).sha256_text(), "content_version": 1}
		active = {"entry_id": entry_id, "transaction_id": context.transaction_id,
			"stage": context.expected_stage, "playback_token": receipt.playback_token,
			"context_fingerprint": receipt.context_fingerprint, "execution_mode": execution_mode,
			"completion_kind": &"natural_end"}
		if complete_during_start: finish()
		receipt.merge(receipt_overrides, true)
		return {"ok": true, "code": &"started", "value": {}, "receipt": receipt}

	func has_active_playback() -> bool:
		return not active.is_empty()

	func is_entry_playback_active(token: String, entry_id: String) -> bool:
		return active.get("playback_token") == token and active.get("entry_id") == entry_id

	func finish() -> Dictionary:
		last_intent = active.duplicate(true)
		active.clear()
		completion_result = completion_port.complete_entry(last_intent.duplicate(true))
		return completion_result

	func fail_runtime() -> void:
		var failed: Dictionary = active.duplicate(true)
		active.clear()
		entry_playback_failed.emit(failed.playback_token, failed.entry_id,
			{"ok": false, "code": &"fixture_runtime_failure"})

	func abort_current_entry(_reason: StringName) -> Dictionary:
		if not allow_abort: return {"ok": false, "code": &"fixture_abort_refused"}
		abort_calls += 1
		active.clear()
		return {"ok": true}

var bridge: Bridge
var playback: RefCounted
var command: Dictionary

func before_each() -> void:
	bridge = Bridge.new()
	playback = PLAYBACK.new()
	command = {"physical_token": "physical:date-one", "completion_transaction_id": "transaction:date-one",
		"timeline_id": "dating.solo.priscilla.day2.pre_challenge", "command_sha256": "date-one".sha256_text(),
		"context": {"kind": "solo", "participants": ["priscilla"], "day": 2}}
	assert_true(playback.configure(bridge).get("ok", false))

func after_each() -> void:
	# Production objects live for the application lifetime; release this fixture's cycle.
	bridge.completion_port = null

func test_pre_and_post_use_matching_semantic_entries_and_exact_frozen_context() -> void:
	for phase: String in ["pre_challenge", "post_challenge"]:
		var started: Dictionary = playback.begin_phase(command, phase)
		assert_true(started.get("ok", false), str(started))
		var call: Dictionary = bridge.starts.back()
		assert_eq(call.entry_id, "dating.solo.priscilla.day2." + phase)
		assert_eq(call.context, {"expected_stage": phase, "playback_id": "physical:date-one:" + phase,
			"role": "dating_phase", "transaction_id": "transaction:date-one:" + phase},
			"Bridge receives exactly its four declared semantic context fields")
		assert_eq(call.execution_mode, &"canonical")
		assert_eq(playback.pull_phase(command, phase).value.status, "playing")
		assert_true(bridge.finish().get("ok", false))
		assert_eq(playback.pull_phase(command, phase).value.status, "completed")
		assert_true(playback.finish_phase(command, phase).get("ok", false))
	assert_eq(bridge.starts.size(), 2)

func test_repeated_begin_waits_for_natural_completion_without_restarting() -> void:
	assert_true(playback.begin_phase(command, "pre_challenge").get("ok", false))
	for ignored in 3:
		assert_true(playback.begin_phase(command, "pre_challenge").get("ok", false))
		assert_eq(playback.pull_phase(command, "pre_challenge").value.status, "playing")
	assert_eq(bridge.starts.size(), 1, "scene polling cannot restart or skip a running entry")
	assert_false(playback.finish_phase(command, "pre_challenge").get("ok", false),
		"the gameplay boundary cannot retire unfinished prose")
	assert_true(bridge.has_active_playback())
	assert_true(bridge.finish().get("ok", false))
	assert_eq(playback.begin_phase(command, "pre_challenge").value.status, "completed")
	assert_eq(bridge.starts.size(), 1, "completed prose remains completed until its boundary succeeds")

func test_return_only_entry_can_complete_synchronously_inside_start() -> void:
	bridge.complete_during_start = true
	var started: Dictionary = playback.begin_phase(command, "pre_challenge")
	assert_true(started.get("ok", false), str(started))
	assert_true(bridge.completion_result.get("ok", false), str(bridge.completion_result))
	assert_eq(started.value.status, "completed")
	assert_eq(playback.pull_phase(command, "pre_challenge").value.status, "completed")
	assert_eq(bridge.starts.size(), 1, "a return-only file is acknowledged without recursive next-phase playback")
	assert_false(bridge.has_active_playback())

func test_completion_rejects_each_forged_identity_without_poisoning_the_valid_phase() -> void:
	assert_true(playback.begin_phase(command, "pre_challenge").get("ok", false))
	var mismatches := {"entry_id": "hospital.recovery", "transaction_id": "transaction:other",
		"stage": "post_challenge", "playback_token": "playback-forged", "context_fingerprint": "forged",
		"execution_mode": &"rehearsal", "completion_kind": &"cancelled"}
	for field: String in mismatches:
		var forged: Dictionary = bridge.active.duplicate(true)
		forged[field] = mismatches[field]
		assert_false(playback.complete_entry(forged).get("ok", false), "reject forged " + field)
		assert_eq(playback.pull_phase(command, "pre_challenge").value.status, "playing")
	assert_true(bridge.finish().get("ok", false), "the authentic completion remains admissible")
	assert_eq(playback.pull_phase(command, "pre_challenge").value.status, "completed")

func test_synchronous_completion_is_verified_against_returned_start_receipt() -> void:
	bridge.complete_during_start = true
	bridge.receipt_overrides = {"playback_token": "different-token"}
	assert_false(playback.begin_phase(command, "pre_challenge").get("ok", false),
		"an early natural-end intent is provisional until the matching start receipt arrives")
	assert_false(playback.pull_phase(command, "pre_challenge").get("ok", false))
	assert_false(playback.finish_phase(command, "pre_challenge").get("ok", false))
	bridge.receipt_overrides = {}
	assert_eq(playback.begin_phase(command, "pre_challenge", true).value.status, "completed")

func test_command_or_phase_drift_cannot_take_over_retained_playback() -> void:
	assert_true(playback.begin_phase(command, "pre_challenge").get("ok", false))
	var mutations := {"physical_token": "physical:other", "completion_transaction_id": "transaction:other",
		"timeline_id": "dating.solo.lavinia.day2.pre_challenge", "command_sha256": "other".sha256_text(),
		"context": {"kind": "solo", "participants": ["lavinia"], "day": 2}}
	for field: String in mutations:
		var drifted: Dictionary = command.duplicate(true)
		drifted[field] = mutations[field]
		assert_false(playback.begin_phase(drifted, "pre_challenge").get("ok", false), "reject changed " + field)
		assert_false(playback.pull_phase(drifted, "pre_challenge").get("ok", false))
	assert_false(playback.begin_phase(command, "post_challenge").get("ok", false))
	assert_false(playback.pull_phase(command, "post_challenge").get("ok", false))
	assert_eq(bridge.starts.size(), 1)
	assert_eq(playback.pull_phase(command, "pre_challenge").value.status, "playing")

func test_start_failure_is_latched_until_explicit_retry() -> void:
	bridge.fail_start = true
	assert_false(playback.begin_phase(command, "pre_challenge").get("ok", false))
	bridge.fail_start = false
	for ignored in 3:
		assert_false(playback.begin_phase(command, "pre_challenge").get("ok", false))
		assert_false(playback.pull_phase(command, "pre_challenge").get("ok", false))
	assert_eq(bridge.starts.size(), 1, "a frame pump must not produce repeated failed start attempts")
	var retried: Dictionary = playback.begin_phase(command, "pre_challenge", true)
	assert_true(retried.get("ok", false), str(retried))
	assert_eq(retried.value.status, "playing")
	assert_eq(bridge.starts.size(), 2)
	assert_true(bridge.finish().get("ok", false))

func test_runtime_failure_needs_retry_and_rejects_completion_from_failed_attempt() -> void:
	assert_true(playback.begin_phase(command, "pre_challenge").get("ok", false))
	var abandoned: Dictionary = bridge.active.duplicate(true)
	bridge.fail_runtime()
	assert_false(playback.pull_phase(command, "pre_challenge").get("ok", false))
	assert_false(playback.begin_phase(command, "pre_challenge").get("ok", false))
	assert_eq(bridge.starts.size(), 1)
	assert_true(playback.begin_phase(command, "pre_challenge", true).get("ok", false))
	assert_false(playback.complete_entry(abandoned).get("ok", false), "retry receives a fresh Bridge token")
	assert_eq(playback.pull_phase(command, "pre_challenge").value.status, "playing")
	assert_true(bridge.finish().get("ok", false))

func test_unrelated_failure_does_not_retire_current_playback() -> void:
	assert_true(playback.begin_phase(command, "pre_challenge").get("ok", false))
	bridge.entry_playback_failed.emit("unrelated-token", "hospital.recovery", {"ok": false})
	assert_eq(playback.pull_phase(command, "pre_challenge").value.status, "playing")
	assert_true(bridge.finish().get("ok", false))

func test_playback_retired_without_natural_completion_requires_explicit_retry() -> void:
	assert_true(playback.begin_phase(command, "pre_challenge").get("ok", false))
	bridge.active.clear()
	assert_false(playback.pull_phase(command, "pre_challenge").get("ok", false),
		"cancellation cannot be mistaken for a completed DTL")
	assert_false(playback.begin_phase(command, "pre_challenge").get("ok", false))
	assert_eq(bridge.starts.size(), 1)
	assert_true(playback.begin_phase(command, "pre_challenge", true).get("ok", false))
	assert_eq(playback.pull_phase(command, "pre_challenge").value.status, "playing")
	assert_true(bridge.finish().get("ok", false))

func test_finished_pre_phase_cannot_complete_post_phase_with_stale_receipt() -> void:
	assert_true(playback.begin_phase(command, "pre_challenge").get("ok", false))
	assert_true(bridge.finish().get("ok", false))
	var previous: Dictionary = bridge.last_intent.duplicate(true)
	assert_true(playback.finish_phase(command, "pre_challenge").get("ok", false))
	assert_false(playback.complete_entry(previous).get("ok", false), "a retired phase has no completion authority")
	assert_true(playback.begin_phase(command, "post_challenge").get("ok", false))
	assert_false(playback.complete_entry(previous).get("ok", false))
	assert_eq(playback.pull_phase(command, "post_challenge").value.status, "playing")
	assert_true(bridge.finish().get("ok", false))

func test_restored_different_date_cancels_only_retained_phase_and_rejects_old_completion() -> void:
	assert_true(playback.begin_phase(command, "pre_challenge").get("ok", false))
	var previous: Dictionary = bridge.active.duplicate(true)
	var restored: Dictionary = command.duplicate(true)
	restored.physical_token = "physical:restored-date"
	restored.completion_transaction_id = "transaction:restored-date"
	restored.command_sha256 = "restored-date".sha256_text()
	bridge.allow_abort = true
	assert_true(playback.begin_phase(restored, "pre_challenge").get("ok", false))
	assert_eq(bridge.abort_calls, 1, "restore retires the exact earlier token before starting its own entry")
	assert_eq(bridge.starts.size(), 2)
	assert_false(playback.complete_entry(previous).get("ok", false))
	assert_false(playback.pull_phase(command, "pre_challenge").get("ok", false))
	assert_eq(playback.pull_phase(restored, "pre_challenge").value.status, "playing")
	assert_true(bridge.finish().get("ok", false))

func test_new_presentation_replays_same_completed_phase_instead_of_reusing_transient_completion() -> void:
	assert_true(playback.begin_phase(command, "pre_challenge").get("ok", false))
	assert_true(bridge.finish().get("ok", false))
	var previous: Dictionary = bridge.last_intent.duplicate(true)
	assert_eq(playback.begin_phase(command, "pre_challenge", true).value.status, "completed")
	assert_eq(bridge.starts.size(), 1, "retry on the mounted scene retains completed prose")
	assert_true(playback.begin_presentation(command).get("ok", false))
	assert_true(playback.begin_phase(command, "pre_challenge").get("ok", false))
	assert_eq(bridge.starts.size(), 2, "Load mounting the same boundary starts fresh playback")
	assert_ne(bridge.active.playback_token, previous.playback_token)
	assert_eq(bridge.abort_calls, 0, "completed playback needs no cancellation")
	assert_false(playback.complete_entry(previous).get("ok", false))
	assert_eq(playback.pull_phase(command, "pre_challenge").value.status, "playing")
	assert_true(bridge.finish().get("ok", false))

func test_new_presentation_cancels_active_phase_and_rejects_its_late_completion() -> void:
	assert_true(playback.begin_phase(command, "pre_challenge").get("ok", false))
	var previous: Dictionary = bridge.active.duplicate(true)
	bridge.allow_abort = true
	assert_true(playback.begin_presentation(command).get("ok", false))
	assert_eq(bridge.abort_calls, 1)
	assert_false(playback.complete_entry(previous).get("ok", false))
	assert_true(playback.begin_phase(command, "pre_challenge").get("ok", false))
	assert_ne(bridge.active.playback_token, previous.playback_token)
	assert_false(playback.complete_entry(previous).get("ok", false))
	assert_eq(playback.pull_phase(command, "pre_challenge").value.status, "playing")
	assert_true(bridge.finish().get("ok", false))

func test_configuration_is_retained_and_invalid_phase_never_starts_bridge() -> void:
	assert_true(playback.configure(bridge).get("ok", false))
	var other := Bridge.new()
	assert_false(playback.configure(other).get("ok", false))
	assert_false(playback.begin_phase(command, "challenge").get("ok", false))
	var malformed: Dictionary = command.duplicate(true)
	malformed.timeline_id = "hospital.recovery"
	assert_false(playback.begin_phase(malformed, "pre_challenge").get("ok", false))
	assert_eq(bridge.starts.size(), 0)
	other.completion_port = null
