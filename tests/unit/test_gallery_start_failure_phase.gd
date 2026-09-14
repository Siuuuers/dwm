extends GutTest

const BRIDGE := preload("res://autoload/DialogicBridge.gd")
const REPLAY := preload("res://scripts/application/ending/GalleryReplayOwner.gd")
const PROFILE := preload("res://autoload/ProfileManager.gd")
const STORAGE := preload("res://scripts/infrastructure/storage/JsonFileStorage.gd")
const FILES := preload("res://tests/support/FakeFileOps.gd")


class Runtime extends RefCounted:
	signal timeline_started_signal
	signal timeline_ended_signal
	signal event_handled_signal(resource)
	signal runtime_signal_event(argument)
	signal preference_reapply_requested
	signal playback_start_failed(failure: Dictionary)

	var admit_start := true
	var replace_during_start := false
	var active := false

	func start_timeline(_path: String, _label: Variant = 0) -> Dictionary:
		if replace_during_start:
			active = true
			playback_start_failed.emit({"ok": false, "code": &"runtime_playback_replaced"})
			return {"ok": false, "code": &"runtime_start_cancelled"}
		if not admit_start:
			return {"ok": false, "code": &"fixture_start_refused"}
		active = true
		return {"ok": true}

	func has_active_playback() -> bool:
		return active

	func halt_with_error(_failure: Dictionary) -> Dictionary:
		active = false
		return {"ok": true}


var _profile: Node
var _bridge: Node
var _runtime: Runtime
var _replay: RefCounted
var _signature_id := ""
var _bridge_finishes: Array[Dictionary] = []
var _owner_finishes: Array[Dictionary] = []


func before_each() -> void:
	_profile = PROFILE.new()
	add_child_autofree(_profile)
	assert_true(_profile.initialize(STORAGE.new(
		"gallery-start-failure-phase.memory", FILES.new())).get("ok", false))
	var recorded: Dictionary = _profile.record_reached_presentation({
		"entry_id": "ending.alone.normal",
		"schema_version": 1,
		"fields": {"ending_role": "core", "ending_form": "alone_normal"},
	})
	assert_true(recorded.get("ok", false), str(recorded))
	_signature_id = str(recorded.get("value", {}).get("signature_id", ""))
	_runtime = Runtime.new()
	_bridge = BRIDGE.new()
	add_child_autofree(_bridge)
	assert_true(_bridge.initialize(null, _runtime).get("ok", false))
	_replay = REPLAY.new()
	assert_true(_replay.configure(_profile, _bridge).get("ok", false))
	_bridge_finishes.clear()
	_bridge.reached_replay_finished.connect(func(result: Dictionary) -> void:
		_bridge_finishes.append(result.duplicate(true)))
	_owner_finishes.clear()
	_replay.playback_finished.connect(func(result: Dictionary) -> void:
		_owner_finishes.append(result.duplicate(true)))


func _unlock() -> void:
	var unlocked: Dictionary = _profile.unlock_ending("ending.alone", "gallery-start-phase:fixture")
	assert_true(unlocked.get("ok", false), str(unlocked))


func test_pre_admission_refusal_has_no_start_failure_phase_or_retry_identity() -> void:
	var before: Dictionary = _profile.get_profile_snapshot()
	var refused: Dictionary = _replay.begin(_signature_id)

	assert_false(refused.get("ok", true), str(refused))
	assert_eq(refused.get("code"), &"ending_not_discovered")
	assert_false(refused.has("failure_phase"), "a refusal before replay allocation cannot claim a start failure")
	assert_false(refused.has("signature_id"), "a refusal does not publish a Retry target")
	assert_true(_owner_finishes.is_empty())
	assert_false(_replay.is_playing())
	assert_eq(_profile.get_profile_snapshot(), before)


