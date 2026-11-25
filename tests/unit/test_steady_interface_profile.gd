extends "res://addons/gut/test.gd"

const SCHEMA := preload("res://scripts/profile/ProfileSchema.gd")
const MANAGER := preload("res://autoload/ProfileManager.gd")
const STORAGE := preload("res://scripts/infrastructure/storage/JsonFileStorage.gd")
const FILES := preload("res://tests/support/FakeFileOps.gd")
const STRICT_JSON := preload("res://scripts/validation/StrictJson.gd")
const ROOT := "steady-interface-profile-tests/isolated"
const PATH := ROOT + "/profile.json"


func test_steady_interface_survives_restart_and_reset() -> void:
	var files := FILES.new()
	var first: Node = autofree(MANAGER.new())
	assert_true(first.initialize(STORAGE.new(ROOT, files)).ok)
	assert_true(first.set_preference(&"preferences.accessibility.steady_interface", true).get("ok", false))
	assert_true(first.get_preference(&"preferences.accessibility.steady_interface"))
	var restarted: Node = autofree(MANAGER.new())
	var enabled_restart: Dictionary = restarted.initialize(STORAGE.new(ROOT, files))
	assert_true(enabled_restart.get("ok", false), str(enabled_restart))
	if not enabled_restart.get("ok", false): return
	assert_true(restarted.get_preference(&"preferences.accessibility.steady_interface"), "enabled setting survives restart")
	assert_true(restarted.reset_preferences().get("ok", false))
	assert_false(restarted.get_preference(&"preferences.accessibility.steady_interface"))
	var reset_persisted := STRICT_JSON.parse_object((files.snapshot_persisted()[PATH] as PackedByteArray).get_string_from_utf8())
	assert_true(reset_persisted.get("ok", false), str(reset_persisted))
	if reset_persisted.get("ok", false):
		assert_false(reset_persisted.value.preferences.accessibility.steady_interface, "reset writes false")


func test_steady_interface_requires_a_boolean() -> void:
	var current := SCHEMA.make_defaults()
	assert_false(current.preferences.accessibility.steady_interface)
	current.preferences.accessibility.steady_interface = true
	var explicit := SCHEMA.validate(current)
	assert_true(explicit.get("ok", false), str(explicit))
	if explicit.get("ok", false):
		assert_true(explicit.value.preferences.accessibility.steady_interface)
	for invalid: Variant in [null, 0, "false"]:
		current.preferences.accessibility.steady_interface = invalid
		assert_false(SCHEMA.validate(current).ok)
