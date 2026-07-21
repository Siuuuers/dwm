extends "res://addons/gut/test.gd"
# SaveManager isolated-storage unit tests
# (docs/superpowers/plans/2026-07-17-phase-2r-03-lifecycle-save.md Task 6).

const SAVE_MANAGER_PATH := "res://autoload/SaveManager.gd"
const STORAGE_PATH := "res://scripts/infrastructure/storage/JsonFileStorage.gd"
const TEMP_PATH := "res://tests/support/TemporaryStorage.gd"
const GATE_PATH := "res://scripts/application/transaction/ApplicationMutationGate.gd"
const VALID_FIXTURE := "res://tests/fixtures/snapshots/valid_day3.json"

var _suite_counter := 0

func _artifacts_exist() -> bool:
	for path: String in [SAVE_MANAGER_PATH, STORAGE_PATH, TEMP_PATH, GATE_PATH]:
		if not ResourceLoader.exists(path, "Script"):
			return false
	return true

func _isolated_root(suite_id: String) -> String:
	_suite_counter += 1
	var root := OS.get_environment("DWM_TEST_ROOT").path_join("save_manager") \
		.path_join("%s_%d" % [suite_id, _suite_counter]).path_join("saves")
	assert_eq(DirAccess.make_dir_recursive_absolute(root), OK)
	return root

func _isolated_manager(suite_id: String) -> Dictionary:
	var root := _isolated_root(suite_id)
	var storage: RefCounted = load(STORAGE_PATH).new(root)
	var manager: Node = load(SAVE_MANAGER_PATH).new()
	autofree(manager)
	assert_true(manager.initialize(storage)["ok"])
	return {"manager": manager, "storage": storage, "root": root}

func _checkpoint_inputs(run_id: String, day: int = 3) -> Dictionary:
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(VALID_FIXTURE))
	var lifecycle: Dictionary = fixture["lifecycle"]
	lifecycle["run_id"] = run_id
	lifecycle["day"] = day
	return {
		"snapshot_input": {
			"lifecycle": lifecycle,
			"gameplay": fixture["gameplay"],
			"contacts": fixture["contacts"],
			"schedule": fixture["schedule"],
			"dating": fixture["dating"],
			"applied_effect_transaction_ids": [],
			"applied_variable_transaction_ids": [],
		},
		"dialogic_checkpoint": {},
		"route_id": "main",
		"active_app_id": null,
		"audio_context": {},
		"content_version": 1,
	}

func _seed_checkpoint(manager: Node, run_id: String) -> void:
	assert_true(manager._journal.reset(run_id)["ok"])
	var recorded: Dictionary = manager.record_stable_checkpoint(_checkpoint_inputs(run_id), &"day_start")
	assert_true(recorded.get("ok", false), JSON.stringify(recorded))

func test_invalid_save_references_do_not_touch_storage() -> void:
	for path in [SAVE_MANAGER_PATH, STORAGE_PATH, TEMP_PATH]:
		assert_true(ResourceLoader.exists(path, "Script"), path + " must exist")
		if not ResourceLoader.exists(path, "Script"):
			return
	var root := _isolated_root("invalid_locator")
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
	var manager: Node = wired["manager"]
	_seed_checkpoint(manager, "run-save")
	assert_true(manager.save_latest_to_slot(1)["ok"])
	assert_true(manager.quick_save_latest()["ok"])
	assert_true(manager.autosave_latest()["ok"])
	var logout: Dictionary = manager.save_for_logout()
	assert_true(logout["ok"])
	assert_eq(logout["value"]["save_reason"], "logout")
	assert_true(manager.save_exists(&"slot", 1))
	assert_true(manager.save_exists(&"quick", -1))
	assert_true(manager.save_exists(&"autosave", -1))
	var files := Array(DirAccess.get_files_at(str(wired["root"])))
	files.sort()
	for name: String in files:
		assert_true(name in ["slot_1.json", "quicksave.json", "autosave.json"] \
			or name.ends_with(".bak"), "unexpected artifact: " + name)

func test_logout_without_checkpoint_reports_unwritten() -> void:
	assert_true(_artifacts_exist(), "save-manager artifacts must exist")
	if not _artifacts_exist():
		return
	var wired := _isolated_manager("logout_empty")
	var manager: Node = wired["manager"]
	var logout: Dictionary = manager.save_for_logout()
	assert_true(logout["ok"])
	assert_eq(logout["value"], {"written": false, "save_reason": "logout"})
	assert_false(manager.save_exists(&"autosave", -1))

func test_metadata_family_present_absent_corrupt_and_ordering() -> void:
	assert_true(_artifacts_exist(), "save-manager artifacts must exist")
	if not _artifacts_exist():
		return
	var wired := _isolated_manager("metadata_family")
	var manager: Node = wired["manager"]
	_seed_checkpoint(manager, "run-meta")
	assert_true(manager.save_latest_to_slot(1)["ok"])
	var present: Dictionary = manager.get_save_metadata(&"slot", 1)
	assert_true(present["ok"], JSON.stringify(present))
	assert_eq(present["value"], {
		"exists": true, "kind": "slot", "slot_id": 1, "save_reason": "manual",
		"run_id": "run-meta", "day": 3, "state": "PLAYING", "checkpoint_id": "run-meta:1",
	})
	var absent: Dictionary = manager.get_save_metadata(&"slot", 2)
	assert_true(absent["ok"])
	assert_eq(absent["value"]["exists"], false)
	assert_true(absent["value"]["run_id"] == null and absent["value"]["checkpoint_id"] == null,
		"absent metadata uses JSON null values")
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
	var manager: Node = wired["manager"]
	_seed_checkpoint(manager, "run-restore")
	assert_true(manager.save_latest_to_slot(2)["ok"])
	assert_true(manager.quick_save_latest()["ok"])
	var prepared: Dictionary = manager.prepare_restore_slot(2)
	assert_true(prepared["ok"], JSON.stringify(prepared))
	assert_eq(str(prepared["value"]["prepared"]["document"]["kind"]), "slot")
	assert_true(manager.prepare_restore_quick()["ok"])
	assert_false(manager.prepare_restore_autosave().get("ok", true), "absent autosave rejects")
	assert_eq(manager.commit_prepared_restore(prepared["value"]["prepared"])["code"],
		&"TRANSACTION_PARTICIPANTS_NOT_CONFIGURED", "restore commit waits for Task 7 participants")
	assert_true(manager.delete_slot(2)["ok"])
	assert_false(manager.save_exists(&"slot", 2), "delete leaves the locator absent")
	assert_true(manager.delete_quick_save()["ok"])
	assert_false(manager.save_exists(&"quick", -1))
	assert_true(manager.start_new_run("run-b", {}).get("code") == &"TRANSACTION_PARTICIPANTS_NOT_CONFIGURED",
		"start_new_run stays disabled until Task 7")

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
	var manager: Node = wired["manager"]
	_seed_checkpoint(manager, "run-wrap")
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
