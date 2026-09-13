extends GutTest

const CONTROLLER := preload("res://scripts/ui/witnessed/WitnessedSkipController.gd")
const AUTO_ENABLED := &"preferences.reading.auto_enabled"


class FakeProfile extends Node:
	signal preference_changed(path: StringName, value: Variant)
	signal profile_restored(profile: Dictionary)

	var auto_enabled := false
	var fail_write := false
	var calls: Array[String] = []
	var journal: Array[String]
	var during_set: Callable

	func get_preference(path: StringName, fallback: Variant = null) -> Variant:
		return auto_enabled if path == &"preferences.reading.auto_enabled" else fallback

	func set_preference(path: StringName, value: Variant) -> Dictionary:
		calls.append("profile:auto_off")
		journal.append("profile:auto_off")
		if fail_write:
			return {"ok": false, "code": &"write_failed"}
		auto_enabled = bool(value)
		preference_changed.emit(path, value)
		if during_set.is_valid():
			during_set.call()
		return {"ok": true, "code": &"ok", "value": {}, "receipt": {}}

	func publish_auto(enabled: bool) -> void:
		auto_enabled = enabled
		preference_changed.emit(&"preferences.reading.auto_enabled", enabled)

	func restore_auto(enabled: bool) -> void:
		auto_enabled = enabled
		profile_restored.emit({"preferences": {"reading": {"auto_enabled": enabled}}})


class FakeBridge extends Node:
	var results: Array[Dictionary] = []
	var calls: Array[String] = []
	var journal: Array[String]
	var during_step: Callable

	func request_skip_step() -> Dictionary:
		calls.append("bridge:step")
		journal.append("bridge:step")
		if during_step.is_valid():
			during_step.call()
		if results.is_empty():
			return {"ok": true, "value": {"advance": true}}
		return results.pop_front()


func _fixture(auto_enabled: bool = false, admitted: bool = true) -> Dictionary:
	var profile := FakeProfile.new()
	profile.auto_enabled = auto_enabled
	var bridge := FakeBridge.new()
	add_child_autofree(profile)
	add_child_autofree(bridge)
	var journal: Array[String] = []
	profile.journal = journal
	bridge.journal = journal
	var custody := {"admitted": admitted}
	var controller := CONTROLLER.new()
	add_child_autofree(controller)
	assert_true(controller.configure(profile, bridge,
		func() -> bool: return bool(custody.admitted)))
	return {"controller": controller, "profile": profile, "bridge": bridge,
		"custody": custody, "journal": journal}


func test_auto_off_is_durable_before_the_first_step_and_failure_does_not_start() -> void:
	var failed := _fixture(true)
	failed.profile.fail_write = true
	var rejected: Dictionary = failed.controller.toggle_skip()
	assert_false(rejected.get("ok", true))
	assert_eq(rejected.get("code"), &"write_failed")
	assert_true(failed.controller.is_auto_enabled())
	assert_false(failed.controller.is_skip_active())
	failed.controller._process(0.0)
	assert_eq(failed.bridge.calls, [])
	assert_eq(failed.journal, ["profile:auto_off"])

	var started := _fixture(true)
	assert_true(started.controller.toggle_skip().get("ok", false))
	assert_false(started.controller.is_auto_enabled())
	assert_true(started.controller.is_skip_active())
	started.controller.set_process(false)
	started.controller._process(0.0)
	assert_eq(started.journal, ["profile:auto_off", "bridge:step"],
		"the first step follows the committed Auto Off")


func test_stop_during_auto_commit_retires_the_pending_start() -> void:
	var f := _fixture(true)
	f.profile.during_set = Callable(f.controller, "stop_skip")
	var result: Dictionary = f.controller.toggle_skip()
	assert_false(result.get("ok", true))
	assert_eq(result.get("code"), &"skip_start_retired")
	assert_false(f.controller.is_auto_enabled(), "the completed profile commit remains truthful")
	assert_false(f.controller.is_skip_active())
	f.controller._process(0.0)
	assert_eq(f.bridge.calls, [])


func test_second_toggle_stops_and_each_frame_runs_at_most_one_step() -> void:
	var f := _fixture()
	assert_true(f.controller.toggle_skip().get("ok", false))
	f.controller.set_process(false)
	f.controller._process(0.0)
	f.controller._process(0.0)
	assert_eq(f.bridge.calls.size(), 1)
	assert_true(f.controller.is_skip_active())
	assert_true(f.controller.toggle_skip().get("ok", false))
	assert_false(f.controller.is_skip_active())


func test_failure_false_decision_and_boundary_each_stop_the_session() -> void:
	var endings: Array[Dictionary] = [
		{"ok": false, "code": &"write_failed"},
		{"ok": true, "value": {"advance": false}},
		{"ok": true, "value": {"advance": true, "stop_before_boundary": true}},
	]
	for ending: Dictionary in endings:
		var f := _fixture()
		f.bridge.results.append(ending)
		assert_true(f.controller.toggle_skip().get("ok", false))
		f.controller.set_process(false)
		f.controller._process(0.0)
		assert_false(f.controller.is_skip_active(), str(ending))
		assert_eq(f.bridge.calls.size(), 1, str(ending))


func test_reentrant_replacement_cannot_let_the_old_step_stop_the_new_session() -> void:
	var f := _fixture()
	assert_true(f.controller.toggle_skip().get("ok", false))
	f.controller.set_process(false)
	var replaced := false
	f.bridge.during_step = func() -> void:
		if replaced:
			return
		replaced = true
		f.controller.stop_skip()
		assert_true(f.controller.toggle_skip().get("ok", false))
		f.controller.set_process(false)
	f.controller._process(0.0)
	assert_eq(f.bridge.calls.size(), 1, "no reentrant second bridge call")
	assert_true(f.controller.is_skip_active(), "the stale result cannot retire the replacement generation")


func test_external_auto_on_and_admission_loss_stop_without_an_extra_step() -> void:
	var f := _fixture()
	assert_true(f.controller.toggle_skip().get("ok", false))
	f.profile.publish_auto(true)
	assert_true(f.controller.is_auto_enabled())
	assert_false(f.controller.is_skip_active())
	assert_eq(f.bridge.calls, [])

	assert_true(f.controller.toggle_skip().get("ok", false), "restart first commits Auto Off")
	f.controller.set_process(false)
	f.custody.admitted = false
	f.controller._process(0.0)
	assert_false(f.controller.is_skip_active())
	assert_eq(f.bridge.calls, [], "lost admission prevents the next narrative mutation")


func test_profile_restore_retires_skip_even_when_auto_remains_off() -> void:
	var f := _fixture()
	assert_true(f.controller.toggle_skip().get("ok", false))
	f.profile.restore_auto(false)
	assert_false(f.controller.is_skip_active())
	assert_false(f.controller.is_auto_enabled())
	f.controller._process(0.0)
	assert_eq(f.bridge.calls, [])


func test_freed_dependencies_fail_closed_before_another_step() -> void:
	var missing_profile := _fixture()
	assert_true(missing_profile.controller.toggle_skip().get("ok", false))
	missing_profile.controller.set_process(false)
	missing_profile.profile.free()
	missing_profile.controller._process(0.0)
	assert_false(missing_profile.controller.is_skip_active())
	assert_eq(missing_profile.bridge.calls, [])

	var missing_bridge := _fixture()
	assert_true(missing_bridge.controller.toggle_skip().get("ok", false))
	missing_bridge.controller.set_process(false)
	missing_bridge.bridge.free()
	missing_bridge.controller._process(0.0)
	assert_false(missing_bridge.controller.is_skip_active())
