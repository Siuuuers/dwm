extends "res://addons/gut/test.gd"

const PROBE := preload("res://tests/support/DynamicScriptProbe.gd")
const REGISTRY_PATH := "res://scripts/domain/desktop/DesktopAppRegistry.gd"

# --- Contract: exact seven-app registry -----------------------------------------
const EXPECTED := {
	&"minesweeper": {"scene": &"res://scenes/apps/MinesweeperApp.tscn", "focus": NodePath("%HideButton")},
	&"contacts":    {"scene": &"res://scenes/apps/ContactListApp.tscn", "focus": NodePath("%HideButton")},
	&"schedule":    {"scene": &"res://scenes/apps/ScheduleApp.tscn", "focus": NodePath("%HideButton")},
	&"shop":        {"scene": &"res://scenes/apps/ShopApp.tscn", "focus": NodePath("%HideButton")},
	&"backup":      {"scene": &"res://scenes/apps/BackupApp.tscn", "focus": NodePath("%HideButton")},
	&"settings":    {"scene": &"res://scenes/apps/SettingsApp.tscn", "focus": NodePath("%HideButton")},
	&"logout":      {"scene": &"res://scenes/apps/LogOutApp.tscn", "focus": NodePath("%NoButton")},
}

func _load_registry():
	var loaded: Dictionary = PROBE.load_script(REGISTRY_PATH)
	assert_true(loaded.get("ok", false), "DesktopAppRegistry must exist after implementation")
	if not loaded.get("ok", false):
		return null
	return loaded["value"].new()

func test_registry_has_exactly_seven_known_apps() -> void:
	var registry = _load_registry()
	if registry == null:
		return
	var ids: Array = registry.get_ids()
	assert_eq(ids.size(), 7, "registry must expose exactly seven app ids")
	for id in EXPECTED.keys():
		assert_true(ids.has(id), "registry must contain app id %s" % id)

func test_registry_get_record_returns_exact_scene_and_focus() -> void:
	var registry = _load_registry()
	if registry == null:
		return
	for id in EXPECTED.keys():
		var rec: Dictionary = registry.get_record(id)
		assert_true(rec.get("ok", false), "get_record(%s) ok" % id)
		assert_eq(rec.get("scene"), EXPECTED[id]["scene"], "scene for %s" % id)
		assert_eq(NodePath(rec.get("focus_target")), EXPECTED[id]["focus"], "focus for %s" % id)

func test_registry_get_record_rejects_unknown_id() -> void:
	var registry = _load_registry()
	if registry == null:
		return
	var rec: Dictionary = registry.get_record(&"not_a_real_app")
	assert_false(rec.get("ok", false), "unknown id must be rejected")
	assert_eq(rec.get("code"), &"unknown_app_id")

func test_registry_has_app_matches_get_ids() -> void:
	var registry = _load_registry()
	if registry == null:
		return
	assert_true(registry.has_app(&"shop"))
	assert_false(registry.has_app(&"not_a_real_app"))
