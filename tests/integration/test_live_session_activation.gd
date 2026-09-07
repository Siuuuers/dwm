extends GutTest

## The live-session fence is a transaction-completion fact. These tests keep the
## real SaveManager, GameState, Profile, issuer, journals, storage, and run/desktop
## restore participants; only unrelated physical presentation participants are
## bounded doubles so failures can be placed after the real run apply.
const SAVE := preload("res://autoload/SaveManager.gd")
const PROFILE := preload("res://autoload/ProfileManager.gd")
const GAME_STATE := preload("res://autoload/GameState.gd")
const STORAGE := preload("res://scripts/infrastructure/storage/JsonFileStorage.gd")
const FILE_OPS := preload("res://tests/support/FakeFileOps.gd")
const GATE := preload("res://scripts/application/transaction/ApplicationMutationGate.gd")
const ROOT_STORE := preload("res://scripts/infrastructure/identity/DesktopIssuerRootStore.gd")
const ISSUER := preload("res://scripts/application/desktop/DesktopIdentityNonceIssuer.gd")
const NAMESPACE := preload("res://tests/support/FakeDesktopNamespaceSource.gd")
const RUN_PARTICIPANT := preload("res://scripts/application/restore/RunRestoreParticipant.gd")
const PROFILE_PARTICIPANT := preload("res://scripts/application/restore/ProfileRestoreParticipant.gd")
const CONSEQUENCE_PARTICIPANT := preload("res://scripts/application/restore/DesktopConsequenceRestoreParticipant.gd")
const BOARD_PARTICIPANT := preload("res://scripts/application/restore/DesktopBoardRestoreParticipant.gd")
const CONSEQUENCE_STATE := preload("res://scripts/domain/desktop/DesktopConsequenceState.gd")
const BOARD_STATE := preload("res://scripts/domain/minesweeper/DesktopBoardState.gd")
const IDENTITY_PARTICIPANT := preload("res://scripts/application/restore/DesktopIdentityAllocationRestoreParticipant.gd")


class CompletionFaultStorage extends "res://scripts/infrastructure/storage/JsonFileStorage.gd":
	var fail_completed_operation := false
	var completed_write_failures := 0
	var fail_kind := "new_run"

	func write_atomic(relative_path: String, text: String, validator: Callable,
			keep_backup: bool = true) -> Dictionary:
		if fail_completed_operation and relative_path == "desktop-continuation-operations.json":
			var parsed: Variant = JSON.parse_string(text)
			if typeof(parsed) == TYPE_DICTIONARY:
				var operations: Variant = (parsed as Dictionary).get("operations")
				if typeof(operations) == TYPE_DICTIONARY:
					for operation: Variant in (operations as Dictionary).values():
						if typeof(operation) == TYPE_DICTIONARY \
								and str((operation as Dictionary).get("stage", "")) == "completed" \
								and str((operation as Dictionary).get("kind", "")) == fail_kind:
							fail_completed_operation = false
							completed_write_failures += 1
							return {"ok": false, "code": &"fixture_completion_write_failure"}
		return super.write_atomic(relative_path, text, validator, keep_backup)


class FaultRunParticipant extends "res://scripts/application/restore/RunRestoreParticipant.gd":
	var fail_validation := false
	var fail_activation := false
	var rollback_count := 0

	func validate_live_session_activation(ticket: Dictionary) -> Dictionary:
		if fail_validation:
			return {"ok": false, "code": &"fixture_activation_validation_failure"}
		return super.validate_live_session_activation(ticket)

	func activate_live_session(ticket: Dictionary) -> Dictionary:
		if fail_activation:
			return {"ok": false, "code": &"fixture_activation_failure"}
		return super.activate_live_session(ticket)

	func rollback_silent(backup: Dictionary) -> Dictionary:
		rollback_count += 1
		return super.rollback_silent(backup)