func test_synchronous_physical_start_failure_returns_exact_retryable_start_identity() -> void:
	_unlock()
	_runtime.admit_start = false
	var before: Dictionary = _profile.get_profile_snapshot()
	var failed: Dictionary = _replay.begin(_signature_id)

	assert_false(failed.get("ok", true), str(failed))
	assert_eq(failed.get("code"), &"runtime_start_failed")
	assert_eq(failed.get("failure_phase"), &"start")
	assert_eq(str(failed.get("signature_id", "")), _signature_id)
	assert_true(_owner_finishes.is_empty(), "the owner returns the synchronous failure once")
	assert_false(_replay.is_playing())
	assert_false(_bridge.has_active_playback())
	assert_eq(_profile.get_profile_snapshot(), before)


func test_deferred_runtime_start_failure_emits_exact_retryable_start_identity() -> void:
	_unlock()
	var before: Dictionary = _profile.get_profile_snapshot()
	var started: Dictionary = _replay.begin(_signature_id)
	assert_true(started.get("ok", false), str(started))
	if not started.get("ok", false):
		return
	var token := str(started.get("receipt", {}).get("playback_token", ""))

	_runtime.active = false
	_runtime.playback_start_failed.emit({"ok": false, "code": &"runtime_start_failed"})

	assert_eq(_owner_finishes.size(), 1)
	if _owner_finishes.is_empty():
		return
	var failed: Dictionary = _owner_finishes[0]
	assert_eq(failed.get("outcome"), "failed")
	assert_eq(failed.get("code"), "runtime_start_failed")
	assert_eq(failed.get("failure_phase"), &"start")
	assert_eq(str(failed.get("signature_id", "")), _signature_id)
	assert_eq(str(failed.get("playback_token", "")), token)
	assert_false(_replay.is_playing())
	assert_eq(_profile.get_profile_snapshot(), before)


func test_runtime_replacement_remains_generic_failure_without_retryable_start_phase() -> void:
	_unlock()
	var before: Dictionary = _profile.get_profile_snapshot()
	var started: Dictionary = _replay.begin(_signature_id)
	assert_true(started.get("ok", false), str(started))
	if not started.get("ok", false):
		return
	var token := str(started.get("receipt", {}).get("playback_token", ""))

	_runtime.active = false
	_runtime.playback_start_failed.emit({"ok": false, "code": &"runtime_playback_replaced"})

	assert_eq(_owner_finishes.size(), 1)
	if _owner_finishes.is_empty():
		return
	var failed: Dictionary = _owner_finishes[0]
	assert_eq(failed.get("outcome"), "failed")
	assert_eq(failed.get("code"), "runtime_playback_replaced")
	assert_false(failed.has("failure_phase"), "an interrupted live request cannot claim pre-session Retry")
	assert_eq(str(failed.get("signature_id", "")), _signature_id)
	assert_eq(str(failed.get("playback_token", "")), token)
	assert_false(_replay.is_playing())
	assert_eq(_profile.get_profile_snapshot(), before)


func test_synchronous_reentrant_runtime_replacement_cannot_be_reclassified_as_start_failure() -> void:
	_unlock()
	_runtime.replace_during_start = true
	var before: Dictionary = _profile.get_profile_snapshot()
	var failed: Dictionary = _replay.begin(_signature_id)

	assert_false(failed.get("ok", true), str(failed))
	assert_eq(failed.get("code"), &"runtime_start_failed")
	assert_false(failed.has("failure_phase"), "retired replay ownership cannot manufacture Retry")
	assert_false(failed.has("signature_id"), "the failed begin cannot republish a retired target")
	assert_eq(_bridge_finishes.size(), 1)
	if _bridge_finishes.is_empty():
		return
	var replaced: Dictionary = _bridge_finishes[0]
	assert_eq(replaced.get("outcome"), "failed")
	assert_eq(replaced.get("code"), "runtime_playback_replaced")
	assert_false(replaced.has("failure_phase"))
	assert_eq(str(replaced.get("signature_id", "")), _signature_id)
	assert_true(_owner_finishes.is_empty(), "a failed begin returns once and releases its queued callback")
	assert_false(_replay.is_playing())
	assert_true(_bridge.has_active_playback(), "the foreign replacement remains live, not a retryable empty start")
	assert_eq(_profile.get_profile_snapshot(), before)
