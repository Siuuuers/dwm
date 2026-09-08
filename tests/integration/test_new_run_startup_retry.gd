extends "res://addons/gut/test.gd"

const BOOTSTRAP := preload("res://autoload/ApplicationBootstrap.gd")
const STORAGE := preload("res://scripts/infrastructure/storage/JsonFileStorage.gd")
const OPS := preload("res://tests/support/FakeFileOps.gd")
const GATE := preload("res://scripts/application/transaction/ApplicationMutationGate.gd")

class RecoveryProfile extends Node:
	var bound_storage: RefCounted
	var configure_count := 0
	var initialize_count := 0

	func configure_new_run_storage(storage: RefCounted) -> Dictionary:
		configure_count += 1
		if bound_storage != null and bound_storage != storage:
			return {"ok": false, "code": &"profile_storage_replaced"}
		bound_storage = storage
		return {"ok": true}

	func initialize(storage: RefCounted) -> Dictionary:
		initialize_count += 1
		return {"ok": storage == bound_storage, "code": &"ok"}


class RecoverySaves extends Node:
	var initialized_storage: RefCounted
	var initialize_count := 0
	var profile_owner: Object
	var profile_bind_count := 0
	var storage_reconcile_count := 0
	var continuation_reconcile_count := 0
	var backup_bind_count := 0
	var fail_storage := false
	var fail_continuation := false
	var transaction_id := "new-run-startup-transaction"
	var retained_details := {"phase": "fixture", "nested": {"kept": true}}

	func initialize(storage: RefCounted) -> Dictionary:
		initialize_count += 1
		if initialized_storage != null and initialized_storage != storage:
			return {"ok": false, "code": &"save_storage_replaced"}
		initialized_storage = storage
		return {"ok": true}

	func configure_new_run_profile_owner(owner: Object) -> Dictionary:
		profile_bind_count += 1
		if profile_owner != null and profile_owner != owner:
			return {"ok": false, "code": &"profile_owner_replaced"}
		profile_owner = owner
		return {"ok": true}

	func reconcile_new_run_storage() -> Dictionary:
		storage_reconcile_count += 1
		if fail_storage:
			return _pending()
		return {"ok": true, "value": {"settled": [transaction_id]}}

	func reconcile_incomplete_continuations() -> Dictionary:
		continuation_reconcile_count += 1
		if fail_continuation:
			return _pending()
		return {"ok": true, "value": {"resumed": [transaction_id]}}

	func configure_backup_capture_provider(_provider: Callable, _paused_desktop_admission: Callable = Callable()) -> Dictionary:
		backup_bind_count += 1
		return {"ok": true}

	func _pending() -> Dictionary:
		return {
			"ok": false,
			"code": &"NEW_RUN_RECOVERY_PENDING",
			"recovery_required": true,
			"transaction_id": transaction_id,
			"details": retained_details.duplicate(true),
		}


class RouteHold extends Node:
	signal restore_publication_released()
	var bootstrap: Object
	var publish_count := 0
	var ready_during_publish := true
	var fail_publish := false
	var pause_services: Dictionary = {}
	var pause_bind_count := 0

	func configure_pause_services(services: Dictionary) -> Dictionary:
		# Pause composition is an unrelated service boundary in these retry-order tests.
		# Retain exactly what production publication supplies; do not replace recovery logic.
		pause_bind_count += 1
		if not services.has_all(["game_state", "saves", "bridge", "input", "audio", "gate",
				"profile", "localization", "backup_capture", "dating_presentation"]) \
				or not services.backup_capture is Callable or not services.backup_capture.is_valid():
			return {"ok": false, "code": &"invalid_pause_fixture_contract"}
		if not pause_services.is_empty() and pause_services != services:
			return {"ok": false, "code": &"pause_fixture_services_replaced"}
		pause_services = services.duplicate()
		return {"ok": true}

	func publish_startup_route_hold(token: String) -> Dictionary:
		publish_count += 1
		ready_during_publish = bool(bootstrap.get_startup_state().ready)
		if fail_publish:
			return {"ok": false, "code": &"fixture_route_publish_failure",
				"message": "physical route publication failed"}
		return {"ok": true, "code": &"ok",
			"value": {"deferred": false, "route_id": "main", "token": token}}


