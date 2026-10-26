extends "res://addons/gut/test.gd"

const FIXTURE := preload("res://tests/support/SceneChallengeFixture.gd")
const LEDGER := preload("res://scripts/profile/DatingAttemptLedger.gd")
var f: RefCounted

func before_each() -> void:
	f = FIXTURE.new()
	assert_true(f.setup().ok)

func after_each() -> void:
	f.dispose()

func _retain_old_global_record(record: Dictionary) -> void:
	var snapshot: Dictionary = f.profile.get_profile_snapshot()
	var old: Dictionary = LEDGER.prepare_update(snapshot.dating_attempts, f.state.lifecycle.run_id,
		LEDGER.semantic_slot(record.context), f.state.lifecycle.branch_id, record, 0, -1, {}, {"mode": "fresh"})
	assert_true(old.ok, str(old))
	if not old.ok: return
	snapshot.dating_attempts = old.value.ledger
	f.profile.set("_profile", snapshot)

func test_saved_absence_ignores_old_global_attempt_on_same_branch() -> void:
	assert_true(f.begin().ok)
	var selected: Dictionary = f.state.capture_restore_state().value.backup
	assert_true(f.action("start").ok)
	_retain_old_global_record(f.record())
	var global_before: Dictionary = f.profile.get_profile_snapshot()
	assert_true(f.state.rollback_restore_silent(selected).ok)
	assert_true(f.owner.reconcile_restore_silent({}).ok)
	assert_true(f.begin().ok)
	assert_eq(f.record(), {})
	assert_eq(f.owner.pull_physical(f.token).value.state, "never_started")
	var closed: Dictionary = f.owner.close_scene_challenge(f.token)
	assert_true(closed.ok, str(closed))
	if closed.ok:
		assert_null(closed.value.attempt_proof)
		assert_eq(closed.value.outcome, "never_started")
	assert_eq(f.profile.get_profile_snapshot(), global_before)

func test_saved_absence_starts_from_current_run_inventory_not_old_global_spec() -> void:
	assert_true(f.begin().ok)
	var selected: Dictionary = f.state.capture_restore_state().value.backup
	assert_true(f.action("start").ok)
	var old: Dictionary = f.record()
	_retain_old_global_record(old)
	var global_before: Dictionary = f.profile.get_profile_snapshot()
	assert_true(f.state.rollback_restore_silent(selected).ok)
	f.state.inventory = {"debug_key": 1}
	assert_true(f.recreate_owner().ok)
	assert_true(f.begin().ok)
	assert_true(f.action("start").ok)
	assert_eq(f.record().phase, "preparing")
	assert_true(f.record().spec.capability_ids.has("forced_no_guess"))
	assert_ne(f.record().spec.board_token, old.spec.board_token)
	assert_eq(f.profile.get_profile_snapshot(), global_before)

func test_selected_board_is_exact_even_when_global_record_disagrees() -> void:
	assert_true(f.begin().ok)
	assert_true(f.action("start").ok)
	_retain_old_global_record(f.record())
	assert_true(f.action("flag", 0).ok)
	var selected: Dictionary = f.state.capture_restore_state().value.backup
	var selected_record: Dictionary = f.record()
	assert_true(f.action("unflag", 0).ok)
	assert_true(f.action("reveal", 323).ok)
	var global_before: Dictionary = f.profile.get_profile_snapshot()
	assert_true(f.state.rollback_restore_silent(selected).ok)
	assert_true(f.owner.reconcile_restore_silent({}).ok)
	assert_true(f.begin().ok)
	assert_eq(f.record(), selected_record)
	assert_eq(f.record().envelope.shell.flagged_indices, [0])
	assert_true(f.owner.close_scene_challenge(f.token).ok)
	assert_eq(f.profile.get_profile_snapshot(), global_before)
