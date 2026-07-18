extends "res://addons/gut/test.gd"

const PROBE := preload("res://tests/support/DynamicScriptProbe.gd")
const ROOT := "profile-tests/root"

var _schema: Script
var _manager_script: Script
var _storage_script: Script
var _fake_ops_script: Script
var _gate_script: Script

func before_all() -> void:
	_schema = _load("res://scripts/profile/ProfileSchema.gd")
	_manager_script = _load("res://autoload/ProfileManager.gd")
	_storage_script = _load("res://scripts/infrastructure/storage/JsonFileStorage.gd")
	_fake_ops_script = _load("res://tests/support/FakeFileOps.gd")
	_gate_script = _load("res://tests/support/FakeApplicationMutationGate.gd")

func _load(path: String) -> Script:
	var result := PROBE.load_script(path)
	assert_true(result.get("ok", false), "%s: %s" % [path, result])
	return result.get("value")

func _new_manager() -> Dictionary:
	var ops: RefCounted = _fake_ops_script.new()
	var storage: RefCounted = _storage_script.new(ROOT, ops)
	var manager: Node = autofree(_manager_script.new())
	var initialized: Dictionary = manager.call(&"initialize", storage)
	assert_true(initialized.get("ok", false), str(initialized))
	return {"manager": manager, "ops": ops, "storage": storage}

func test_defaults_are_schema_valid_and_exact() -> void:
	var profile: Dictionary = _schema.call(&"make_defaults")
	var result: Dictionary = _schema.call(&"validate", profile)
	assert_true(result.get("ok", false), str(result))
	assert_eq(profile["preferences"]["dialogue"]["skip_mode"], "read_only")
	assert_eq(profile["gallery_transaction_receipts"], {})
	assert_eq(profile["migration_receipts"].size(), 3)

func test_schema_rejects_unknown_nested_fields_bad_types_and_aliases() -> void:
	var profile: Dictionary = _schema.call(&"make_defaults")
	profile["preferences"]["audio"]["unknown"] = true
	assert_false(_schema.call(&"validate", profile).get("ok", true))
	profile = _schema.call(&"make_defaults")
	profile["preferences"]["audio"]["music_volume"] = 1
	assert_false(_schema.call(&"validate", profile).get("ok", true), "volume must remain TYPE_FLOAT")
	profile = _schema.call(&"make_defaults")
	var validated: Dictionary = _schema.call(&"validate", profile)
	profile["preferences"]["audio"]["music_volume"] = 0.1
	assert_eq(validated["value"]["preferences"]["audio"]["music_volume"], 0.8)

func test_invalid_skip_is_the_only_narrow_document_repair() -> void:
	var migration := _load("res://scripts/profile/ProfileMigration.gd")
	var profile: Dictionary = _schema.call(&"make_defaults")
	profile["preferences"]["dialogue"]["skip_mode"] = "legacy-invalid"
	var repaired: Dictionary = migration.call(&"prepare_document", profile)
	assert_true(repaired.get("ok", false), str(repaired))
	assert_eq(repaired["value"]["preferences"]["dialogue"]["skip_mode"], "read_only")
	assert_true(repaired["value"]["migration_receipts"]["invalid_persisted_skip_mode_v1"])
	profile["unexpected"] = true
	assert_false(migration.call(&"prepare_document", profile).get("ok", true))

func test_manager_initializes_once_and_uses_detached_snapshots() -> void:
	var fixture := _new_manager()
	var manager: Node = fixture["manager"]
	assert_eq(manager.call(&"initialize", fixture["storage"]).get("code"), &"already_initialized")
	var snapshot: Dictionary = manager.call(&"get_profile_snapshot")
	snapshot["preferences"]["audio"]["music_volume"] = 0.1
	assert_eq(manager.call(&"get_preference", &"preferences.audio.music_volume"), 0.8)

