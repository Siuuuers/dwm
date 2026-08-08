extends "res://addons/gut/test.gd"

const MIGRATIONS_PATH := "res://scripts/infrastructure/save/SaveMigrations.gd"
const FIXTURES := "res://tests/fixtures/saves/"

func _migrations_exist() -> bool:
	return ResourceLoader.exists(MIGRATIONS_PATH, "Script")

func _fixture(name: String) -> Variant:
	return JSON.parse_string(FileAccess.get_file_as_string(FIXTURES + name))

func test_save_migrations_exists() -> void:
	assert_true(_migrations_exist(), "SaveMigrations must exist")

func test_ending_id_migration_map_and_passthrough() -> void:
	assert_true(_migrations_exist(), "SaveMigrations must exist")
	if not _migrations_exist():
		return
	var m: Script = load(MIGRATIONS_PATH)
	assert_eq(m.migrate_ending_id("alone")["value"]["ending_id"], "ending.alone")
	assert_eq(m.migrate_ending_id("lavinia_priscilla")["value"]["ending_id"], "ending.priscilla_lavinia")
	assert_eq(m.migrate_ending_id("sylvia.special")["value"]["ending_id"], "ending.sylvia.special")
	assert_eq(m.migrate_ending_id("ending.alone")["value"]["ending_id"], "ending.alone",
		"canonical ids pass through unchanged")
	assert_false(m.migrate_ending_id("priscilla.platonic").get("ok", true), "unknown ids reject recoverably")

func test_pair_token_migration() -> void:
	assert_true(_migrations_exist(), "SaveMigrations must exist")
	if not _migrations_exist():
		return
	var m: Script = load(MIGRATIONS_PATH)
	assert_eq(m.migrate_pair_token("lavinia_priscilla")["value"]["token"], "priscilla_lavinia")
	assert_eq(m.migrate_pair_token("priscilla_lavinia")["value"]["token"], "priscilla_lavinia")
	assert_false(m.migrate_pair_token("angela_priscilla").get("ok", true))

func test_snapshot_v1_to_v2() -> void:
	assert_true(_migrations_exist(), "SaveMigrations must exist")
	if not _migrations_exist():
		return
	var m: Script = load(MIGRATIONS_PATH)
	var document: Dictionary = _fixture("v1_minimal_slot.json")
	var v1_snapshot: Dictionary = document["current_snapshot"]["snapshot"]
	# Strip the profile-owned legacy members the document migrator removes.
	v1_snapshot.erase("settings")
	v1_snapshot.erase("seen_endings")
	var migrated: Dictionary = m.migrate_snapshot_v1_to_v2(v1_snapshot)
	assert_true(migrated.get("ok", false), JSON.stringify(migrated))
	var snapshot: Dictionary = migrated["value"]["snapshot"]
	assert_eq(int(snapshot["schema_version"]), 2)
	assert_eq(snapshot["lifecycle"]["active_resolution_plan"], null, "plan moved into lifecycle")
	assert_true(snapshot["lifecycle"].has("ending_plan"))
	assert_eq(snapshot["applied_effect_transaction_ids"], ["t-a", "t-b"], "ids renamed")
	assert_eq(snapshot["applied_variable_transaction_ids"], [], "variable ledger added")
	assert_eq(snapshot["active_app_id"], null, "active_app_id default added")
	assert_eq(snapshot["gameplay"]["narrative_variables"], {}, "narrative_variables default added")

func test_migrate_document_strips_legacy_profile_members() -> void:
	assert_true(_migrations_exist(), "SaveMigrations must exist")
	if not _migrations_exist():
		return
	var m: Script = load(MIGRATIONS_PATH)
	var raw: Dictionary = _fixture("v1_minimal_slot.json")
	var migrated: Dictionary = m.migrate_document(raw, {"kind": "slot", "slot_id": 1})
	assert_true(migrated.get("ok", false), JSON.stringify(migrated))
	var snapshot: Dictionary = migrated["value"]["document"]["current_snapshot"]["snapshot"]
	assert_false(snapshot.has("settings"), "legacy settings leave the run candidate")
	assert_false(snapshot.has("seen_endings"), "legacy seen_endings leave the run candidate")
	var patch: Dictionary = migrated["value"]["legacy_profile_patch_input"]
	assert_eq(patch["legacy_run_state"]["settings"], {"master_volume": 0.8},
		"stripped settings move to the profile patch input")
	assert_eq(patch["legacy_run_state"]["seen_endings"], ["ending.alone"])
	assert_true(migrated["value"]["migration_receipts"].size() >= 1, "receipts record each migration step")
	assert_eq(int(migrated["value"]["document"]["schema_version"]), 2)

