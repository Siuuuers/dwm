extends "res://addons/gut/test.gd"

const TEMPLATES := preload("res://tests/templates/seven_day/SevenDayTemplates.gd")
const MANIFEST := preload("res://scripts/data/AudioManifest.gd")

func test_title_and_scene_tracks_are_separate_imported_loops_with_authored_binding() -> void:
	var menu: Dictionary = MANIFEST.new().resolve_music_context("menu")
	assert_true(menu.ok)
	assert_eq(menu.value.path, "res://audio/bgm/menu_theme.ogg")
	assert_eq(TEMPLATES.MUSIC_PATH, "res://audio/bgm/story_theme.ogg")
	for path: String in [menu.value.path, TEMPLATES.MUSIC_PATH]:
		var stream: AudioStreamOggVorbis = ResourceLoader.load(path) as AudioStreamOggVorbis
		assert_not_null(stream, path)
		if stream == null: return
		assert_true(stream.loop, "native imported audio loops: " + path)
		assert_gt(stream.get_length(), 0.0)
	var prepared: Dictionary = TEMPLATES.prepare()
	assert_true(prepared.ok, str(prepared))
	if not prepared.ok: return
	var catalogue: Dictionary = prepared.value.registration.audio_catalogue
	assert_eq(catalogue.schema_version, 2)
	assert_eq(catalogue.assets.size(), 1)
	assert_eq(catalogue.assets[0].path, TEMPLATES.MUSIC_PATH)
	assert_eq(catalogue.assets[0].sha256, FileAccess.get_sha256(TEMPLATES.MUSIC_PATH))
	assert_eq(catalogue.plans.size(), 1)
	assert_eq(catalogue.plans[0].music, catalogue.assets[0].asset_id)
	assert_null(catalogue.plans[0].ambience_asset_id)
	assert_eq(catalogue.bindings.size(), 8)
	for binding: Dictionary in catalogue.bindings:
		assert_eq(binding.plan_id, catalogue.plans[0].plan_id)
