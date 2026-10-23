extends "res://addons/gut/test.gd"

const PARTICIPANT := preload("res://scripts/application/restore/ProfileRestoreParticipant.gd")
const PROFILE := preload("res://autoload/ProfileManager.gd")
const STORAGE := preload("res://scripts/infrastructure/storage/JsonFileStorage.gd")
const FILES := preload("res://tests/support/FakeFileOps.gd")
const WINDOW_PATH := &"preferences.display.window_mode"

class FakeWindowOutput extends Node:
	var mode := "windowed"
	var physical := {"marker": "windowed"}
	var fail_apply := false
	var mutate_before_apply_failure := false
	var fail_rollback := false
	var fail_finalize := false
	var calls: Array[StringName] = []
	var latched: Array[Dictionary] = []

	func prepare_restore(preferences: Dictionary) -> Dictionary:
		calls.append(&"prepare")
		var display: Variant = preferences.get("display")
		if typeof(display) != TYPE_DICTIONARY:
			return _failure(&"invalid_window_preferences")
		var requested: Variant = (display as Dictionary).get("window_mode")
		if typeof(requested) != TYPE_STRING or requested not in ["windowed", "borderless"]:
			return _failure(&"invalid_window_mode")
		return _success({"window_mode": requested})

	func capture_restore_state() -> Dictionary:
		calls.append(&"capture")
		return _success({"output": physical.duplicate(true), "mode": mode})

	func apply_restore_silent(plan: Dictionary) -> Dictionary:
		calls.append(&"apply")
		if plan.size() != 1 or typeof(plan.get("window_mode")) != TYPE_STRING:
			return _failure(&"invalid_window_restore_plan")
		if fail_apply:
			if mutate_before_apply_failure:
				mode = plan.window_mode
				physical = {"marker": mode}
			return _failure(&"forced_window_apply_failure")
		mode = plan.window_mode
		physical = {"marker": mode}
		return _success({})

	func rollback_restore_silent(backup: Dictionary) -> Dictionary:
		calls.append(&"rollback")
		if fail_rollback:
			return _failure(&"forced_window_rollback_failure")
		if typeof(backup.get("output")) != TYPE_DICTIONARY or typeof(backup.get("mode")) != TYPE_STRING:
			return _failure(&"invalid_window_restore_backup")
		physical = (backup.output as Dictionary).duplicate(true)
		mode = backup.mode
		return _success({})

	func finalize_restore() -> Dictionary:
		calls.append(&"finalize")
		return _failure(&"forced_window_finalize_failure") if fail_finalize else _success({})

	func latch_output_failure(phase: StringName, cause: Dictionary) -> void:
		latched.append({"phase": phase, "cause": cause.duplicate(true)})

	func _success(value: Dictionary) -> Dictionary:
		return {"ok": true, "code": &"ok", "value": value}

	func _failure(code: StringName) -> Dictionary:
		return {"ok": false, "code": code}

class IncompleteWindowOutput extends Node:
	func prepare_restore(_preferences: Dictionary) -> Dictionary:
		return {"ok": true, "value": {"window_mode": "windowed"}}

func _make_profile(suffix: String) -> Node:
	var profile: Node = PROFILE.new()
	add_child_autofree(profile)
	assert_true(profile.initialize(STORAGE.new("profile-window-restore/" + suffix, FILES.new())).get("ok", false))
	return profile

func _set_mode(profile: Node, mode: String) -> void:
	var prepared: Dictionary = profile.prepare_preferences({WINDOW_PATH: mode})
	assert_true(prepared.get("ok", false), str(prepared))
	if prepared.get("ok", false):
		assert_true(profile.commit_prepared_profile(prepared.value).get("ok", false))

func _prepare_target(profile: Node, participant: RefCounted, mode: String) -> Dictionary:
	_set_mode(profile, mode)
	var prepared: Dictionary = participant.prepare({"legacy_profile_patch_input": {
		"legacy_run_state": {"settings": {"fullscreen": mode == "borderless"}},
		"legacy_input_mappings": {},
	}})
	assert_true(prepared.get("ok", false), str(prepared))
	return prepared.get("value", {}).get("profile_plan", {}).duplicate(true)

func _bound(suffix: String) -> Dictionary:
	var profile := _make_profile(suffix)
	var window := FakeWindowOutput.new()
	add_child_autofree(window)
	var participant: RefCounted = PARTICIPANT.new(profile)
	assert_true(participant.configure_window_output(window).get("ok", false))
	return {"profile": profile, "window": window, "participant": participant}

func test_configuration_is_identity_immutable_and_validates_the_contract() -> void:
	var profile := _make_profile("configuration")
	var participant: RefCounted = PARTICIPANT.new(profile)
	var first := FakeWindowOutput.new()
	var replacement := FakeWindowOutput.new()
	var incomplete := IncompleteWindowOutput.new()
	add_child_autofree(first)
	add_child_autofree(replacement)
	add_child_autofree(incomplete)
	assert_false(participant.configure_window_output(incomplete).get("ok", true))
	var configured: Dictionary = participant.configure_window_output(first)
	assert_true(configured.get("ok", false))
	assert_eq(configured.value.window_output_instance_id, first.get_instance_id())
	assert_true(participant.configure_window_output(first).value.already_configured)
	assert_eq(participant.configure_window_output(replacement).get("code"), &"window_output_already_configured")