class Participant extends RefCounted:
	var participant_id := ""
	var plan_key := ""
	var fail_apply := false
	var fail_finalize := false
	var apply_count := 0
	var finalize_count := 0
	var before_finalize: Callable

	func _init(id: String, key: String) -> void:
		participant_id = id
		plan_key = key

	func prepare(input: Dictionary) -> Dictionary:
		return {"ok": true, "code": &"ok", "value": {plan_key: input.duplicate(true)}}

	func capture() -> Dictionary:
		return {"ok": true, "code": &"ok", "value": {"backup": {"id": participant_id}}}

	func apply_silent(plan: Dictionary) -> Dictionary:
		apply_count += 1
		if fail_apply:
			return {"ok": false, "code": &"fixture_late_apply_failure"}
		if participant_id == "route":
			return {"ok": true, "code": &"ok", "value": {
				"route_ready_token": {"id": "route-ready-%d" % apply_count}}}
		return {"ok": true, "code": &"ok", "value": {"plan": plan.duplicate(true)}}

	func rollback_silent(_backup: Dictionary) -> Dictionary:
		return {"ok": true, "code": &"ok", "value": {"rolled_back": participant_id}}

	func finalize() -> Dictionary:
		finalize_count += 1
		if before_finalize.is_valid():
			before_finalize.call()
		if fail_finalize:
			return {"ok": false, "code": &"fixture_late_finalize_failure"}
		return {"ok": true, "code": &"ok", "value": {}}


func _context() -> Dictionary:
	return {"route_id": "main", "dialogic_checkpoint": {}, "active_app_id": null,
		"audio_context": {}, "content_version": 1}


func _fixture() -> Dictionary:
	var ops: RefCounted = FILE_OPS.new()
	var saves: RefCounted = CompletionFaultStorage.new("live-session/saves", ops)
	var profiles: RefCounted = STORAGE.new("live-session/profile", ops)
	var gate: RefCounted = GATE.new()

	var profile: Node = add_child_autofree(PROFILE.new())
	assert_true(profile.configure_new_run_storage(profiles).get("ok", false))
	assert_true(profile.configure_mutation_gate(gate).get("ok", false))
	assert_true(profile.initialize(profiles).get("ok", false))

	var root_store: RefCounted = ROOT_STORE.new()
	assert_true(root_store.configure(STORAGE.new("live-session/issuer", ops),
		NAMESPACE.new("7".repeat(64))).get("ok", false))
	assert_true(root_store.load_or_create().get("ok", false))
	var issuer: RefCounted = ISSUER.new()
	assert_true(issuer.configure(root_store).get("ok", false))

	var manager: Node = add_child_autofree(SAVE.new())
	assert_true(manager.initialize(saves).get("ok", false))
	assert_true(manager.configure_mutation_gate(gate).get("ok", false))
	assert_true(manager.configure_identity_issuer(issuer).get("ok", false))
	assert_true(manager.configure_new_run_profile_owner(profile).get("ok", false))
	assert_true(manager.configure_identity_allocation_participant(
		IDENTITY_PARTICIPANT.new(issuer, manager)).get("ok", false))

	var game_state: Node = add_child_autofree(GAME_STATE.new())
	assert_true(game_state.configure_mutation_gate(gate).get("ok", false))
	var localization := Participant.new("localization", "localization_plan")
	var audio := Participant.new("audio", "audio_plan")
	var route := Participant.new("route", "route_plan")
	var narrative := Participant.new("narrative", "narrative_plan")
	var run := FaultRunParticipant.new(game_state)
	var registry: RefCounted = preload("res://scripts/domain/schedule/ScheduleActionRegistry.gd").load_current().value.registry
	var view: RefCounted = preload("res://scripts/application/schedule/ScheduleViewController.gd").new()
	assert_true(view.configure(registry, preload("res://scripts/domain/schedule/ScheduleRules.gd"), registry.fingerprint()).ok)
	assert_true(manager.configure_restore_participants({
		"run": run,
		"desktop_consequence": CONSEQUENCE_PARTICIPANT.new(CONSEQUENCE_STATE.new()),
		"desktop_board": BOARD_PARTICIPANT.new(BOARD_STATE.new()),
		"schedule_view": preload("res://scripts/application/restore/ScheduleViewRestoreParticipant.gd").new(
			view, registry, issuer, preload("res://scripts/domain/desktop/DesktopContinuationRemapper.gd")),
		"profile": PROFILE_PARTICIPANT.new(profile),
		"localization": localization,
		"audio": audio,
		"route": route,
		"narrative": narrative,
	}).get("ok", false))
	return {"ops": ops, "saves": saves, "gate": gate, "profile": profile,
		"issuer": issuer, "manager": manager, "game_state": game_state, "run": run,
		"localization": localization, "audio": audio, "route": route,
		"narrative": narrative}


