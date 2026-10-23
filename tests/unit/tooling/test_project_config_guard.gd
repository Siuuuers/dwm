extends "res://addons/gut/test.gd"

const GUARD_PATH := "res://tools/config/ProjectConfigGuard.gd"

func test_inspect_text_matrix() -> void:
	var guard_script: Script = load(GUARD_PATH)
	assert_not_null(guard_script, "ProjectConfigGuard.gd must exist")
	if guard_script == null: return
	var guard: RefCounted = guard_script.new()
	assert_true(guard.inspect_text("config_version=5\n\n[application]\n").ok)
	for invalid: String in [
		"[application]\nconfig_version=5\n",
		"config_version=4\n[application]\n",
		"config_version=5\nconfig_version=5\n[application]\n",
		"\"config_version\"=5\n[application]\n",
		"\"ï»¿config_version\"=5\n[application]\n",
	]:
		assert_false(guard.inspect_text(invalid).ok, invalid)

func test_project_file_has_one_canonical_version() -> void:
	var guard_script: Script = load(GUARD_PATH)
	assert_not_null(guard_script, "ProjectConfigGuard.gd must exist")
	if guard_script == null: return
	var result: Dictionary = guard_script.new().inspect_file("res://project.godot")
	assert_true(result.ok, JSON.stringify(result.errors))
	assert_eq(result.canonical_count, 1)
