extends "res://addons/gut/test.gd"

const ART := preload("res://scripts/data/ArtManifest.gd")
const TICKET := "res://assets/ui/schedule/neutral-ticket-compact.svg"
const PORTRAIT := "res://tests/fixtures/art/placement-portrait-left.svg"

func before_each() -> void:
	assert_true(ART.reload_placements())

func after_each() -> void:
	ART.reload_placements()

func test_missing_unknown_and_non_image_assets_return_no_texture() -> void:
	assert_null(ART.get_texture("not.registered"))
	ART.set_overlay_info("", "missing", "res://art/absent.png", Vector2i.ZERO, "missing")
	assert_null(ART.get_texture("missing"))
	ART.set_overlay_info("", "script", "res://scripts/data/ArtManifest.gd", Vector2i.ZERO, "preview")
	assert_null(ART.get_texture("script"))
	assert_has(ART.get_missing_art_report(), "missing")

func test_real_imported_texture_obeys_fixed_ui_dimensions() -> void:
	ART.set_overlay_info("", "ticket", TICKET, Vector2i(24, 24), "preview")
	assert_not_null(ART.get_texture("ticket", Vector2i(24, 24)))
	assert_null(ART.get_texture("ticket", Vector2i(64, 64)))
	assert_eq(ART.get_expected_size(TICKET), Vector2i(24, 24))
	assert_does_not_have(ART.get_missing_art_report(), "ticket")

func test_solo_and_pair_art_are_fixed_and_return_detached_lists() -> void:
	var solo := ART.get_scene_art("dating.solo.priscilla.day1.pre_challenge")
	var after := ART.get_scene_art("dating.solo.priscilla.day1.post_challenge")
	assert_eq(solo, after)
	assert_eq(solo.portraits, ["character.priscilla"])
	var pair := ART.get_scene_art("dating.group.priscilla_lavinia.day2.pre_challenge")
	assert_eq(pair.portraits, ["character.priscilla", "character.lavinia"])
	pair.portraits.clear()
	assert_eq(ART.get_scene_art("dating.group.priscilla_lavinia.day2.pre_challenge").portraits.size(), 2)

func test_all_registered_entries_have_explicit_scene_rows_and_known_asset_ids() -> void:
	var entries: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/manifests/dialogic_entries.json"))
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ART.PLACEMENTS_PATH))
	for entry: Dictionary in entries.entries:
		assert_has(catalog.scenes, entry.entry_id)
		var scene := ART.get_scene_art(entry.entry_id)
		assert_has(catalog.assets, scene.background)
		assert_lte(scene.portraits.size(), 2)
		for portrait: String in scene.portraits:
			assert_has(catalog.assets, portrait)
		if not scene.cg.is_empty():
			assert_has(catalog.assets, scene.cg)
	assert_eq(ART.get_scene_art("not.registered"), {"background":"", "portraits":[], "cg":""})

func test_exact_ending_entries_keep_distinct_cg_bindings() -> void:
	var full := ART.get_scene_art("ending.priscilla.observer.full")
	var residue := ART.get_scene_art("ending.priscilla.observer.residue")
	assert_ne(full.cg, residue.cg)
	assert_eq(full.portraits, residue.portraits)
	assert_ne(ART.get_scene_art("ending.alone.normal").cg, ART.get_scene_art("ending.alone.dark_mode").cg)

func test_preview_overrides_do_not_write_catalog_and_reload_discards_them() -> void:
	var original := FileAccess.get_file_as_string(ART.PLACEMENTS_PATH)
	ART.set_overlay_info("character", "priscilla", PORTRAIT, Vector2i(320, 448), "preview")
	assert_not_null(ART.get_texture("character.priscilla"))
	assert_eq(FileAccess.get_file_as_string(ART.PLACEMENTS_PATH), original)
	assert_true(ART.reload_placements())
	assert_ne(ART.get_asset_path("character.priscilla"), PORTRAIT)

func test_legacy_intro_art_uses_runtime_ids_instead_of_editor_resource_aliases() -> void:
	var timelines: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/manifests/timelines.json"))
	for id: String in ["opening.day1", "tutorial.desktop_day1"]:
		var found := false
		for record: Dictionary in timelines.records:
			if record.id == id: found = true
		assert_true(found)
		assert_false(ART.get_scene_art(id).background.is_empty())
