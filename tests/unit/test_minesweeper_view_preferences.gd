extends GutTest

const REGISTRY := preload("res://scripts/settings/SettingsPreferenceRegistry.gd")
const SCHEMA := preload("res://scripts/profile/ProfileSchema.gd")
const MANAGER := preload("res://autoload/ProfileManager.gd")
const RESTORE_PARTICIPANT := preload("res://scripts/application/restore/ProfileRestoreParticipant.gd")
const STORAGE := preload("res://scripts/infrastructure/storage/JsonFileStorage.gd")
const FILES := preload("res://tests/support/FakeFileOps.gd")
const STRICT_JSON := preload("res://scripts/validation/StrictJson.gd")
const ROOT := "minesweeper-view-preferences"
const SCOPES := ["app_beginner", "app_intermediate", "app_expert", "challenge"]


func test_registry_has_four_hidden_independent_scopes_and_all_manual_sizes() -> void:
	var records: Dictionary = {}
	for record: Dictionary in REGISTRY.records():
		if String(record.path).begins_with("preferences.display.minesweeper_"):
			records[String(record.path)] = record
	assert_eq(records.size(), 8)
	for scope: String in SCOPES:
		var size_path := _path(scope, "cell_size")
		var fit_path := _path(scope, "always_fit")
		assert_true(records.has(String(size_path)), String(size_path))
		assert_true(records.has(String(fit_path)), String(fit_path))
		if not records.has(String(size_path)) or not records.has(String(fit_path)):
			continue
		var size_record: Dictionary = records[String(size_path)]
		var fit_record: Dictionary = records[String(fit_path)]
		assert_eq(size_record.type, &"enum_int")
		assert_eq(size_record.default_value, 36)
		assert_eq(size_record.allowed_values, range(10, 61, 2))
		assert_eq(fit_record.type, &"bool")
		assert_eq(fit_record.default_value, false)
		assert_false(size_record.visible)
		assert_false(fit_record.visible)
		assert_true(REGISTRY.is_player_writable(size_path))
		assert_true(REGISTRY.is_player_writable(fit_path))
		for size: int in range(10, 61, 2):
			assert_true(REGISTRY.validate(size_path, size).ok, "%s: %d" % [size_path, size])
		for invalid: Variant in [9, 11, 61, 36.0, true]:
			assert_false(REGISTRY.validate(size_path, invalid).ok, "%s: %s" % [size_path, invalid])
		assert_true(REGISTRY.validate(fit_path, true).ok)
		assert_false(REGISTRY.validate(fit_path, 1).ok)
	for record: Dictionary in REGISTRY.visible_records(&"display"):
		assert_false(String(record.path).begins_with("preferences.display.minesweeper_"))


func test_old_profile_admits_only_the_complete_absent_set_and_preserves_other_preferences() -> void:
	var old: Dictionary = SCHEMA.make_defaults()
	_remove_view_leaves(old)
	old.preferences.display.window_mode = "borderless"
	old.preferences.audio.music_volume = 0.35
	var before := old.duplicate(true)
	var admitted: Dictionary = SCHEMA.validate(old)
	assert_true(admitted.get("ok", false), str(admitted))
	if not admitted.get("ok", false):
		return
	assert_eq(old, before, "admission must not mutate stored input")
	assert_eq(admitted.value.preferences.display.window_mode, "borderless")
	assert_eq(admitted.value.preferences.audio.music_volume, 0.35)
	for scope: String in SCOPES:
		assert_eq(admitted.value.preferences.display[String(_path(scope, "cell_size")).get_slice(".", 2)], 36)
		assert_eq(admitted.value.preferences.display[String(_path(scope, "always_fit")).get_slice(".", 2)], false)
	var partial := old.duplicate(true)
	partial.preferences.display["minesweeper_challenge_cell_size"] = 44
	assert_false(SCHEMA.validate(partial).get("ok", true), "a partial new shape is malformed")
	var invalid: Dictionary = admitted.value.duplicate(true)
	invalid.preferences.display["minesweeper_challenge_cell_size"] = 11
	assert_false(SCHEMA.validate(invalid).get("ok", true), "invalid new values are never repaired")


