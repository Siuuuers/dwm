extends GutTest

const CONTROLLER := preload("res://scripts/ui/witnessed/WitnessedAutoController.gd")
const AUTO_ENABLED := &"preferences.reading.auto_enabled"
const AUTO_DELAY := &"preferences.reading.auto_delay"


class FakeProfile extends Node:
	signal preference_changed(path: StringName, value: Variant)
	signal profile_restored(profile: Dictionary)

	var values := {String(AUTO_ENABLED): false, String(AUTO_DELAY): "normal"}
	var fail_write := false
	var writes: Array[Array] = []
	var during_set: Callable

	func get_preference(path: StringName, fallback: Variant = null) -> Variant:
		return values.get(String(path), fallback)

	func set_preference(path: StringName, value: Variant) -> Dictionary:
		writes.append([path, value])
		if fail_write:
			return {"ok": false, "code": &"write_failed"}
		values[String(path)] = value
		preference_changed.emit(path, value)
		if during_set.is_valid():
			during_set.call()
		return {"ok": true, "code": &"ok", "value": {}, "receipt": {}}

	func publish(path: StringName, value: Variant) -> void:
		values[String(path)] = value
		preference_changed.emit(path, value)

	func restore(enabled: bool, delay: String) -> void:
		values[String(AUTO_ENABLED)] = enabled
		values[String(AUTO_DELAY)] = delay
		profile_restored.emit({"preferences": {"reading": {
			"auto_enabled": enabled, "auto_delay": delay}}})


class FakeBridge extends Node:
	var frontier := _proof("line-a", 1)
	var can_advance := true
	var requests: Array[Dictionary] = []
	var next_result := {"ok": true, "code": &"ok", "value": {"advance": true}}
	var during_request: Callable

	static func _proof(line_id: String, generation: int) -> Dictionary:
		return {"ok": true, "value": {"line_id": line_id,
			"frontier": {"generation": generation}}}

	func capture_current_line_presentation_frontier() -> Dictionary:
		return frontier.duplicate(true)

	func can_auto_advance_current_line() -> bool:
		return can_advance

	func request_auto_step(expected_frontier: Dictionary) -> Dictionary:
		requests.append(expected_frontier.duplicate(true))
		if during_request.is_valid():
			during_request.call()
		return next_result.duplicate(true)


func _fixture(enabled := true, delay := "normal", admitted := true) -> Dictionary:
	var profile := FakeProfile.new()
	profile.values[String(AUTO_ENABLED)] = enabled
	profile.values[String(AUTO_DELAY)] = delay
	var bridge := FakeBridge.new()
	var custody := {"admitted": admitted}
	var controller := CONTROLLER.new()
	add_child_autofree(profile)
	add_child_autofree(bridge)
	add_child_autofree(controller)
	assert_true(controller.configure(profile, bridge,
		func() -> bool: return bool(custody.admitted)))
	controller.set_process(false)
	return {"controller": controller, "profile": profile, "bridge": bridge,
		"custody": custody}


func _arm(fixture: Dictionary) -> void:
	fixture.controller.arm_after_reveal(fixture.bridge.frontier.duplicate(true))
	# Presentation and resume deltas cannot spend reading time.
	fixture.controller._process(0.0)


func test_toggle_commits_the_profile_and_a_failed_commit_preserves_truth() -> void:
	var started := _fixture(false, "short")
	assert_true(started.controller.toggle_auto().get("ok", false))
	assert_true(started.controller.is_auto_enabled())
	assert_eq(started.profile.writes, [[AUTO_ENABLED, true]])

	var failed := _fixture(true, "short")
	failed.profile.fail_write = true
	var result: Dictionary = failed.controller.toggle_auto()
	assert_false(result.get("ok", true))
	assert_eq(result.get("code"), &"write_failed")
	assert_true(failed.controller.is_auto_enabled())
	_arm(failed)
	failed.controller._process(1.01)
	assert_eq(failed.bridge.requests, [failed.bridge.frontier],
		"a failed Auto-Off commit leaves the previously On mode truthful")