class RecoveryBootstrap extends "res://autoload/ApplicationBootstrap.gd":
	var targets: Dictionary = {}
	var stage_calls: Array[StringName] = []
	var generic_failure_stage: StringName = &""
	var retained_graph_owner: RefCounted
	var graph_owner_ids: Array[int] = []

	func _target(target_name: StringName) -> Node:
		return targets.get(target_name)

	func _run_stage(stage_id: StringName, mode: StringName) -> Dictionary:
		stage_calls.append(stage_id)
		if stage_id == generic_failure_stage:
			return {"ok": false, "code": &"fixture_generic_failure",
				"message": "generic stage failed", "details": {"stage": str(stage_id)}}
		if stage_id in [&"initialize_saves", &"initialize_profile", &"publish_application_ready"]:
			return super._run_stage(stage_id, mode)
		return {"ok": true, "code": &"ok"}

	func _configure_desktop_production_graph() -> Dictionary:
		if retained_graph_owner == null:
			retained_graph_owner = RefCounted.new()
		graph_owner_ids.append(retained_graph_owner.get_instance_id())
		return targets[&"SaveManager"].reconcile_incomplete_continuations()


func _fixture(fail_stage: StringName) -> Dictionary:
	var profile: Node = autofree(RecoveryProfile.new())
	var saves: Node = autofree(RecoverySaves.new())
	saves.fail_storage = fail_stage == &"initialize_saves"
	saves.fail_continuation = fail_stage == &"publish_application_ready"
	var bootstrap: Node = autofree(RecoveryBootstrap.new())
	var gate: RefCounted = GATE.new()
	var route_hold: Node = autofree(RouteHold.new())
	# Keep the real gate used by save-stage wake/fatal wiring; other composition is outside
	# the original retry stage-order contract and stays behind the recording router boundary.
	bootstrap.targets = {&"ProfileManager": profile, &"SaveManager": saves, &"SceneRouter": route_hold}
	bootstrap.set("_application_gate", gate)
	bootstrap.set("_selected_root", "startup-retry")
	bootstrap.set("_profile_storage", STORAGE.new("startup-retry/profile", OPS.new()))
	route_hold.bootstrap = bootstrap
	bootstrap.set("_startup_route_owner", route_hold)
	bootstrap.set("_startup_route_hold_token", "startup-route-fixture")
	return {"bootstrap": bootstrap, "profile": profile, "saves": saves, "route_hold": route_hold,
		"gate": gate}


func test_getter_is_pure_and_generic_startup_failure_is_not_retryable() -> void:
	var f := _fixture(&"")
	f.bootstrap.generic_failure_stage = &"initialize_localization"
	watch_signals(f.bootstrap)
	var failed: Dictionary = f.bootstrap.start()
	assert_eq(failed.get("code"), &"fixture_generic_failure")
	assert_eq(f.bootstrap.get_startup_state().fatal_result, failed)
	assert_eq(f.bootstrap.get_startup_state().failed_stage, &"initialize_localization")
	var before_calls: Array = f.bootstrap.stage_calls.duplicate()
	var recovery: Dictionary = f.bootstrap.get_new_run_startup_recovery()
	assert_eq(recovery, {"ok": true, "code": &"ok",
		"value": {"available": false, "transaction_id": ""}})
	assert_eq(f.bootstrap.stage_calls, before_calls)
	assert_eq(f.bootstrap.retry_new_run_startup("anything").get("code"),
		&"new_run_startup_recovery_unavailable")
	assert_false(f.bootstrap.get_startup_state().ready)
	assert_signal_emit_count(f.bootstrap, "startup_recovery_changed", 1)


