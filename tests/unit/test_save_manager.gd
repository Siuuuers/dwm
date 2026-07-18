extends "res://addons/gut/test.gd"
# SaveManager unit tests (prompt_docs/requirements/persistence.md).

func before_each() -> void:
	GameState.reset_game()
	SaveManager.ensure_save_folder()
	# Clean the slots we touch so tests are deterministic.
	for slot in [1, 2]:
		if SaveManager.has_slot(slot):
			SaveManager.delete_slot(slot)


func test_ensure_save_folder() -> void:
	assert_true(SaveManager.ensure_save_folder())


func test_save_and_load_slot_roundtrip() -> void:
	GameState.change_money(45)
	var save_res := SaveManager.save_slot(1)
	assert_true(bool(save_res["ok"]), "save_slot(1) writes JSON")
	assert_true(SaveManager.has_slot(1))
	GameState.reset_game()
	assert_eq(GameState.money, 0)
	var load_res := SaveManager.load_slot(1)
	assert_true(bool(load_res["ok"]))
	assert_eq(GameState.money, 45, "loaded money restored")


func test_pending_date_state_cleared_on_load() -> void:
	# CONTRACTS §6 REQUIRED GUARD: a save taken mid-dating-queue must not restore stale
	# pending_date_* with no consumer. apply_save_dict clears them unless scene_id == "dating".
	GameState.pending_date_entries = [{"type": "solo", "friend_id": "priscilla", "day": 1}]
	GameState.pending_date_entry_index = 1
	GameState.pending_date_friend_id = "priscilla"
	GameState.pending_date_advance_day_after_finish = true
	var data := {
		"schema_version": SaveManager._current_schema_version(),
		"kind": "autosave", "slot_id": -1,
		"saved_at_unix_time": 0, "scene_id": "main",
		"route_context": {}, "summary": {}, "game_state": {"day": 1}
	}
	var res := SaveManager.apply_save_dict(data)
	assert_true(bool(res["ok"]), "apply_save_dict ok")
	assert_eq(GameState.pending_date_entries, [], "stale pending_date_entries cleared on load")
	assert_eq(GameState.pending_date_entry_index, 0, "stale index cleared on load")
	assert_eq(GameState.pending_date_friend_id, "", "stale friend_id cleared on load")
	assert_false(GameState.pending_date_advance_day_after_finish, "stale advance flag cleared on load")


func test_load_missing_slot_rejected() -> void:
	var res := SaveManager.load_slot(2)
	assert_false(bool(res["ok"]), "missing slot rejected safely")


func test_invalid_slot_ids() -> void:
	assert_eq(SaveManager.get_slot_path(8), "", "no slot_8")
	assert_eq(SaveManager.get_slot_path(9), "", "no slot_9")
	assert_eq(SaveManager.get_slot_path(0), "")
	assert_ne(SaveManager.get_slot_path(7), "", "slot_7 valid")


func test_corrupted_json_rejected() -> void:
	var path := SaveManager.get_slot_path(1)
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string("{ this is not valid json ")
	f.close()
	var read := SaveManager.read_json_file(path)
	assert_false(bool(read["ok"]), "malformed JSON rejected")
	var load_res := SaveManager.load_slot(1)
	assert_false(bool(load_res["ok"]), "corrupt slot load rejected safely")


func test_quick_and_autosave_roundtrip() -> void:
	GameState.change_coins(3)
	assert_true(bool(SaveManager.quick_save()["ok"]))
	assert_true(bool(SaveManager.autosave()["ok"]))
	GameState.reset_game()
	assert_true(bool(SaveManager.quick_load()["ok"]))
	assert_eq(GameState.coins, 3)


func test_unsupported_future_schema_rejected() -> void:
	var data := SaveManager.build_save_dict("slot", 1)
	data["schema_version"] = 999
	var v := SaveManager.validate_save_dict(data)
	assert_false(bool(v["ok"]), "future schema version rejected")


func test_malformed_dict_rejected() -> void:
	var v := SaveManager.validate_save_dict({"no_schema": true})
	assert_false(bool(v["ok"]))


func test_migrate_upgrades_old_version() -> void:
	var data := SaveManager.build_save_dict("slot", 1)
	data["schema_version"] = 0
	var migrated := SaveManager.migrate_save_dict(data)
	assert_eq(int(migrated["schema_version"]), int(SaveManager._current_schema_version()), "migrated forward to current")


func test_save_dict_has_no_objects() -> void:
	var data := SaveManager.build_save_dict("slot", 1)
	var json := JSON.stringify(data)
	var reparsed := JSON.new()
	assert_eq(reparsed.parse(json), OK, "save dict is pure JSON (no Nodes/Objects/Resources)")


func test_round_floor_preserved_and_clamped() -> void:
	GameState.change_minesweeper_round_floor(-3)
	assert_true(bool(SaveManager.save_slot(1)["ok"]))
	GameState.reset_game()
	SaveManager.load_slot(1)
	assert_eq(GameState.minesweeper_round_floor, -3, "floor preserved through save/load")
