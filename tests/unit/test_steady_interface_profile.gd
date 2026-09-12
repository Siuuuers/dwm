extends "res://addons/gut/test.gd"

const SCHEMA := preload("res://scripts/profile/ProfileSchema.gd")
const MIGRATION := preload("res://scripts/profile/ProfileMigration.gd")
const MANAGER := preload("res://autoload/ProfileManager.gd")
const STORAGE := preload("res://scripts/infrastructure/storage/JsonFileStorage.gd")
const FILES := preload("res://tests/support/FakeFileOps.gd")
const STRICT_JSON := preload("res://scripts/validation/StrictJson.gd")
const ROOT := "steady-interface-profile-tests/isolated"
const PATH := ROOT + "/profile.json"


func test_old_v8_profile_is_repaired_persisted_and_stays_repaired_after_restart() -> void:
	var old := SCHEMA.make_defaults()
	old.preferences.accessibility.erase("steady_interface")
	old.preferences.audio.music_volume = 0.41
	var original := old.duplicate(true)
	var files := FILES.new({PATH: JSON.stringify(old).to_utf8_buffer()})
	var first: Node = autofree(MANAGER.new())
	var storage := STORAGE.new(ROOT, files)
	assert_eq(storage.describe_root(), ROOT, "profile I/O must use only the isolated fake root")
	var initialized: Dictionary = first.initialize(storage)
	assert_true(initialized.get("ok", false), str(initialized))
	if not initialized.get("ok", false): return
	assert_false(first.get_preference(&"preferences.accessibility.steady_interface"))
	assert_eq(first.get_preference(&"preferences.audio.music_volume"), 0.41)
	assert_eq(old, original, "admission must not mutate the caller's document")
	var persisted := STRICT_JSON.parse_object((files.snapshot_persisted()[PATH] as PackedByteArray).get_string_from_utf8())
	assert_true(persisted.get("ok", false), str(persisted))
	if not persisted.get("ok", false): return
	assert_eq(persisted.value.preferences.accessibility.steady_interface, false)
	var second: Node = autofree(MANAGER.new())
	var restarted: Dictionary = second.initialize(STORAGE.new(ROOT, files))
	assert_true(restarted.get("ok", false), str(restarted))
	if not restarted.get("ok", false): return
	assert_false(second.get_preference(&"preferences.accessibility.steady_interface"))
	assert_eq(second.get_preference(&"preferences.audio.music_volume"), 0.41)
	assert_true(second.set_preference(&"preferences.accessibility.steady_interface", true).get("ok", false))
	assert_true(second.get_preference(&"preferences.accessibility.steady_interface"))
	var third: Node = autofree(MANAGER.new())
	var enabled_restart: Dictionary = third.initialize(STORAGE.new(ROOT, files))
	assert_true(enabled_restart.get("ok", false), str(enabled_restart))
	if not enabled_restart.get("ok", false): return
	assert_true(third.get_preference(&"preferences.accessibility.steady_interface"), "enabled setting survives restart")
	assert_true(third.reset_preferences().get("ok", false))
	assert_false(third.get_preference(&"preferences.accessibility.steady_interface"))
	var reset_persisted := STRICT_JSON.parse_object((files.snapshot_persisted()[PATH] as PackedByteArray).get_string_from_utf8())
	assert_true(reset_persisted.get("ok", false), str(reset_persisted))
	if reset_persisted.get("ok", false):
		assert_false(reset_persisted.value.preferences.accessibility.steady_interface, "reset writes false")


func test_missing_only_admission_preserves_explicit_true_and_rejects_other_bad_shapes() -> void:
	var current := SCHEMA.make_defaults()
	assert_false(current.preferences.accessibility.steady_interface)
	assert_true(SCHEMA.validate_preference(&"preferences.accessibility.steady_interface", true).get("ok", false))
	current.preferences.accessibility.steady_interface = true
	var explicit := SCHEMA.validate(current)
	assert_true(explicit.get("ok", false), str(explicit))
	if explicit.get("ok", false):
		assert_true(explicit.value.preferences.accessibility.steady_interface)
		assert_false(explicit.get("migrated", false))
	var old := current.duplicate(true)
	old.preferences.accessibility.erase("steady_interface")
	var repaired := SCHEMA.validate(old)
	assert_true(repaired.get("ok", false), str(repaired))
	if repaired.get("ok", false):
		assert_true(repaired.get("migrated", false))
		assert_false(repaired.value.preferences.accessibility.steady_interface)
	assert_false(old.preferences.accessibility.has("steady_interface"))
	for invalid: Variant in [null, 0, "false"]:
		var wrong := old.duplicate(true)
		wrong.preferences.accessibility.steady_interface = invalid
		assert_false(SCHEMA.validate(wrong).get("ok", true), "wrong type must not be repaired: %s" % str(invalid))
	var extra := old.duplicate(true)
	extra.preferences.accessibility.unregistered = false
	assert_false(SCHEMA.validate(extra).get("ok", true), "unknown leaves still fail closed")
	var other_missing := old.duplicate(true)
	other_missing.preferences.accessibility.erase("high_contrast")
	assert_false(SCHEMA.validate(other_missing).get("ok", true), "another missing leaf still fails closed")


func test_v2_through_v7_historical_documents_admit_only_missing_steady_default() -> void:
	for version: int in range(2, 8):
		var source := _historical_source(version)
		var before := source.duplicate(true)
		var result := MIGRATION.prepare_document(source)
		assert_true(result.get("ok", false), "v%d: %s" % [version, str(result)])
		if not result.get("ok", false): continue
		assert_eq(result.value.schema_version, SCHEMA.SCHEMA_VERSION)
		assert_false(result.value.preferences.accessibility.steady_interface)
		assert_eq(source, before, "v%d source remains detached" % version)
		var malformed := source.duplicate(true)
		malformed.preferences.accessibility.steady_interface = 1
		assert_false(MIGRATION.prepare_document(malformed).get("ok", true), "v%d wrong type must fail" % version)


func _historical_source(version: int) -> Dictionary:
	var source := SCHEMA.make_defaults()
	source.schema_version = version
	source.preferences.accessibility.erase("steady_interface")
	if version < 8:
		for key: String in ["observer_evidence", "pair_deck_draws", "reached_presentations"]: source.erase(key)
	if version < 6: source.erase("dating_attempts")
	if version < 5: source.erase("pair_form_witness_receipts")
	if version < 4:
		source.erase("migration_receipts")
		source.erase("legacy_preferences_v1")
	if version < 3:
		source.erase("controls_bindings")
		source.erase("controls_import_pending")
		source.input_mappings = SCHEMA._default_input_mappings()
	return source
