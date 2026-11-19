extends "res://addons/gut/test.gd"

const TEMPLATES := preload("res://tests/templates/seven_day/SevenDayTemplates.gd")
const MANIFEST := preload("res://scripts/data/AudioManifest.gd")

func test_title_and_scene_tracks_are_separate_vrc6_scores_with_authored_binding() -> void:
	var menu: Dictionary = MANIFEST.new().resolve_music_context("menu")
	assert_true(menu.ok)
	assert_eq(menu.value.path, "res://audio/bgm/menu_theme.nsf")
	assert_eq(TEMPLATES.MUSIC_PATH, "res://audio/bgm/story_theme.nsf")
	for path: String in [menu.value.path, TEMPLATES.MUSIC_PATH]:
		var bytes := FileAccess.get_file_as_bytes(path)
		assert_gt(bytes.size(), 128, path)
		if bytes.size() <= 128: return
		assert_eq(bytes.slice(0, 5), PackedByteArray([78, 69, 83, 77, 26]), path)
		assert_eq(bytes[123] & 1, 1, "NSF uses VRC6: " + path)
	var prepared: Dictionary = TEMPLATES.prepare()
	assert_true(prepared.ok, str(prepared))
	if not prepared.ok: return
	var catalogue: Dictionary = prepared.value.registration.audio_catalogue
	assert_eq(catalogue.schema_version, 3)
	assert_eq(catalogue.assets.size(), 1)
	assert_eq(catalogue.assets[0].duration_ms, 0)
	assert_eq(catalogue.assets[0].path, TEMPLATES.MUSIC_PATH)
	assert_eq(catalogue.assets[0].sha256, FileAccess.get_sha256(TEMPLATES.MUSIC_PATH))
	assert_eq(catalogue.plans.size(), 1)
	assert_eq(catalogue.plans[0].music, catalogue.assets[0].asset_id)
	assert_null(catalogue.plans[0].ambience_asset_id)
	assert_eq(catalogue.bindings.size(), 8)
	for binding: Dictionary in catalogue.bindings:
		assert_eq(binding.plan_id, catalogue.plans[0].plan_id)