func test_early_failure_retains_full_result_and_retries_without_reinitializing() -> void:
	var f := _fixture(&"initialize_saves")
	watch_signals(f.bootstrap)
	var failed: Dictionary = f.bootstrap.start()
	assert_eq(failed.get("code"), &"NEW_RUN_RECOVERY_PENDING")
	assert_eq(f.bootstrap.get_startup_state().fatal_result, failed)
	assert_eq(f.bootstrap.get_startup_state().failed_stage, &"initialize_saves")
	assert_eq(f.bootstrap.get_new_run_startup_recovery().value,
		{"available": true, "transaction_id": f.saves.transaction_id})
	assert_signal_emit_count(f.bootstrap, "startup_recovery_changed", 1)
	var checkpoint: Object = f.bootstrap.get("_retained_checkpoint_port")
	var save_identity: int = f.saves.get_instance_id()
	var storage_identity: int = f.saves.initialized_storage.get_instance_id()
	f.saves.fail_storage = false
	var recovered: Dictionary = f.bootstrap.retry_new_run_startup(f.saves.transaction_id)
	assert_true(recovered.get("ok", false), str(recovered))
	assert_true(f.bootstrap.get_startup_state().ready)
	assert_eq(f.saves.get_instance_id(), save_identity)
	assert_eq(f.saves.initialized_storage.get_instance_id(), storage_identity)
	assert_same(f.bootstrap.get("_retained_checkpoint_port"), checkpoint)
	assert_same(checkpoint.get("_gate"), f.gate, "retained checkpoint uses the real application gate")
	assert_eq(f.route_hold.pause_bind_count, 1, "successful publication binds current Pause services once")
	assert_same(f.route_hold.pause_services.gate, f.gate)
	assert_same(f.route_hold.pause_services.saves, f.saves)
	assert_same(f.route_hold.pause_services.profile, f.profile)
	assert_eq(f.saves.initialize_count, 1)
	assert_eq(f.saves.profile_bind_count, 1)
	assert_eq(f.profile.configure_count, 1)
	assert_eq(f.profile.initialize_count, 1)
	assert_eq(f.saves.storage_reconcile_count, 2)
	assert_eq(f.bootstrap.stage_calls.count(&"initialize_saves"), 1)
	assert_signal_emit_count(f.bootstrap, "startup_recovery_changed", 2)
	assert_signal_emit_count(f.bootstrap, "application_ready", 1)
	assert_eq(f.route_hold.publish_count, 1)
	assert_false(f.route_hold.ready_during_publish)
	assert_eq(f.bootstrap.get_new_run_startup_recovery().value,
		{"available": false, "transaction_id": ""})


func test_early_retry_rejects_foreign_reentrant_and_repeated_requests() -> void:
	var f := _fixture(&"initialize_saves")
	assert_false(f.bootstrap.start().get("ok", true))
	var calls_before: Array = f.bootstrap.stage_calls.duplicate()
	assert_eq(f.bootstrap.retry_new_run_startup("foreign").get("code"),
		&"invalid_new_run_startup_transaction")
	assert_eq(f.bootstrap.stage_calls, calls_before)
	f.bootstrap.set("_startup_recovery_busy", true)
	assert_eq(f.bootstrap.retry_new_run_startup(f.saves.transaction_id).get("code"),
		&"new_run_startup_retry_busy")
	f.bootstrap.set("_startup_recovery_busy", false)
	f.saves.fail_storage = false
	assert_true(f.bootstrap.retry_new_run_startup(f.saves.transaction_id).get("ok", false))
	assert_eq(f.bootstrap.retry_new_run_startup(f.saves.transaction_id).get("code"),
		&"new_run_startup_recovery_unavailable")


func test_repeated_early_recovery_failure_stays_on_same_operation_and_stage() -> void:
	var f := _fixture(&"initialize_saves")
	watch_signals(f.bootstrap)
	var first: Dictionary = f.bootstrap.start()
	var second: Dictionary = f.bootstrap.retry_new_run_startup(f.saves.transaction_id)
	assert_eq(second, first)
	assert_eq(f.bootstrap.get_startup_state().failed_stage, &"initialize_saves")
	assert_eq(f.bootstrap.get_new_run_startup_recovery().value.transaction_id,
		f.saves.transaction_id)
	assert_eq(f.saves.initialize_count, 1)
	assert_eq(f.saves.storage_reconcile_count, 2)
	assert_signal_emit_count(f.bootstrap, "startup_recovery_changed", 2)
	assert_signal_not_emitted(f.bootstrap, "application_ready")


