extends "res://addons/gut/test.gd"

const MANIFEST := preload("res://scripts/narrative/DialogicEntryManifest.gd")
const STRICT := preload("res://scripts/validation/StrictJson.gd")
const PATH := "res://tests/fixtures/dialogic/scene_reading_registration.json"

func _bundle() -> Dictionary:
	return STRICT.parse_object(FileAccess.get_file_as_string(PATH)).value

func test_complete_bundle_matches_actual_dtl_and_internal_return() -> void:
	var bundle := _bundle()
	assert_true(MANIFEST.validate_scene_registration(bundle).ok)
	assert_eq(bundle.targets[0].target.label, "scene.test.a.loop")
	var bad := bundle.duplicate(true)
	bad.targets[0].target.label = "unregistered.label"
	assert_false(MANIFEST.validate_scene_registration(bad).ok)

func test_every_sibling_table_is_bound_and_unknown_members_refuse() -> void:
	var bundle := _bundle()
	for table: String in ["entry_manifest", "context_registry", "ids_registry", "caption_registry", "scene_programme"]:
		var bad := bundle.duplicate(true)
		bad[table]["caller_override"] = true
		assert_false(MANIFEST.validate_scene_registration(bad).ok, table)
	for table: String in ["targets", "contacts"]:
		var bad := bundle.duplicate(true)
		bad[table][0]["caller_override"] = true
		assert_false(MANIFEST.validate_scene_registration(bad).ok, table)
	for table: String in ["board_profiles", "challenges"]:
		var bad := bundle.duplicate(true)
		bad[table] = [{"caller_override": true}]
		assert_false(MANIFEST.validate_scene_registration(bad).ok, table)

func test_source_content_programme_and_marker_position_are_rederived() -> void:
	for field: String in ["content_sha256", "program_sha256"]:
		var bad := _bundle()
		bad.scene_programme.entries[0][field] = "0".repeat(64)
		assert_false(MANIFEST.validate_scene_registration(bad).ok, field)
	var bad := _bundle()
	bad.caption_registry.entries[0].lines[0].text = "Forged caption."
	assert_false(MANIFEST.validate_scene_registration(bad).ok)
	bad = _bundle()
	bad.scene_programme.entries[2].markers[0].after_line_id = "line.scene.test.b.one"
	assert_false(MANIFEST.validate_scene_registration(bad).ok)

func test_duplicate_unsorted_and_dangling_registration_refuse() -> void:
	var bad := _bundle()
	bad.targets.append(bad.targets[0].duplicate(true))
	assert_false(MANIFEST.validate_scene_registration(bad).ok)
	bad = _bundle()
	bad.entry_manifest.entries.reverse()
	assert_false(MANIFEST.validate_scene_registration(bad).ok)
	bad = _bundle()
	bad.contacts[0].return_target_id = "absent"
	assert_false(MANIFEST.validate_scene_registration(bad).ok)
	bad = _bundle()
	bad.scene_programme.entries[2].markers[0].payload.target_id = "absent"
	assert_false(MANIFEST.validate_scene_registration(bad).ok)

func test_existing_board_profile_supported_and_unknown_policy_refuses() -> void:
	var bundle := _bundle()
	bundle.board_profiles = [{"board_profile_id": "test.board", "board_kind": "solo_challenge",
		"difficulty_id": "canonical_solo", "width": 18, "height": 18, "base_mine_count": 36,
		"generator_version": "dwm_generator_v1", "verifier_version": "visible_deduction_v1",
		"capability_policy_id": "owned_inventory_v1"}]
	assert_true(MANIFEST.validate_scene_registration(bundle).ok)
	bundle.board_profiles[0].capability_policy_id = "caller_policy"
	assert_false(MANIFEST.validate_scene_registration(bundle).ok)

func test_historical_manifest_validator_remains_available() -> void:
	var historical := STRICT.parse_object(FileAccess.get_file_as_string(MANIFEST.MANIFEST_PATH))
	assert_true(historical.ok)
	assert_true(MANIFEST.validate_document(historical.value).ok)