func test_old_profile_defaults_persist_and_four_scopes_survive_restart() -> void:
	var old: Dictionary = SCHEMA.make_defaults()
	_remove_view_leaves(old)
	old.preferences.audio.music_volume = 0.35
	var ops := FILES.new({ROOT + "/profile.json": JSON.stringify(old).to_utf8_buffer()})
	var manager: Node = autofree(MANAGER.new())
	var initialized: Dictionary = manager.initialize(STORAGE.new(ROOT, ops))
	assert_true(initialized.get("ok", false), str(initialized))
	if not initialized.get("ok", false):
		return
	var persisted: Dictionary = STRICT_JSON.parse_object(ops.snapshot_persisted()[ROOT + "/profile.json"].get_string_from_utf8())
	assert_true(persisted.get("ok", false), str(persisted))
	if persisted.get("ok", false):
		assert_eq(persisted.value, manager.get_profile_snapshot(), "admitted defaults must be durable at startup")
	assert_eq(manager.get_preference(_path("challenge", "cell_size")), 36)
	assert_eq(manager.get_preference(_path("challenge", "always_fit")), false)
	for index: int in SCOPES.size():
		var scope: String = SCOPES[index]
		assert_true(manager.set_preferences({_path(scope, "cell_size"): 10 + index * 10,
			_path(scope, "always_fit"): index % 2 == 0}).get("ok", false))
	var restarted: Node = autofree(MANAGER.new())
	var restored: Dictionary = restarted.initialize(STORAGE.new(ROOT, FILES.new(ops.snapshot_persisted())))
	assert_true(restored.get("ok", false), str(restored))
	if not restored.get("ok", false):
		return
	for index: int in SCOPES.size():
		var scope: String = SCOPES[index]
		assert_eq(restarted.get_preference(_path(scope, "cell_size")), 10 + index * 10)
		assert_eq(restarted.get_preference(_path(scope, "always_fit")), index % 2 == 0)
	assert_eq(restarted.get_preference(&"preferences.audio.music_volume"), 0.35)


func test_failed_preference_write_keeps_memory_and_profile_bytes_unchanged() -> void:
	var ops := FILES.new()
	var manager: Node = autofree(MANAGER.new())
	assert_true(manager.initialize(STORAGE.new(ROOT, ops)).get("ok", false))
	var before_profile: Dictionary = manager.get_profile_snapshot()
	var before_bytes: Dictionary = ops.snapshot_persisted()
	var changes: Array = []
	manager.preference_changed.connect(func(path: StringName, _value: Variant) -> void: changes.append(path))
	ops.fail_after(ops.operation_count() + 1)
	var result: Dictionary = manager.set_preferences({
		_path("challenge", "cell_size"): 44,
		_path("challenge", "always_fit"): true,
	})
	assert_false(result.get("ok", true), str(result))
	assert_eq(manager.get_profile_snapshot(), before_profile)
	assert_eq(ops.snapshot_persisted(), before_bytes)
	assert_eq(changes, [])


func test_new_account_preparation_preserves_all_four_permanent_view_scopes() -> void:
	var ops := FILES.new()
	var storage := STORAGE.new(ROOT + "-new-account", ops)
	var manager: Node = autofree(MANAGER.new())
	assert_true(manager.initialize(storage).get("ok", false))
	assert_true(manager.configure_new_run_storage(storage).get("ok", false))
	assert_true(manager.set_preferences(_nondefault_view_changes()).get("ok", false))
	var before: Dictionary = manager.get_profile_snapshot()
	var disk: Dictionary = ops.snapshot_persisted()
	var prepared: Dictionary = manager.prepare_new_run_consumption(manager.get_profile_revision())
	assert_true(prepared.get("ok", false), str(prepared))
	if not prepared.get("ok", false): return
	assert_eq(prepared.value.before.preferences.display, before.preferences.display)
	assert_eq(prepared.value.candidate.preferences.display, before.preferences.display)
	assert_eq(manager.get_profile_snapshot(), before)
	assert_eq(ops.snapshot_persisted(), disk, "New Account preparation does not write a checkpoint")


func test_older_save_restore_plan_keeps_current_view_scopes_without_legacy_patch() -> void:
	var ops := FILES.new()
	var manager: Node = autofree(MANAGER.new())
	assert_true(manager.initialize(STORAGE.new(ROOT + "-restore", ops)).get("ok", false))
	assert_true(manager.set_preferences(_nondefault_view_changes()).get("ok", false))
	var before: Dictionary = manager.get_profile_snapshot()
	var disk: Dictionary = ops.snapshot_persisted()
	var participant := RESTORE_PARTICIPANT.new(manager)
	var prepared: Dictionary = participant.prepare({"legacy_profile_patch_input": {}})
	assert_true(prepared.get("ok", false), str(prepared))
	if not prepared.get("ok", false): return
	assert_eq(prepared.value.profile_plan.profile.preferences.display, before.preferences.display)
	assert_eq(prepared.value.profile_plan.profile, before)
	assert_eq(manager.get_profile_snapshot(), before)
	assert_eq(ops.snapshot_persisted(), disk, "restore preparation does not rewrite permanent preferences")


func _nondefault_view_changes() -> Dictionary:
	var changes: Dictionary = {}
	for index: int in SCOPES.size():
		changes[_path(SCOPES[index], "cell_size")] = 12 + index * 10
		changes[_path(SCOPES[index], "always_fit")] = true
	return changes


func _path(scope: String, leaf: String) -> StringName:
	return StringName("preferences.display.minesweeper_%s_%s" % [scope, leaf])


func _remove_view_leaves(profile: Dictionary) -> void:
	for scope: String in SCOPES:
		for leaf: String in ["cell_size", "always_fit"]:
			profile.preferences.display.erase("minesweeper_%s_%s" % [scope, leaf])