func _capture_session(game_state: Node) -> Dictionary:
	if not game_state.has_method("capture_live_session"):
		fail_test("GameState must expose capture_live_session()")
		return {}
	var result: Dictionary = game_state.call(&"capture_live_session")
	assert_true(result.get("ok", false), str(result))
	if not result.get("ok", false):
		return {}
	var value: Dictionary = (result["value"] as Dictionary).duplicate(true)
	var keys: Array = value.keys()
	keys.sort()
	assert_eq(keys, ["active", "generation", "owner_id", "run_id"])
	assert_typeof(value.active, TYPE_BOOL)
	assert_typeof(value.generation, TYPE_INT)
	assert_typeof(value.run_id, TYPE_STRING)
	return value


func _validate_session(game_state: Node, handle: Dictionary) -> Dictionary:
	if not game_state.has_method("validate_live_session"):
		fail_test("GameState must expose validate_live_session(handle)")
		return {"ok": false, "code": &"missing_test_api"}
	return game_state.call(&"validate_live_session", handle.duplicate(true))


func _start_and_save(fixture: Dictionary) -> Dictionary:
	var started: Dictionary = fixture.manager.start_new_run(_context())
	assert_true(started.get("ok", false), str(started))
	if not started.get("ok", false):
		return {}
	var saved: Dictionary = fixture.manager.save_latest_to_slot(1)
	assert_true(saved.get("ok", false), str(saved))
	return started


func _prepared_slot(fixture: Dictionary) -> Dictionary:
	var prepared: Dictionary = fixture.manager.prepare_restore_slot(1)
	assert_true(prepared.get("ok", false), str(prepared))
	return (prepared.get("value", {}) as Dictionary).get("prepared", {}).duplicate(true)


func test_successful_new_run_activates_once_after_every_participant_finalizes() -> void:
	var f := _fixture()
	var before := _capture_session(f.game_state)
	if before.is_empty(): return
	assert_false(before.active)
	var observed_during_last_finalize: Array[Dictionary] = []
	f.route.before_finalize = func() -> void:
		observed_during_last_finalize.append(_capture_session(f.game_state))

	var started: Dictionary = f.manager.start_new_run(_context())
	assert_true(started.get("ok", false), str(started))
	if not started.get("ok", false): return
	assert_eq(observed_during_last_finalize.size(), 1)
	assert_eq(observed_during_last_finalize[0], before,
		"the final fallible participant runs before session activation")
	var after := _capture_session(f.game_state)
	assert_true(after.active)
	assert_eq(after.generation, before.generation + 1)
	assert_eq(after.owner_id, f.game_state.get_instance_id())
	assert_false(str(after.run_id).is_empty())
	assert_true(_validate_session(f.game_state, after).get("ok", false))
	assert_false(f.gate.is_active())
	var operation: Dictionary = f.manager._continuation_journal.get_operation(
		str(started.value.transaction_id))
	assert_true(operation.get("ok", false), str(operation))
	assert_eq(str(operation.get("value", {}).get("stage", "")), "completed")