func test_explicit_auto_target_is_idempotent_and_retries_the_same_failed_target() -> void:
	var f := _fixture(false, "short")
	f.profile.fail_write = true
	var failed: Dictionary = f.controller.set_auto_enabled(true)
	assert_false(failed.get("ok", true))
	assert_eq(failed.get("code"), &"write_failed")
	assert_false(f.controller.is_auto_enabled())
	assert_eq(f.profile.writes, [[AUTO_ENABLED, true]])

	f.profile.fail_write = false
	assert_true(f.controller.set_auto_enabled(true).get("ok", false))
	assert_true(f.controller.is_auto_enabled())
	assert_eq(f.profile.writes, [[AUTO_ENABLED, true], [AUTO_ENABLED, true]],
		"retry repeats the requested target instead of toggling stale state")
	assert_true(f.controller.set_auto_enabled(true).get("ok", false))
	assert_eq(f.profile.writes.size(), 2, "the already-current target performs no second write")

	f.profile.publish(AUTO_ENABLED, false)
	assert_false(f.controller.is_auto_enabled())
	assert_true(f.controller.set_auto_enabled(true).get("ok", false))
	assert_true(f.controller.is_auto_enabled())
	assert_eq(f.profile.writes.back(), [AUTO_ENABLED, true],
		"an explicit target remains exact after the current preference changes")


func test_reentrant_auto_source_replacement_retires_the_old_setter() -> void:
	var f := _fixture(false, "short")
	var replacement_profile := FakeProfile.new()
	replacement_profile.values[String(AUTO_ENABLED)] = true
	replacement_profile.values[String(AUTO_DELAY)] = "short"
	var replacement_bridge := FakeBridge.new()
	add_child_autofree(replacement_profile)
	add_child_autofree(replacement_bridge)
	f.profile.during_set = func() -> void:
		assert_true(f.controller.configure(replacement_profile, replacement_bridge,
			func() -> bool: return true))
	var result: Dictionary = f.controller.set_auto_enabled(true)
	assert_false(result.get("ok", true))
	assert_eq(result.get("code"), &"auto_set_retired")
	assert_true(f.controller.is_auto_enabled(), "replacement profile remains the truthful owner")
	assert_eq(replacement_profile.writes, [], "the old command never writes the replacement profile")


func test_exact_delays_advance_once_and_never_restart_for_duplicate_finished_signal() -> void:
	for row: Array in [["short", 1.0], ["normal", 2.0], ["long", 4.0]]:
		var f := _fixture(true, row[0])
		_arm(f)
		f.controller._process(float(row[1]) - 0.01)
		f.controller.arm_after_reveal(f.bridge.frontier.duplicate(true))
		f.controller._process(0.02)
		f.controller._process(float(row[1]) * 2.0)
		assert_eq(f.bridge.requests, [f.bridge.frontier], str(row[0]))


func test_suspension_preserves_remaining_time_and_skips_the_resume_delta() -> void:
	var f := _fixture(true, "short")
	_arm(f)
	f.controller._process(0.4)
	f.custody.admitted = false
	f.controller._process(20.0)
	assert_eq(f.bridge.requests, [])
	f.custody.admitted = true
	f.controller._process(20.0)
	assert_eq(f.bridge.requests, [], "the first resumed delta contains ineligible time")
	f.controller._process(0.59)
	assert_eq(f.bridge.requests, [])
	f.controller._process(0.02)
	assert_eq(f.bridge.requests, [f.bridge.frontier])


func test_suspension_notification_quarantines_resume_without_an_ineligible_tick() -> void:
	var f := _fixture(true, "short")
	_arm(f)
	f.controller._process(0.4)
	var remaining: float = f.controller.get("_remaining")
	f.custody.admitted = false
	f.controller.suspend_current()
	# The source restores before this controller receives any inactive process tick.
	f.custody.admitted = true
	f.controller._process(20.0)
	assert_eq(f.controller.get("_remaining"), remaining)
	assert_eq(f.bridge.requests, [])
	f.controller._process(0.59)
	assert_eq(f.bridge.requests, [])
	f.controller._process(0.02)
	assert_eq(f.bridge.requests, [f.bridge.frontier])