func test_generic_stage_failure_after_early_settlement_closes_retry_capability() -> void:
	var f := _fixture(&"initialize_saves")
	watch_signals(f.bootstrap)
	assert_false(f.bootstrap.start().get("ok", true))
	f.saves.fail_storage = false
	f.bootstrap.generic_failure_stage = &"initialize_profile"
	var failed: Dictionary = f.bootstrap.retry_new_run_startup(f.saves.transaction_id)
	assert_eq(failed.get("code"), &"fixture_generic_failure")
	assert_eq(f.bootstrap.get_startup_state().failed_stage, &"initialize_profile")
	assert_eq(f.bootstrap.get_new_run_startup_recovery().value,
		{"available": false, "transaction_id": ""})
	assert_eq(f.bootstrap.retry_new_run_startup(f.saves.transaction_id).get("code"),
		&"new_run_startup_recovery_unavailable")
	assert_signal_emit_count(f.bootstrap, "startup_recovery_changed", 2)
	assert_signal_not_emitted(f.bootstrap, "application_ready")


func test_late_failure_retries_only_publish_and_retains_partial_graph_owner() -> void:
	var f := _fixture(&"publish_application_ready")
	watch_signals(f.bootstrap)
	var failed: Dictionary = f.bootstrap.start()
	assert_eq(failed.get("code"), &"NEW_RUN_RECOVERY_PENDING", str(failed))
	assert_eq(f.bootstrap.get_startup_state().failed_stage, &"publish_application_ready")
	assert_eq(f.bootstrap.get_startup_state().completed_stages.size(),
		f.bootstrap.get("STAGE_ORDER").size() - 1)
	var graph_owner: RefCounted = f.bootstrap.retained_graph_owner
	var calls_before: Array = f.bootstrap.stage_calls.duplicate()
	f.saves.fail_continuation = false
	var recovered: Dictionary = f.bootstrap.retry_new_run_startup(f.saves.transaction_id)
	assert_true(recovered.get("ok", false), str(recovered))
	assert_same(f.bootstrap.retained_graph_owner, graph_owner)
	assert_eq(f.bootstrap.graph_owner_ids,
		[graph_owner.get_instance_id(), graph_owner.get_instance_id()],
		"both publication attempts reuse the same retained graph owner")
	assert_eq(f.saves.initialize_count, 1)
	assert_eq(f.saves.continuation_reconcile_count, 2)
	for stage_id: StringName in f.bootstrap.get("STAGE_ORDER"):
		var expected := 2 if stage_id == &"publish_application_ready" else 1
		assert_eq(f.bootstrap.stage_calls.count(stage_id), expected, str(stage_id))
	assert_eq(f.bootstrap.stage_calls.slice(0, calls_before.size()), calls_before)
	assert_signal_emit_count(f.bootstrap, "application_ready", 1)
	assert_signal_emit_count(f.bootstrap, "startup_recovery_changed", 2)
	assert_eq(f.route_hold.publish_count, 1)
	assert_false(f.route_hold.ready_during_publish)


func test_route_publish_failure_keeps_title_hold_and_never_claims_readiness() -> void:
	var f := _fixture(&"")
	f.route_hold.fail_publish = true
	watch_signals(f.bootstrap)
	var failed: Dictionary = f.bootstrap.start()
	assert_eq(failed.get("code"), &"fixture_route_publish_failure")
	assert_eq(f.bootstrap.get_startup_state().failed_stage, &"publish_application_ready")
	assert_false(f.bootstrap.get_startup_state().ready)
	assert_eq(f.bootstrap.get("_startup_route_hold_token"), "startup-route-fixture")
	assert_eq(f.route_hold.publish_count, 1)
	assert_false(f.route_hold.ready_during_publish)
	assert_eq(f.bootstrap.get_new_run_startup_recovery().value,
		{"available": false, "transaction_id": ""})
	assert_signal_not_emitted(f.bootstrap, "application_ready")


func test_late_retry_with_different_transaction_becomes_nonretryable_fatal() -> void:
	var f := _fixture(&"publish_application_ready")
	assert_false(f.bootstrap.start().get("ok", true))
	f.saves.transaction_id = "different-new-run"
	var failed: Dictionary = f.bootstrap.retry_new_run_startup("new-run-startup-transaction")
	assert_eq(failed.get("code"), &"new_run_startup_transaction_changed")
	assert_eq(f.bootstrap.get_new_run_startup_recovery().value,
		{"available": false, "transaction_id": ""})
	assert_false(f.bootstrap.get_startup_state().ready)
