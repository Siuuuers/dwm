extends GutTest
## Real durable NewRun owners and actual SceneTree publication. Bootstrap's unrelated
## construction stages are bypassed; its start/retry cursor and final publication are real.
const PAIR := preload("res://tests/integration/test_new_run_pair_durability.gd")
const SAVE := preload("res://autoload/SaveManager.gd")
const ROUTER := preload("res://autoload/SceneRouter.gd")
const ROUTE := preload("res://scripts/application/restore/RouteRestoreParticipant.gd")
const CHECKPOINT := preload("res://scripts/application/run/SaveManagerCheckpointPort.gd")

class FaultStorage extends "res://scripts/infrastructure/storage/JsonFileStorage.gd":
	var fail_completion := false
	var target_transaction := ""
	var completion_faults := 0
	var fail_late_read := false
	var late_read_faults := 0
	var fail_autosave_inspection := false
	func inspect_revision(relative_path: String) -> Dictionary:
		if fail_autosave_inspection and relative_path == "autosave.json":
			return {"ok":false,"code":&"fixture_autosave_inspection_failure"}
		return super.inspect_revision(relative_path)
	func write_atomic(relative_path: String, text: String, validator: Callable, keep_backup: bool = true) -> Dictionary:
		if fail_completion and relative_path == "desktop-continuation-operations.json":
			var parsed: Variant = JSON.parse_string(text)
			if parsed is Dictionary:
				var operation: Dictionary = parsed.get("operations",{}).get(target_transaction,{})
				if operation.get("stage") == "completed":
					completion_faults += 1
					return {"ok":false,"code":&"fixture_completion_write_failure"}
		return super.write_atomic(relative_path,text,validator,keep_backup)
	func read_text(relative_path: String) -> Dictionary:
		if fail_late_read and relative_path == "desktop-consequence-checkpoint.json":
			late_read_faults += 1
			return {"ok":false,"code":&"fixture_consequence_read_failure"}
		return super.read_text(relative_path)

class StartupDriver extends "res://autoload/ApplicationBootstrap.gd":
	var saves: Node
	var profile: Node
	var profile_storage: RefCounted
	var checkpoint: RefCounted
	func _target(target_name: StringName) -> Node:
		if target_name == &"SaveManager": return saves
		if target_name == &"ProfileManager": return profile
		return null
	func _run_stage(stage_id: StringName, _mode: StringName) -> Dictionary:
		if stage_id == &"initialize_saves": return saves.reconcile_new_run_storage()
		if stage_id == &"initialize_profile": return profile.initialize(profile_storage)
		if stage_id == &"publish_application_ready":
			var resumed: Dictionary = saves.reconcile_incomplete_continuations()
			if not resumed.get("ok",false): return resumed
			return checkpoint.read_pending_consequence_checkpoint()
		return {"ok":true}

var original_scene: Node
var title: Control
var ready_count := 0
var helper: Node

func before_each() -> void:
	original_scene = get_tree().current_scene
	title = Control.new()
	title.name = "RetainedStartupTitle"
	get_tree().root.add_child(title)
	get_tree().current_scene = title
	ready_count = 0
	helper = add_child_autofree(PAIR.new())
	helper.gut = gut

func after_each() -> void:
	var published := get_tree().current_scene
	get_tree().current_scene = original_scene if is_instance_valid(original_scene) else null
	if is_instance_valid(published) and published != original_scene and published != title: published.free()
	if is_instance_valid(title): title.free()
	await get_tree().process_frame

func _cold_fixture() -> Dictionary:
	# Leave a real durable decision with an unfinished live route, then create fresh
	# owners over precisely the persisted bytes, as a new process would.
	var seed: Dictionary = helper._fixture()
	seed.route.fail_apply = true
	var failure: Dictionary = seed.manager.start_new_run(helper._context())
	assert_eq(failure.get("code"),&"NEW_RUN_RECOVERY_PENDING",str(failure))
	if not failure.has("transaction_id"): return {}
	var f: Dictionary = helper._fixture(seed.ops.snapshot_persisted(),false)
	var storage := FaultStorage.new("pair/saves",f.ops)
	storage.target_transaction = str(failure.transaction_id)
	var manager: Node = autofree(SAVE.new())
	assert_true(manager.initialize(storage).get("ok",false))
	assert_true(manager.configure_mutation_gate(f.gate).get("ok",false))
	assert_true(manager.configure_identity_issuer(f.manager._identity_issuer).get("ok",false))
	assert_true(manager.configure_new_run_profile_owner(f.profile).get("ok",false))
	var router: Node = add_child_autofree(ROUTER.new())
	assert_true(router.configure_mutation_gate(f.gate).get("ok",false))
	var participants: Dictionary = f.manager._restore_participants.duplicate()
	participants.route = ROUTE.new(router)
	assert_true(manager.configure_restore_participants(participants).get("ok",false))
	var held: Dictionary = router.begin_startup_route_hold()
	assert_true(held.get("ok",false))
	var bootstrap: Node = autofree(StartupDriver.new())
	bootstrap.saves = manager
	bootstrap.profile = f.profile
	bootstrap.profile_storage = f.profiles
	bootstrap.checkpoint = CHECKPOINT.new(manager)
	assert_true(bootstrap.checkpoint.configure_fatal_latch(f.gate).get("ok",false))
	bootstrap._startup_route_owner = router
	bootstrap._startup_route_hold_token = str(held.value.token)
	bootstrap.application_ready.connect(func(): ready_count += 1)
	f.manager = manager
	f.storage = storage
	f.router = router
	f.bootstrap = bootstrap
	f.transaction = str(failure.transaction_id)
	return f