func test_source_identity_and_bridge_barriers_fail_closed_without_retry() -> void:
	var stale := _fixture(true, "short")
	_arm(stale)
	stale.bridge.frontier = FakeBridge._proof("line-b", 2)
	stale.controller._process(2.0)
	assert_eq(stale.bridge.requests, [], "a replacement cannot receive the old deadline")

	var blocked := _fixture(true, "short")
	_arm(blocked)
	blocked.bridge.can_advance = false
	blocked.controller._process(2.0)
	blocked.bridge.can_advance = true
	blocked.controller._process(2.0)
	assert_eq(blocked.bridge.requests, [], "a semantic boundary retires this line's timer")

	var failed := _fixture(true, "short")
	failed.bridge.next_result = {"ok": false, "code": &"technical_failure"}
	_arm(failed)
	failed.controller._process(1.01)
	failed.controller._process(10.0)
	assert_eq(failed.bridge.requests, [failed.bridge.frontier],
		"Auto never retries a failed narrative command")


func test_preference_changes_and_restore_replace_the_timer_with_one_full_delay() -> void:
	var f := _fixture(true, "short")
	_arm(f)
	f.controller._process(0.75)
	f.profile.publish(AUTO_DELAY, "long")
	f.controller._process(0.0)
	f.controller._process(3.99)
	assert_eq(f.bridge.requests, [])
	f.controller._process(0.02)
	assert_eq(f.bridge.requests, [f.bridge.frontier])

	var restored := _fixture(true, "short")
	_arm(restored)
	restored.controller._process(0.75)
	restored.profile.restore(false, "short")
	restored.controller._process(5.0)
	assert_false(restored.controller.is_auto_enabled())
	assert_eq(restored.bridge.requests, [])
	restored.profile.restore(true, "short")
	restored.controller._process(0.0)
	restored.controller._process(0.99)
	assert_eq(restored.bridge.requests, [])
	restored.controller._process(0.02)
	assert_eq(restored.bridge.requests, [restored.bridge.frontier])


func test_retirement_and_reentrant_replacement_cannot_leak_an_old_generation() -> void:
	var retired := _fixture(true, "short")
	_arm(retired)
	retired.controller._process(0.9)
	retired.controller.retire_current()
	retired.controller.arm_after_reveal(retired.bridge.frontier.duplicate(true))
	retired.controller._process(0.0)
	retired.controller._process(0.99)
	assert_eq(retired.bridge.requests, [])
	retired.controller._process(0.02)
	assert_eq(retired.bridge.requests, [retired.bridge.frontier],
		"explicit retirement permits the same authoritative source one fresh full delay")
	retired.controller.arm_after_reveal(retired.bridge.frontier.duplicate(true))
	retired.controller._process(10.0)
	assert_eq(retired.bridge.requests, [retired.bridge.frontier],
		"a duplicate finished signal cannot retry a consumed command")

	var replaced := _fixture(true, "short")
	_arm(replaced)
	var replacement := FakeBridge._proof("line-b", 2)
	replaced.bridge.during_request = func() -> void:
		replaced.controller.retire_current()
		replaced.bridge.frontier = replacement.duplicate(true)
		replaced.controller.arm_after_reveal(replacement.duplicate(true))
		replaced.controller._process(50.0)
	replaced.controller._process(1.01)
	assert_eq(replaced.bridge.requests, [FakeBridge._proof("line-a", 1)],
		"the replacement cannot run reentrantly inside the old Bridge command")
	replaced.controller._process(0.0)
	replaced.controller._process(1.01)
	assert_eq(replaced.bridge.requests, [FakeBridge._proof("line-a", 1), replacement])
