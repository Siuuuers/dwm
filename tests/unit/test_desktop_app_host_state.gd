extends "res://addons/gut/test.gd"

const HOST := preload("res://scripts/domain/desktop/DesktopAppHostState.gd")
const REGISTRY := preload("res://scripts/domain/desktop/DesktopAppRegistry.gd")

func _host() -> RefCounted:
	return HOST.new()

func test_reset_clears_active_and_cache() -> void:
	var h := _host()
	h.reset(3)
	h.open_app(&"minesweeper", 3)
	h.reset(5)
	assert_eq(h.get_state()["active_app_id"], null)
	assert_eq(h.get_state()["cached_app_ids"].size(), 0)
	assert_eq(h.get_state()["current_day"], 5)

func test_open_app_first_instantiate_true_and_focus() -> void:
	var h := _host()
	var opened: Dictionary = h.open_app(&"minesweeper", 1)
	assert_true(opened.get("ok", false), JSON.stringify(opened))
	assert_true(opened["instantiate"], "first open of the day instantiates")
	assert_eq(opened["hide_app_id"], null)
	assert_eq(opened["show_app_id"], &"minesweeper")
	assert_eq(opened["focus_target"], NodePath("%HideButton"))

func test_open_app_switch_returns_previous_and_reopen_not_instantiate() -> void:
	var h := _host()
	h.open_app(&"minesweeper", 1)
	var switched: Dictionary = h.open_app(&"contacts", 1)
	assert_eq(switched["hide_app_id"], &"minesweeper")
	assert_eq(switched["show_app_id"], &"contacts")
	assert_true(switched["instantiate"], "contacts not yet cached this day")
	var reopen: Dictionary = h.open_app(&"minesweeper", 1)
	assert_false(reopen["instantiate"], "minesweeper already cached this day")
	assert_eq(reopen["hide_app_id"], &"contacts")

func test_open_app_unknown_rejects() -> void:
	var h := _host()
	var opened: Dictionary = h.open_app(&"does_not_exist", 1)
	assert_false(opened.get("ok", true), "unknown app id rejects")
	assert_eq(str(opened.get("code")), "unknown_app_id")

func test_close_app_returns_focus_icon_and_clears_active() -> void:
	var h := _host()
	h.open_app(&"minesweeper", 1)
	var closed: Dictionary = h.close_app()
	assert_true(closed.get("ok", false), JSON.stringify(closed))
	assert_eq(closed["focus_icon_app_id"], &"minesweeper")
	assert_eq(h.get_state()["active_app_id"], null)

func test_change_day_rejects_nonpositive_and_backward() -> void:
	var h := _host()
	h.reset(3)
	assert_false(h.change_day(0).get("ok", true), "nonpositive rejects")
	assert_false(h.change_day(3).get("ok", true), "unchanged rejects")
	assert_false(h.change_day(2).get("ok", true), "backward rejects")

func test_change_day_returns_exact_eviction_command_in_registry_order() -> void:
	var h := _host()
	h.reset(1)
	h.open_app(&"contacts", 1)
	h.open_app(&"minesweeper", 1)
	h.open_app(&"shop", 1)
	var changed: Dictionary = h.change_day(2)
	assert_true(changed.get("ok", false), JSON.stringify(changed))
	var command: Dictionary = changed["value"]["eviction_command"]
	assert_eq(command["command_id"], "desktop-day:2")
	assert_eq(command["kind"], &"evict_cached_apps")
	assert_eq(int(command["day"]), 2)
	# app_ids in DesktopAppRegistry.get_ids() order, not cache insertion order.
	assert_eq(command["app_ids"], [&"minesweeper", &"contacts", &"shop"])
	assert_eq(h.get_state()["active_app_id"], null, "active cleared after day change")
	assert_eq(h.get_state()["cached_app_ids"].size(), 0, "cache cleared after day change")

func test_capture_persistent_state_returns_registered_id_or_null() -> void:
	var h := _host()
	h.reset(1)
	assert_eq(h.capture_persistent_state()["active_app_id"], null)
	h.open_app(&"settings", 1)
	assert_eq(h.capture_persistent_state()["active_app_id"], &"settings")

func test_prepare_restore_round_trips_null_and_registered_id() -> void:
	var h := _host()
	h.reset(2)
	var null_restore: Dictionary = h.prepare_restore(null, 2)
	assert_true(null_restore.get("ok", false), JSON.stringify(null_restore))
	assert_eq(null_restore["value"]["instantiate_command"], null)
	assert_eq(null_restore["value"]["candidate_state"]["active_app_id"], null)
	assert_eq(null_restore["value"]["candidate_state"]["cached_app_ids"].size(), 0)

	var id_restore: Dictionary = h.prepare_restore(&"minesweeper", 4)
	assert_true(id_restore.get("ok", false), JSON.stringify(id_restore))
	assert_eq(id_restore["value"]["candidate_state"]["active_app_id"], &"minesweeper")
	assert_eq(id_restore["value"]["candidate_state"]["current_day"], 4)
	assert_true(id_restore["value"]["instantiate_command"]["instantiate"])
	assert_eq(id_restore["value"]["instantiate_command"]["show_app_id"], &"minesweeper")

	var bad_restore: Dictionary = h.prepare_restore(&"ghost_app", 4)
	assert_false(bad_restore.get("ok", true), "unknown saved id rejects before apply")

func test_registry_focus_targets_resolve_for_all_seven() -> void:
	for id in REGISTRY.new().get_ids():
		var rec: Dictionary = REGISTRY.new().get_record(id)
		assert_true(rec["focus_target"] is NodePath, "%s focus target is a NodePath" % id)

func test_logout_action_never_enters_workspace_cache_or_restore() -> void:
	var h := _host()
	h.reset(2)
	h.open_app(&"contacts", 2)
	var before: Dictionary = h.get_state()
	assert_false(h.open_app(&"logout", 3).get("ok", true))
	assert_eq(h.get_state(), before, "rejected action does not advance day or mutate cache")
	assert_eq(h.capture_persistent_state(), {"active_app_id": &"contacts"})
	for id: Variant in ["logout", &"logout"]:
		assert_false(h.prepare_restore(id, 4).get("ok", true))
		assert_eq(h.get_state(), before, "invalid saved action never falls back to launcher")
	var invalid_active := before.duplicate(true)
	invalid_active.active_app_id = &"logout"
	assert_false(h.commit_restore(invalid_active).get("ok", true))
	var invalid_cache := before.duplicate(true)
	invalid_cache.cached_app_ids.append(&"logout")
	assert_false(h.commit_restore(invalid_cache).get("ok", true))
	assert_eq(h.get_state(), before)

func test_all_six_content_workspaces_still_capture_and_restore() -> void:
	var h := _host()
	for id: StringName in [&"minesweeper", &"contacts", &"schedule", &"shop", &"backup", &"settings"]:
		h.reset(1)
		assert_true(h.open_app(id, 1).get("ok", false))
		assert_eq(h.capture_persistent_state(), {"active_app_id": id})
		var prepared: Dictionary = h.prepare_restore(id, 1)
		assert_true(prepared.get("ok", false))
		assert_true(h.commit_restore(prepared.value.candidate_state).get("ok", false))
		assert_eq(h.capture_persistent_state(), {"active_app_id": id})