func _frames() -> void:
	for frame in 4: await get_tree().process_frame

func test_real_completion_journal_failure_keeps_title_then_same_startup_retry_publishes_once() -> void:
	var f := _cold_fixture()
	if f.is_empty(): return
	var autosave_before: Dictionary = f.storage.inspect_revision("autosave.json")
	var profile_before: Dictionary = f.profiles.inspect_revision("profile.json")
	f.storage.fail_completion = true
	var failed: Dictionary = f.bootstrap.start()
	assert_eq(failed.get("code"),&"NEW_RUN_RECOVERY_PENDING",str(failed))
	assert_eq(f.storage.completion_faults,1,"Fault is after real route finalize at journal completion")
	assert_eq(failed.get("transaction_id"),f.transaction)
	assert_eq(f.manager._continuation_journal.get_operation(f.transaction).value.stage,"participants_applied")
	assert_true(f.gate.is_internal_owner_active(&"new_run"))
	assert_false(f.bootstrap.get_startup_state().ready)
	assert_eq(ready_count,0)
	await _frames()
	assert_eq(get_tree().current_scene,title,"Real route finalize cannot remove Title before durable acknowledgement")
	assert_true(title.is_inside_tree())
	assert_eq(f.storage.inspect_revision("autosave.json"),autosave_before)
	assert_eq(f.profiles.inspect_revision("profile.json"),profile_before)
	f.storage.fail_completion = false
	var retried: Dictionary = f.bootstrap.retry_new_run_startup(f.transaction)
	assert_true(retried.get("ok",false),str(retried))
	assert_eq(ready_count,1)
	assert_true(f.bootstrap.get_startup_state().ready)
	assert_false(f.gate.is_active())
	await _frames()
	assert_eq(get_tree().current_scene.scene_file_path,"res://scenes/main/MainGameScene.tscn")
	assert_eq(f.manager._continuation_journal.get_operation(f.transaction).value.stage,"completed")
	assert_eq(f.storage.inspect_revision("autosave.json"),autosave_before)
	assert_eq(f.profiles.inspect_revision("profile.json"),profile_before)
	assert_false(f.bootstrap.retry_new_run_startup(f.transaction).get("ok",true))
	assert_eq(ready_count,1)

func test_real_late_consequence_read_failure_keeps_title_after_completed_new_run() -> void:
	var f := _cold_fixture()
	if f.is_empty(): return
	assert_true(f.ops.write_bytes("pair/saves/desktop-consequence-checkpoint.json",
		'{"schema_version":1,"records":{},"abandoned":{}}'.to_utf8_buffer()).get("ok",false))
	assert_true(f.ops.flush_path("pair/saves/desktop-consequence-checkpoint.json").get("ok",false))
	f.storage.fail_late_read = true
	var failed: Dictionary = f.bootstrap.start()
	assert_eq(failed.get("code"),&"fixture_consequence_read_failure",str(failed))
	assert_eq(f.storage.late_read_faults,1,"Real checkpoint port performs post-replay read")
	assert_eq(f.manager._continuation_journal.get_operation(f.transaction).value.stage,"completed")
	assert_false(f.gate.is_active())
	assert_false(f.bootstrap.get_startup_state().ready)
	assert_false(f.bootstrap.get_new_run_startup_recovery().value.available,"Generic failure must not fabricate unfinished New Run")
	assert_eq(ready_count,0)
	await _frames()
	assert_eq(get_tree().current_scene,title,"Later setup failure cannot expose Main after a completed journal")
	assert_true(title.is_inside_tree())

func test_real_early_pair_failure_retries_before_profile_initialization_with_same_owners() -> void:
	var f := _cold_fixture()
	if f.is_empty(): return
	var storage_id: int = f.storage.get_instance_id()
	var profile_id: int = f.profile.get_instance_id()
	var gate_id: int = f.gate.get_instance_id()
	f.storage.fail_autosave_inspection = true
	var failed: Dictionary = f.bootstrap.start()
	assert_eq(failed.get("code"),&"NEW_RUN_RECOVERY_PENDING",str(failed))
	assert_eq(f.bootstrap.get_startup_state().failed_stage,&"initialize_saves")
	assert_eq(f.profile.get_profile_snapshot(),{},"Profile is not adopted before pair settlement")
	assert_true(f.gate.is_internal_owner_active(&"new_run"))
	assert_eq(ready_count,0)
	await _frames()
	assert_eq(get_tree().current_scene,title)
	var still_failed: Dictionary = f.bootstrap.retry_new_run_startup(f.transaction)
	assert_eq(still_failed.get("transaction_id"),f.transaction)
	assert_eq(f.profile.get_profile_snapshot(),{})
	f.storage.fail_autosave_inspection = false
	var recovered: Dictionary = f.bootstrap.retry_new_run_startup(f.transaction)
	assert_true(recovered.get("ok",false),str(recovered))
	assert_eq(f.manager._storage.get_instance_id(),storage_id)
	assert_eq(f.profile.get_instance_id(),profile_id)
	assert_eq(f.gate.get_instance_id(),gate_id)
	assert_false(f.profile.get_profile_snapshot().preferences.dark_mode.next_run_enabled)
	assert_true(f.gs.get_run_configuration().value.dark_mode)
	assert_eq(f.bootstrap.get_startup_state().completed_stages.count(&"initialize_profile"),1)
	assert_eq(ready_count,1)
	await _frames()
	assert_eq(get_tree().current_scene.scene_file_path,"res://scenes/main/MainGameScene.tscn")