func test_completion_write_failure_keeps_activated_handle_inaccessible_then_retry_reuses_it() -> void:
	var f := _fixture()
	var before := _capture_session(f.game_state)
	if before.is_empty(): return
	f.saves.fail_completed_operation = true
	var failed: Dictionary = f.manager.start_new_run(_context())
	assert_eq(failed.get("code"), &"NEW_RUN_RECOVERY_PENDING", str(failed))
	assert_eq(f.saves.completed_write_failures, 1)
	var pending := _capture_session(f.game_state)
	assert_true(pending.active)
	assert_eq(pending.generation, before.generation + 1)
	assert_false(_validate_session(f.game_state, pending).get("ok", true),
		"the retained New Run gate makes the activated handle externally unusable")
	assert_true(f.gate.is_internal_owner_active(&"new_run"))

	var retried: Dictionary = f.manager.retry_new_run(str(failed.transaction_id))
	assert_true(retried.get("ok", false), str(retried))
	if not retried.get("ok", false): return
	var recovered := _capture_session(f.game_state)
	assert_eq(recovered, pending,
		"same-operation retry replays the activation ticket without bumping generation")
	assert_true(_validate_session(f.game_state, recovered).get("ok", false))
	assert_false(f.gate.is_active())
	var operation: Dictionary = f.manager._continuation_journal.get_operation(
		str(failed.transaction_id))
	assert_true(operation.get("ok", false), str(operation))
	assert_eq(str(operation.get("value", {}).get("stage", "")), "completed")


func test_compensated_late_restore_failures_preserve_the_original_session_handle() -> void:
	for failure_kind: String in ["apply", "finalize"]:
		var f := _fixture()
		if _start_and_save(f).is_empty(): continue
		var before_state: Dictionary = f.game_state.capture_restore_state()
		var original := _capture_session(f.game_state)
		if original.is_empty(): continue
		var prepared := _prepared_slot(f)
		if prepared.is_empty(): continue
		if failure_kind == "apply":
			f.narrative.fail_apply = true
		else:
			f.route.fail_finalize = true
		var failed: Dictionary = f.manager.commit_prepared_restore(prepared)
		assert_false(failed.get("ok", true), failure_kind)
		assert_eq(failed.get("code"),
			&"fixture_late_apply_failure" if failure_kind == "apply" \
			else &"fixture_late_finalize_failure")
		assert_eq(f.game_state.capture_restore_state(), before_state,
			"%s refusal fully compensates real GameState" % failure_kind)
		assert_eq(_capture_session(f.game_state), original,
			"%s refusal cannot advance the process session generation" % failure_kind)
		assert_true(_validate_session(f.game_state, original).get("ok", false),
			"the paused source handle remains resumable after %s compensation" % failure_kind)
		assert_false(f.gate.is_active())


func test_successful_load_invalidates_the_old_handle_and_activates_one_new_generation() -> void:
	var f := _fixture()
	if _start_and_save(f).is_empty(): return
	var original := _capture_session(f.game_state)
	if original.is_empty(): return
	f.game_state.coins += 1
	var prepared := _prepared_slot(f)
	if prepared.is_empty(): return
	var loaded: Dictionary = f.manager.commit_prepared_restore(prepared)
	assert_true(loaded.get("ok", false), str(loaded))
	if not loaded.get("ok", false): return
	var restored := _capture_session(f.game_state)
	assert_true(restored.active)
	assert_eq(restored.generation, original.generation + 1)
	assert_eq(restored.owner_id, original.owner_id)
	assert_false(_validate_session(f.game_state, original).get("ok", true),
		"a successful Load permanently stales the pre-restore handle")
	assert_true(_validate_session(f.game_state, restored).get("ok", false))
	assert_false(f.gate.is_active())


func test_restore_completion_write_retry_reuses_the_activated_handle() -> void:
	var f := _fixture()
	if _start_and_save(f).is_empty(): return
	var prepared := _prepared_slot(f)
	if prepared.is_empty(): return
	f.saves.fail_kind = "restore"
	f.saves.fail_completed_operation = true
	var loaded: Dictionary = f.manager.commit_prepared_restore(prepared)
	assert_true(loaded.get("ok", false), str(loaded))
	assert_eq(f.saves.completed_write_failures, 1)
	var activated := _capture_session(f.game_state)
	var reconciled: Dictionary = f.manager.reconcile_incomplete_continuations()
	assert_true(reconciled.get("ok", false), str(reconciled))
	assert_eq(reconciled.get("value", {}).get("reconciled", []).size(), 1)
	assert_eq(_capture_session(f.game_state), activated)
	assert_true(_validate_session(f.game_state, activated).get("ok", false))
	assert_false(f.gate.is_fatal_latched())
	assert_eq(f.manager._continuation_journal.list_incomplete().get("value"), [])


