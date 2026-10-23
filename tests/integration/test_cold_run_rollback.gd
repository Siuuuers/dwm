extends "res://addons/gut/test.gd"

var _scene_validation_scope := preload("res://tests/support/SceneValidationScope.gd").new()

const GAME_STATE := preload("res://autoload/GameState.gd")
const PARTICIPANT := preload("res://scripts/application/restore/RunRestoreParticipant.gd")

func _installed_plan() -> Dictionary:
	var template: Node = autofree(GAME_STATE.new())
	template.reset_game()
	return {"snapshot": template.capture_run_snapshot_input()}

func test_cold_compensation_restores_exact_baseline_and_allows_retry() -> void:
	var owner: Node = autofree(GAME_STATE.new())
	var participant := PARTICIPANT.new(owner)
	var captured: Dictionary = participant.capture()
	assert_true(captured.ok)
	var baseline: Dictionary = captured.value.duplicate(true)
	assert_false(baseline.backup.run_configuration_installed)
	assert_eq(baseline.backup.lifecycle.run_id, "")
	var plan := _installed_plan()
	watch_signals(owner)
	for attempt: int in 2:
		assert_true(participant.apply_silent(plan).get("ok", false), "retry can install a validated run")
		assert_true(owner.capture_restore_state().value.backup.run_configuration_installed)
		var rolled: Dictionary = participant.rollback_silent(captured.value)
		assert_true(rolled.get("ok", false), str(rolled))
		assert_eq(owner.capture_restore_state().value, baseline, "all captured owner state returns exactly")
		assert_true(participant.rollback_silent(captured.value).get("ok", false), "compensation is retryable")
	assert_eq(captured.value, baseline, "retained backup remains detached")
	assert_signal_not_emitted(owner, "save_relevant_state_changed")

func test_cold_backup_cannot_bypass_installed_or_session_validation() -> void:
	var owner: Node = autofree(GAME_STATE.new())
	var captured: Dictionary = owner.capture_restore_state().value
	assert_true(owner.apply_restore_silent(_installed_plan()).get("ok", false))
	var installed: Dictionary = owner.capture_restore_state().value
	var forged := captured.duplicate(true)
	forged.backup.run_configuration_installed = true
	assert_false(owner.rollback_restore_silent(forged).get("ok", false))
	assert_eq(owner.capture_restore_state().value, installed)
	forged = captured.duplicate(true)
	forged.backup.lifecycle.day = 2
	assert_false(owner.rollback_restore_silent(forged).get("ok", false), "only exact cold lifecycle is admitted")
	assert_eq(owner.capture_restore_state().value, installed)
	forged = captured.duplicate(true)
	forged.backup.session_generation += 1
	assert_eq(owner.rollback_restore_silent(forged).get("code"), &"stale_run_backup")
	assert_eq(owner.capture_restore_state().value, installed)
	assert_false(owner._run_lifecycle.prepare_restore(captured.backup.lifecycle).get("ok", false), "persisted run validation stays strict")

func test_scene_install_compensation_preserves_cold_state_and_configured_owners() -> void:
	var fixture := preload("res://tests/support/SceneRunSaveFixture.gd").new()
	var setup: Dictionary = fixture.setup(get_tree())
	assert_true(setup.get("ok", false), str(setup))
	if not setup.get("ok", false):
		fixture.close()
		return
	var owner: Node = fixture.game
	var participant := PARTICIPANT.new(owner)
	var captured: Dictionary = participant.capture()
	var lifecycle_owner: RefCounted = owner._run_lifecycle
	var bridge_owner: Object = owner._scene_event_bridge
	assert_false(captured.value.backup.run_configuration_installed)
	assert_eq(captured.value.backup.lifecycle.run_id, "")
	watch_signals(owner)
	for attempt: int in 2:
		var applied: Dictionary = participant.apply_silent({"snapshot": fixture.snapshot})
		assert_true(applied.get("ok", false), str(applied))
		if not applied.get("ok", false): break
		assert_true(owner.capture_restore_state().value.backup.lifecycle.has("scene_assignment"))
		var rolled: Dictionary = participant.rollback_silent(captured.value)
		assert_true(rolled.get("ok", false), str(rolled))
		assert_eq(owner.capture_restore_state().value, captured.value, "scene identity, references, receipts and contacts return exactly")
		assert_same(owner._run_lifecycle, lifecycle_owner)
		assert_same(owner._run_lifecycle._scene_issuer, fixture.issuer)
		assert_same(owner._scene_event_bridge, bridge_owner)
	assert_signal_not_emitted(owner, "save_relevant_state_changed")
	fixture.close()

func before_each() -> void:
	_scene_validation_scope.install(true)

func after_each() -> void:
	_scene_validation_scope.restore()
