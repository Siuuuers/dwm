extends "res://addons/gut/test.gd"
## Real storage, identity, Profile, GameState and save admission. Route/native
## readiness uses the existing diagnostic fixture; rendered coverage is separate.
const FIXTURE := preload("res://tests/support/SceneNewRunFixture.gd")
const ROOT_PATH := "desktop-issuer-root.json"
const JOURNAL_PATH := "desktop-continuation-operations.json"
var fixture: RefCounted
var fixture_ready := false
var validation_scope: RefCounted

func before_all() -> void:
	validation_scope = preload("res://tests/support/SceneValidationScope.gd").new()
	validation_scope.install(true)
	fixture = FIXTURE.new()
	var setup: Dictionary = fixture.setup(get_tree())
	assert_true(setup.ok, str(setup))
	fixture_ready = setup.ok

func after_all() -> void:
	if fixture != null: fixture.close()
	if validation_scope != null: validation_scope.restore()

func test_selected_load_preserves_identity_disk_and_current_settings_then_allows_normal_save() -> void:
	assert_true(fixture_ready)
	if not fixture_ready: return
	var started: Dictionary = fixture.start()
	assert_eq(started.get("code"), &"scene_activation_pending", str(started))
	if started.get("code") != &"scene_activation_pending": return
	fixture.confirm_activation()
	assert_true(fixture.manager.autosave_latest().ok)
	var document: Dictionary = fixture.read_autosave().value
	var selected: Dictionary = document.current_snapshot.snapshot
	fixture.game.money = 21
	assert_true(fixture.profile.set_preference(&"preferences.audio.master_volume", 0.25).ok)
	assert_true(fixture.profile.unlock_ending("ending.alone", "TEST.direct.load.discovery").ok)
	var profile_before: Dictionary = fixture.profile.get_profile_snapshot()
	var revision_before: int = fixture.profile.get_profile_revision()
	var root_before: Dictionary = fixture.root.capture()
	var disk := {}
	for path: String in [ROOT_PATH, JOURNAL_PATH, "profile.json", "autosave.json"]:
		disk[path] = fixture.storage.inspect_revision(path)
	var prepared: Dictionary = fixture.manager.prepare_restore_autosave()
	assert_true(prepared.ok, str(prepared))
	if not prepared.ok: return
	assert_false(prepared.value.prepared.has("source_locator"))
	assert_false(prepared.value.prepared.has("remap_source_transaction_ids"))
	var loaded: Dictionary = fixture.manager.commit_prepared_restore(prepared.value.prepared)
	assert_eq(loaded.get("code"), &"scene_activation_pending", str(loaded))
	if loaded.get("code") != &"scene_activation_pending": return
	for path: String in disk:
		assert_eq(fixture.storage.inspect_revision(path), disk[path], "pending Load leaves " + path + " unchanged")
	assert_eq(fixture.root.capture(), root_before, "Load does not issue or allocate identities")
	fixture.confirm_activation()
	assert_true(fixture.manager.capture_scene_restore_activation(loaded.transaction_id).ok)
	assert_eq(fixture.game.money, selected.gameplay.money)
	assert_eq(fixture.game.capture_run_snapshot_input().lifecycle, selected.lifecycle)
	assert_eq(fixture.manager.get_latest_stable_checkpoint().value.bundle, document.current_snapshot)
	assert_eq(fixture.profile.get_profile_snapshot(), profile_before)
	assert_eq(fixture.profile.get_profile_revision(), revision_before)
	assert_eq(fixture.root.capture(), root_before)
	for path: String in disk:
		assert_eq(fixture.storage.inspect_revision(path), disk[path], "ready Load leaves " + path + " unchanged")
	assert_true(fixture.manager.save_latest_to_slot(2).ok, "a later explicit Save still works")
	var saved: Dictionary = FIXTURE.PARSER.parse_object(fixture.storage.read_text("slot_2.json").value)
	assert_true(saved.ok, str(saved))
	if saved.ok: assert_eq(saved.value.current_snapshot, document.current_snapshot)

	# Public preparation is checked before the lock notification. A listener may
	# still hold that transport; only the retained private selection owns Load.
	for mutation: String in ["malformed", "valid_progress"]:
		var offered: Dictionary = fixture.manager.prepare_restore_autosave()
		assert_true(offered.ok, str(offered))
		if not offered.ok: return
		var public_prepared: Dictionary = offered.value.prepared
		var altered: Dictionary = public_prepared.duplicate(true)
		altered.journal_seed.current.snapshot.gameplay.money += 1
		assert_eq(fixture.manager.commit_prepared_restore(altered).get("code"),
			&"invalid_scene_restore_preparation", "seed tampering before commit is refused")
		var changed_snapshot: Dictionary = selected.duplicate(true)
		changed_snapshot.gameplay.money += 1
		assert_true(preload("res://scripts/domain/run/RunSnapshotSchema.gd").validate(changed_snapshot).ok,
			"valid progress still cannot replace the selected save")
		var storage_root: String = fixture.storage.describe_root()
		var stored_bytes := {}
		for filename: String in DirAccess.get_files_at(storage_root):
			stored_bytes[filename] = FileAccess.get_file_as_bytes(storage_root.path_join(filename))
		var callback_ran := []
		var mutate_public := func(_capability: Dictionary) -> void:
			if fixture.manager._lock_owner != &"restore" or not callback_ran.is_empty(): return
			callback_ran.append(true)
			if mutation == "malformed":
				public_prepared.journal_seed.current.snapshot = {"invalid": true}
			else:
				public_prepared.journal_seed.current.snapshot = changed_snapshot
		fixture.manager.save_capability_changed.connect(mutate_public)
		var committed: Dictionary = fixture.manager.commit_prepared_restore(public_prepared)
		fixture.manager.save_capability_changed.disconnect(mutate_public)
		assert_eq(callback_ran.size(), 1, mutation)
		assert_eq(committed.get("code"), &"scene_activation_pending", str(committed))
		if committed.get("code") != &"scene_activation_pending": return
		fixture.confirm_activation()
		assert_true(fixture.manager.capture_scene_restore_activation(committed.transaction_id).ok)
		assert_eq(fixture.manager.get_latest_stable_checkpoint().value.bundle, document.current_snapshot, mutation)
		assert_eq(fixture.game.capture_run_snapshot_input().gameplay, selected.gameplay, mutation)
		assert_eq(fixture.game.capture_run_snapshot_input().lifecycle, selected.lifecycle, mutation)
		assert_eq(fixture.root.capture(), root_before, mutation)
		assert_eq(fixture.profile.get_profile_snapshot(), profile_before, mutation)
		var after_bytes := {}
		for filename: String in DirAccess.get_files_at(storage_root):
			after_bytes[filename] = FileAccess.get_file_as_bytes(storage_root.path_join(filename))
		assert_eq(after_bytes, stored_bytes, "Load preserves all persistent bytes: " + mutation)