func test_composite_prepare_apply_capture_rollback_and_finalize_use_one_profile_plan() -> void:
	var fixture := _bound("round-trip")
	var profile: Node = fixture.profile
	var window: FakeWindowOutput = fixture.window
	var participant: RefCounted = fixture.participant
	var target := _prepare_target(profile, participant, "borderless")
	assert_eq(target.window_plan, {"window_mode": "borderless"})
	_set_mode(profile, "windowed")
	var profile_before: Dictionary = profile.get_profile_snapshot()
	var captured: Dictionary = participant.capture()
	assert_eq(captured.value.profile, profile_before)
	assert_eq(captured.value.window_backup, {"output": {"marker": "windowed"}, "mode": "windowed"})
	var applied: Dictionary = participant.apply_silent(target)
	assert_true(applied.get("ok", false), str(applied))
	assert_eq(applied.get("value"), {}, "the durable participant receipt remains primitive and empty")
	assert_eq(profile.get_preference(WINDOW_PATH), "borderless")
	assert_eq(window.mode, "borderless")
	assert_true(participant.rollback_silent(captured.value).get("ok", false))
	assert_eq(profile.get_profile_snapshot(), profile_before)
	assert_eq(window.mode, "windowed")
	assert_true(participant.finalize().get("ok", false))
	assert_eq(window.calls.slice(window.calls.size() - 2), [&"rollback", &"finalize"])

func test_bound_participant_rejects_missing_window_plan_before_mutation() -> void:
	var fixture := _bound("missing-plan")
	var profile: Node = fixture.profile
	var window: FakeWindowOutput = fixture.window
	var participant: RefCounted = fixture.participant
	var before_profile: Dictionary = profile.get_profile_snapshot()
	var before_physical: Dictionary = window.physical.duplicate(true)
	var result: Dictionary = participant.apply_silent({"profile": before_profile})
	assert_eq(result.get("code"), &"invalid_profile_window_restore_plan")
	assert_eq(profile.get_profile_snapshot(), before_profile)
	assert_eq(window.physical, before_physical)
	assert_false(&"apply" in window.calls)

func test_window_apply_failure_is_compensated_without_touching_profile() -> void:
	var fixture := _bound("window-failure")
	var profile: Node = fixture.profile
	var window: FakeWindowOutput = fixture.window
	var participant: RefCounted = fixture.participant
	var target := _prepare_target(profile, participant, "borderless")
	_set_mode(profile, "windowed")
	var before_profile: Dictionary = profile.get_profile_snapshot()
	var before_physical: Dictionary = window.physical.duplicate(true)
	window.fail_apply = true
	window.mutate_before_apply_failure = true
	var result: Dictionary = participant.apply_silent(target)
	assert_eq(result.get("code"), &"forced_window_apply_failure")
	assert_eq(profile.get_profile_snapshot(), before_profile)
	assert_eq(window.physical, before_physical)
	assert_eq(window.mode, "windowed")
	assert_eq(window.latched, [])

func test_profile_apply_failure_compensates_the_already_applied_window() -> void:
	var fixture := _bound("profile-failure")
	var profile: Node = fixture.profile
	var window: FakeWindowOutput = fixture.window
	var participant: RefCounted = fixture.participant
	var before_profile: Dictionary = profile.get_profile_snapshot()
	var before_physical: Dictionary = window.physical.duplicate(true)
	var invalid_profile := before_profile.duplicate(true)
	invalid_profile["unknown_root"] = true
	var result: Dictionary = participant.apply_silent({
		"profile": invalid_profile, "window_plan": {"window_mode": "borderless"},
	})
	assert_false(result.get("ok", true))
	assert_eq(profile.get_profile_snapshot(), before_profile)
	assert_eq(window.mode, "windowed")
	assert_eq(window.physical, before_physical)
	assert_eq(window.latched, [])

func test_unproved_rollback_latches_window_failure_and_returns_fatal() -> void:
	var fixture := _bound("fatal-rollback")
	var profile: Node = fixture.profile
	var window: FakeWindowOutput = fixture.window
	var participant: RefCounted = fixture.participant
	var target := _prepare_target(profile, participant, "borderless")
	_set_mode(profile, "windowed")
	var backup: Dictionary = participant.capture().value
	assert_true(participant.apply_silent(target).get("ok", false))
	window.fail_rollback = true
	var result: Dictionary = participant.rollback_silent(backup)
	assert_false(result.get("ok", true))
	assert_true(result.get("fatal", false))
	assert_eq(result.get("code"), &"profile_window_restore_indeterminate")
	assert_eq(window.latched.size(), 1)
	assert_eq(window.latched[0].phase, &"profile_window_rollback")
	assert_eq(profile.get_profile_snapshot(), backup.profile,
		"Profile rollback is still attempted after a physical rollback failure")

func test_unbound_participant_preserves_the_legacy_profile_only_contract() -> void:
	var profile := _make_profile("unbound")
	var participant: RefCounted = PARTICIPANT.new(profile)
	var target := _prepare_target(profile, participant, "borderless")
	assert_false(target.has("window_plan"))
	_set_mode(profile, "windowed")
	var backup: Dictionary = participant.capture().value
	assert_eq(backup.keys(), ["profile"])
	assert_true(participant.apply_silent(target).get("ok", false))
	assert_eq(profile.get_preference(WINDOW_PATH), "borderless")
	assert_true(participant.rollback_silent(backup).get("ok", false))
	assert_eq(profile.get_preference(WINDOW_PATH), "windowed")
