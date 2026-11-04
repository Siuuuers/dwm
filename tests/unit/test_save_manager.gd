extends "res://addons/gut/test.gd"
# SaveManager isolated-storage unit tests
# (docs/superpowers/plans/2026-07-17-phase-2r-03-lifecycle-save.md Task 6).

const SAVE_MANAGER_PATH := "res://autoload/SaveManager.gd"
const STORAGE_PATH := "res://scripts/infrastructure/storage/JsonFileStorage.gd"
const TEMP_PATH := "res://tests/support/TemporaryStorage.gd"
const GATE_PATH := "res://scripts/application/transaction/ApplicationMutationGate.gd"

var _suite_counter := 0
var _scene_fixture: RefCounted
var _scene_scope: RefCounted

func before_all() -> void:
	_scene_scope = preload("res://tests/support/SceneValidationScope.gd").new()
	_scene_scope.install(true)
	_scene_fixture = preload("res://tests/support/SceneRunSaveFixture.gd").new()
	var setup: Dictionary = _scene_fixture.setup(get_tree())
	assert_true(setup.ok, str(setup))

func after_all() -> void:
	if _scene_fixture != null: _scene_fixture.close()
	if _scene_scope != null: _scene_scope.restore()

func _artifacts_exist() -> bool:
	for path: String in [SAVE_MANAGER_PATH, STORAGE_PATH, TEMP_PATH, GATE_PATH]:
		if not ResourceLoader.exists(path, "Script"):
			return false
	return true

func _isolated_root(suite_id: String) -> String:
	_suite_counter += 1
	var relative := "save_manager".path_join("%s_%d" % [suite_id, _suite_counter]).path_join("saves")
	var result: Dictionary = TemporaryStorage.create(relative)
	assert_true(result.ok, result.get("message", ""))
	if not result.ok:
		return ""
	return result.value

func _isolated_manager(suite_id: String) -> Dictionary:
	var root := _isolated_root(suite_id)
	if root.is_empty():
		return {}
	var storage: RefCounted = load(STORAGE_PATH).new(root)
	var manager: Node = load(SAVE_MANAGER_PATH).new()
	autofree(manager)
	assert_true(manager.initialize(storage)["ok"])
	return {"manager": manager, "storage": storage, "root": root}

func _seed_checkpoint(manager: Node) -> void:
	var snapshot: Dictionary = _scene_fixture.snapshot.duplicate(true)
	var input := {}
	for key: String in ["lifecycle", "gameplay", "contacts", "desktop", "scene"]:
		input[key] = snapshot[key].duplicate(true)
	input.merge({"command_receipts": {}, "applied_effect_transaction_ids": [], "applied_variable_transaction_ids": []})
	var board := preload("res://scripts/domain/minesweeper/DesktopBoardState.gd").new()
	var restored: Dictionary = board.prepare_player_restore_scene(snapshot.desktop.board, _scene_fixture.issuer)
	assert_true(restored.ok, str(restored))
	assert_true(board.commit(restored.value.candidate).ok)
	input.desktop.board = board.capture()
	assert_true(manager._journal.reset(snapshot.run_id).ok)
	var recorded: Dictionary = manager.record_stable_checkpoint({"snapshot_input": input,
		"dialogic_checkpoint": snapshot.narrative_checkpoint, "route_id": "scene", "active_app_id": null,
		"audio_context": {}, "content_version": snapshot.content_version}, &"line")
	assert_true(recorded.ok, str(recorded))

func test_invalid_save_references_do_not_touch_storage() -> void:
	for path in [SAVE_MANAGER_PATH, STORAGE_PATH, TEMP_PATH]:
		assert_true(ResourceLoader.exists(path, "Script"), path + " must exist")
		if not ResourceLoader.exists(path, "Script"):
			return
	var root := _isolated_root("invalid_locator")
	if root.is_empty():
		return
	var storage: RefCounted = load(STORAGE_PATH).new(root)
	var manager: Node = load(SAVE_MANAGER_PATH).new()
	autofree(manager)
	assert_true(manager.initialize(storage)["ok"])
	assert_false(manager.save_exists(&"slot", 0))
	assert_false(manager.save_exists(&"quick", 1))
	assert_false(manager.save_exists(&"unknown", -1))
	assert_eq(manager.get_save_metadata(&"slot", 8)["code"],
		&"INVALID_SAVE_REFERENCE")
	assert_eq(manager.delete_slot(0)["code"], &"INVALID_SAVE_REFERENCE")
	assert_eq(DirAccess.get_files_at(root), PackedStringArray())

func test_save_family_writes_closed_relative_names() -> void:
	assert_true(_artifacts_exist(), "save-manager artifacts must exist")
	if not _artifacts_exist():
		return
	var wired := _isolated_manager("save_family")
	if wired.is_empty():
		return
	var manager: Node = wired["manager"]
	_seed_checkpoint(manager)
	assert_true(manager.save_latest_to_slot(1)["ok"])
	assert_true(manager.quick_save_latest()["ok"])
	assert_true(manager.autosave_latest()["ok"])
	assert_true(manager.save_exists(&"slot", 1))
	assert_true(manager.save_exists(&"quick", -1))
	assert_true(manager.save_exists(&"autosave", -1))
	var files := Array(DirAccess.get_files_at(str(wired["root"])))
	files.sort()
	for name: String in files:
		assert_true(name in ["slot_1.json", "quicksave.json", "autosave.json"] \
			or name.ends_with(".bak"), "unexpected artifact: " + name)