func test_schema_dispatch_rejects_future_and_invalid() -> void:
	assert_true(_migrations_exist(), "SaveMigrations must exist")
	if not _migrations_exist():
		return
	var m: Script = load(MIGRATIONS_PATH)
	var future: Dictionary = _fixture("v2_future_schema.json")
	var migrated: Dictionary = m.migrate_document(future, {"kind": "slot", "slot_id": 1})
	assert_false(migrated.get("ok", true), "schema_version 3 is unsupported")
	assert_eq(migrated["code"], &"unsupported_future_schema")

func test_migrate_document_rejects_bad_locator() -> void:
	assert_true(_migrations_exist(), "SaveMigrations must exist")
	if not _migrations_exist():
		return
	var m: Script = load(MIGRATIONS_PATH)
	var raw: Dictionary = _fixture("v1_minimal_slot.json")
	assert_false(m.migrate_document(raw, {"kind": "slot", "slot_id": 8}).get("ok", true))
	assert_false(m.migrate_document(raw, {"kind": "quick", "slot_id": 1}).get("ok", true))

func test_legacy_day8_group_synchronized_recompute() -> void:
	assert_true(_migrations_exist(), "SaveMigrations must exist")
	if not _migrations_exist():
		return
	var m: Script = load(MIGRATIONS_PATH)
	var snapshot: Dictionary = _fixture("day8_group_synchronized.json")
	var result: Dictionary = m.migrate_legacy_day8(snapshot, [])
	assert_true(result.get("ok", false), JSON.stringify(result))
	assert_eq(result["value"]["ending_id"], "ending.priscilla.dark",
		"a synchronized group primary recomputes to the Angela pairing")
	assert_eq(result["value"]["epilogue_ending_id"], "ending.priscilla_lavinia")
	assert_eq(int(result["value"]["snapshot"]["lifecycle"]["day"]), 7, "no Day 8 survives")
	assert_eq(str(result["value"]["snapshot"]["lifecycle"]["state"]), "ENDING")

func test_legacy_day8_non_group_preserved_at_day7() -> void:
	assert_true(_migrations_exist(), "SaveMigrations must exist")
	if not _migrations_exist():
		return
	var m: Script = load(MIGRATIONS_PATH)
	var result: Dictionary = m.migrate_legacy_day8(_fixture("day8_ending_non_group.json"), [])
	assert_true(result.get("ok", false), JSON.stringify(result))
	assert_eq(result["value"]["ending_id"], "ending.sylvia.sweet", "valid non-group primary preserved")
	assert_eq(int(result["value"]["snapshot"]["lifecycle"]["day"]), 7)

func test_legacy_day8_falls_back_to_greatest_compatible_bundle() -> void:
	assert_true(_migrations_exist(), "SaveMigrations must exist")
	if not _migrations_exist():
		return
	var m: Script = load(MIGRATIONS_PATH)
	var playing: Dictionary = _fixture("day8_playing_with_day7_journal.json")
	var result: Dictionary = m.migrate_legacy_day8(playing["snapshot"], playing["day7_bundles"])
	assert_true(result.get("ok", false), JSON.stringify(result))
	assert_eq(result["value"]["resolution"], "day7_bundle_fallback")
	assert_eq(int(result["value"]["bundle"]["snapshot"]["checkpoint_sequence"]), 7,
		"the greatest compatible Day-7 bundle wins")
	var invalid_group: Dictionary = _fixture("day8_group_invalid_with_day7_journal.json")
	var fallback: Dictionary = m.migrate_legacy_day8(invalid_group["snapshot"], invalid_group["day7_bundles"])
	assert_true(fallback.get("ok", false), JSON.stringify(fallback))
	assert_eq(fallback["value"]["resolution"], "day7_bundle_fallback",
		"a group primary without synchronized inputs falls back")

func test_legacy_day8_no_fallback_rejects() -> void:
	assert_true(_migrations_exist(), "SaveMigrations must exist")
	if not _migrations_exist():
		return
	var m: Script = load(MIGRATIONS_PATH)
	var result: Dictionary = m.migrate_legacy_day8(_fixture("day8_no_fallback.json"), [])
	assert_false(result.get("ok", true), "no valid terminal and no fallback rejects")
	assert_eq(result["code"], &"no_day8_reconstruction")

func test_migrate_retired_true_ending_ids() -> void:
	var m: Script = load("res://scripts/infrastructure/save/SaveMigrations.gd")
	assert_eq(m.migrate_ending_id("priscilla.true")["value"]["ending_id"], "ending.priscilla.observation")
	assert_eq(m.migrate_ending_id("ending.lavinia.true")["value"]["ending_id"], "ending.lavinia.observation")
	assert_eq(m.migrate_ending_id("sylvia.true")["value"]["ending_id"], "ending.sylvia.special")
	assert_eq(m.migrate_ending_id("ending.sylvia.true")["value"]["ending_id"], "ending.sylvia.special")