func test_post_route_activation_failure_retains_custody_and_latches_fatal_without_rollback() -> void:
	for operation: String in ["new_run", "restore"]:
		var f := _fixture()
		var prepared := {}
		if operation == "restore":
			if _start_and_save(f).is_empty(): continue
			prepared = _prepared_slot(f)
			if prepared.is_empty(): continue
		var routes_before: int = f.route.finalize_count
		f.run.fail_activation = true
		var failed: Dictionary = f.manager.start_new_run(_context()) if operation == "new_run" \
			else f.manager.commit_prepared_restore(prepared)
		assert_false(failed.get("ok", true), operation)
		assert_eq(failed.get("code"), &"APPLICATION_FATAL", operation)
		assert_eq(f.route.finalize_count, routes_before + 1, operation)
		assert_eq(f.run.rollback_count, 0, operation)
		assert_true(f.gate.is_fatal_latched(), operation)
		assert_false(f.manager.save_latest_to_slot(2).get("ok", true), operation)


func test_restore_activation_validation_failure_compensates_before_route_dispatch() -> void:
	var f := _fixture()
	if _start_and_save(f).is_empty(): return
	var original := _capture_session(f.game_state)
	var state_before: Dictionary = f.game_state.capture_restore_state()
	var routes_before: int = f.route.finalize_count
	var prepared := _prepared_slot(f)
	if prepared.is_empty(): return
	f.run.fail_validation = true
	var failed: Dictionary = f.manager.commit_prepared_restore(prepared)
	assert_eq(failed.get("code"), &"fixture_activation_validation_failure")
	assert_eq(f.route.finalize_count, routes_before)
	assert_eq(f.run.rollback_count, 1)
	assert_eq(f.game_state.capture_restore_state(), state_before)
	assert_eq(_capture_session(f.game_state), original)
	assert_true(_validate_session(f.game_state, original).get("ok", false))
	assert_false(f.gate.is_active())


func test_desktop_ports_read_the_activated_run_identity_and_refresh_after_load() -> void:
	var f := _fixture()
	if not f.game_state.has_method("capture_desktop_identity_context"):
		fail_test("GameState must expose the activated desktop identity")
		return
	var provider := Callable(f.game_state, "capture_desktop_identity_context")
	assert_false(provider.call().get("ok", true), "title has no playable desktop identity")
	var board := preload("res://scripts/application/minesweeper/GameStateDesktopBoardPort.gd").new()
	var shop := preload("res://scripts/application/shop/GameStateMinesweeperShopPort.gd").new()
	assert_true(board.configure(f.game_state, f.issuer, provider).get("ok", false))
	assert_true(shop.configure(f.game_state, provider).get("ok", false))
	assert_false(board.capture().get("ok", true))
	if _start_and_save(f).is_empty(): return
	var original: Dictionary = provider.call().value
	assert_eq(board.capture().value.branch_id, original.branch_id)
	assert_eq(shop.capture().value.causal_day_instance, original.causal_day_instance)
	var held: Dictionary = f.gate.acquire(&"restore")
	assert_true(held.ok)
	assert_false(board.guard_external(&"reveal").get("ok", true))
	assert_false(shop.guard_external(&"purchase").get("ok", true))
	assert_true(f.gate.release(&"restore", str(held.value.token)).ok)
	var loaded: Dictionary = f.manager.commit_prepared_restore(_prepared_slot(f))
	assert_true(loaded.ok, str(loaded))
	if not loaded.ok: return
	var restored: Dictionary = provider.call().value
	assert_ne(restored.branch_id, original.branch_id)
	assert_eq(board.capture().value.branch_id, restored.branch_id)
	assert_eq(shop.capture().value.causal_day_instance, restored.causal_day_instance)
	assert_true(board.guard_external(&"reveal").ok)
	# Reconstructing a port must use persisted completions, not an empty local counter.
	f.game_state.minesweeper_app_rounds_finished_today = 1
	var reconstructed := preload("res://scripts/application/minesweeper/GameStateDesktopBoardPort.gd").new()
	assert_true(reconstructed.configure(f.game_state, f.issuer, provider).ok)
	assert_eq(reconstructed.capture().value.next_app_round_ordinal, 2)