func test_flat_fully_qualified_preference_batch_is_atomic() -> void:
	var manager: Node = _new_manager()["manager"]
	var prepared: Dictionary = manager.call(&"prepare_preferences", {
		&"preferences.audio.music_volume": 0.5,
		&"preferences.dialogue.skip_mode": "all_text",
	})
	assert_true(prepared.get("ok", false), str(prepared))
	assert_eq(prepared["changed_paths"], [&"preferences.audio.music_volume", &"preferences.dialogue.skip_mode"])
	assert_eq(manager.call(&"prepare_preferences", {"preferences.audio.music_volume": 0.2}).get("code"), &"invalid_preference_path")
	assert_eq(manager.call(&"prepare_preferences", {&"audio.music_volume": 0.2}).get("code"), &"invalid_preference_path")
	assert_eq(manager.call(&"prepare_preferences", {&"preferences.language": "zh_HK", &"preferences.audio.music_volume": 0.2}).get("code"), &"managed_preference")
	assert_eq(manager.call(&"get_preference", &"preferences.audio.music_volume"), 0.8)

func test_locale_candidate_commits_deferred_and_publishes_exactly_once() -> void:
	var manager: Node = _new_manager()["manager"]
	var events: Array = []
	manager.preference_changed.connect(func(path: StringName, value: Variant) -> void: events.append([path, value]))
	var prepared: Dictionary = manager.call(&"prepare_locale_preference", "zh_HK")
	assert_true(prepared.get("ok", false), str(prepared))
	var committed: Dictionary = manager.call(&"commit_prepared_profile", prepared["value"], true)
	assert_true(committed.get("ok", false), str(committed))
	assert_eq(events, [])
	var publication_id: String = committed["value"]["publication_id"]
	assert_true(manager.call(&"publish_deferred_profile_signals", publication_id).get("ok", false))
	assert_eq(events, [[&"preferences.language", "zh_HK"]])
	assert_eq(manager.call(&"publish_deferred_profile_signals", publication_id).get("code"), &"unknown_publication")

func test_prepared_gallery_transaction_is_idempotent_and_conflicts_fail() -> void:
	var manager: Node = _new_manager()["manager"]
	var prepared: Dictionary = manager.call(&"prepare_ending_unlock", "ending.alone", "run-1-ending")
	assert_true(prepared.get("ok", false), str(prepared))
	assert_true(prepared["value"]["requires_commit"])
	var committed: Dictionary = manager.call(&"commit_prepared_profile", prepared["value"]["candidate"], true)
	var publication_id: String = committed["value"]["publication_id"]
	var repeat: Dictionary = manager.call(&"prepare_ending_unlock", "ending.alone", "run-1-ending")
	assert_false(repeat["value"]["requires_commit"])
	assert_eq(repeat["value"]["pending_publication_id"], publication_id)
	assert_eq(manager.call(&"prepare_ending_unlock", "ending.priscilla.true", "run-1-ending").get("code"), &"gallery_transaction_conflict")

func test_gallery_and_entire_reset_retain_internal_ledgers() -> void:
	var manager: Node = _new_manager()["manager"]
	assert_true(manager.call(&"unlock_ending", "ending.alone", "transaction-retained").get("ok", false))
	assert_true(manager.call(&"reset_gallery").get("ok", false))
	var snapshot: Dictionary = manager.call(&"get_profile_snapshot")
	assert_eq(snapshot["gallery_unlocks"], [])
	assert_true(snapshot["gallery_transaction_receipts"].has("transaction-retained"))
	assert_true(manager.call(&"reset_entire_profile").get("ok", false))
	snapshot = manager.call(&"get_profile_snapshot")
	assert_true(snapshot["gallery_transaction_receipts"].has("transaction-retained"))

func test_mutation_gate_configuration_is_identity_stable_and_side_effect_free() -> void:
	var manager: Node = autofree(_manager_script.new())
	var gate: RefCounted = _gate_script.new()
	var first: Dictionary = manager.call(&"configure_mutation_gate", gate)
	assert_true(first.get("ok", false), str(first))
	assert_false(first["value"]["already_configured"])
	var same: Dictionary = manager.call(&"configure_mutation_gate", gate)
	assert_true(same["value"]["already_configured"])
	assert_eq(manager.call(&"configure_mutation_gate", null).get("code"), &"invalid_mutation_gate")
	assert_eq(manager.call(&"configure_mutation_gate", _gate_script.new()).get("code"), &"mutation_gate_already_configured")