func test_metadata_family_present_absent_and_ordering() -> void:
	assert_true(_artifacts_exist(), "save-manager artifacts must exist")
	if not _artifacts_exist():
		return
	var wired := _isolated_manager("metadata_family")
	if wired.is_empty():
		return
	var manager: Node = wired["manager"]
	_seed_checkpoint(manager)
	assert_true(manager.save_latest_to_slot(1)["ok"])
	var present: Dictionary = manager.get_save_metadata(&"slot", 1)
	assert_true(present["ok"], JSON.stringify(present))
	assert_eq(present["value"], {
		"exists": true, "kind": "slot", "slot_id": 1, "save_reason": null,
		"run_id": _scene_fixture.snapshot.run_id, "day": null, "state": "PLAYING",
		"checkpoint_id": _scene_fixture.snapshot.run_id + ":1",
	})
	var absent: Dictionary = manager.get_save_metadata(&"slot", 2)
	assert_true(absent["ok"])
	assert_eq(absent["value"]["exists"], false)
	assert_true(absent["value"]["run_id"] == null and absent["value"]["checkpoint_id"] == null,
		"absent metadata uses JSON null values")
	var all_records: Array = manager.get_all_save_metadata()
	assert_eq(all_records.size(), 9, "slots 1-7 then quick then autosave")
	assert_true(all_records[0].ok and all_records[0].value.exists)
	assert_true(all_records[1].ok and not all_records[1].value.exists)

func test_corrupt_metadata_preserves_sibling_ordering() -> void:
	var wired := _isolated_manager("corrupt_metadata")
	if wired.is_empty(): return
	var manager: Node = wired.manager
	_seed_checkpoint(manager)
	assert_true(manager.save_latest_to_slot(1).ok)
	var corrupt_file := FileAccess.open(str(wired["root"]).path_join("slot_3.json"), FileAccess.WRITE)
	corrupt_file.store_string("{not json")
	corrupt_file.close()
	var corrupt: Dictionary = manager.get_save_metadata(&"slot", 3)
	assert_false(corrupt.get("ok", true), "a corrupt record is never a valid existing save")
	var all_records: Array = manager.get_all_save_metadata()
	assert_eq(all_records.size(), 9, "slots 1-7 then quick then autosave")
	assert_true(all_records[0]["ok"] and all_records[0]["value"]["exists"], "slot 1 present")
	assert_false(all_records[2].get("ok", true), "the corrupt slot is a failure element")
	assert_true(all_records[1]["ok"], "corrupt locators cannot erase valid sibling metadata")

func test_restore_preparation_and_delete_families() -> void:
	assert_true(_artifacts_exist(), "save-manager artifacts must exist")
	if not _artifacts_exist():
		return
	var wired := _isolated_manager("restore_delete")
	if wired.is_empty():
		return
	var manager: Node = wired["manager"]
	_seed_checkpoint(manager)
	assert_true(manager.save_latest_to_slot(2)["ok"])
	assert_true(manager.quick_save_latest()["ok"])
	# prepare_restore now builds participant plans, so it requires configured participants;
	# the full prepare->commit round-trip is covered by the restore integration tests.
	assert_eq(manager.prepare_restore_slot(2).get("code"), &"TRANSACTION_PARTICIPANTS_NOT_CONFIGURED",
		"prepare_restore requires configured restore participants")
	assert_eq(manager.commit_prepared_restore({}).get("code"), &"TRANSACTION_PARTICIPANTS_NOT_CONFIGURED",
		"commit_prepared_restore requires configured participants")
	assert_true(manager.delete_slot(2)["ok"])
	assert_false(manager.save_exists(&"slot", 2), "delete leaves the locator absent")
	assert_true(manager.delete_quick_save()["ok"])
	assert_false(manager.save_exists(&"quick", -1))

func test_configure_mutation_gate_matrix_without_side_effects() -> void:
	assert_true(_artifacts_exist(), "save-manager artifacts must exist")
	if not _artifacts_exist():
		return
	var manager: Node = load(SAVE_MANAGER_PATH).new()
	autofree(manager)
	var gate: RefCounted = load(GATE_PATH).new()
	assert_eq(manager.configure_mutation_gate(null).get("code"), &"invalid_mutation_gate")
	assert_eq(manager.configure_mutation_gate(RefCounted.new()).get("code"), &"invalid_mutation_gate")
	var configured: Dictionary = manager.configure_mutation_gate(gate)
	assert_true(configured["ok"])
	assert_eq(configured["value"]["gate_instance_id"], gate.get_instance_id())
	assert_eq(configured["value"]["already_configured"], false)
	var repeat: Dictionary = manager.configure_mutation_gate(gate)
	assert_true(repeat["ok"])
	assert_eq(repeat["value"]["already_configured"], true)
	assert_eq(manager.configure_mutation_gate(load(GATE_PATH).new()).get("code"),
		&"mutation_gate_already_configured")
	assert_false(gate.is_active(), "configuration never mutates the gate")

func test_deprecated_wrappers_delegate() -> void:
	assert_true(_artifacts_exist(), "save-manager artifacts must exist")
	if not _artifacts_exist():
		return
	var wired := _isolated_manager("wrappers")
	if wired.is_empty():
		return
	var manager: Node = wired["manager"]
	_seed_checkpoint(manager)
	assert_true(manager.save_slot(4)["ok"], "save_slot delegates to save_latest_to_slot")
	assert_true(manager.has_slot(4), "has_slot delegates to save_exists")
	assert_true(manager.quick_save()["ok"])
	assert_true(manager.autosave()["ok"])
	assert_eq(manager.get_slot_metadata(4)["value"]["kind"], "slot")
	assert_eq((manager.get_all_slot_metadata() as Array).size(), 9)
	assert_eq(manager.load_slot(4).get("code"), &"TRANSACTION_PARTICIPANTS_NOT_CONFIGURED",
		"load wrappers delegate prepare + commit without a second parser path")
	assert_false(manager.quick_load().get("ok", true))
	assert_true(manager.delete_slot(4)["ok"])
